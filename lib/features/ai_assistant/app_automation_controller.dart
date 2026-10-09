import 'package:flutter/foundation.dart';

import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../../domain/assistant/assistant_command.dart';
import '../journey/journey_controller.dart';

/// Result of a single Live tool call applied to the booking draft.
class AutomationResult {
  const AutomationResult({
    required this.spokenHint,
    required this.displayText,
    this.actionType,
    this.actionLabel,
    this.missingSlots = const [],
    this.isComplete = false,
    this.needsGateway = false,
  });

  final String spokenHint;
  final String displayText;
  final String? actionType;
  final String? actionLabel;
  final List<String> missingSlots;
  final bool isComplete;
  final bool needsGateway;
}

/// Voice task-agent driver for the book-ticket flow (Live Gemini only).
///
/// Holds a pre-confirmation [booking draft]: trip + bus + passenger + payment.
/// All setters are read-only (no ticket issued, no money moved). Only the
/// user tapping confirm in [BookingCheckoutDialog] issues a ticket —
/// preserving Astra BUS-P0-05.
class AppAutomationController extends ChangeNotifier {
  AppAutomationController({this.repository, this.journeyController});

  TransportRepository? repository;
  JourneyController? journeyController;

  Stop? origin;
  Stop? destination;
  Route? route;
  String busId = '18B';
  bool hasCustomBus = false;
  PassengerType passengerType = PassengerType.general;
  String passengerName = 'Passenger';
  PaymentMethod paymentMethod = PaymentMethod.upi;

  void attach({
    TransportRepository? repo,
    JourneyController? journeyCtrl,
  }) {
    if (repo != null) repository = repo;
    if (journeyCtrl != null) journeyController = journeyCtrl;
  }

  /// Main entry: applies a Live function call (name + args) to the draft.
  AutomationResult handleToolCall(String name, Map<String, dynamic>? args) {
    switch (name) {
      case 'set_trip':
        return _applyTrip(args);
      case 'select_bus':
        return _applyBus(args);
      case 'set_passenger':
        return _applyPassenger(args);
      case 'set_payment':
        return _applyPayment(args);
      case 'confirm_booking':
        return bookingReadiness();
      default:
        return const AutomationResult(
          spokenHint: 'Got it.',
          displayText: 'Action noted.',
        );
    }
  }

  // ── Slot setters ───────────────────────────────────────────────────

  AutomationResult _applyTrip(Map<String, dynamic>? args) {
    final repo = repository;
    final oRaw = (args?['origin'] as String?)?.trim();
    final dRaw = (args?['destination'] as String?)?.trim();
    if (repo != null) {
      if (oRaw != null && oRaw.isNotEmpty) {
        origin = _resolveStop(repo, oRaw) ?? origin;
      }
      if (dRaw != null && dRaw.isNotEmpty) {
        destination = _resolveStop(repo, dRaw) ?? destination;
      }
      // Corridor default: bare "Katpadi" means the railway terminus.
      if (destination == null && dRaw != null && dRaw.isEmpty) {
        destination = _resolveStop(repo, 'Katpadi Railway Station');
      }
      _refreshRoute();
      _driveJourney();
    } else {
      // Repository-less fallback (unit tests): synthesize minimal stops.
      if (oRaw != null && oRaw.isNotEmpty) {
        origin = Stop(id: _slug(oRaw), name: oRaw, area: 'Vellore');
      }
      if (dRaw != null && dRaw.isNotEmpty) {
        destination = Stop(id: _slug(dRaw), name: dRaw, area: 'Katpadi');
      }
    }
    notifyListeners();
    final missing = _missingSlots();
    if (missing.isEmpty) {
      return AutomationResult(
        spokenHint:
            'Trip set from ${origin!.name} to ${destination!.name}. Which bus would you like — 18B in 4 minutes or 12A in 12 minutes?',
        displayText:
            '${origin!.name} → ${destination!.name}\nTap a bus or tell me which one.',
        actionType: 'search_route',
        actionLabel: AssistantCommandGateway.getMetadata('search_route')
                ?.gatewayScreenPrompt ??
            '🚌 View Route Options',
      );
    }
    return AutomationResult(
      spokenHint:
          'Got it. ${missing.contains('destination') ? 'Where would you like to go?' : 'Where are you starting from?'}',
      displayText: 'Trip partially set.\nMissing: ${missing.join(', ')}.',
      missingSlots: missing,
    );
  }

