import 'ad_format.dart';
import 'ad_placement.dart';

/// Observable provider lifecycle/revenue event.
enum AdEventType {
  /// Creative finished loading.
  loaded,

  /// Creative generated an impression.
  impression,

  /// User clicked the creative.
  clicked,

  /// Full-screen creative was dismissed.
  dismissed,

  /// Provider emitted an impression-level paid event.
  paid,
}

/// Provider-neutral impression-level revenue data.
final class AdRevenue {
  /// Creates an ad revenue record.
  const AdRevenue({
    required this.valueMicros,
    required this.currencyCode,
    required this.provider,
    this.mediationNetwork,
  });

  /// Revenue in one-millionths of [currencyCode].
  final num valueMicros;

  /// ISO 4217 currency code supplied by the provider.
  final String currencyCode;

  /// Selected ad provider or mediation SDK.
  final String provider;

  /// Winning mediation network when available.
  final String? mediationNetwork;

  /// Revenue in whole currency units.
  double get value => valueMicros.toDouble() / 1000000;
}

/// Ad event that can be routed into any analytics sink.
final class AdEvent {
  /// Creates an ad event.
  const AdEvent({
    required this.type,
    required this.placement,
    required this.provider,
    required this.occurredAt,
    this.revenue,
  });

  /// Event type.
  final AdEventType type;

  /// Logical placement.
  final AdPlacement placement;

  /// Provider identifier.
  final String provider;

  /// Event time.
  final DateTime occurredAt;

  /// Revenue payload for paid events.
  final AdRevenue? revenue;

  /// Convenience format accessor.
  AdFormat get format => placement.format;
}
