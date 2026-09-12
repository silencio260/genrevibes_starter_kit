import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// The remote-config keys that shape onboarding.
abstract final class OnboardingPolicyKeys {
  static const _bool = RemoteConfigBoolCodec();

  /// Whether onboarding may show ads. Defaults to true.
  ///
  /// A remote switch rather than a constant, so ads can come off onboarding —
  /// after a retention drop, a policy concern, or to A/B test the flow —
  /// without a release. It only permits ads: premium, consent and the ad
  /// provider still decide whether one is shown.
  static const adsEnabled = RemoteConfigKey<bool>(
    name: 'onboarding_ads_enabled',
    defaultValue: true,
    codec: _bool,
  );

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(adsEnabled),
      ];
}
