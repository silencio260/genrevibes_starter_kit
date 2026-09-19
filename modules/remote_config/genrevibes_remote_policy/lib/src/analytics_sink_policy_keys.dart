import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// Remote kill switches for individual paid analytics providers.
///
/// Each key turns one provider off without a release, to stop paying for its
/// events or replay-linked traffic while the rest of analytics keeps running.
/// Every key defaults to `true`, so an app that never sets them behaves exactly
/// as before.
///
/// Firebase has no key here on purpose. It costs nothing to run and is the
/// portfolio's baseline dashboard, so it stays on. Its own
/// `collectionEnabled` flag exists for consent and for keeping development
/// traffic out of production, not for cost.
abstract final class AnalyticsSinkPolicyKeys {
  static const _bool = RemoteConfigBoolCodec();

  /// `false` stops all Mixpanel event delivery on the next fetch activation.
  static const mixpanelEnabled = RemoteConfigKey<bool>(
    name: 'analytics_mixpanel_enabled',
    defaultValue: true,
    codec: _bool,
  );

  /// `false` stops all PostHog event delivery on the next fetch activation.
  static const posthogEnabled = RemoteConfigKey<bool>(
    name: 'analytics_posthog_enabled',
    defaultValue: true,
    codec: _bool,
  );

  static const _known = <String, RemoteConfigKey<bool>>{
    'mixpanel': mixpanelEnabled,
    'posthog': posthogEnabled,
  };

  /// The switch for the sink whose `sinkId` is [sinkId].
  ///
  /// Unknown sinks get `analytics_<sinkId>_enabled`, defaulting to `true`. Add
  /// that key to the app's schema and template before relying on it.
  static RemoteConfigKey<bool> keyFor(String sinkId) =>
      _known[sinkId] ??
      RemoteConfigKey<bool>(
        name: 'analytics_${sinkId}_enabled',
        defaultValue: true,
        codec: _bool,
      );

  /// Every shared key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(mixpanelEnabled),
        remoteConfigKey(posthogEnabled),
      ];
}
