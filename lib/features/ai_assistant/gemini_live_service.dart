import '../../core/di/service_locator.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../data/datasources/local_transport_data_source.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/transport_models.dart';

enum GeminiLiveIntent {
  searchRoute,
  trackBus,
  remainingStops,
  bookTicket,
  emergencySos,
  openSaved,
  customizeHome,
  resetHome,
  unknown,
}

class GeminiLiveResponse {
  const GeminiLiveResponse({
    required this.userTranscript,
    required this.spokenResponse,
    required this.displayText,
    required this.intent,
    this.actionType,
    this.actionData,
  });

  final String userTranscript;
  final String spokenResponse;
  final String displayText;
  final GeminiLiveIntent intent;
  final String? actionType;
  final Map<String, dynamic>? actionData;
}

class GeminiLiveService {
  const GeminiLiveService();

  /// Reads API key from AppSettingsController or via --dart-define=GEMINI_API_KEY at build/runtime.
  static const String defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static String get apiKey => AppSettingsController.instance.geminiApiKey.isNotEmpty
      ? AppSettingsController.instance.geminiApiKey
      : defaultApiKey;

  /// Returns true if a live Google Gemini API key is configured.
  bool get isLiveApiKeyConfigured => apiKey.isNotEmpty;

  GeminiLiveResponse processVoiceQuery(
    String query, {
    Ticket? activeTicket,
    List<Stop>? availableStops,
  }) {
    final lower = query.toLowerCase().trim();

    // 1. Where is my bus? / Live Tracking
    if (lower.contains('where is my bus') ||
        lower.contains('track') ||
        lower.contains('bus location') ||
        lower.contains('where is the bus')) {
      if (activeTicket != null) {
        final stopName = activeTicket.destination.name;
        final speed = 32;
        return GeminiLiveResponse(
          userTranscript: query,
          spokenResponse:
              'Your active bus ${activeTicket.busId} is traveling at $speed km/h near Green Circle. Next stop is $stopName.',
          displayText:
              'Bus ${activeTicket.busId} • 32 km/h near Green Circle\nNext stop: $stopName',
          intent: GeminiLiveIntent.trackBus,
          actionType: 'track_bus',
          actionData: {'ticketId': activeTicket.id},
        );
      } else {
        return GeminiLiveResponse(
          userTranscript: query,
          spokenResponse:
              'You do not have an active bus ticket right now. Would you like me to open ticket booking for the VIT Katpadi corridor?',
          displayText:
              'No active ticket found.\nTap below to book a ticket and enable real-time tracking.',
          intent: GeminiLiveIntent.bookTicket,
          actionType: 'book_ticket',
        );
      }
    }

    // 2. How many stops are left? / Remaining Stops
    if (lower.contains('how many stops') ||
        lower.contains('stops left') ||
        lower.contains('remaining stops') ||
        lower.contains('next stop')) {
      if (activeTicket != null) {
        final nextStop = _nextStopAfterBoarding(
          originId: activeTicket.origin.id,
          destinationId: activeTicket.destination.id,
        );
        return GeminiLiveResponse(
          userTranscript: query,
          spokenResponse:
              'There are 3 stops remaining on your trip to ${activeTicket.destination.name}. Next stop is ${nextStop.name} in approximately 2 minutes.',
          displayText:
              '3 stops remaining to ${activeTicket.destination.name}\nNext stop: ${nextStop.name} (~2 min)',
          intent: GeminiLiveIntent.remainingStops,
          actionType: 'track_bus',
        );
      } else {
        return GeminiLiveResponse(
          userTranscript: query,
          spokenResponse:
              'You are not currently on an active journey. Select a route to start tracking stops.',
          displayText:
              'No active journey in progress.\nSearch a route or book a ticket to start.',
          intent: GeminiLiveIntent.searchRoute,
          actionType: 'search_route',
        );
      }
    }

    // 3. Find a bus / Route search
    if (lower.contains('find a bus') ||
        lower.contains('find route') ||
        lower.contains('search route') ||
        lower.contains('route') ||
        lower.contains('buses to') ||
        lower.contains('vit to katpadi')) {
      return GeminiLiveResponse(
        userTranscript: query,
        spokenResponse:
            'Found 3 available buses for the VIT Main Gate to Katpadi Railway Station corridor. Bus 18B is arriving in 4 minutes for 20 rupees.',
        displayText:
            'Buses available: VIT → Katpadi\n• Bus 18B: Arriving in 4 min (₹20)\n• Bus 12A: In 12 min (₹20)',
        intent: GeminiLiveIntent.searchRoute,
        actionType: 'search_route',
        actionData: const {'origin': 'VIT Main Gate', 'destination': 'Katpadi Railway Station'},
      );
    }

    // 4. Book ticket / Buy pass
    if (lower.contains('book') || lower.contains('buy') || lower.contains('pass')) {
      return GeminiLiveResponse(
        userTranscript: query,
        spokenResponse:
            'Opening digital ticket booking. General fare is 20 rupees, and Student or Senior citizen concession is 12 rupees.',
        displayText:
            'Opening Ticket Booking Checkout...\nSelect passenger type & payment method.',
        intent: GeminiLiveIntent.bookTicket,
        actionType: 'book_ticket',
      );
    }

    // 5. Emergency SOS / Share location
    if (lower.contains('emergency') ||
        lower.contains('sos') ||
        lower.contains('share my location') ||
        lower.contains('danger') ||
        lower.contains('call 112') ||
        lower.contains('call police') ||
        lower.contains('emergency help')) {
      return GeminiLiveResponse(
        userTranscript: query,
        spokenResponse:
            'Initiating emergency safety broadcast. Generating live tracking link to send to your trusted contacts.',
        displayText:
            '🚨 Emergency Broadcast Triggered\nLive tracking link generated for trusted emergency contacts.',
        intent: GeminiLiveIntent.emergencySos,
        actionType: 'share_location',
      );
    }

    // 6. Reset Home Screen Layout (Specific command checked before general home)
    if (lower.contains('reset') && (lower.contains('home') || lower.contains('layout') || lower.contains('card')) ||
        lower.contains('reset home') ||
        lower.contains('reset layout') ||
        lower.contains('restore default cards') ||
        lower.contains('restore home')) {
      AppSettingsController.instance.resetHomeScreenLayout();
      return GeminiLiveResponse(
        userTranscript: query,
        spokenResponse:
            'I have reset your home screen layout and restored all default feature cards.',
        displayText:
            'Home screen reset to default layout.\nAll default feature cards restored.',
        intent: GeminiLiveIntent.resetHome,
        actionType: 'reset_home',
      );
    }

    // 7. Customize Home Screen / Layout (Specific command checked before general home)
    if (lower.contains('customize home') ||
        lower.contains('change home') ||
        lower.contains('reorder home') ||
        lower.contains('customize layout') ||
        lower.contains('home screen layout')) {
      return GeminiLiveResponse(
        userTranscript: query,
        spokenResponse:
            'Opening Home Screen customization. You can rearrange cards, toggle features, or reset to defaults.',
        displayText:
            'Customize Home Screen\n• Rearrange features\n• Show or hide cards',
        intent: GeminiLiveIntent.customizeHome,
        actionType: 'customize_home',
      );
    }

    // 8. Saved places / Favourite route / Go home
    if (lower.contains('saved') ||
        lower.contains('favourite') ||
        lower.contains('favorite') ||
        lower.contains('take me home') ||
        lower.contains('go home') ||
        lower.contains('my home') ||
        lower == 'home') {
      return GeminiLiveResponse(
        userTranscript: query,
        spokenResponse:
            'Opening your saved places and favourite routes. Your primary saved destination is Katpadi Railway Station.',
        displayText:
            'Saved Places:\n• Katpadi Railway Station\n• VIT Main Gate',
        intent: GeminiLiveIntent.openSaved,
        actionType: 'open_saved',
      );
    }

    // Default Fallback
    return GeminiLiveResponse(
      userTranscript: query,
      spokenResponse:
          'I am listening! You can ask me: "Find a bus from VIT to Katpadi", "Where is my bus?", "How many stops left?", or "Book a ticket".',
      displayText:
          'BusBuddy Conversational Assistant\nSpoken natural voice control active.',
      intent: GeminiLiveIntent.unknown,
    );
  }

  /// Resolves the first real stop the bus reaches after the boarding stop on
  /// the route connecting origin to destination.
  Stop _nextStopAfterBoarding({
    required String originId,
    required String destinationId,
  }) {
    final dataSource = AppServiceLocator.instance.transportDataSource;
    for (final route in dataSource.allRoutes) {
      final o = route.orderedStopIds.indexOf(originId);
      final d = route.orderedStopIds.indexOf(destinationId);
      if (o != -1 && d != -1 && o < d && o + 1 < route.orderedStopIds.length) {
        return dataSource.stopById(route.orderedStopIds[o + 1]) ??
            destinationFallback;
      }
    }
    return destinationFallback;
  }

  static const Stop destinationFallback = Stop(
    id: 'katpadi-railway-station',
    name: 'Katpadi Railway Station',
    area: 'Katpadi',
  );
}
