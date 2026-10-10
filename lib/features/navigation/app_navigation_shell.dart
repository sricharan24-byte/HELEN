import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/transport_models.dart' as models;
import '../../data/repositories/transport_repository.dart';
import '../home/home_page.dart';
import '../journey/journey_controller.dart';
import '../route_details/route_details_page.dart';
import '../tickets/ticket_controller.dart';

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({
    super.key,
    required this.controller,
    required this.repository,
    required this.ticketController,
  });

  final JourneyController controller;
  final TransportRepository repository;
  final TicketController ticketController;

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _navigatorObserver = _ShellNavigatorObserver(_onRouteChanged);
  bool _navigationRefreshScheduled = false;

  void _onRouteChanged() {
    if (!mounted || _navigationRefreshScheduled) return;
    _navigationRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationRefreshScheduled = false;
      if (mounted) setState(() {});
    });
  }

  void _showRouteDetails(String routeId) {
    final originId = widget.controller.state.origin?.id;
    final destinationId = widget.controller.state.destination?.id;
    if (originId == null || destinationId == null) return;

    final routes = widget.repository.findRoutes(
      originId: originId,
      destinationId: destinationId,
    );
    models.Route? route;
    for (final candidate in routes) {
      if (candidate.id == routeId) {
        route = candidate;
        break;
      }
    }
    route ??= routes.isNotEmpty ? routes.first : null;
    if (route == null) return;

    widget.controller.selectRoute(route);
    unawaited(
      _navigatorKey.currentState?.push(
        MaterialPageRoute<void>(
          builder: (_) => RouteDetailsPage(
            controller: widget.controller,
            repository: widget.repository,
          ),
        ),
      ),
    );
  }

  Future<void> _handleBack() async {
    await _navigatorKey.currentState?.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final activeNavigator = _navigatorKey.currentState;

    return PopScope<Object?>(
      canPop: !(activeNavigator?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: Navigator(
          key: _navigatorKey,
          observers: [_navigatorObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => HomePage(
              controller: widget.controller,
              repository: widget.repository,
              ticketController: widget.ticketController,
              onRouteSelected: _showRouteDetails,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellNavigatorObserver extends NavigatorObserver {
  _ShellNavigatorObserver(this.onRouteChanged);

  final VoidCallback onRouteChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onRouteChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onRouteChanged();
}
