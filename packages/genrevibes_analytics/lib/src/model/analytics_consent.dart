/// Application-level analytics consent state.
enum AnalyticsConsent {
  /// Consent has not been resolved yet.
  unknown,

  /// The customer declined analytics collection.
  denied,

  /// The customer granted analytics collection.
  granted,
}
