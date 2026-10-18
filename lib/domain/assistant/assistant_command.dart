/// Categorization of voice assistant tools and user commands into
/// read-only informational queries versus confirmable mutating commands
/// per Astra BUS-P0-05.
enum CommandSafetyLevel { readOnly, requiresUserConfirmation }

class AssistantToolMetadata {
  const AssistantToolMetadata({
    required this.name,
    required this.safetyLevel,
    required this.description,
    required this.promptSummary,
    required this.gatewayScreenPrompt,
    this.parameters = const {},
    this.requiredParams = const [],
  });

  final String name;
  final CommandSafetyLevel safetyLevel;
  final String description;
  final String promptSummary;
  final String gatewayScreenPrompt;

  /// OpenAPI-style JSON Schema properties for Gemini Live function calling.
  /// e.g. {'origin': {'type': 'string', 'description': '...'}, ...}
  final Map<String, Map<String, String>> parameters;
  final List<String> requiredParams;

  bool get isConfirmable =>
      safetyLevel == CommandSafetyLevel.requiresUserConfirmation;

  /// Serializes to a Gemini Live / REST functionDeclaration entry.
  Map<String, dynamic> toFunctionDeclaration() {
    final Map<String, dynamic> decl = {
      'name': name,
      'description': description,
    };
    if (parameters.isNotEmpty) {
      decl['parameters'] = {
        'type': 'object',
        'properties': parameters,
        if (requiredParams.isNotEmpty) 'required': requiredParams,
      };
    }
    return decl;
  }
}

class AssistantCommandGateway {
  static const Map<String, AssistantToolMetadata> registry = {
    'track_bus': AssistantToolMetadata(
      name: 'track_bus',
      safetyLevel: CommandSafetyLevel.readOnly,
      description:
          'Opens the live GPS map for the active ticket when the passenger asks to open, show, or view the map or track the bus. If no active ticket exists, explain that tracking requires one.',
      promptSummary: 'Live bus tracker is now open.',
      gatewayScreenPrompt: '📍 Open Live Bus Map',
    ),
    'search_route': AssistantToolMetadata(
      name: 'search_route',
      safetyLevel: CommandSafetyLevel.readOnly,
      description:
          'Finds available buses and shows route options between origin and destination. Saved places are one-tap chips inside route search and booking.',
      promptSummary: 'Route options and schedules are displayed.',
      gatewayScreenPrompt: '🚌 View Route Options',
    ),
    'emergency_sos': AssistantToolMetadata(
      name: 'emergency_sos',
      safetyLevel: CommandSafetyLevel.requiresUserConfirmation,
      description:
          'Opens the emergency location sharing screen. Requires explicit passenger confirmation and a recipient choice before any message is sent.',
      promptSummary: 'Opening emergency location sharing for review.',
      gatewayScreenPrompt: 'Review emergency location sharing',
    ),
    'share_location': AssistantToolMetadata(
      name: 'share_location',
      safetyLevel: CommandSafetyLevel.requiresUserConfirmation,
      description:
          'Presents the live location sharing gateway on screen. Requires user confirmation before transmitting coordinates.',
      promptSummary:
          'Opening location sharing. Please review and confirm on your screen to share.',
      gatewayScreenPrompt: '📍 Review & Share Location',
    ),
    'book_ticket': AssistantToolMetadata(
      name: 'book_ticket',
      safetyLevel: CommandSafetyLevel.requiresUserConfirmation,
      description:
          'Presents the ticket booking and payment checkout gateway. Requires user route review and payment approval.',
      promptSummary:
          'Opening digital ticket booking. Please review your route and confirm booking.',
      gatewayScreenPrompt: '🎫 Review & Confirm Booking',
    ),
    // ── Voice task-agent booking tools (Live Gemini only, Chunk 41) ──
    // Read-only slot setters drive JourneyController + checkout pre-fill.
    // Booking tools prepare a draft; checkout is the ticket-creation source
    // of truth.
    'set_trip': AssistantToolMetadata(
      name: 'set_trip',
      safetyLevel: CommandSafetyLevel.readOnly,
      description:
          'Sets the trip origin and destination stops for booking. Resolves stop names like VIT Main Gate or Katpadi Railway Station.',
      promptSummary: 'Trip route updated.',
      gatewayScreenPrompt: '🗺️ Trip Updated',
      parameters: {
        'origin': {
          'type': 'string',
          'description': 'Origin stop name or id, e.g. VIT Main Gate',
        },
        'destination': {
          'type': 'string',
          'description':
              'Destination stop name or id, e.g. Katpadi Railway Station',
        },
      },
    ),
    'select_bus': AssistantToolMetadata(
      name: 'select_bus',
      safetyLevel: CommandSafetyLevel.readOnly,
      description:
          'Selects a bus for the active trip, e.g. Bus 18B. Must be called after set_trip.',
      promptSummary: 'Bus selected.',
      gatewayScreenPrompt: '🚌 Bus Selected',
      parameters: {
        'busId': {
          'type': 'string',
          'description': 'Bus identifier, e.g. 18B or Bus 18B',
        },
      },
    ),
    'set_passenger': AssistantToolMetadata(
      name: 'set_passenger',
      safetyLevel: CommandSafetyLevel.readOnly,
      description:
          'Sets passenger type and name for the checkout. Student and senior get 40% concession; the passenger name is required before checkout.',
      promptSummary: 'Passenger details updated.',
      gatewayScreenPrompt: '🧾 Passenger Updated',
      parameters: {
        'type': {
          'type': 'string',
          'description': 'Passenger type: general, student, or senior',
        },
        'name': {
          'type': 'string',
          'description': 'Required passenger display name',
        },
      },
    ),
    'set_payment': AssistantToolMetadata(
      name: 'set_payment',
      safetyLevel: CommandSafetyLevel.readOnly,
      description: 'Sets payment method for the checkout.',
      promptSummary: 'Payment method updated.',
      gatewayScreenPrompt: '💳 Payment Updated',
      parameters: {
        'method': {
          'type': 'string',
          'description': 'Payment method: upi, card, or wallet',
        },
      },
    ),
    'prepare_booking': AssistantToolMetadata(
      name: 'prepare_booking',
      safetyLevel: CommandSafetyLevel.readOnly,
      description:
          'Atomically prepares one complete ticket request. Provide every value the passenger stated. Use busPreference earliest to select the soonest listed demo estimate. This never issues a ticket or processes payment.',
      promptSummary: 'Booking request checked.',
      gatewayScreenPrompt: '🎫 Review Booking',
      parameters: {
        'origin': {'type': 'string', 'description': 'Exact origin stop name'},
        'destination': {
          'type': 'string',
          'description':
              'Exact destination stop name; Vellore Fort may be recognized as Bello Fort',
        },
        'busPreference': {
          'type': 'string',
          'description':
              'Use earliest when the passenger asks for the first/earliest bus',
        },
        'busId': {'type': 'string', 'description': 'Explicit available bus id'},
        'passengerType': {
          'type': 'string',
          'description': 'Student, senior, or general',
        },
        'passengerName': {'type': 'string', 'description': 'Passenger name'},
        'paymentMethod': {
          'type': 'string',
          'description': 'UPI, card, or wallet',
        },
        'openMapAfterBooking': {
          'type': 'boolean',
          'description':
              'True only when the passenger asked to open the map after ticket creation',
        },
      },
    ),
    'confirm_booking': AssistantToolMetadata(
      name: 'confirm_booking',
      safetyLevel: CommandSafetyLevel.requiresUserConfirmation,
      description:
          'Opens the demo ticket checkout with the current trip, bus, passenger and payment choice pre-filled. Ticket creation may follow the passenger confirmation; no real payment is processed.',
      promptSummary:
          'Opening booking confirmation. Please review and confirm on your screen.',
      gatewayScreenPrompt: '🎫 Review & Confirm Booking',
    ),
    // ── Booking personalization (read-only context retrieval) ──────────
    // Only after a clear booking intent: returns the opted-in profile,
    // communication preferences, saved places, recent trips, and the current
    // draft with slot provenance. Read-only, no arguments.
    'get_booking_context': AssistantToolMetadata(
      name: 'get_booking_context',
      safetyLevel: CommandSafetyLevel.readOnly,
      description:
          'Loads the passenger\u2019s booking context: preferred name and default passenger type (only if saved), communication preferences, saved places, up to three recent trips, and the current booking draft showing which values the passenger already chose. Call ONLY once the passenger clearly wants to book a ticket, and only once per booking attempt; do not call for general questions.',
      promptSummary: 'Booking context loaded.',
      gatewayScreenPrompt: '🧾 Booking Context Loaded',
    ),
  };

