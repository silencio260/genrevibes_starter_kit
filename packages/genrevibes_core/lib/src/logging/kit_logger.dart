/// Severity levels understood by starter-kit modules.
enum KitLogLevel {
  /// Verbose diagnostic information.
  debug,

  /// Expected lifecycle or business information.
  info,

  /// A recoverable or degraded condition.
  warning,

  /// An operation failed.
  error,
}

/// Logging boundary that keeps modules independent from logging packages.
abstract interface class KitLogger {
  /// Records a structured starter-kit message.
  void log(
    KitLogLevel level,
    String message, {
    String? moduleId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields,
  });
}

/// Logger used when an application does not need starter-kit logs.
final class NoopKitLogger implements KitLogger {
  /// Creates a no-op logger.
  const NoopKitLogger();

  @override
  void log(
    KitLogLevel level,
    String message, {
    String? moduleId,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {}
}
