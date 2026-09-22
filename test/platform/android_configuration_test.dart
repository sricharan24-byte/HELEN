import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Packaging & Keystore Configuration Tests (BUS-P0-07)', () {
    test('build.gradle.kts specifies production applicationId and namespace', () {
      final gradleFile = File('android/app/build.gradle.kts');
      expect(gradleFile.existsSync(), isTrue);

      final content = gradleFile.readAsStringSync();
      expect(content, contains('namespace = "com.busbuddy.app"'));
      expect(content, contains('applicationId = "com.busbuddy.app"'));
      expect(content, isNot(contains('com.example.busbuddy')));
    });

    test('build.gradle.kts contains release signing configuration separation', () {
      final gradleFile = File('android/app/build.gradle.kts');
      final content = gradleFile.readAsStringSync();

      expect(content, contains('create("release")'));
      expect(content, contains('RELEASE_STORE_FILE'));
      expect(content, contains('RELEASE_STORE_PASSWORD'));
      expect(content, contains('RELEASE_KEY_ALIAS'));
      expect(content, contains('RELEASE_KEY_PASSWORD'));
    });

    test('MainActivity.kt is located under com.busbuddy.app package hierarchy', () {
      final mainActivityFile =
          File('android/app/src/main/kotlin/com/busbuddy/app/MainActivity.kt');
      expect(mainActivityFile.existsSync(), isTrue);

      final content = mainActivityFile.readAsStringSync();
      expect(content, contains('package com.busbuddy.app'));

      final legacyFile =
          File('android/app/src/main/kotlin/com/example/busbuddy/MainActivity.kt');
      expect(legacyFile.existsSync(), isFalse);
    });

    test('AndroidManifest.xml specifies correct application label', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content, contains('android:label="BusBuddy"'));
    });
  });

  group('Android permission minimization (BUS-P2-01)', () {
    late String manifest;

    setUp(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    });

    test('declares only INTERNET as a uses-permission', () {
      final declared = RegExp(r'android:name="(android\.permission\.[A-Z_]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, equals({'android.permission.INTERNET'}));
    });

    test('does not declare location or microphone permissions', () {
      expect(manifest, isNot(contains('android.permission.ACCESS_FINE_LOCATION')));
      expect(manifest, isNot(contains('android.permission.ACCESS_COARSE_LOCATION')));
      expect(manifest, isNot(contains('android.permission.RECORD_AUDIO')));
    });

    test('documents re-add rationale for removed permissions', () {
      expect(manifest, contains('BUS-P2-01'));
      expect(manifest, contains('just-in-time runtime request'));
    });
  });

  group('Release shrinking configuration (BUS-P2-02)', () {
    late String gradle;

    setUp(() {
      gradle = File('android/app/build.gradle.kts').readAsStringSync();
    });

    test('enables R8 minification and resource shrinking for release', () {
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      expect(gradle, contains('proguard-android-optimize.txt'));
      expect(gradle, contains('proguard-rules.pro'));
    });

    test('proguard-rules.pro exists with evidence-based keep rules only', () {
      final proguard = File('android/app/proguard-rules.pro');
      expect(proguard.existsSync(), isTrue);

      final content = proguard.readAsStringSync();
      expect(content, contains('io.flutter.embedding.**'));
      expect(content, contains('com.busbuddy.app.MainActivity'));
      expect(content, contains('io.flutter.plugins.sharedpreferences.**'));
      // Optional Play Core split APIs referenced by Flutter embedding but
      // not on our classpath — must be dontwarn, not kept as live code.
      expect(content, contains('-dontwarn com.google.android.play.core.'));
    });
  });
}
