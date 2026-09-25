/// Categorization of voice assistant tools and user commands into
/// read-only informational queries versus confirmable mutating commands
/// per Astra BUS-P0-05.
enum CommandSafetyLevel {
  readOnly,
  requiresUserConfirmation,
}

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
  bool get isReadOnly => safetyLevel == CommandSafetyLevel.readOnly;

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
      description: 'Opens the live GPS map tracker for the active bus route.',
      promptSummary: 'Live bus tracker is now open.',
      gatewayScreenPrompt: '📍 Open Live Bus Map',
    ),
    'search_route': AssistantToolMetadata(
      name: 'search_route',
      safetyLevel: CommandSafetyLevel.readOnly,
      description: 'Finds available buses and shows route options between origin and destination.',
      promptSummary: 'Route options and schedules are displayed.',
      gatewayScreenPrompt: '🚌 View Route Options',
    ),
    'open_saved': AssistantToolMetadata(
      name: 'open_saved',
      safetyLevel: CommandSafetyLevel.readOnly,
      description: 'Opens saved places like Home, College, or Hostel.',
      promptSummary: 'Saved places are open.',
      gatewayScreenPrompt: '⭐ Saved Places',
    ),
    'emergency_sos': AssistantToolMetadata(
      name: 'emergency_sos',
      safetyLevel: CommandSafetyLevel.requiresUserConfirmation,
      description:
          'Presents the emergency safety broadcast confirmation gateway on screen. Requires explicit passenger tap before transmitting alerts.',
      promptSummary:
          'Opening Emergency Safety Broadcast. Please tap confirm on your screen to notify contacts.',
      gatewayScreenPrompt: '🚨 Review & Confirm SOS',
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
    // Only confirm_booking is confirmable; it opens BookingCheckoutDialog.
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
          'Sets passenger type and optional name for the checkout. Student and senior get 40% concession.',
      promptSummary: 'Passenger details updated.',
      gatewayScreenPrompt: '🧾 Passenger Updated',
      parameters: {
        'type': {
          'type': 'string',
          'description': 'Passenger type: general, student, or senior',
        },
        'name': {
          'type': 'string',
          'description': 'Passenger display name (optional)',
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
    'confirm_booking': AssistantToolMetadata(
      name: 'confirm_booking',
      safetyLevel: CommandSafetyLevel.requiresUserConfirmation,
      description:
          'Opens the ticket booking confirmation gateway with the current trip, bus, passenger and payment pre-filled. Requires explicit passenger tap before payment is taken.',
      promptSummary:
          'Opening booking confirmation. Please review and confirm on your screen.',
      gatewayScreenPrompt: '🎫 Review & Confirm Booking',
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
