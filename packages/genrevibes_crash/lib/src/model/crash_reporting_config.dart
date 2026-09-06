/// Crash reporting behavior an application must decide explicitly.
final class CrashReportingConfig {
  /// Creates crash reporting configuration.
  ///
  /// [collectionEnabled] has no default on purpose. Reporting local debug
  /// crashes pollutes the dashboard and hides real regressions, so the app
  /// states its intent, typically `!kDebugMode`.
  const CrashReportingConfig({required this.collectionEnabled});

  /// Whether reports are sent to the backend.
  final bool collectionEnabled;
}
