import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';

void main() {
  late LocalTransportDataSource dataSource;
  late LocalTransportRepository repository;

  setUp(() {
    dataSource = LocalTransportDataSource();
    repository = LocalTransportRepository(dataSource: dataSource);
  });

  group('findStops', () {
    test('empty query returns all stops in fixture order', () {
      final stops = repository.findStops('');
      expect(stops.length, greaterThanOrEqualTo(10));
      expect(stops.first.id, 'vit-main-gate');
      expect(stops.last.id, 'thottapalayam');
    });

    test('case-insensitive search by stop name', () {
      final stops = repository.findStops('VIT');
      expect(stops, isNotEmpty);
      expect(stops.any((s) => s.id == 'vit-main-gate'), isTrue);
    });

    test('case-insensitive search by area', () {
      final stops = repository.findStops('vellore');
      expect(stops, isNotEmpty);
      // Should match stops whose area contains "vellore"
    });

    test('query with leading/trailing spaces is trimmed', () {
      final stops = repository.findStops('  Katpadi  ');
      expect(stops, isNotEmpty);
      expect(stops.any((s) => s.id == 'katpadi-railway-station'), isTrue);
    });

    test('non-matching query returns empty list', () {
      final stops = repository.findStops('zzz_nonexistent');
      expect(stops, isEmpty);
    });
  });

  group('findRoutes', () {
    test('VIT Main Gate to Katpadi Railway Station returns corridor route', () {
      final routes = repository.findRoutes(
        originId: 'vit-main-gate',
        destinationId: 'katpadi-railway-station',
      );
      expect(routes, isNotEmpty);
      expect(routes.first.orderedStopIds, contains('vit-main-gate'));
      expect(routes.first.orderedStopIds, contains('katpadi-railway-station'));
      // origin must appear before destination in orderedStopIds
      final originIndex = routes.first.orderedStopIds.indexOf('vit-main-gate');
      final destIndex = routes.first.orderedStopIds.indexOf(
        'katpadi-railway-station',
      );
      expect(originIndex, lessThan(destIndex));
    });

    test('reversed origin/destination Katpadi to VIT returns katpadi-to-vit route', () {
      final routes = repository.findRoutes(
        originId: 'katpadi-railway-station',
        destinationId: 'vit-main-gate',
      );
      expect(routes, isNotEmpty);
      expect(routes.first.id, 'katpadi-to-vit');
    });

    test('unsupported destination returns empty list', () {
      final routes = repository.findRoutes(
        originId: 'vit-main-gate',
        destinationId: 'nonexistent-stop',
      );
      expect(routes, isEmpty);
    });

    test('unknown origin returns empty list', () {
      final routes = repository.findRoutes(
        originId: 'nonexistent-stop',
        destinationId: 'katpadi-railway-station',
      );
      expect(routes, isEmpty);
    });
  });

  group('getStop', () {
    test('returns correct stop for known ID', () {
      final stop = repository.getStop('vit-main-gate');
      expect(stop, isNotNull);
      expect(stop!.name, 'VIT Main Gate');
    });

    test('returns null for unknown ID', () {
      final stop = repository.getStop('nonexistent-id');
      expect(stop, isNull);
    });
  });
}
