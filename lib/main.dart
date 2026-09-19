import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_json_store.dart';
import 'data/datasources/local_transport_data_source.dart';
import 'data/repositories/emergency_contact_repository.dart';
import 'data/models/transport_models.dart' as models;
import 'data/repositories/ticket_repository.dart';
import 'data/repositories/transport_repository.dart';
import 'features/ai_assistant/floating_ai_assistant_overlay.dart';
import 'features/home/home_page.dart';
import 'features/journey/journey_controller.dart';
import 'features/route_details/route_details_page.dart';
import 'features/adaptive_ui/adaptive_ui_service.dart';
import 'features/tickets/ticket_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalJsonStore.open();
  await AppSettingsController.instance.hydrate(store);
  await EmergencyContactRepository.instance.hydrate(store);
  await AdaptiveUiService.instance.hydrate(store);

  // ── Composition root ─────────────────────────────────────────────────
  final locator = AppServiceLocator.instance;
  if (locator.ticketRepository is LocalTicketRepository) {
    await (locator.ticketRepository as LocalTicketRepository).hydrate(store);
  }
  final journeyController = locator.journeyController;
  final repository = locator.transportRepository;
  final ticketController = locator.ticketController;

  runApp(
    MyApp(
      journeyController: journeyController,
      repository: repository,
      ticketController: ticketController,
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({
    super.key,
    required this.journeyController,
    required this.repository,
    required this.ticketController,
  });

  final JourneyController journeyController;
  final TransportRepository repository;
  final TicketController ticketController;

  // Stable navigator key — created once for the lifetime of MyApp.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final settings = AppSettingsController.instance;
        return MaterialApp(
          title: 'BusBuddy',
          navigatorKey: _navigatorKey,
          theme: settings.isHighContrast ? AppTheme.highContrast : AppTheme.dark,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final platformScale = media.textScaler.scale(1.0);
            final effectiveScale = (platformScale * settings.textScaleFactor).clamp(0.85, 2.0);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(effectiveScale),
              ),
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => Stack(
                      children: [
                        child!,
                        FloatingAiAssistantOverlay(
                          navigatorKey: _navigatorKey,
                          ticketController: ticketController,
                          repository: repository,
                          journeyController: journeyController,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
      home: HomePage(
        controller: journeyController,
        repository: repository,
        ticketController: ticketController,
        onRouteSelected: (routeId) {
          // Resolve the route from the repository and push the details page.
          final originId = journeyController.state.origin?.id;
          final destinationId = journeyController.state.destination?.id;
          if (originId == null || destinationId == null) return;

          final routes = repository.findRoutes(
            originId: originId,
            destinationId: destinationId,
          );
          models.Route? resolved;
          for (final r in routes) {
            if (r.id == routeId) {
              resolved = r;
              break;
            }
          }
          resolved ??= routes.isNotEmpty ? routes.first : null;
          if (resolved == null) return;

          journeyController.selectRoute(resolved);

          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => RouteDetailsPage(
                controller: journeyController,
                repository: repository,
              ),
            ),
          );
        },
      ),
    );
      },
    );
  }
}
