import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:busbuddy/features/journey/live_location_map_widget.dart';

/// 1x1 transparent PNG served in place of network map tiles during tests.
final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Tile provider that renders a transparent image without any network I/O.
class SilentTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) {
    return MemoryImage(_transparentPng);
  }
}

/// Installs the silent tile provider for all [LiveLocationMapWidget]s.
/// Call from `setUpAll` (or `setUp`) in widget tests that pump screens with a
/// map so `pumpAndSettle` never races real tile requests.
void stubMapTiles() {
  LiveLocationMapWidget.debugTileProviderFactory = () => SilentTileProvider();
}
