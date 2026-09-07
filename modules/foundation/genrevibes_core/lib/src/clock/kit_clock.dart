/// Clock abstraction used to make time-based policies deterministic in tests.
abstract interface class KitClock {
  /// Returns the current time.
  DateTime now();
}

/// System implementation of [KitClock].
final class SystemKitClock implements KitClock {
  /// Creates a system clock.
  const SystemKitClock();

  @override
  DateTime now() => DateTime.now();
}
