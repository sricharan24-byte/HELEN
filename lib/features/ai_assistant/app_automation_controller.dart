import 'package:flutter/foundation.dart';

import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';
import '../../data/repositories/transport_repository.dart';
import '../../domain/assistant/assistant_command.dart';
import '../journey/journey_controller.dart';

/// Where a booking-draft slot's value came from. Readiness rules depend on
/// this: only [BookingValueSource.passenger] and [BookingValueSource.profileDefault]
/// can satisfy a required slot — an app fallback or a merely staged recent-trip
/// suggestion must never masquerade as a passenger choice (spec §"Booking
/// dialogue and decision rules").
enum BookingValueSource { unset, passenger, profileDefault, recentActivity, appDefault }

/// Result of a single Live tool call applied to the booking draft.
class AutomationResult {
  const AutomationResult({
    required this.spokenHint,
    required this.displayText,
    this.success = true,
    this.actionType,
    this.actionLabel,
    this.missingSlots = const [],
    this.isComplete = false,
    this.needsGateway = false,
  });

  final String spokenHint;
  final String displayText;

  /// Whether the tool call actually applied (or validly evaluated). A
  /// not-ready booking reports success=false with its missing slots, so the
  /// session can never serialize a "done" envelope for an unconfirmed draft.
  final bool success;

  final String? actionType;
  final String? actionLabel;
  final List<String> missingSlots;
  final bool isComplete;
  final bool needsGateway;

  /// JSON-safe fields for the Gemini tool response: success, user-facing
  /// summary, missing slots, and whether the confirmation gateway is needed.
  Map<String, Object?> toToolResultJson() => {
    'success': success,
    'summary': spokenHint,
    'missingSlots': List<String>.from(missingSlots),
    'requiresConfirmation': needsGateway,
    'draftComplete': isComplete,
  };
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

  /// Provenance for every booking slot. Starts [BookingValueSource.unset]:
  /// the constructor fallbacks above (Bus 18B, UPI, general) are display
  /// defaults only and can never satisfy readiness.
  final Map<String, BookingValueSource> slotSources = {
    'origin': BookingValueSource.unset,
    'destination': BookingValueSource.unset,
    'bus': BookingValueSource.unset,
    'passengerName': BookingValueSource.unset,
    'passengerType': BookingValueSource.unset,
    'paymentMethod': BookingValueSource.unset,
  };

  /// The passenger's opted-in preferred name, used to ADDRESS them in spoken
  /// replies. Never copied into [passengerName] — the ticket passenger is an
  /// explicit choice, not an assumption.
  String profilePreferredName = '';

  /// Whether a recent-trip suggestion is staged in the draft awaiting the
  /// passenger's acceptance.
  bool _hasStagedSuggestion = false;

  /// The six-slot draft in the exact shape [BookingContextBuilder] consumes:
  /// every slot serialized as `{value, source}` and nothing else.
  Map<String, Object?> bookingDraftSnapshot() => {
    'slots': {
      'origin': {
        'value': origin?.name ?? '',
        'source': slotSources['origin']!.name,
      },
      'destination': {
        'value': destination?.name ?? '',
        'source': slotSources['destination']!.name,
      },
      'bus': {'value': busId, 'source': slotSources['bus']!.name},
      'passengerName': {
        'value': passengerName,
        'source': slotSources['passengerName']!.name,
      },
      'passengerType': {
        'value': passengerType.name,
        'source': slotSources['passengerType']!.name,
      },
      'paymentMethod': {
        'value': _paymentLabel(),
        'source': slotSources['paymentMethod']!.name,
      },
    },
  };

  /// Applies the passenger's saved profile defaults. The preferred name is
  /// kept for addressing only; the default passenger type prefills the slot
  /// only when the passenger has not chosen one, marked
  /// [BookingValueSource.profileDefault] so the assistant can disclose it.
  void applyProfileDefaults({
    required String preferredName,
    required PassengerType? passengerType,
  }) {
    profilePreferredName = preferredName.trim();
    if (passengerType != null &&
        slotSources['passengerType'] == BookingValueSource.unset) {
      this.passengerType = passengerType;
      slotSources['passengerType'] = BookingValueSource.profileDefault;
    }
    notifyListeners();
  }

  /// Stages at most one recent-route suggestion into the draft, marked
  /// [BookingValueSource.recentActivity]. Staged values never overwrite a
  /// passenger choice or a profile default, and never satisfy readiness —
  /// the passenger must accept (or restate) them.
  void stageRecentTripSuggestion({
    required Stop origin,
    required Stop destination,
    required String busId,
  }) {
    _stageSlot('origin', origin);
    _stageSlot('destination', destination);
    _stageSlot('bus', busId);
    _hasStagedSuggestion = true;
    notifyListeners();
  }

  void _stageSlot(String slot, Object value) {
    final current = slotSources[slot];
    if (current == BookingValueSource.passenger ||
        current == BookingValueSource.profileDefault) {
      return;
    }
    switch (slot) {
      case 'origin':
        origin = value as Stop;
      case 'destination':
        destination = value as Stop;
      case 'bus':
        busId = value as String;
    }
    slotSources[slot] = BookingValueSource.recentActivity;
  }

