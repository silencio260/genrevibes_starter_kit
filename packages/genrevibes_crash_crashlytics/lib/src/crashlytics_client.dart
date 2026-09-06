import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Injectable boundary around the Crashlytics SDK.
///
/// Tests substitute this so they never touch Firebase.
abstract interface class CrashlyticsClient {
  /// Enables or disables report collection.
  Future<void> setCrashlyticsCollectionEnabled(bool enabled);

  /// Associates subsequent reports with [identifier].
  Future<void> setUserIdentifier(String identifier);

  /// Attaches a key/value to subsequent reports.
  Future<void> setCustomKey(String key, Object value);

  /// Records a Dart error.
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Iterable<Object> information,
    bool fatal,
  });

  /// Records a Flutter framework error.
  Future<void> recordFlutterError(FlutterErrorDetails details, {bool fatal});

  /// Adds a breadcrumb.
  Future<void> log(String message);
}

/// Production Crashlytics client.
final class DefaultCrashlyticsClient implements CrashlyticsClient {
  /// Creates a client over the shared Crashlytics instance.
  const DefaultCrashlyticsClient();

  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) =>
      _crashlytics.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> setUserIdentifier(String identifier) =>
      _crashlytics.setUserIdentifier(identifier);

  @override
  Future<void> setCustomKey(String key, Object value) =>
      _crashlytics.setCustomKey(key, value);

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Iterable<Object> information = const <Object>[],
    bool fatal = false,
  }) {
    return _crashlytics.recordError(
      error,
      stack,
      reason: reason,
      information: information,
      fatal: fatal,
    );
  }

  @override
  Future<void> recordFlutterError(
    FlutterErrorDetails details, {
    bool fatal = true,
  }) {
    return _crashlytics.recordFlutterError(details, fatal: fatal);
  }

  @override
  Future<void> log(String message) => _crashlytics.log(message);
}
