import 'package:genrevibes_ads/genrevibes_ads.dart';

/// AdMob unit mapped to a provider-neutral logical placement.
final class AdMobAdUnit {
  /// Creates an AdMob ad unit.
  const AdMobAdUnit({required this.placement, required this.adUnitId});

  /// Logical placement used by application code and policy.
  final AdPlacement placement;

  /// Platform-specific AdMob unit identifier selected by the application.
  final String adUnitId;
}

/// Application-owned AdMob configuration.
final class GenRevibesAdMobConfiguration {
  /// Creates AdMob configuration.
  GenRevibesAdMobConfiguration({
    required Iterable<AdMobAdUnit> adUnits,
    List<String> testDeviceIds = const <String>[],
    this.fullScreenShowTimeout = const Duration(minutes: 2),
  })  : adUnits = _indexUnits(adUnits),
        testDeviceIds = List<String>.unmodifiable(testDeviceIds);

  /// Ad units indexed by logical placement ID.
  final Map<String, AdMobAdUnit> adUnits;

  /// Explicit test device IDs passed to Google Mobile Ads.
  final List<String> testDeviceIds;

  /// Maximum wait for a full-screen dismissal or failure callback.
  final Duration fullScreenShowTimeout;

  /// Looks up the AdMob unit for [placement].
  AdMobAdUnit? unitFor(AdPlacement placement) {
    final unit = adUnits[placement.id];
    return unit?.placement.format == placement.format ? unit : null;
  }

  static Map<String, AdMobAdUnit> _indexUnits(Iterable<AdMobAdUnit> units) {
    final indexed = <String, AdMobAdUnit>{};
    for (final unit in units) {
      if (indexed.containsKey(unit.placement.id)) {
        throw ArgumentError.value(
          unit.placement.id,
          'adUnits',
          'Logical AdMob placement IDs must be unique.',
        );
      }
      indexed[unit.placement.id] = unit;
    }
    return Map<String, AdMobAdUnit>.unmodifiable(indexed);
  }
}
