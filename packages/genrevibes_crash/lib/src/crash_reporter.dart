import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/crash_report.dart';

/// Contract implemented by Crashlytics and other crash-reporting adapters.
///
/// Implementations must never throw: a failing crash reporter inside an error
/// handler would mask the original error.
abstract interface class CrashReporter implements StarterModule {
  /// Stable provider identifier, such as `crashlytics`.
  String get providerId;

  /// Enables or disables sending reports to the backend.
  Future<KitResult<void>> setCollectionEnabled(bool enabled);

  /// Associates subsequent reports with an application user or install id.
  Future<KitResult<void>> setUserIdentifier(String identifier);

  /// Attaches a key/value that appears on every subsequent report.
  Future<KitResult<void>> setCustomKey(String key, Object value);

  /// Records [report].
  ///
  /// When collection is disabled this must still succeed and simply not send.
  Future<KitResult<void>> record(CrashReport report);

  /// Adds a breadcrumb message to the next report.
  Future<KitResult<void>> log(String message);
}