  /// Passenger acceptance of the staged suggestion: promotes every
  /// recentActivity slot to a passenger choice so readiness can count it.
  void acceptStagedSuggestion() {
    if (!_hasStagedSuggestion) return;
    for (final slot in slotSources.keys) {
      if (slotSources[slot] == BookingValueSource.recentActivity) {
        slotSources[slot] = BookingValueSource.passenger;
      }
    }
    _hasStagedSuggestion = false;
    notifyListeners();
  }

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
        final resolved = _resolveStop(repo, oRaw);
        if (resolved != null) {
          origin = resolved;
          slotSources['origin'] = BookingValueSource.passenger;
        }
      }
      if (dRaw != null && dRaw.isNotEmpty) {
        final resolved = _resolveStop(repo, dRaw);
        if (resolved != null) {
          destination = resolved;
          slotSources['destination'] = BookingValueSource.passenger;
        }
      }
      // Corridor default: bare "Katpadi" means the railway terminus. This is
      // an app assumption, not a passenger choice — it cannot satisfy
      // readiness, so the assistant still asks where exactly they are going.
      if (destination == null && dRaw != null && dRaw.isEmpty) {
        final fallback = _resolveStop(repo, 'Katpadi Railway Station');
        if (fallback != null) {
          destination = fallback;
          slotSources['destination'] = BookingValueSource.appDefault;
        }
      }
      _refreshRoute();
      _driveJourney();
    } else {
      // Repository-less fallback (unit tests): synthesize minimal stops.
      if (oRaw != null && oRaw.isNotEmpty) {
        origin = Stop(id: _slug(oRaw), name: oRaw, area: 'Vellore');
        slotSources['origin'] = BookingValueSource.passenger;
      }
      if (dRaw != null && dRaw.isNotEmpty) {
        destination = Stop(id: _slug(dRaw), name: dRaw, area: 'Katpadi');
        slotSources['destination'] = BookingValueSource.passenger;
      }
    }
    notifyListeners();
    final tripReady =
        _slotSatisfied('origin') && _slotSatisfied('destination');
    final missing = _missingSlots();
    if (tripReady) {
      return AutomationResult(
        spokenHint:
            'Trip set from ${origin!.name} to ${destination!.name}. Which bus would you like — 18B in 4 minutes or 12A in 12 minutes?',
        displayText:
            '${origin!.name} → ${destination!.name}\nTap a bus or tell me which one.',
        missingSlots: missing,
        actionType: 'search_route',
        actionLabel: AssistantCommandGateway.getMetadata('search_route')
                ?.gatewayScreenPrompt ??
            '🚌 View Route Options',
      );
    }
    return AutomationResult(
      spokenHint:
          'Got it. ${_slotSatisfied('origin') ? 'Where would you like to go?' : 'Where are you starting from?'}',
      displayText: 'Trip partially set.\nMissing: ${_missingSlots().join(', ')}.',
      missingSlots: _missingSlots(),
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
      slotSources['bus'] = BookingValueSource.passenger;
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

  AutomationResult _applyPassenger(Map<String, dynamic>? args) {
    final typeRaw =
        (args?['type'] as String?)?.trim().toLowerCase() ?? '';
    final nameRaw = (args?['name'] as String?)?.trim() ?? '';
    if (typeRaw.contains('student')) {
      passengerType = PassengerType.student;
      slotSources['passengerType'] = BookingValueSource.passenger;
    } else if (typeRaw.contains('senior')) {
      passengerType = PassengerType.senior;
      slotSources['passengerType'] = BookingValueSource.passenger;
    } else if (typeRaw.contains('general') ||
        typeRaw.contains('adult') ||
        typeRaw.contains('regular')) {
      passengerType = PassengerType.general;
      slotSources['passengerType'] = BookingValueSource.passenger;
    }
    if (nameRaw.isNotEmpty) {
      passengerName = nameRaw;
      slotSources['passengerName'] = BookingValueSource.passenger;
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
    } else {
      // Unrecognized method: do not advance the draft, do not claim success.
      return AutomationResult(
        success: false,
        spokenHint:
            "I didn't catch that payment method. UPI, card or wallet?",
        displayText: 'Payment method not recognized. Please say UPI, card or wallet.',
      );
    }
    slotSources['paymentMethod'] = BookingValueSource.passenger;
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
  /// Requires an explicitly chosen trip, bus, passenger type, and payment —
  /// app fallbacks and staged suggestions never satisfy it.
  AutomationResult bookingReadiness() {
    final missing = _missingSlots();
    if (missing.isNotEmpty) {
      final ask = missing.contains('trip')
          ? 'Tell me your origin and destination first.'
          : missing.contains('bus')
              ? 'Which bus would you like?'
              : missing.contains('passenger')
                  ? 'Is that a student, senior or general ticket?'
                  : 'Which payment method — UPI, card or wallet?';
      return AutomationResult(
        success: false,
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

  /// A slot can satisfy readiness only when the passenger chose it (or an
  /// explicit profile default filled it). Unset, suggested, and app-default
  /// values never count.
  bool _slotSatisfied(String slot) =>
      slotSources[slot] == BookingValueSource.passenger ||
      slotSources[slot] == BookingValueSource.profileDefault;

  List<String> _missingSlots() {
    final missing = <String>[];
    if (!_slotSatisfied('origin') || !_slotSatisfied('destination')) {
      missing.add('trip');
    }
    if (!_slotSatisfied('bus')) missing.add('bus');
    if (!_slotSatisfied('passengerType')) missing.add('passenger');
    if (!_slotSatisfied('paymentMethod')) missing.add('payment');
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
