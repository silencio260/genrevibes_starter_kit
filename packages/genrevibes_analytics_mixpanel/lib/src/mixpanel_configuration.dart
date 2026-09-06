/// Application-owned configuration for the Mixpanel events SDK.
final class GenreVibesMixpanelConfiguration {
  /// Creates Mixpanel configuration.
  const GenreVibesMixpanelConfiguration({
    required this.token,
    this.trackAutomaticEvents = false,
    this.optOutTrackingDefault = false,
    this.loggingEnabled = false,
    this.serverUrl,
    this.flushBatchSize,
  });

  /// Mixpanel project token.
  final String token;

  /// Whether Mixpanel collects its built-in automatic events.
  final bool trackAutomaticEvents;

  /// Initial SDK opt-out value. The analytics pipeline should only initialize
  /// this sink after application-level consent has been granted.
  final bool optOutTrackingDefault;

  /// Whether verbose Mixpanel SDK logging is enabled.
  final bool loggingEnabled;

  /// Optional custom ingestion URL, including Mixpanel's EU endpoint.
  final String? serverUrl;

  /// Optional number of events sent per request.
  final int? flushBatchSize;
}
