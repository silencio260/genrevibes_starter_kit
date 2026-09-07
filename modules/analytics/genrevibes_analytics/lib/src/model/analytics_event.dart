/// A provider-neutral analytics event.
final class AnalyticsEvent {
  /// Creates an analytics event.
  const AnalyticsEvent({
    required this.name,
    this.properties = const <String, Object?>{},
    this.occurredAt,
  });

  /// Stable event name shared by every analytics provider.
  final String name;

  /// Provider-neutral event properties.
  final Map<String, Object?> properties;

  /// Original event time, or `null` when the sink should use delivery time.
  final DateTime? occurredAt;
}
