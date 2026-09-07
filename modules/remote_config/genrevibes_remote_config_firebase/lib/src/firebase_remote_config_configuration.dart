/// Application-owned Firebase Remote Config fetch policy.
final class GenRevibesFirebaseRemoteConfigConfiguration {
  /// Creates Firebase fetch settings.
  const GenRevibesFirebaseRemoteConfigConfiguration({
    this.fetchTimeout = const Duration(minutes: 1),
    this.minimumFetchInterval = const Duration(hours: 12),
  });

  /// Maximum duration of a Firebase fetch attempt.
  final Duration fetchTimeout;

  /// Minimum duration Firebase waits between backend fetches.
  final Duration minimumFetchInterval;
}
