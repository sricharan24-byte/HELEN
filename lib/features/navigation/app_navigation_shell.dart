import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/transport_models.dart' as models;
import '../../data/repositories/transport_repository.dart';
import '../home/home_page.dart';
import '../journey/journey_controller.dart';
import '../route_details/route_details_page.dart';
import '../tickets/my_tickets_page.dart';
import '../tickets/ticket_booking_suite_page.dart';
import '../tickets/ticket_controller.dart';
import 'more_page.dart';

/// Four-destination shell (Home / Plan / Tickets / More).
///
/// Each destination owns a nested [Navigator], so detail pages open inside the
/// selected destination's stack, tab switching preserves in-progress state, and
/// system Back pops the active stack first, then returns to Home, and exits
/// only from the Home root.
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
  static const int _homeIndex = 0;
  static const int _planIndex = 1;
  static const int _ticketsIndex = 2;
  static const int _moreIndex = 3;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  /// One observer per destination — the framework asserts a
  /// [NavigatorObserver] is attached to a single Navigator.
  late final List<_ShellNavigatorObserver> _navigatorObservers = List.generate(
    4,
    (_) => _ShellNavigatorObserver(_onRouteChanged),
  );

  /// Destinations build on first visit; the [IndexedStack] then keeps their
  /// navigator (and its state) alive for the rest of the session, so a booking
  /// form or ticket tab is never recreated by switching tabs.
  final Set<int> _visited = {_homeIndex};
  int _selectedIndex = _homeIndex;
  bool _navigationRefreshScheduled = false;

  GlobalKey<NavigatorState> get _activeNavigatorKey =>
      _navigatorKeys[_selectedIndex];

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
      _navigatorKeys[_homeIndex].currentState?.push(
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
    final navigator = _activeNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      await navigator.maybePop();
      return;
    }
    if (_selectedIndex != _homeIndex) {
      setState(() => _selectedIndex = _homeIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);
    final activeCanPop = _activeNavigatorKey.currentState?.canPop() ?? false;

    return PopScope<Object?>(
      canPop: !activeCanPop && _selectedIndex == _homeIndex,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _destination(
              _homeIndex,
              (_) => HomePage(
                controller: widget.controller,
                repository: widget.repository,
                ticketController: widget.ticketController,
                onRouteSelected: _showRouteDetails,
              ),
            ),
            _destination(
              _planIndex,
              (_) => TicketBookingSuitePage(
                ticketController: widget.ticketController,
                journeyController: widget.controller,
                showBackButton: false,
              ),
            ),
            _destination(
              _ticketsIndex,
              (_) => MyTicketsPage(
                ticketController: widget.ticketController,
                repository: widget.repository,
                showBackButton: false,
              ),
            ),
            _destination(
              _moreIndex,
              (_) => MorePage(
                repository: widget.repository,
                ticketController: widget.ticketController,
              ),
            ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: colors.surface,
              elevation: 0,
              indicatorColor: colors.actionPrimary.withValues(alpha: 0.16),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? colors.actionPrimary
                      : colors.textSecondary,
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? colors.actionPrimary
                      : colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                if (index == _selectedIndex) return;
                setState(() {
                  _selectedIndex = index;
                  _visited.add(index);
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.directions_bus_outlined),
                  selectedIcon: Icon(Icons.directions_bus),
                  label: 'Plan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.confirmation_number_outlined),
                  selectedIcon: Icon(Icons.confirmation_number),
                  label: 'Tickets',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz),
                  label: 'More',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destination(int index, WidgetBuilder builder) {
    if (!_visited.contains(index)) return const SizedBox.shrink();
    return Navigator(
      key: _navigatorKeys[index],
      observers: [_navigatorObservers[index]],
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: builder),
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
