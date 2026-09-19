/// Pure-Dart Result type for functional, deterministic error handling.
/// Eliminates unexpected runtime exceptions and forces callers to handle failures.
sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is FailureResult<T, E>;

  T? get valueOrNull => switch (this) {
        Success(:final value) => value,
        FailureResult() => null,
      };

  E? get errorOrNull => switch (this) {
        Success() => null,
        FailureResult(:final error) => error,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) {
    return switch (this) {
      Success(:final value) => success(value),
      FailureResult(:final error) => failure(error),
    };
  }

  Result<R, E> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Success(transform(value)),
      FailureResult(:final error) => FailureResult(error),
    };
  }
}

/// Represents a successful computation holding a value of type [T].
final class Success<T, E> extends Result<T, E> {
  const Success(this.value);
  final T value;

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Represents a failed computation holding an error of type [E].
final class FailureResult<T, E> extends Result<T, E> {
  const FailureResult(this.error);
  final E error;

  @override
  String toString() => 'FailureResult($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureResult<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}
