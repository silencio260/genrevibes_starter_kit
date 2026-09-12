import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// The remote-config keys for the full-screen ad after the splash loader.
///
/// Know the format before changing it. AdMob's disallowed interstitial
/// implementations include "Do not place interstitial ads on app load and when
/// exiting apps", which applies whenever AdMob serves the ad through
/// mediation. App open ads are the format made for launch screens, and
/// rewarded ads must be opted into by the user.
abstract final class SplashAdPolicyKeys {
  static const _int = RemoteConfigIntCodec();
  static const _bool = RemoteConfigBoolCodec();
  static const _string = RemoteConfigStringCodec();

  /// The values [format] accepts.
  static const formatNames = <String>{
    'interstitial',
    'rewarded',
    'app_open',
    'none',
  };

  static bool _isFormat(String value) => formatNames.contains(value.trim());

  static bool _isWait(int value) => value >= 1 && value <= 30;

  /// The ad after the splash: `interstitial`, `rewarded`, `app_open` or
  /// `none`. A format the app's provider does not serve shows nothing.
  static const format = RemoteConfigKey<String>(
    name: 'splash_ad_format',
    defaultValue: 'interstitial',
    codec: _string,
    isValid: _isFormat,
  );

  /// The longest the splash waits, in seconds, for startup, the decision and
  /// the ad's load together. 1 to 30.
  static const maxWaitSeconds = RemoteConfigKey<int>(
    name: 'splash_ad_max_wait_seconds',
    defaultValue: 8,
    codec: _int,
    isValid: _isWait,
  );

  /// Whether a user's first launch, before onboarding, gets the ad too.
  static const onFirstLaunch = RemoteConfigKey<bool>(
    name: 'splash_ad_on_first_launch',
    defaultValue: true,
    codec: _bool,
  );

  /// The configured format, or null for `none`.
  static AdFormat? formatOf(RemoteConfigSnapshot snapshot) =>
      switch (snapshot.read(format).trim()) {
        'interstitial' => AdFormat.interstitial,
        'rewarded' => AdFormat.rewarded,
        'app_open' => AdFormat.appOpen,
        _ => null,
      };

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(format),
        remoteConfigKey(maxWaitSeconds),
        remoteConfigKey(onFirstLaunch),
      ];
}
