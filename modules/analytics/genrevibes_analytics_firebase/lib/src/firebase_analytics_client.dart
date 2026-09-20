import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

/// Injectable boundary around the Firebase Analytics plugin.
abstract interface class FirebaseAnalyticsClient {
  /// Whether the host application initialized at least one Firebase app.
  bool get isFirebaseInitialized;

  /// Turns analytics collection on.
  ///
  /// There is deliberately no way to turn it off. Firebase Analytics is the
  /// portfolio's baseline measurement, disclosed in every app's privacy
  /// policy, so no consent state, remote switch or host call may disable it.
  /// This exists only to repair an install that an older build left disabled
  /// in Firebase's own preferences.
  Future<void> enableCollection();

  /// Logs an event with Firebase-compatible parameters.
  Future<void> logEvent(String name, Map<String, Object>? parameters);

  /// Sets or clears the Firebase Analytics user identifier.
  Future<void> setUserId(String? userId);

  /// Sets one Firebase Analytics user property.
  Future<void> setUserProperty(String name, String? value);

  /// Resets Firebase Analytics application-instance data.
  Future<void> resetAnalyticsData();
}

/// Production client backed by the default Firebase Analytics instance.
final class DefaultFirebaseAnalyticsClient implements FirebaseAnalyticsClient {
  /// Creates a production Firebase Analytics client.
  DefaultFirebaseAnalyticsClient({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> resetAnalyticsData() => _analytics.resetAnalyticsData();

  @override
  Future<void> enableCollection() {
    return _analytics.setAnalyticsCollectionEnabled(true);
  }

  @override
  Future<void> setUserId(String? userId) => _analytics.setUserId(id: userId);

  @override
  Future<void> setUserProperty(String name, String? value) {
    return _analytics.setUserProperty(name: name, value: value);
  }
}
