/// Limits how often a denied permission is re-requested.
///
/// A prompt the user has already dismissed several times is a nag, and on
/// Android repeated denials flip the permission to permanently denied. Once
/// [maxRequests] have been made, a new request waits [minimumInterval] after
/// the last one.
final class PermissionRequestThrottle {
  /// Creates a throttle.
  const PermissionRequestThrottle({
    this.maxRequests = 3,
    this.minimumInterval = const Duration(days: 1),
  });

  /// Requests allowed before the interval applies.
  final int maxRequests;

  /// Minimum gap between requests once [maxRequests] is reached.
  final Duration minimumInterval;

  /// When the next request may be made, or `null` for "now".
  DateTime? retryAt({
    required int previousRequests,
    required DateTime? lastRequestedAt,
    required DateTime now,
  }) {
    if (previousRequests < maxRequests || lastRequestedAt == null) return null;
    final allowedAt = lastRequestedAt.add(minimumInterval);
    return now.isBefore(allowedAt) ? allowedAt : null;
  }
}