  AutomationResult _applyBus(Map<String, dynamic>? args) {
    var raw = (args?['busId'] as String?)?.trim() ?? '';
    raw = raw
        .replaceAll(RegExp(r'^bus\s*', caseSensitive: false), '')
        .trim();
    if (raw.isNotEmpty) {
      final upper = raw.toUpperCase();
      if (upper.startsWith('BUS')) {
        busId = raw;
      } else if (RegExp(r'\d').hasMatch(upper)) {
        busId = 'Bus $upper'.replaceAll(
          RegExp(r'^bus bus ', caseSensitive: false),
          'Bus ',
        );
      } else {
        busId = raw;
      }
      // Normalize common forms: "18b" -> "Bus 18B", "Bus 18B" stays.
      if (!busId.toLowerCase().startsWith('bus ')) {
        busId = 'Bus ${raw.toUpperCase()}';
      }
      hasCustomBus = true;
    }
    notifyListeners();
    final missing = _missingSlots();
    if (missing.isNotEmpty) {
      return AutomationResult(
        spokenHint: 'Bus $busId noted. ${missing.join(', ')} still needed.',
        displayText: 'Bus: $busId\nStill missing: ${missing.join(', ')}.',
        missingSlots: missing,
      );
    }
    return AutomationResult(
      spokenHint:
          'Bus $busId selected. Is that a student, senior or general ticket?',
      displayText: 'Bus: $busId selected.\nNext: passenger type.',
      actionType: 'book_ticket',
      actionLabel: AssistantCommandGateway.getMetadata('book_ticket')
              ?.gatewayScreenPrompt ??
          '🎫 Review & Confirm Booking',
    );
  }

  bool _passengerExplicit = false;

  AutomationResult _applyPassenger(Map<String, dynamic>? args) {
    final typeRaw =
        (args?['type'] as String?)?.trim().toLowerCase() ?? '';
    final nameRaw = (args?['name'] as String?)?.trim() ?? '';
    if (typeRaw.contains('student')) {
      passengerType = PassengerType.student;
      _passengerExplicit = true;
    } else if (typeRaw.contains('senior')) {
      passengerType = PassengerType.senior;
      _passengerExplicit = true;
    } else if (typeRaw.contains('general') ||
        typeRaw.contains('adult') ||
        typeRaw.contains('regular')) {
      passengerType = PassengerType.general;
      _passengerExplicit = true;
    } else if (typeRaw.isEmpty && nameRaw.isNotEmpty) {
      _passengerExplicit = true;
    }
    if (nameRaw.isNotEmpty) {
      passengerName = nameRaw;
      _passengerExplicit = true;
    }
    notifyListeners();
    final missing = _missingSlots();
    if (missing.isNotEmpty) {
      return AutomationResult(
        spokenHint:
            '${_passengerLabel()} ticket noted. ${missing.join(', ')} still needed.',
        displayText:
            'Passenger: ${_passengerLabel()}\nStill missing: ${missing.join(', ')}.',
        missingSlots: missing,
      );
    }
    return AutomationResult(
      spokenHint:
          '${_passengerLabel()} ticket noted. UPI, card or wallet for payment?',
      displayText: 'Passenger: ${_passengerLabel()}.\nNext: payment method.',
      actionType: 'book_ticket',
      actionLabel: AssistantCommandGateway.getMetadata('book_ticket')
              ?.gatewayScreenPrompt ??
          '🎫 Review & Confirm Booking',
    );
  }

