/// Route search page — origin/destination selection and route results.
library;

import 'package:flutter/material.dart';

import '../../core/a11y/announcement_coordinator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/tokens/app_spacing.dart';
import '../../core/tokens/status_level.dart';
import '../../data/models/transport_models.dart' as models;
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';

/// A page for choosing origin and destination stops, then searching routes.
///
/// Shows prominent controls with semantic labels, accessible 48dp touch targets,
/// semantic tokens, and announcement coordinator integration per Astra Step 2.3.
class RouteSearchPage extends StatefulWidget {
  const RouteSearchPage({
    super.key,
    required this.controller,
    required this.repository,
    required this.onRouteSelected,
  });

  final JourneyController controller;
  final TransportRepository repository;

  /// Called when the user taps a route result.
  final void Function(String routeId) onRouteSelected;

  @override
  State<RouteSearchPage> createState() => _RouteSearchPageState();
}

class _RouteSearchPageState extends State<RouteSearchPage> {
  List<models.Route> _results = [];

  JourneyController get _ctrl => widget.controller;

  bool get _canSearch =>
      _ctrl.state.origin != null && _ctrl.state.destination != null;

  // ── Stop picker ──────────────────────────────────────────────────────

  Future<void> _pickStop({required bool isOrigin}) async {
    final selected = await showModalBottomSheet<models.Stop>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _StopPickerSheet(repository: widget.repository),
    );

    if (selected != null && mounted) {
      if (isOrigin) {
        _ctrl.selectOrigin(selected);
        AnnouncementCoordinator.instance.announce(
          'Selected starting stop: ${selected.name}.',
          priority: AnnouncementPriority.low,
        );
      } else {
        _ctrl.selectDestination(selected);
        AnnouncementCoordinator.instance.announce(
          'Selected destination stop: ${selected.name}.',
          priority: AnnouncementPriority.low,
        );
      }
      setState(() {});
    }
  }

  // ── Search ───────────────────────────────────────────────────────────

  void _search() {
    final routes = _ctrl.searchRoutes();
    setState(() {
      _results = routes;
    });
    AnnouncementCoordinator.instance.announce(
      'Found ${routes.length} routes connecting ${_ctrl.state.origin?.name} to ${_ctrl.state.destination?.name}.',
      priority: AnnouncementPriority.normal,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        final state = _ctrl.state;

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: const Text('Route Search'),
            backgroundColor: colors.background,
            foregroundColor: colors.textPrimary,
            elevation: 0,
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Stop selectors ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Origin
                      Semantics(
                        label: 'Choose starting stop',
                        button: true,
                        excludeSemantics: true,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
                              foregroundColor: colors.textPrimary,
                              side: BorderSide(color: colors.border, width: colors.isHighContrast ? 2 : 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                            ),
                            onPressed: () => _pickStop(isOrigin: true),
                            icon: Icon(Icons.trip_origin, size: 20, color: colors.actionPrimary),
                            label: Text(
                              state.origin?.name ?? 'Choose starting stop',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Destination
                      Semantics(
                        label: 'Choose destination stop',
                        button: true,
                        excludeSemantics: true,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
                              foregroundColor: colors.textPrimary,
                              side: BorderSide(color: colors.border, width: colors.isHighContrast ? 2 : 1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                            ),
                            onPressed: () => _pickStop(isOrigin: false),
                            icon: const Icon(Icons.location_on, size: 20, color: Color(0xFFE11D48)),
                            label: Text(
                              state.destination?.name ?? 'Choose destination stop',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search status guidance
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.errorMessage ??
                              (_canSearch
                                  ? 'Ready to search routes.'
                                  : 'Choose an origin and destination first.'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: state.errorMessage != null ? colors.statusError : colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Search button
                      Semantics(
                        label: 'Search routes',
                        button: true,
                        excludeSemantics: true,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
                              backgroundColor: colors.actionPrimary,
                              foregroundColor: colors.onActionPrimary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                            ),
                            onPressed: _canSearch ? _search : null,
                            child: const Text('Search', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 32, color: colors.border),

                // ── Results ────────────────────────────────────────────
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _canSearch
                                ? 'Tap Search to find routes.'
                                : 'Select origin and destination above.',
                            style: TextStyle(fontSize: 15, color: colors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final route = _results[index];
                            return Semantics(
                              label: 'View route ${route.displayName}',
                              button: true,
                              excludeSemantics: true,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  border: Border.all(color: colors.border, width: colors.isHighContrast ? 2 : 1),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: colors.surfaceSubtle,
                                      foregroundColor: colors.actionPrimary,
                                      child: const Icon(Icons.directions_bus, size: 20),
                                    ),
                                    title: Text(
                                      route.displayName,
                                      style: TextStyle(fontWeight: FontWeight.w800, color: colors.textPrimary),
                                    ),
                                    subtitle: Text(
                                      '${route.direction} · ${route.orderedStopIds.length} stops',
                                      style: TextStyle(color: colors.textSecondary),
                                    ),
                                    trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                                    onTap: () {
                                      _ctrl.selectRoute(route);
                                      widget.onRouteSelected(route.id);
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Stop picker bottom sheet
// ---------------------------------------------------------------------------

/// A bottom sheet with a search field and a list of stops.
class _StopPickerSheet extends StatefulWidget {
  const _StopPickerSheet({required this.repository});

  final TransportRepository repository;

  @override
  State<_StopPickerSheet> createState() => _StopPickerSheetState();
}

class _StopPickerSheetState extends State<_StopPickerSheet> {
  final _controller = TextEditingController();
  List<models.Stop> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.repository.findStops('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyFilter(String query) {
    setState(() {
      _filtered = widget.repository.findStops(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.colors(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Material(
          color: colors.background,
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search stops…',
                    hintStyle: TextStyle(color: colors.textSecondary),
                    prefixIcon: Icon(Icons.search, color: colors.actionPrimary),
                  ),
                  onChanged: _applyFilter,
                ),
              ),
              // Stop list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final stop = _filtered[index];
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.3))),
                      ),
                      child: ListTile(
                        title: Text(
                          stop.name,
                          style: TextStyle(fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                        subtitle: Text(
                          stop.area,
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        onTap: () => Navigator.of(context).pop(stop),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
