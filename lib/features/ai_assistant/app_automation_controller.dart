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
enum BookingValueSource {
  unset,
  passenger,
  profileDefault,
  recentActivity,
  appDefault,
}

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
    this.status,
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
  final String? status;

  /// JSON-safe fields for the Gemini tool response: success, user-facing
  /// summary, missing slots, and whether the confirmation gateway is needed.
  Map<String, Object?> toToolResultJson() => {
    'success': success,
    'summary': spokenHint,
    'missingSlots': List<String>.from(missingSlots),
    'requiresConfirmation': needsGateway,
    'draftComplete': isComplete,
    'draftReady': isComplete,
    'ticketIssued': false,
    'status': status ?? (isComplete ? 'draft_ready' : 'needs_clarification'),
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
  bool openMapAfterBooking = false;

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

  /// Applies the passenger's saved profile defaults. Both the preferred name
  /// and the default passenger type prefill their slots — but only when the
  /// passenger has not chosen a value — marked
  /// [BookingValueSource.profileDefault] so the assistant discloses them and
  /// the checkout shows them for review (owner decision, 2026-10-11: the
  /// ticket passenger name comes from the profile too; the earlier
  /// address-only rule kept leaving the name blank and the passenger had to
  /// restate it every time).
  void applyProfileDefaults({
    required String preferredName,
    required PassengerType? passengerType,
  }) {
    final name = preferredName.trim();
    profilePreferredName = name;
    if (passengerType != null &&
        slotSources['passengerType'] == BookingValueSource.unset) {
      this.passengerType = passengerType;
      slotSources['passengerType'] = BookingValueSource.profileDefault;
    }
    if (name.isNotEmpty &&
        slotSources['passengerName'] == BookingValueSource.unset) {
      passengerName = name;
      slotSources['passengerName'] = BookingValueSource.profileDefault;
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
    // Readiness requires a real route between the accepted stops; resolve it
    // now instead of leaving "route" missing after the passenger accepts.
    if (route == null && origin != null && destination != null) {
      final repo = repository;
      if (repo != null) {
        final routes = repo.findRoutes(
          originId: origin!.id,
          destinationId: destination!.id,
        );
        route = routes.isNotEmpty ? routes.first : null;
      }
    }
    _hasStagedSuggestion = false;
    notifyListeners();
  }

  /// Passenger rejects the staged suggestion: recentActivity slots revert to
  /// unset (values back to their fallbacks), so nothing was ever a choice.
  void dismissStagedSuggestion() {
    if (!_hasStagedSuggestion) return;
    if (slotSources['origin'] == BookingValueSource.recentActivity) {
      origin = null;
      slotSources['origin'] = BookingValueSource.unset;
    }
    if (slotSources['destination'] == BookingValueSource.recentActivity) {
      destination = null;
      slotSources['destination'] = BookingValueSource.unset;
    }
    if (slotSources['bus'] == BookingValueSource.recentActivity) {
      busId = '18B';
      hasCustomBus = false;
      slotSources['bus'] = BookingValueSource.unset;
    }
    _hasStagedSuggestion = false;
    notifyListeners();
  }

  /// Whether [slot] can satisfy readiness right now — a passenger choice or
  /// an explicit profile default. Public for the draft preview UI, which
  /// mirrors the same readiness rules the voice flow enforces.
  bool isSlotSatisfied(String slot) => _slotSatisfied(slot);

  /// The booking slots still missing for checkout, in guidance order.
  List<String> get missingBookingSlots => _missingSlots();

  void attach({TransportRepository? repo, JourneyController? journeyCtrl}) {
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
      case 'prepare_booking':
        return prepareBooking(args);
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
      final nextOrigin = oRaw != null && oRaw.isNotEmpty
          ? _resolveStop(repo, oRaw)
          : origin;
      Stop? nextDestination = dRaw != null && dRaw.isNotEmpty
          ? _resolveStop(repo, dRaw)
          : destination;
      // Corridor default: bare "Katpadi" means the railway terminus. This is
      // an app assumption, not a passenger choice — it cannot satisfy
      // readiness, so the assistant still asks where exactly they are going.
      final usesCorridorDefault =
          nextDestination == null && dRaw != null && dRaw.isEmpty;
      if (usesCorridorDefault) {
        nextDestination = _resolveStop(repo, 'Katpadi Railway Station');
      }
      final invalidStop = oRaw != null && oRaw.isNotEmpty && nextOrigin == null
          ? oRaw
          : dRaw != null && dRaw.isNotEmpty && nextDestination == null
          ? dRaw
          : null;
      if (invalidStop != null) {
        return AutomationResult(
          success: false,
          spokenHint:
              'I could not match $invalidStop to a stop. Which stop did you mean?',
          displayText: 'Stop not found. The booking draft was not changed.',
        );
      }
      final routes = nextOrigin != null && nextDestination != null
          ? repo.findRoutes(
              originId: nextOrigin.id,
              destinationId: nextDestination.id,
            )
          : const <Route>[];
      if (nextOrigin != null && nextDestination != null && routes.isEmpty) {
        return AutomationResult(
          success: false,
          spokenHint:
              'There is no listed route between those stops. Please choose another destination.',
          displayText: 'Route not found. The booking draft was not changed.',
        );
      }
      if (oRaw != null && oRaw.isNotEmpty) {
        origin = nextOrigin;
        slotSources['origin'] = BookingValueSource.passenger;
      }
      if (dRaw != null && dRaw.isNotEmpty) {
        destination = nextDestination;
        slotSources['destination'] = BookingValueSource.passenger;
      } else if (usesCorridorDefault) {
        destination = nextDestination;
        slotSources['destination'] = BookingValueSource.appDefault;
      }
      route = routes.isEmpty ? null : routes.first;
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
    final tripReady = _slotSatisfied('origin') && _slotSatisfied('destination');
    final missing = _missingSlots();
    if (tripReady) {
      return AutomationResult(
        spokenHint:
            'Trip set from ${origin!.name} to ${destination!.name}. I can check the listed bus options.',
        displayText:
            '${origin!.name} → ${destination!.name}\nTap a bus or tell me which one.',
        missingSlots: missing,
        actionType: 'search_route',
        actionLabel:
            AssistantCommandGateway.getMetadata(
              'search_route',
            )?.gatewayScreenPrompt ??
            '🚌 View Route Options',
      );
    }
    return AutomationResult(
      spokenHint:
          'Got it. ${_slotSatisfied('origin') ? 'Where would you like to go?' : 'Where are you starting from?'}',
      displayText:
          'Trip partially set.\nMissing: ${_missingSlots().join(', ')}.',
      missingSlots: _missingSlots(),
    );
  }

  AutomationResult _applyBus(Map<String, dynamic>? args) {
    var raw = (args?['busId'] as String?)?.trim() ?? '';
    raw = raw.replaceFirst(RegExp(r'^bus\s*', caseSensitive: false), '').trim();
    if (raw.isNotEmpty) {
      final normalized = raw.toUpperCase();
      final options = route == null
          ? const <BusDepartureOption>[]
          : repository?.availableBusesForRoute(route!.id) ??
                const <BusDepartureOption>[];
      if (!options.any((option) => option.busId == normalized)) {
        return AutomationResult(
          success: false,
          spokenHint:
              'Bus $normalized is not in the listed options for this route. Which listed bus would you like?',
          displayText: 'Bus not available for the selected route.',
        );
      }
      busId = normalized;
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
      actionLabel:
          AssistantCommandGateway.getMetadata(
            'book_ticket',
          )?.gatewayScreenPrompt ??
          '🎫 Review & Confirm Booking',
    );
  }

  AutomationResult _applyPassenger(Map<String, dynamic>? args) {
    final typeRaw = (args?['type'] as String?)?.trim().toLowerCase() ?? '';
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
      actionLabel:
          AssistantCommandGateway.getMetadata(
            'book_ticket',
          )?.gatewayScreenPrompt ??
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
        spokenHint: "I didn't catch that payment method. UPI, card or wallet?",
        displayText:
            'Payment method not recognized. Please say UPI, card or wallet.',
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
  /// Requires an explicitly chosen trip, bus, passenger name/type, and payment —
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
          : missing.contains('passenger name')
          ? 'What name should I put on the ticket?'
          : 'Which payment method — UPI, card or wallet?';
      return AutomationResult(
        success: false,
        spokenHint: ask,
        displayText: 'Almost ready.\nMissing: ${missing.join(', ')}.',
        missingSlots: missing,
      );
    }
    final concession = passengerType == PassengerType.general
        ? ''
        : ' with 40% concession';
    return AutomationResult(
      spokenHint:
          'I have your ${passengerType.name} ticket$concession on $busId from ${origin!.name} to ${destination!.name}, paying by ${_paymentLabel()}. I am opening the confirmation screen — please review and tap confirm.',
      displayText:
          '${origin!.name} → ${destination!.name}\n$busId • ${_passengerLabel()}$concession • ${_paymentLabel()}\nReview and confirm below.',
      actionType: 'confirm_booking',
      actionLabel:
          AssistantCommandGateway.getMetadata(
            'confirm_booking',
          )?.gatewayScreenPrompt ??
          '🎫 Review & Confirm Booking',
      isComplete: true,
      needsGateway: true,
      status: 'checkout_pending',
    );
  }

  /// Resolves and validates a compound booking request without changing the
  /// current draft until every supplied and required value is valid.
  AutomationResult prepareBooking(Map<String, dynamic>? args) {
    final repo = repository;
    if (repo == null) {
      return const AutomationResult(
        success: false,
        spokenHint: 'I cannot check the route right now. Please try again.',
        displayText: 'Transport data is unavailable.',
      );
    }

    final rawOrigin = args?['origin']?.toString().trim() ?? '';
    final rawDestination = args?['destination']?.toString().trim() ?? '';
    final nextOrigin = rawOrigin.isEmpty
        ? (_slotSatisfied('origin') ? origin : null)
        : _resolveStop(repo, rawOrigin);
    final nextDestination = rawDestination.isEmpty
        ? (_slotSatisfied('destination') ? destination : null)
        : _resolveStop(repo, rawDestination);
    final invalid = <String>[];
    if (rawOrigin.isNotEmpty && nextOrigin == null) invalid.add('origin stop');
    if (rawDestination.isNotEmpty && nextDestination == null) {
      invalid.add('destination stop');
    }

    final nextRoutes = nextOrigin != null && nextDestination != null
        ? repo.findRoutes(
            originId: nextOrigin.id,
            destinationId: nextDestination.id,
          )
        : const <Route>[];
    final nextRoute = nextRoutes.isNotEmpty ? nextRoutes.first : null;
    if (nextOrigin != null && nextDestination != null && nextRoute == null) {
      invalid.add('route');
    }

    final rawPreference =
        args?['busPreference']?.toString().trim().toLowerCase() ?? '';
    final rawBus = args?['busId']?.toString().trim() ?? '';
    final available = nextRoute == null
        ? const <BusDepartureOption>[]
        : repo.availableBusesForRoute(nextRoute.id);
    BusDepartureOption? selectedOption;
    if (rawPreference == 'earliest' ||
        rawPreference == 'soonest' ||
        rawPreference == 'first') {
      if (available.isEmpty) {
        invalid.add('available bus');
      } else {
        selectedOption = available.reduce(
          (a, b) => a.etaMinutes <= b.etaMinutes ? a : b,
        );
      }
    } else if (rawPreference.isNotEmpty) {
      invalid.add('bus preference');
    } else if (rawBus.isNotEmpty) {
      final normalized = rawBus
          .replaceFirst(RegExp(r'^bus\s*', caseSensitive: false), '')
          .trim()
          .toUpperCase();
      for (final option in available) {
        if (option.busId == normalized) selectedOption = option;
      }
      if (selectedOption == null) invalid.add('listed bus');
    } else if (busId.isNotEmpty && _slotSatisfied('bus')) {
      for (final option in available) {
        if (option.busId == busId) selectedOption = option;
      }
    }

    final rawType =
        args?['passengerType']?.toString().trim().toLowerCase() ?? '';
    PassengerType? nextType;
    if (rawType.isEmpty) {
      if (_slotSatisfied('passengerType')) nextType = passengerType;
    } else if (rawType.contains('student')) {
      nextType = PassengerType.student;
    } else if (rawType.contains('senior')) {
      nextType = PassengerType.senior;
    } else if (rawType.contains('general') ||
        rawType.contains('adult') ||
        rawType.contains('regular')) {
      nextType = PassengerType.general;
    } else {
      invalid.add('passenger type');
    }

    final rawName =
        (args?['passengerName'] ?? args?['name'])?.toString().trim() ?? '';
    final nextName = rawName.isNotEmpty
        ? rawName
        : _slotSatisfied('passengerName')
        ? passengerName.trim()
        : '';
    if (rawName.isNotEmpty && rawName.length > 80) {
      invalid.add('passenger name');
    }

    final rawPayment =
        args?['paymentMethod']?.toString().trim().toLowerCase() ?? '';
    PaymentMethod? nextPayment;
    if (rawPayment.isEmpty) {
      if (_slotSatisfied('paymentMethod')) nextPayment = paymentMethod;
    } else if (rawPayment.contains('upi')) {
      nextPayment = PaymentMethod.upi;
    } else if (rawPayment.contains('card') ||
        rawPayment.contains('credit') ||
        rawPayment.contains('debit')) {
      nextPayment = PaymentMethod.card;
    } else if (rawPayment.contains('wallet')) {
      nextPayment = PaymentMethod.wallet;
    } else {
      invalid.add('payment method');
    }
    if (args != null &&
        args.containsKey('openMapAfterBooking') &&
        args['openMapAfterBooking'] is! bool) {
      invalid.add('map request');
    }

    final missing = <String>[];
    if (nextOrigin == null || nextDestination == null) {
      missing.add('origin and destination');
    }
    if (nextRoute == null && nextOrigin != null && nextDestination != null) {
      // An invalid route is reported above, not as a missing value.
    }
    if (selectedOption == null) missing.add('bus preference or bus');
    if (nextType == null) missing.add('passenger type');
    if (nextName.isEmpty) missing.add('passenger name');
    if (nextPayment == null) missing.add('payment method');
    final missingUnique = missing.toSet().toList();
    if (invalid.isNotEmpty || missingUnique.isNotEmpty) {
      final details = [...invalid, ...missingUnique].join(', ');
      return AutomationResult(
        success: false,
        spokenHint: invalid.isNotEmpty
            ? 'I could not verify ${invalid.join(', ')}. ${missingUnique.isEmpty ? 'Please check those details.' : 'I still need ${missingUnique.join(', ')}.'}'
            : 'I still need ${missingUnique.join(', ')} before I can open checkout.',
        displayText:
            'Booking not prepared. Please provide or correct: $details.',
        missingSlots: missingUnique,
        status: 'needs_clarification',
      );
    }

    origin = nextOrigin;
    destination = nextDestination;
    route = nextRoute;
    busId = selectedOption!.busId;
    hasCustomBus = true;
    passengerType = nextType!;
    passengerName = nextName;
    paymentMethod = nextPayment!;
    for (final slot in [
      'origin',
      'destination',
      'bus',
      'passengerName',
      'passengerType',
      'paymentMethod',
    ]) {
      slotSources[slot] = BookingValueSource.passenger;
    }
    _driveJourney();
    notifyListeners();
    openMapAfterBooking = args?['openMapAfterBooking'] == true;
    return AutomationResult(
      spokenHint:
          'Your ${_passengerLabel()} trip from ${origin!.name} to ${destination!.name} on bus $busId is ready for checkout. The listed bus time is a demo estimate. No ticket or payment has been issued yet.',
      displayText:
          '${origin!.name} → ${destination!.name}\n$busId • ${_passengerLabel()} • ${_paymentLabel()}\nReady for checkout; ticket not issued.',
      isComplete: true,
      needsGateway: true,
      actionType: 'confirm_booking',
      actionLabel:
          AssistantCommandGateway.getMetadata(
            'confirm_booking',
          )?.gatewayScreenPrompt ??
          '🎫 Review Booking',
      status: 'draft_ready',
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
    if (origin != null && destination != null && route == null) {
      missing.add('route');
    }
    if (!_slotSatisfied('bus')) missing.add('bus');
    if (!_slotSatisfied('passengerName')) missing.add('passenger name');
    if (!_slotSatisfied('passengerType')) missing.add('passenger');
    if (!_slotSatisfied('paymentMethod')) missing.add('payment');
    return missing;
  }

  String _passengerLabel() {
    final base =
        passengerType.name[0].toUpperCase() + passengerType.name.substring(1);
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
    final normalized = q
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
    if (normalized == 'bello fort') return repo.getStop('vat-vellore-fort');
    // 1. Exact id match.
    final byId = repo.getStop(_slug(q));
    if (byId != null) return byId;
    final direct = repo.getStop(q);
    if (direct != null) return direct;
    // 2. Exact name match only. Partial search hits must not silently choose
    // the first stop with a similar name.
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
    return null;
  }

  String _slug(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }
}
