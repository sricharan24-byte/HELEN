import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/services/osrm_routing_service.dart';

class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  final testStops = [
    const Stop(
      id: 'vit-main-gate',
      name: 'VIT Main Gate',
      area: 'Katpadi',
      latitude: 12.96813,
      longitude: 79.15553,
    ),
    const Stop(
      id: 'katpadi-railway-station',
      name: 'Katpadi Railway Station',
      area: 'Station Road',
      latitude: 12.97984,
      longitude: 79.13697,
    ),
  ];

  group('Astra BUS-P1-07: Typed OSRM Routing & Offline Failure States Tests', () {
    test('returns liveRoadRoute on HTTP 200 with valid geojson coordinates', () async {
      final validGeoJson = jsonEncode({
        'code': 'Ok',
        'routes': [
          {
            'geometry': {
              'coordinates': [
                [79.15553, 12.96813],
                [79.14500, 12.97300],
                [79.13697, 12.97984],
              ]
            }
          }
        ]
      });

      final client = FakeHttpClient((req) async {
        return http.Response(validGeoJson, 200);
      });

      final service = OsrmRoutingService(httpClient: client);
      final outcome = await service.fetchRouteOutcome(testStops);

      expect(outcome.type, equals(RoutingOutcomeType.liveRoadRoute));
      expect(outcome.isLiveRoadRoute, isTrue);
      expect(outcome.isFallback, isFalse);
      expect(outcome.failureReason, isNull);
      expect(outcome.points.length, equals(3));
      expect(outcome.points.first.latitude, closeTo(12.96813, 0.0001));
    });

    test('returns bakedCorridorFallback with rateLimited on HTTP 429', () async {
      final client = FakeHttpClient((req) async {
        return http.Response('Too Many Requests', 429);
      });

      final service = OsrmRoutingService(httpClient: client);
      final outcome = await service.fetchRouteOutcome(testStops);

      expect(outcome.type, equals(RoutingOutcomeType.bakedCorridorFallback));
      expect(outcome.isFallback, isTrue);
      expect(outcome.failureReason, equals(RoutingFailureReason.rateLimited));
      expect(outcome.userStatusMessage, contains('429'));
      expect(outcome.points.isNotEmpty, isTrue);
    });

    test('returns bakedCorridorFallback with serverError on HTTP 500', () async {
      final client = FakeHttpClient((req) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = OsrmRoutingService(httpClient: client);
      final outcome = await service.fetchRouteOutcome(testStops);

      expect(outcome.type, equals(RoutingOutcomeType.bakedCorridorFallback));
      expect(outcome.isFallback, isTrue);
      expect(outcome.failureReason, equals(RoutingFailureReason.serverError));
      expect(outcome.userStatusMessage, contains('server error'));
      expect(outcome.points.isNotEmpty, isTrue);
    });

    test('returns bakedCorridorFallback with timeout on request timeout', () async {
      final client = FakeHttpClient((req) async {
        throw TimeoutException('Connection timed out');
      });

      final service = OsrmRoutingService(httpClient: client);
      final outcome = await service.fetchRouteOutcome(testStops);

      expect(outcome.type, equals(RoutingOutcomeType.bakedCorridorFallback));
      expect(outcome.isFallback, isTrue);
      expect(outcome.failureReason, equals(RoutingFailureReason.timeout));
      expect(outcome.userStatusMessage, contains('timed out'));
    });

    test('returns bakedCorridorFallback with offline on socket failure', () async {
      final client = FakeHttpClient((req) async {
        throw const SocketException('Network is unreachable');
      });

      final service = OsrmRoutingService(httpClient: client);
      final outcome = await service.fetchRouteOutcome(testStops);

      expect(outcome.type, equals(RoutingOutcomeType.bakedCorridorFallback));
      expect(outcome.isFallback, isTrue);
      expect(outcome.failureReason, equals(RoutingFailureReason.offline));
      expect(outcome.userStatusMessage, contains('Offline mode active'));
    });

    test('returns bakedCorridorFallback with invalidResponse on oversized payload', () async {
      final hugePayload = 'A' * (600 * 1024); // 600KB > 512KB safe threshold
      final client = FakeHttpClient((req) async {
        return http.Response(hugePayload, 200);
      });

      final service = OsrmRoutingService(httpClient: client);
      final outcome = await service.fetchRouteOutcome(testStops);

      expect(outcome.type, equals(RoutingOutcomeType.bakedCorridorFallback));
      expect(outcome.isFallback, isTrue);
      expect(outcome.failureReason, equals(RoutingFailureReason.invalidResponse));
    });

    test('returns straightLineFallback when stops are insufficient', () async {
      const singleStop = [
        Stop(
          id: 'single-stop',
          name: 'Single Stop',
          area: 'VIT',
          latitude: 12.96813,
          longitude: 79.15553,
        ),
      ];

      final service = const OsrmRoutingService();
      final outcome = await service.fetchRouteOutcome(singleStop);

      expect(outcome.type, equals(RoutingOutcomeType.straightLineFallback));
      expect(outcome.failureReason, equals(RoutingFailureReason.noStops));
      expect(outcome.points.length, equals(1));
    });
  });
}
