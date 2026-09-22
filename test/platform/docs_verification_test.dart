import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BUS-P2-03: documentation verification runs inside the test suite so a
/// missing ADR, workflow, or release-config claim fails CI the same way a
/// unit test does.
void main() {
  group('BUS-P2-03 documentation & claim verification', () {
    test('required ADRs and audit sources exist', () {
      const required = [
        'docs/adr/ADR-001-phase1-domain-and-a11y-contracts.md',
        'docs/adr/ADR-002-phase2-accessibility-and-safety-architecture.md',
        'docs/adr/ADR-003-production-readiness-and-audit-resolution.md',
        'docs/audit/gpt6_astra_feedback_phase2.txt',
        'docs/audit/gpt6_astra_paper.txt',
        'README.md',
        'progress.md',
        'AGENTS.md',
        '.github/workflows/ci.yml',
        'tool/ci/verify_docs.sh',
        'tool/release_smoke.sh',
        'tool/startup_memory_benchmark.sh',
        'test/platform/permission_flow_test.dart',
        'test/platform/docs_verification_test.dart',
        'test/platform/android_configuration_test.dart',
      ];

      for (final path in required) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: 'BUS-P2-03 requires $path to exist',
        );
      }
    });

    test('README ADR references resolve to real files', () {
      final readme = File('README.md').readAsStringSync();
      expect(readme, contains('ADR-001'));
      expect(readme, contains('ADR-002'));
      expect(readme, contains('ADR-003'));

      expect(
        File(
          'docs/adr/ADR-001-phase1-domain-and-a11y-contracts.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'docs/adr/ADR-002-phase2-accessibility-and-safety-architecture.md',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          'docs/adr/ADR-003-production-readiness-and-audit-resolution.md',
        ).existsSync(),
        isTrue,
      );
    });

    test('CI workflow is the test/analysis source of truth', () {
      final ci = File('.github/workflows/ci.yml').readAsStringSync();
      expect(ci, contains('flutter analyze --fatal-infos --fatal-warnings'));
      expect(ci, contains('flutter test'));
      expect(ci, contains('tool/ci/verify_docs.sh'));
      expect(ci, contains('flutter build apk --release'));
      expect(ci, contains('flutter build appbundle --release'));
      expect(ci, contains('flutter build web --release'));
      expect(ci, contains('upload-artifact'));
      expect(ci, contains('commit_sha'));
    });

    test('BUS-P2-02 release shrinking claims match gradle + proguard', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
      expect(gradle, contains('proguard-rules.pro'));

      final proguard = File('android/app/proguard-rules.pro').readAsStringSync();
      expect(proguard, contains('BUS-P2-02'));
      expect(proguard, contains('-dontwarn com.google.android.play.core.'));
    });

    test('BUS-P2-01 permission claim matches manifest', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      final declared = RegExp(r'android:name="(android\.permission\.[A-Z_]+)"')
          .allMatches(manifest)
          .map((m) => m.group(1)!)
          .toSet();
      expect(declared, equals({'android.permission.INTERNET'}));
    });

    test('device release-smoke tooling is present for P2 exit criteria', () {
      final smoke = File('tool/release_smoke.sh');
      expect(smoke.existsSync(), isTrue);
      final smokeContent = smoke.readAsStringSync();
      expect(smokeContent, contains('BUS-P2-02'));
      expect(smokeContent, contains('adb'));

      final bench = File('tool/startup_memory_benchmark.sh');
      expect(bench.existsSync(), isTrue);
      final benchContent = bench.readAsStringSync();
      expect(benchContent, contains('BUS-P2-02'));
      expect(benchContent, contains('TotalTime'));
      expect(benchContent, contains('dumpsys meminfo'));
    });
  });
}
