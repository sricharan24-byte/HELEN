/// Route search page — origin/destination selection and route results.
library;

import 'package:flutter/material.dart';

import '../../data/models/transport_models.dart' as models;
import '../../data/repositories/transport_repository.dart';
import '../journey/journey_controller.dart';

/// A page for choosing origin and destination stops, then searching routes.
///
/// Shows two prominent controls with semantic labels for choosing stops,
/// a search button, and a results list.
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
      } else {
        _ctrl.selectDestination(selected);
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
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        final state = _ctrl.state;

        return Scaffold(
          appBar: AppBar(title: const Text('Route Search')),
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
                        child: OutlinedButton.icon(
                          onPressed: () => _pickStop(isOrigin: true),
                          icon: const Text('From'),
                          label: Text(
                            state.origin?.name ?? 'Choose starting stop',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Destination
                      Semantics(
                        label: 'Choose destination stop',
                        button: true,
                        child: OutlinedButton.icon(
                          onPressed: () => _pickStop(isOrigin: false),
                          icon: const Text('To'),
                          label: Text(
                            state.destination?.name ??
                                'Choose destination stop',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Guidance / error text
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          state.errorMessage ??
                              (_canSearch
                                  ? 'Ready to search routes.'
                                  : 'Choose an origin and destination first.'),
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Search button
                      Semantics(
                        label: 'Search routes',
                        button: true,
                        child: ElevatedButton(
                          onPressed: _canSearch ? _search : null,
                          child: const Text('Search'),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // ── Results ────────────────────────────────────────────
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _canSearch
                                ? 'Tap Search to find routes.'
                                : 'Select origin and destination above.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final route = _results[index];
                            return Semantics(
                              label: 'View route ${route.displayName}',
                              button: true,
                              child: Card(
                                child: ListTile(
                                  title: Text(route.displayName),
                                  subtitle: Text(
                                    '${route.direction} · '
                                    '${route.orderedStopIds.length} stops',
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                  ),
                                  onTap: () {
                                    _ctrl.selectRoute(route);
                                    widget.onRouteSelected(route.id);
                                  },
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
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
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
                decoration: const InputDecoration(
                  hintText: 'Search stops…',
                  prefixIcon: Icon(Icons.search),
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
                  return ListTile(
                    title: Text(stop.name),
                    subtitle: Text(stop.area),
                    onTap: () => Navigator.of(context).pop(stop),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
