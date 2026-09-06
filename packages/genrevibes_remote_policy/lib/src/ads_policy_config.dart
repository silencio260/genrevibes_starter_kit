import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'ads_policy_keys.dart';

/// Typed view of the ads-policy remote configuration.
final class AdsPolicyConfig {
  /// Creates a config.
  const AdsPolicyConfig({
    required this.enabled,
    required this.firstInterstitialDelay,
    required this.firstRewardedDelay,
    required this.interstitialInterval,
    required this.bannerInterval,
    required this.rewardedInterval,
    required this.nativeInterval,
    required this.appOpenInterval,
    required this.showAppOpenAd,
    required Map<AdFormat, String> unitOverrides,
  }) : _unitOverrides = unitOverrides;

  /// Reads every key from [snapshot], defaulting defensively.
  factory AdsPolicyConfig.fromSnapshot(RemoteConfigSnapshot snapshot) {
    Duration seconds(RemoteConfigKey<int> key) =>
        Duration(seconds: snapshot.read(key));
    return AdsPolicyConfig(
      enabled: snapshot.read(AdsPolicyKeys.adsEnabled),
      firstInterstitialDelay:
          seconds(AdsPolicyKeys.timeBeforeFirstInterstitial),
      firstRewardedDelay: seconds(AdsPolicyKeys.timeBeforeFirstRewarded),
      interstitialInterval: seconds(AdsPolicyKeys.minInterstitialInterval),
      bannerInterval: seconds(AdsPolicyKeys.minBannerInterval),
      rewardedInterval: seconds(AdsPolicyKeys.minRewardedInterval),
      nativeInterval: seconds(AdsPolicyKeys.minNativeInterval),
      appOpenInterval: seconds(AdsPolicyKeys.minAppOpenInterval),
      showAppOpenAd: snapshot.read(AdsPolicyKeys.showAppOpenAd),
      unitOverrides: <AdFormat, String>{
        for (final format in AdFormat.values)
          if (snapshot.read(AdsPolicyKeys.unitFor(format)).trim().isNotEmpty)
            format: snapshot.read(AdsPolicyKeys.unitFor(format)).trim(),
      },
    );
  }

  /// Master switch.
  final bool enabled;

  /// Session-start delay before the first interstitial.
  final Duration firstInterstitialDelay;

  /// Session-start delay before the first rewarded ad.
  final Duration firstRewardedDelay;

  /// Minimum gap between interstitials.
  final Duration interstitialInterval;

  /// Minimum gap between banner refreshes.
  final Duration bannerInterval;

  /// Minimum gap between rewarded ads.
  final Duration rewardedInterval;

  /// Minimum gap between native ads.
  final Duration nativeInterval;

  /// Minimum gap between app-open ads.
  final Duration appOpenInterval;

  /// Whether app-open ads may show.
  final bool showAppOpenAd;

  final Map<AdFormat, String> _unitOverrides;

  /// Remote ad unit for [format], or `null` to keep the bundled unit.
  String? unitOverride(AdFormat format) => _unitOverrides[format];

  /// The placement policy this config implies for [format].
  AdPlacementPolicy policyFor(AdFormat format) => switch (format) {
        AdFormat.banner => AdPlacementPolicy(
            enabled: enabled,
            minimumInterval: bannerInterval,
          ),
        AdFormat.interstitial => AdPlacementPolicy(
            enabled: enabled,
            initialDelay: firstInterstitialDelay,
            minimumInterval: interstitialInterval,
          ),
        AdFormat.rewarded => AdPlacementPolicy(
            enabled: enabled,
            initialDelay: firstRewardedDelay,
            minimumInterval: rewardedInterval,
          ),
        AdFormat.native => AdPlacementPolicy(
            enabled: enabled,
            minimumInterval: nativeInterval,
          ),
        AdFormat.appOpen => AdPlacementPolicy(
            enabled: enabled && showAppOpenAd,
            minimumInterval: appOpenInterval,
          ),
      };

  /// Placement policies keyed by placement ID for the given placements.
  Map<String, AdPlacementPolicy> toPlacementPolicies(
    Iterable<AdPlacement> placements,
  ) {
    return <String, AdPlacementPolicy>{
      for (final placement in placements)
        placement.id: policyFor(placement.format),
    };
  }
}
