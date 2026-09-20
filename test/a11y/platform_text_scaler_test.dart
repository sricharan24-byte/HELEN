import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:busbuddy/core/a11y/enlarging_text_scaler.dart';
import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/main.dart';
import 'package:busbuddy/core/di/service_locator.dart';
import 'package:busbuddy/data/datasources/local_transport_data_source.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/repositories/transport_repository.dart';
import 'package:busbuddy/features/journey/journey_controller.dart';
import 'package:busbuddy/features/tickets/ticket_controller.dart';
import '../helpers/map_test_tiles.dart';

/// Fake non-linear platform text scaler simulating Android 14+ curve.
/// In Android 14, small body text scales faster (e.g. 2.0x) than large headings (e.g. 1.4x)
/// to maintain layout proportion.
class FakeNonlinearTextScaler implements TextScaler {
  const FakeNonlinearTextScaler({required this.factor});

  final double factor;

  @override
  double scale(double fontSize) {
    // Non-linear scaling function: fontSize <= 14 scales with full factor;
    // fontSize >= 24 scales with diminished curve (factor * 0.75).
    if (fontSize <= 14.0) {
      return fontSize * factor;
    } else if (fontSize >= 24.0) {
      return fontSize * (1.0 + (factor - 1.0) * 0.75);
    } else {
      final t = (fontSize - 14.0) / 10.0;
      final effectiveCurve = factor * (1.0 - t) + (1.0 + (factor - 1.0) * 0.75) * t;
      return fontSize * effectiveCurve;
    }
  }

  @override
  TextScaler clamp({double minScaleFactor = 0.0, double maxScaleFactor = double.infinity}) {
    return this;
  }
}

void main() {
  setUpAll(stubMapTiles);

  group('Astra BUS-P0-03: Platform TextScaler Preservation Tests', () {
    test('EnlargingTextScaler preserves exact non-linear curve when factor is 1.0', () {
      const platformScaler = FakeNonlinearTextScaler(factor: 2.0);
      const scaler = EnlargingTextScaler(platformScaler, 1.0);

      // Body font 12 scales by 2.0 -> 24.0
      expect(scaler.scale(12.0), equals(platformScaler.scale(12.0)));
      expect(scaler.scale(12.0), equals(24.0));

      // Heading font 24 scales by (1.0 + 1.0 * 0.75) = 1.75 -> 42.0
      expect(scaler.scale(24.0), equals(platformScaler.scale(24.0)));
      expect(scaler.scale(24.0), equals(42.0));

      // The ratio between small and large scale factors remains non-linear!
      final smallScaleRatio = scaler.scale(12.0) / 12.0;
      final largeScaleRatio = scaler.scale(24.0) / 24.0;
      expect(smallScaleRatio, isNot(equals(largeScaleRatio)));
    });

    test('EnlargingTextScaler enlarges platform output without flattening to linear', () {
      const platformScaler = FakeNonlinearTextScaler(factor: 1.5);
      const scaler = EnlargingTextScaler(platformScaler, 1.2); // 20% in-app enlargement

      expect(scaler.scale(12.0), equals(12.0 * 1.5 * 1.2));
      expect(scaler.scale(24.0), equals(platformScaler.scale(24.0) * 1.2));

      // Guaranteed non-linear scaling curve is preserved
      expect(scaler.scale(12.0) / 12.0, greaterThan(scaler.scale(24.0) / 24.0));
    });

    test('AppSettingsController textScaleFactor never downscales below 1.0', () {
      final settings = AppSettingsController.instance;

      settings.updateTextSize('Small');
      expect(settings.textScaleFactor, greaterThanOrEqualTo(1.0));
      expect(settings.inAppEnlargementMultiplier, greaterThanOrEqualTo(1.0));

      settings.updateTextSize('Medium');
      expect(settings.textScaleFactor, equals(1.0));

      settings.updateTextSize('Large');
      expect(settings.textScaleFactor, equals(1.15));

      settings.updateTextSize('Extra Large');
      expect(settings.textScaleFactor, equals(1.30));

      // Reset
      settings.updateTextSize('Medium');
    });

    testWidgets('BusBuddyApp renders at 320dp width with 300% platform text scaling without crash', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dataSource = LocalTransportDataSource();
      final repository = LocalTransportRepository(dataSource: dataSource);
      final journeyController = JourneyController(repository);
      final ticketRepo = LocalTicketRepository();
      final ticketController = TicketController(ticketRepo);

      // Inject 300% (3.0x) platform text scaler
      const platform300Scaler = FakeNonlinearTextScaler(factor: 3.0);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: platform300Scaler,
          ),
          child: MyApp(
            journeyController: journeyController,
            repository: repository,
            ticketController: ticketController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Home Page is rendered with 300% scaling
      expect(find.text('Bus'), findsOneWidget);
      expect(find.text('Buddy'), findsOneWidget);

      // Verify that primary action buttons remain present and operable at 320dp / 300% scale
      expect(find.text('Find a Place'), findsOneWidget);
      expect(find.text('My Journey'), findsOneWidget);
    });
  });
}