  static bool requiresConfirmation(String actionType) {
    return registry[actionType]?.isConfirmable ?? false;
  }

  /// Slot-filling protocol tools for the voice task agent. These turns are
  /// machine protocol, not user-facing speech: the UI must never speak their
  /// turn text (neither partial nor default), otherwise the protocol turn's
  /// TTS overlaps the follow-up answer's voice saying the same words.
  static const Set<String> silentProtocolActions = {
    'set_trip',
    'select_bus',
    'set_passenger',
    'set_payment',
    'prepare_booking',
    'get_booking_context',
  };

  static bool isSilentProtocol(String? actionType) =>
      actionType != null && silentProtocolActions.contains(actionType);

  static AssistantToolMetadata? getMetadata(String actionType) {
    return registry[actionType];
  }

  static Map<String, dynamic> buildToolResponseContext(
    String actionName, [
    Map<String, dynamic>? args,
  ]) {
    final meta = registry[actionName];
    if (meta == null) {
      return {
        'status': 'success',
        'requiresConfirmation': false,
        'result': 'Action presented on the passenger screen.',
      };
    }
    if (meta.isConfirmable) {
      return {
        'status': 'requires_confirmation',
        'requiresConfirmation': true,
        'result':
            'Confirmation gateway screen opened. Explicit user confirmation is strictly required before execution.',
        if (args != null && args.isNotEmpty) 'appliedArgs': args,
      };
    }
    return {
      'status': 'success',
      'requiresConfirmation': false,
      'result': meta.promptSummary,
      if (args != null && args.isNotEmpty) 'appliedArgs': args,
    };
  }
}
