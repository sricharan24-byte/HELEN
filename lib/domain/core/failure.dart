/// Pure-Dart domain failure hierarchy representing recoverable domain and data errors.
/// Zero Flutter imports.
abstract class Failure {
  const Failure(
    this.message, {
    this.code,
    this.cause,
  });

  final String message;
  final Object? code;
  final Object? cause;

  @override
  String toString() => '$runtimeType(message: $message, code: $code)';
}

/// Network or remote service failure (e.g. OSRM, Gemini API, GTFS-RT endpoint).
class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.code,
    super.cause,
  });
}

/// Storage, persistence, or serialization failure (e.g. corrupt prefs or JSON).
class StorageFailure extends Failure {
  const StorageFailure(
    super.message, {
    super.code,
    super.cause,
  });
}

/// Validation failure for commuter inputs (e.g. invalid stop, negative fare, missing contact).
class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    super.code,
    super.cause,
  });
}

/// Entity or resource not found failure (e.g. unknown bus ID, missing stop ID).
class NotFoundFailure extends Failure {
  const NotFoundFailure(
    super.message, {
    super.code,
    super.cause,
  });
}

/// Service or hardware capability unavailable (e.g. GPS disabled, speech unavailable).
class ServiceUnavailableFailure extends Failure {
  const ServiceUnavailableFailure(
    super.message, {
    super.code,
    super.cause,
  });
}
