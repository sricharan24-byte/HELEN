import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BUS-P2-01 exit criteria (in-repo, no device required):
///
/// The production manifest declares zero runtime-dangerous permissions, so the
/// deny / permanent-deny / revoke-while-running / approximate-location flows
/// have no Android surface to exercise. These tests lock that contract and the
/// feature-fallback paths that must remain when a capability is unavailable
/// (browser mic denial recovery, network-only map/OSRM dependency).
///
/// If a permission is ever re-introduced, extend this group with instrumented
/// or integration permission-flow cases before flipping the manifest.
void main() {
  group('BUS-P2-01 runtime permission-flow contract', () {
    late String mainManifest;

    setUp(() {
      mainManifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    });

    test('main manifest declares only the audited permission set', () {
      final declared = RegExp(r'android:name="(android\.permission\.[A-Z_]+)"')
          .allMatches(mainManifest)
          .map((m) => m.group(1)!)
          .toSet();

      // Dangerous permissions that would require a user-facing flow.
      const dangerous = {
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.ACCESS_BACKGROUND_LOCATION',
        'android.permission.RECORD_AUDIO',
        'android.permission.CAMERA',
        'android.permission.READ_CONTACTS',
        'android.permission.WRITE_CONTACTS',
        'android.permission.READ_PHONE_STATE',
        'android.permission.CALL_PHONE',
        'android.permission.SEND_SMS',
        'android.permission.READ_MEDIA_IMAGES',
        'android.permission.POST_NOTIFICATIONS',
      };

      // RECORD_AUDIO is the one dangerous permission kept, and only while
      // BusBuddyVoiceChannel.kt backs it with a working capability, a
      // just-in-time request, and an accessible denial fallback.
      const auditedDangerous = {'android.permission.RECORD_AUDIO'};
      expect(declared.intersection(dangerous).difference(auditedDangerous), isEmpty);
      expect(
        declared,
        equals(const {
          'android.permission.INTERNET',
          'android.permission.RECORD_AUDIO',
          'android.permission.MODIFY_AUDIO_SETTINGS',
        }),
      );
    });

    test('debug and profile flavor manifests do not re-add dangerous permissions', () {
      final src = Directory('android/app/src');
      expect(src.existsSync(), isTrue);

      final flavorManifests = src
          .listSync()
          .whereType<Directory>()
          .map((d) => File('${d.path}/AndroidManifest.xml'))
          .where((f) => f.existsSync() && !f.path.contains('/main/'));

      for (final manifest in flavorManifests) {
        final content = manifest.readAsStringSync();
        // Flutter's default debug/profile manifests declare INTERNET for
        // hot-reload / DevTools; that is allowed. Only dangerous runtime
        // permissions must stay absent from every flavor.
        final declared = RegExp(r'android:name="(android\.permission\.[A-Z_]+)"')
            .allMatches(content)
            .map((m) => m.group(1)!)
            .toSet();
        const dangerous = {
          'android.permission.ACCESS_FINE_LOCATION',
          'android.permission.ACCESS_COARSE_LOCATION',
          'android.permission.ACCESS_BACKGROUND_LOCATION',
          'android.permission.RECORD_AUDIO',
          'android.permission.CAMERA',
          'android.permission.READ_CONTACTS',
          'android.permission.WRITE_CONTACTS',
          'android.permission.READ_PHONE_STATE',
          'android.permission.CALL_PHONE',
          'android.permission.SEND_SMS',
          'android.permission.READ_MEDIA_IMAGES',
          'android.permission.POST_NOTIFICATIONS',
        };
        expect(
          declared.intersection(dangerous),
          isEmpty,
          reason: '${manifest.path} must not declare dangerous permissions',
        );
        // Flavor manifests may only declare INTERNET (if anything).
        expect(
          declared.difference({'android.permission.INTERNET'}),
          isEmpty,
          reason: '${manifest.path} may only declare INTERNET',
        );
      }
    });

    test('microphone permission request stays confined to the native voice channel', () {
      const auditedVoiceFiles = {
        'android/app/src/main/kotlin/com/busbuddy/app/BusBuddyVoiceChannel.kt',
        'android/app/src/main/kotlin/com/busbuddy/app/MainActivity.kt',
      };

      final micHits = <String>[];
      final locationHits = <String>[];
      final androidRoot = Directory('android');
      if (androidRoot.existsSync()) {
        for (final entity in androidRoot.listSync(recursive: true)) {
          if (entity is! File) continue;
          final path = entity.path;
          if (!path.endsWith('.kt') &&
              !path.endsWith('.java') &&
              !path.endsWith('.xml')) {
            continue;
          }
          // Skip generated/build outputs if present.
          if (path.contains('/build/')) continue;
          final content = entity.readAsStringSync();
          if (content.contains('Manifest.permission.ACCESS_FINE_LOCATION') ||
              content.contains('Manifest.permission.ACCESS_COARSE_LOCATION') ||
              content.contains('registerForActivityResult')) {
            locationHits.add(path);
          }
          if (content.contains('ActivityCompat.requestPermissions') ||
              content.contains('Manifest.permission.RECORD_AUDIO')) {
            micHits.add(path);
          }
        }
      }

      // Location never comes back: it is fixture-based, no runtime surface.
      expect(locationHits, isEmpty, reason: locationHits.join(', '));

      // The mic prompt may exist in exactly one place, and MainActivity must
      // only forward the result rather than request anything itself.
      expect(micHits.toSet().difference(auditedVoiceFiles), isEmpty,
          reason: micHits.join(', '));
      final voiceChannel = File(
        'android/app/src/main/kotlin/com/busbuddy/app/BusBuddyVoiceChannel.kt',
      );
      expect(voiceChannel.existsSync(), isTrue);
      final voiceSource = voiceChannel.readAsStringSync();
      expect(voiceSource, contains('AudioRecord'));
      expect(voiceSource, contains('shouldShowRequestPermissionRationale'));
      final mainActivity = File(
        'android/app/src/main/kotlin/com/busbuddy/app/MainActivity.kt',
      ).readAsStringSync();
      expect(mainActivity, contains('handlePermissionResult'));
      expect(mainActivity, isNot(contains('ActivityCompat.requestPermissions')));

      final dartHits = <String>[];
      final libRoot = Directory('lib');
      for (final entity in libRoot.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (content.contains('permission_handler') ||
            content.contains('Permission.location') ||
            content.contains('Permission.microphone') ||
            content.contains('requestPermissions(')) {
          dartHits.add(entity.path);
        }
      }
      expect(dartHits, isEmpty, reason: dartHits.join(', '));
    });

    test('pubspec does not pull permission or location runtime plugins', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('permission_handler')));
      expect(pubspec, isNot(contains('geolocator')));
      expect(pubspec, isNot(contains('location:')));
      expect(pubspec, isNot(contains('record:')));
      expect(pubspec, isNot(contains('just_audio')));
    });

    test('re-add rationale documents JIT request + denial fallback', () {
      // Deny / permanent-deny / settings-recovery contract for any future
      // permission (Astra Gate 12).
      expect(mainManifest, contains('BUS-P2-01'));
      expect(mainManifest, contains('just-in-time runtime request'));
      expect(mainManifest, contains('contextual purpose rationale'));
      expect(mainManifest, contains('accessible denial fallback'));
    });

    test('feature fallback exists when microphone capability is unavailable', () {
      // Browser/OS mic denial must surface an accessible recovery path rather
      // than a silent dead-end (BUS-P1-08 + BUS-P2-01 fallback). The full-screen
      // GeminiLiveScreen is the app's sole voice surface.
      final gemini = File(
        'lib/features/ai_assistant/gemini_live_screen.dart',
      ).readAsStringSync();
      expect(
        gemini.toLowerCase(),
        contains('permission'),
        reason: 'GeminiLiveScreen must handle mic permission recovery',
      );
    });

    test('map and routing degrade without extra Android permissions', () {
      // OSRM/tiles need only INTERNET; offline fallback must exist.
      final osrm = File(
        'lib/data/services/osrm_routing_service.dart',
      ).readAsStringSync();
      expect(
        osrm.toLowerCase(),
        contains('fallback'),
        reason: 'OSRM must fall back when network routing fails',
      );

      final mapWidget = File(
        'lib/features/journey/live_location_map_widget.dart',
      ).readAsStringSync();
      expect(
        mapWidget.toLowerCase(),
        contains('offline'),
        reason: 'map widget must expose offline failure state',
      );
    });
  });
}
