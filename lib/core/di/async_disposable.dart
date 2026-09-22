/// Contract for application services that manage asynchronous resources
/// (timers, streams, sockets, hardware interfaces) requiring explicit,
/// awaited teardown per Astra BUS-P0-04.
abstract interface class AsyncDisposable {
  /// Asynchronously tears down and releases all held resources.
  /// Implementations must be idempotent and safe to call multiple times.
  Future<void> dispose();
}