  AutomationResult _applyPayment(Map<String, dynamic>? args) {
    final raw = (args?['method'] as String?)?.trim().toLowerCase() ?? '';
    if (raw.contains('upi')) {
      paymentMethod = PaymentMethod.upi;
    } else if (raw.contains('card') ||
        raw.contains('credit') ||
        raw.contains('debit')) {
      paymentMethod = PaymentMethod.card;
    } else if (raw.contains('wallet')) {
      paymentMethod = PaymentMethod.wallet;
    }
    notifyListeners();
    final readiness = bookingReadiness();
    if (readiness.isComplete) return readiness;
    return AutomationResult(
      spokenHint: 'Payment set to ${_paymentLabel()}. ${readiness.spokenHint}',
      displayText: 'Payment: ${_paymentLabel()}.\n${readiness.displayText}',
      missingSlots: readiness.missingSlots,
    );
  }

  /// Readiness check for confirm_booking: complete or lists missing slots.
  AutomationResult bookingReadiness() {
    final missing = _missingSlots();
    if (missing.isNotEmpty) {
      final ask = missing.contains('trip')
          ? 'Tell me your origin and destination first.'
          : missing.contains('passenger')
              ? 'Is that a student, senior or general ticket?'
              : 'UPI, card or wallet for payment?';
      return AutomationResult(
        spokenHint: ask,
        displayText: 'Almost ready.\nMissing: ${missing.join(', ')}.',
        missingSlots: missing,
      );
    }
    final concession =
        passengerType == PassengerType.general ? '' : ' with 40% concession';
    return AutomationResult(
      spokenHint:
          'I have your ${passengerType.name} ticket$concession on $busId from ${origin!.name} to ${destination!.name}, paying by ${_paymentLabel()}. I am opening the confirmation screen — please review and tap confirm.',
      displayText:
          '${origin!.name} → ${destination!.name}\n$busId • ${_passengerLabel()}$concession • ${_paymentLabel()}\nReview and confirm below.',
      actionType: 'confirm_booking',
      actionLabel: AssistantCommandGateway.getMetadata('confirm_booking')
              ?.gatewayScreenPrompt ??
          '🎫 Review & Confirm Booking',
      isComplete: true,
      needsGateway: true,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  List<String> _missingSlots() {
    final missing = <String>[];
    if (origin == null || destination == null) missing.add('trip');
    if (!_passengerExplicit) missing.add('passenger');
    return missing;
  }

  String _passengerLabel() {
    final base = passengerType.name[0].toUpperCase() +
        passengerType.name.substring(1);
    return passengerName == 'Passenger' ? base : '$base • $passengerName';
  }

  String _paymentLabel() {
    switch (paymentMethod) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.wallet:
        return 'Wallet';
      case PaymentMethod.netBanking:
        return 'NetBanking';
    }
  }

  void _refreshRoute() {
    final repo = repository;
    if (repo == null || origin == null || destination == null) return;
    final routes = repo.findRoutes(
      originId: origin!.id,
      destinationId: destination!.id,
    );
    route = routes.isNotEmpty ? routes.first : null;
  }

  void _driveJourney() {
    final journey = journeyController;
    if (journey == null || origin == null || destination == null) return;
    journey.selectOrigin(origin!);
    journey.selectDestination(destination!);
    if (route != null) journey.selectRoute(route!);
  }

  Stop? _resolveStop(TransportRepository repo, String query) {
    final q = query.trim();
    if (q.isEmpty) return null;
    // 1. Exact id match.
    final byId = repo.getStop(_slug(q));
    if (byId != null) return byId;
    final direct = repo.getStop(q);
    if (direct != null) return direct;
    // 2. Name search (case-insensitive substring).
    final hits = repo.findStops(q);
    if (hits.isEmpty) return null;
    final lower = q.toLowerCase();
    for (final s in hits) {
      if (s.name.toLowerCase() == lower) return s;
    }
    // Prefer the railway terminus for bare "katpadi".
    if (lower == 'katpadi') {
      for (final s in hits) {
        if (s.id == 'katpadi-railway-station') return s;
      }
    }
    return hits.first;
  }

  String _slug(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }
}
