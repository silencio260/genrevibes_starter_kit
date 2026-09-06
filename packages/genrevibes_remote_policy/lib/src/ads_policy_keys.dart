import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// The remote-config keys every portfolio app reads for ad timing.
///
/// Names are the production keys already live in Firebase projects; they are
/// not tidied. `time_before_first_rewared_ad` is misspelled in production and
/// stays misspelled here, because renaming it would silently reset the value
/// to its default in every app on the next release.
///
/// Intervals are in seconds. Defaults are Story Saver's bundled values.
abstract final class AdsPolicyKeys {
  static const _int = RemoteConfigIntCodec();
  static const _bool = RemoteConfigBoolCodec();
  static const _string = RemoteConfigStringCodec();

  static bool _nonNegative(int value) => value >= 0;

  /// Master switch. `false` disables every placement without a release.
  static const adsEnabled = RemoteConfigKey<bool>(
    name: 'ads_enabled',
    defaultValue: true,
    codec: _bool,
  );

  /// Seconds after session start before the first interstitial may show.
  static const timeBeforeFirstInterstitial = RemoteConfigKey<int>(
    name: 'time_before_first_insta_ad',
    defaultValue: 3,
    codec: _int,
    isValid: _nonNegative,
  );

  /// Seconds after session start before the first rewarded ad may show.
  static const timeBeforeFirstRewarded = RemoteConfigKey<int>(
    name: 'time_before_first_rewared_ad',
    defaultValue: 0,
    codec: _int,
    isValid: _nonNegative,
  );

  /// Minimum seconds between interstitials.
  static const minInterstitialInterval = RemoteConfigKey<int>(
    name: 'min_insta_ad_interval',
    defaultValue: 5,
    codec: _int,
    isValid: _nonNegative,
  );

  /// Minimum seconds between banner refreshes.
  static const minBannerInterval = RemoteConfigKey<int>(
    name: 'min_banner_ad_interval',
    defaultValue: 3,
    codec: _int,
    isValid: _nonNegative,
  );

  /// Minimum seconds between rewarded ads.
  static const minRewardedInterval = RemoteConfigKey<int>(
    name: 'min_rewarded_ad_interval',
    defaultValue: 0,
    codec: _int,
    isValid: _nonNegative,
  );

  /// Minimum seconds between native ads.
  static const minNativeInterval = RemoteConfigKey<int>(
    name: 'min_native_interval',
    defaultValue: 0,
    codec: _int,
    isValid: _nonNegative,
  );

  /// Minimum seconds between app-open ads.
  static const minAppOpenInterval = RemoteConfigKey<int>(
    name: 'min_app_open_ad',
    defaultValue: 0,
    codec: _int,
    isValid: _nonNegative,
  );

  /// Whether app-open ads may show at all.
  static const showAppOpenAd = RemoteConfigKey<bool>(
    name: 'should_show_app_open_ad',
    defaultValue: true,
    codec: _bool,
  );

  /// Per-format ad unit override. Empty means "use the bundled unit".
  static const bannerUnit = RemoteConfigKey<String>(
    name: 'banner_ad_id',
    defaultValue: '',
    codec: _string,
  );

  /// Per-format ad unit override. Empty means "use the bundled unit".
  static const interstitialUnit = RemoteConfigKey<String>(
    name: 'interstitial_ad_id',
    defaultValue: '',
    codec: _string,
  );

  /// Per-format ad unit override. Empty means "use the bundled unit".
  static const rewardedUnit = RemoteConfigKey<String>(
    name: 'rewarded_ad_id',
    defaultValue: '',
    codec: _string,
  );

  /// Per-format ad unit override. Empty means "use the bundled unit".
  static const nativeUnit = RemoteConfigKey<String>(
    name: 'native_ad_id',
    defaultValue: '',
    codec: _string,
  );

  /// Per-format ad unit override. Empty means "use the bundled unit".
  static const appOpenUnit = RemoteConfigKey<String>(
    name: 'app_open_ad_id',
    defaultValue: '',
    codec: _string,
  );

  /// The unit-override key for [format].
  static RemoteConfigKey<String> unitFor(AdFormat format) => switch (format) {
        AdFormat.banner => bannerUnit,
        AdFormat.interstitial => interstitialUnit,
        AdFormat.rewarded => rewardedUnit,
        AdFormat.native => nativeUnit,
        AdFormat.appOpen => appOpenUnit,
      };

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(adsEnabled),
        remoteConfigKey(timeBeforeFirstInterstitial),
        remoteConfigKey(timeBeforeFirstRewarded),
        remoteConfigKey(minInterstitialInterval),
        remoteConfigKey(minBannerInterval),
        remoteConfigKey(minRewardedInterval),
        remoteConfigKey(minNativeInterval),
        remoteConfigKey(minAppOpenInterval),
        remoteConfigKey(showAppOpenAd),
        remoteConfigKey(bannerUnit),
        remoteConfigKey(interstitialUnit),
        remoteConfigKey(rewardedUnit),
        remoteConfigKey(nativeUnit),
        remoteConfigKey(appOpenUnit),
      ];
}
