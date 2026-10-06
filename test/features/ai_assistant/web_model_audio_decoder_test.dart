import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs the Node harness in `tool/verify/web_model_audio_decoder.mjs`.
///
/// The Chrome decoder lives in JavaScript that `web_speech_real.dart` installs
/// by `eval`ing a string, so no Flutter widget test can reach it — only a
/// browser executes it. That is exactly why the v6/v7 silence bugs survived a
/// 390-test green run: the broken code had no test at all.
///
/// This test does not reimplement the decoder. It runs the shipped bridge
/// source against a mock AudioContext in Node, so the code under test is the
/// code that ships. See that file for the individual checks.
void main() {
  test('the web model-audio bridge decodes every base64 shape Chrome sends', () {
    final script = File('tool/verify/web_model_audio_decoder.mjs');
    expect(
      script.existsSync(),
      isTrue,
      reason: 'decoder harness missing at ${script.path}',
    );

    final result = Process.runSync('node', [script.path]);
    final output = '${result.stdout}${result.stderr}';

    // The harness prints the reason for each failure, so surface it rather than
    // only the exit code — "the decoder is broken" is useless on its own.
    expect(
      result.exitCode,
      0,
      reason: 'web model-audio decoder checks failed:\n$output',
    );
    expect(output, contains('All decoder checks passed.'));
  }, timeout: const Timeout(Duration(seconds: 60)));
}