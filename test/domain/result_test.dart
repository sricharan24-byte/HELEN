import 'package:flutter_test/flutter_test.dart';
import 'package:busbuddy/domain/core/failure.dart';
import 'package:busbuddy/domain/core/result.dart';

void main() {
  group('Result<T, E> - Success branch', () {
    test('Success holds value and reports correct flags', () {
      const Result<int, String> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, isNull);
    });

    test('Success.when executes success callback', () {
      const Result<String, Exception> result = Success('hello');

      final output = result.when(
        success: (val) => 'got $val',
        failure: (err) => 'got error',
      );

      expect(output, 'got hello');
    });

    test('Success.map transforms value', () {
      const Result<int, String> result = Success(10);
      final mapped = result.map((x) => x * 2);

      expect(mapped, equals(const Success<int, String>(20)));
    });

    test('Success equality and string representation', () {
      const s1 = Success<String, int>('test');
      const s2 = Success<String, int>('test');

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1.toString(), 'Success(test)');
    });
  });

  group('Result<T, E> - Failure branch', () {
    test('FailureResult holds error and reports correct flags', () {
      const Failure failure = NetworkFailure('Connection timed out');
      const Result<String, Failure> result = FailureResult(failure);

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, equals(failure));
    });

    test('FailureResult.when executes failure callback', () {
      const Result<String, String> result = FailureResult('Not found');

      final output = result.when(
        success: (val) => 'val: $val',
        failure: (err) => 'err: $err',
      );

      expect(output, 'err: Not found');
    });

    test('FailureResult.map preserves failure without executing transform', () {
      const Result<int, String> result = FailureResult('failed');
      bool transformCalled = false;

      final mapped = result.map((x) {
        transformCalled = true;
        return x * 10;
      });

      expect(transformCalled, isFalse);
      expect(mapped, equals(const FailureResult<int, String>('failed')));
    });

    test('FailureResult equality and string representation', () {
      const f1 = FailureResult<int, String>('err');
      const f2 = FailureResult<int, String>('err');

      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
      expect(f1.toString(), 'FailureResult(err)');
    });
  });
}
