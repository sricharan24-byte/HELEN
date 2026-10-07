import 'dart:async';
import 'package:flutter/material.dart';

import 'core/a11y/enlarging_text_scaler.dart';
import 'core/di/service_locator.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/local_json_store.dart';
import 'data/repositories/emergency_contact_repository.dart';
import 'data/models/transport_models.dart' as models;
import 'data/repositories/transport_repository.dart';
import 'features/ai_assistant/ai_control_glow.dart';
import 'features/ai_assistant/wake_word_service.dart';
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
  final ticketController = locator.ticketController;
  await ticketController.hydrate(store);
  final journeyController = locator.journeyController;
  await journeyController.hydrate(store);
  final repository = locator.transportRepository;

  runApp(
    MyApp(
      journeyController: journeyController,
      repository: repository,
      ticketController: ticketController,
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.journeyController,
    required this.repository,
    required this.ticketController,
    this.navigatorKey,
  });

  final JourneyController journeyController;
  final TransportRepository repository;
  final TicketController ticketController;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GlobalKey<NavigatorState> _navigatorKey;

  @override
  void initState() {
    super.initState();
    _navigatorKey = widget.navigatorKey ?? GlobalKey<NavigatorState>();
    WakeWordService.instance.initialize(
      navigatorKey: _navigatorKey,
      ticketController: widget.ticketController,
      repository: widget.repository,
      journeyController: widget.journeyController,
    );
  }

  @override
  void dispose() {
    WakeWordService.instance.dispose();
    super.dispose();
  }

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
            // Astra BUS-P0-03: Strictly preserve platform non-linear TextScaler.
            // Never linearize via scale(1.0) and never downscale below system settings.
            final multiplier = settings.inAppEnlargementMultiplier;
            final effectiveScaler = multiplier > 1.0
                ? EnlargingTextScaler(media.textScaler, multiplier)
                : media.textScaler;
            return MediaQuery(
              data: media.copyWith(
                textScaler: effectiveScaler,
              ),
              // The AI glow frame sits above the navigator so it follows the
              // assistant across every screen it opens — top bar, bottom bar
              // and side rails glow with its current activity.
              child: Stack(
                children: [
                  child!,
                  const AiGlowFrame(),
                ],
              ),
            );
          },
          home: HomePage(
            controller: widget.journeyController,
            repository: widget.repository,
            ticketController: widget.ticketController,
            onRouteSelected: (routeId) {
              // Resolve the route from the repository and push the details page.
              final originId = widget.journeyController.state.origin?.id;
              final destinationId = widget.journeyController.state.destination?.id;
              if (originId == null || destinationId == null) return;

              final routes = widget.repository.findRoutes(
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

              widget.journeyController.selectRoute(resolved);

              unawaited(_navigatorKey.currentState?.push(
                MaterialPageRoute<void>(
                  builder: (_) => RouteDetailsPage(
                    controller: widget.journeyController,
                    repository: widget.repository,
                  ),
                ),
              ));
            },
          ),
        );
      },
    );
  }
}
