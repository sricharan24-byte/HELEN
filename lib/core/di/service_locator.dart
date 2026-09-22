import 'dart:async';

import '../../data/datasources/local_transport_data_source.dart';
import '../../data/repositories/emergency_contact_repository.dart';
import '../../data/repositories/ticket_repository.dart';
import '../../data/repositories/transport_repository.dart';
import '../../features/ai_assistant/floating_assistant_controller.dart';
import '../../features/journey/journey_controller.dart';
import '../../features/tickets/ticket_controller.dart';
import 'async_disposable.dart';

/// Centralized Dependency Injection container and Service Locator for BusBuddy.
///
/// Guarantees a single source of truth across all screens, preventing duplicate
/// data sources, divergent bus tracking engines, and fragmented ticket states.
class AppServiceLocator implements AsyncDisposable {
  AppServiceLocator._();

  static final AppServiceLocator instance = AppServiceLocator._();

  int _generation = 0;
  int get generation => _generation;

  bool _isResetting = false;
  Future<void>? _activeResetFuture;

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

  void _checkState() {
    if (_isResetting) {
      throw StateError(
          'AppServiceLocator is undergoing teardown / reset; instantiation is forbidden.');
    }
  }

  LocalTransportDataSource get transportDataSource {
    _checkState();
    return _customDataSource ?? (_defaultDataSource ??= LocalTransportDataSource());
  }

  TransportRepository get transportRepository {
    _checkState();
    return _customTransportRepository ??
        (_defaultTransportRepository ??=
            LocalTransportRepository(dataSource: transportDataSource));
  }

  TicketRepository get ticketRepository {
    _checkState();
    return _customTicketRepository ??
        (_defaultTicketRepository ??= LocalTicketRepository());
  }

  TicketController get ticketController {
    _checkState();
    return _customTicketController ??
        (_defaultTicketController ??= TicketController(ticketRepository));
  }

  JourneyController get journeyController {
    _checkState();
    return _customJourneyController ??
        (_defaultJourneyController ??= JourneyController(transportRepository));
  }

  EmergencyContactRepository get emergencyContactRepository {
    _checkState();
    return _customContactRepository ?? EmergencyContactRepository.instance;
  }

  /// Injects overrides during testing.
  void overrideForTesting({
    LocalTransportDataSource? dataSource,
    TransportRepository? transportRepo,
    TicketRepository? ticketRepo,
    TicketController? ticketCtrl,
    JourneyController? journeyCtrl,
    EmergencyContactRepository? contactRepo,
  }) {
    _checkState();
    if (dataSource != null) _customDataSource = dataSource;
    if (transportRepo != null) _customTransportRepository = transportRepo;
    if (ticketRepo != null) _customTicketRepository = ticketRepo;
    if (ticketCtrl != null) _customTicketController = ticketCtrl;
    if (journeyCtrl != null) _customJourneyController = journeyCtrl;
    if (contactRepo != null) _customContactRepository = contactRepo;
  }

  @override
  Future<void> dispose() => resetForTesting();

  /// Resets test overrides back to clean defaults, ensuring all active
  /// movement engines and timers are safely terminated per Astra P0.2 / BUS-P0-04.
  Future<void> resetForTesting() async {
    if (_activeResetFuture != null) {
      await _activeResetFuture;
      return;
    }

    _isResetting = true;
    _generation++;
    final completer = Completer<void>();
    _activeResetFuture = completer.future;

    try {
      if (_defaultTransportRepository is AsyncDisposable) {
        await (_defaultTransportRepository as AsyncDisposable).dispose();
      } else if (_defaultTransportRepository is LocalTransportRepository) {
        await (_defaultTransportRepository as LocalTransportRepository).dispose();
      }
      if (_customTransportRepository is AsyncDisposable) {
        await (_customTransportRepository as AsyncDisposable).dispose();
      } else if (_customTransportRepository is LocalTransportRepository) {
        await (_customTransportRepository as LocalTransportRepository).dispose();
      }
      _defaultTransportRepository = null;
      _customTransportRepository = null;

      if (_defaultDataSource is AsyncDisposable) {
        await (_defaultDataSource as AsyncDisposable).dispose();
      }
      if (_customDataSource is AsyncDisposable) {
        await (_customDataSource as AsyncDisposable).dispose();
      }
      _customDataSource = null;
      _defaultDataSource = null;

      if (_defaultTicketRepository is AsyncDisposable) {
        await (_defaultTicketRepository as AsyncDisposable).dispose();
      }
      if (_customTicketRepository is AsyncDisposable) {
        await (_customTicketRepository as AsyncDisposable).dispose();
      }
      _customTicketRepository = null;
      _defaultTicketRepository = null;

      _customTicketController?.dispose();
      _defaultTicketController?.dispose();
      _customTicketController = null;
      _defaultTicketController = null;

      _customJourneyController?.dispose();
      _defaultJourneyController?.dispose();
      _customJourneyController = null;
      _defaultJourneyController = null;

      _customContactRepository = null;

      FloatingAssistantController.instance.resetForTesting();
    } finally {
      _isResetting = false;
      _activeResetFuture = null;
      completer.complete();
    }
  }
}
