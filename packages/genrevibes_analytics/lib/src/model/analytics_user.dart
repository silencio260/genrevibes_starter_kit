/// Provider-neutral analytics identity.
final class AnalyticsUser {
  /// Creates an analytics user.
  const AnalyticsUser({
    required this.id,
    this.properties = const <String, Object?>{},
  });

  /// Stable portfolio-level application user identifier.
  final String id;

  /// Profile properties safe to send to configured analytics providers.
  final Map<String, Object?> properties;
}
