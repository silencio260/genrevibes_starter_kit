/// Where a crash report originated.
enum CrashSource {
  /// The Flutter framework error handler (build, layout, paint).
  flutter,

  /// The platform dispatcher (engine and platform-channel errors).
  platform,

  /// An uncaught asynchronous error caught by a guarded zone.
  zone,

  /// A state-management error, such as a BLoC `onError`.
  bloc,

  /// Explicitly reported by application code.
  manual,
}

/// One error to record.
///
/// [error] is `Object` rather than a Flutter type so the contract stays
/// Flutter-free. An adapter may recognise framework-specific payloads, such as
/// `FlutterErrorDetails`, and route them to a richer SDK call.
final class CrashReport {
  /// Creates a crash report.
  CrashReport({
    required this.error,
    this.stackTrace,
    this.reason,
    this.fatal = false,
    this.source = CrashSource.manual,
    Map<String, Object?> information = const <String, Object?>{},
  }) : information = Map<String, Object?>.unmodifiable(information);

  /// The thrown object, or a framework error payload.
  final Object error;

  /// Stack at the point of failure, when available.
  final StackTrace? stackTrace;

  /// Short human-readable context, such as the operation that failed.
  final String? reason;

  /// Whether the process could not continue.
  final bool fatal;

  /// Where the report came from.
  final CrashSource source;

  /// Non-sensitive diagnostic fields attached to the report.
  ///
  /// This leaves the device. Never put credentials or personal data here.
  final Map<String, Object?> information;
}
