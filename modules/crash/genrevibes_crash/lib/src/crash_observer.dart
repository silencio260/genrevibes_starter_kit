import 'model/crash_report.dart';

/// Receives every report the coordinator accepts.
///
/// The application uses this to mirror crashes into analytics or logging
/// without the crash package depending on either. Observers must not throw.
abstract interface class CrashObserver {
  /// Called after a report has been handed to the reporter.
  void onReported(CrashReport report);
}

/// [CrashObserver] that does nothing.
final class NoopCrashObserver implements CrashObserver {
  /// Creates a no-op observer.
  const NoopCrashObserver();

  @override
  void onReported(CrashReport report) {}
}
