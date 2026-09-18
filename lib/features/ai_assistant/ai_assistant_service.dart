import '../../data/models/ticket_model.dart';

class AiResponseMessage {
  const AiResponseMessage({
    required this.text,
    this.actionLabel,
    this.actionType,
  });

  final String text;
  final String? actionLabel;
  final String? actionType; // 'book_ticket', 'track_bus', 'share_location', 'search_route'
}

class AiAssistantService {
  AiAssistantService();

  AiResponseMessage processQuery(String query, {Ticket? activeTicket}) {
    final lower = query.toLowerCase().trim();

    if (lower.contains('next bus') || lower.contains('schedule') || lower.contains('timing') || lower.contains('when')) {
      return const AiResponseMessage(
        text: 'Bus TN-23-BUS-42 is departing from VIT Main Gate towards Katpadi Railway Station in 4 minutes. Average ETA to Katpadi is 18 mins.',
        actionLabel: 'View Route & Live GPS',
        actionType: 'search_route',
      );
    }

    if (lower.contains('track') || lower.contains('where is my bus') || lower.contains('bus location') || lower.contains('live location')) {
      if (activeTicket != null) {
        return AiResponseMessage(
          text: 'Your active bus ${activeTicket.busId} is currently traveling at 32 km/h near Green Circle. Next stop: ${activeTicket.destination.name}.',
          actionLabel: 'Open Live GPS Map',
          actionType: 'track_bus',
        );
      } else {
        return const AiResponseMessage(
          text: 'You do not have an active ticket. Please purchase a bus ticket to enable real-time bus tracking and emergency safety features.',
          actionLabel: 'Book Ticket Now',
          actionType: 'book_ticket',
        );
      }
    }

    if (lower.contains('fare') || lower.contains('price') || lower.contains('ticket cost') || lower.contains('discount') || lower.contains('student')) {
      return const AiResponseMessage(
        text: 'BusBuddy fares for the VIT corridor:\n• General Pass: ₹20\n• Student Pass: ₹10 (50% discount)\n• Senior Citizen Pass: ₹14 (30% discount)',
        actionLabel: 'Book Ticket Now',
        actionType: 'book_ticket',
      );
    }

    if (lower.contains('share') || lower.contains('emergency') || lower.contains('contact') || lower.contains('safety')) {
      if (activeTicket != null) {
        return const AiResponseMessage(
          text: 'Emergency safety features are active. You can share your live bus tracking link with trusted contacts via WhatsApp or SMS.',
          actionLabel: 'Share Location Now',
          actionType: 'share_location',
        );
      } else {
        return const AiResponseMessage(
          text: 'To use emergency safety sharing, you must have an active bus ticket.',
          actionLabel: 'Book Ticket Now',
          actionType: 'book_ticket',
        );
      }
    }

    if (lower.contains('book') || lower.contains('buy') || lower.contains('pass')) {
      return const AiResponseMessage(
        text: 'You can book an instant digital pass for the VIT Vellore corridor with QR code validation.',
        actionLabel: 'Open Ticket Booking',
        actionType: 'book_ticket',
      );
    }

    // Default Fallback
    return const AiResponseMessage(
      text: 'I am BusBuddy AI Assistant. I can help you check bus ETAs, book tickets, track live bus locations, and share emergency trip updates.',
      actionLabel: 'Book Ticket Now',
      actionType: 'book_ticket',
    );
  }
}
