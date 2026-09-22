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
  });

  final String name;
  final CommandSafetyLevel safetyLevel;
  final String description;
  final String promptSummary;
  final String gatewayScreenPrompt;

  bool get isConfirmable =>
      safetyLevel == CommandSafetyLevel.requiresUserConfirmation;
  bool get isReadOnly => safetyLevel == CommandSafetyLevel.readOnly;
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
  };

  static bool requiresConfirmation(String actionType) {
    return registry[actionType]?.isConfirmable ?? false;
  }

  static AssistantToolMetadata? getMetadata(String actionType) {
    return registry[actionType];
  }

  static Map<String, dynamic> buildToolResponseContext(String actionName) {
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
      };
    }
    return {
      'status': 'success',
      'requiresConfirmation': false,
      'result': meta.promptSummary,
    };
  }
}
