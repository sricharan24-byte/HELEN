import '../../data/datasources/local_transport_data_source.dart';
import '../../data/repositories/emergency_contact_repository.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../data/repositories/transport_repository.dart';
import '../../features/journey/journey_controller.dart';
import '../../features/tickets/ticket_controller.dart';

/// Centralized Dependency Injection container and Service Locator for BusBuddy.
///
/// Guarantees a single source of truth across all screens, preventing duplicate
/// data sources, divergent bus tracking engines, and fragmented ticket states.
class AppServiceLocator {
  AppServiceLocator._();

  static final AppServiceLocator instance = AppServiceLocator._();

  LocalTransportDataSource? _customDataSource;
  TransportRepository? _customTransportRepository;
  TicketRepository? _customTicketRepository;
  TicketController? _customTicketController;
  JourneyController? _customJourneyController;
  EmergencyContactRepository? _customContactRepository;

  LocalTransportDataSource? _defaultDataSource;
  TransportRepository? _defaultTransportRepository;
  TicketRepository? _defaultTicketRepository;
  TicketController? _defaultTicketController;
  JourneyController? _defaultJourneyController;

  LocalTransportDataSource get transportDataSource =>
      _customDataSource ?? (_defaultDataSource ??= LocalTransportDataSource());

  TransportRepository get transportRepository =>
      _customTransportRepository ??
      (_defaultTransportRepository ??=
          LocalTransportRepository(dataSource: transportDataSource));

  TicketRepository get ticketRepository =>
      _customTicketRepository ??
      (_defaultTicketRepository ??= LocalTicketRepository());

  TicketController get ticketController =>
      _customTicketController ??
      (_defaultTicketController ??= TicketController(ticketRepository));

  JourneyController get journeyController =>
      _customJourneyController ??
      (_defaultJourneyController ??= JourneyController(transportRepository));

  EmergencyContactRepository get emergencyContactRepository =>
      _customContactRepository ?? EmergencyContactRepository.instance;

  /// Injects overrides during testing.
  void overrideForTesting({
    LocalTransportDataSource? dataSource,
    TransportRepository? transportRepo,
    TicketRepository? ticketRepo,
    TicketController? ticketCtrl,
    JourneyController? journeyCtrl,
    EmergencyContactRepository? contactRepo,
  }) {
    if (dataSource != null) _customDataSource = dataSource;
    if (transportRepo != null) _customTransportRepository = transportRepo;
    if (ticketRepo != null) _customTicketRepository = ticketRepo;
    if (ticketCtrl != null) _customTicketController = ticketCtrl;
    if (journeyCtrl != null) _customJourneyController = journeyCtrl;
    if (contactRepo != null) _customContactRepository = contactRepo;
  }

  /// Resets test overrides back to clean defaults.
  void resetForTesting() {
    _customDataSource = null;
    _customTransportRepository = null;
    _customTicketRepository = null;
    _customTicketController = null;
    _customJourneyController = null;
    _customContactRepository = null;
  }
}
