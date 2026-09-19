import '../entities/ticket.dart';
import '../../transit/entities/stop.dart';
import '../../transit/entities/transit_route.dart';
import '../../core/result.dart';
import '../../core/failure.dart';

/// Pure-Dart abstract contract for ticket lifecycle management.
/// Decouples ticketing features from data storage and payment mechanisms.
abstract interface class ITicketRepository {
  /// All issued tickets ordered by recency.
  List<Ticket> get allTickets;

  /// The currently valid, unexpired ticket, if one exists.
  Ticket? get activeTicket;

  /// Whether the commuter possesses an active boarding pass.
  bool get hasActiveTicket;

  /// Books a new ticket using the unified fare engine.
  Future<Result<Ticket, Failure>> bookTicket({
    required Stop origin,
    required Stop destination,
    required TransitRoute route,
    required String passengerName,
    required PassengerType passengerType,
    required PaymentMethod paymentMethod,
    double? customFare,
  });

  /// Adds a pre-formed ticket (e.g. from restore or test fixtures).
  void addTicket(Ticket ticket);

  /// Cancels an active ticket by its identifier.
  void cancelTicket(String ticketId);
}
