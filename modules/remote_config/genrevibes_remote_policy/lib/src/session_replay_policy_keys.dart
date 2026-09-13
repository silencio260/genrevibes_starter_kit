import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// Session replay defaults for new apps: zero rollout and masked content.
/// Apps choose their own rollout via PortfolioRemoteConfigSchema.build.
abstract final class SessionReplayPolicyKeys {
  static const _int = RemoteConfigIntCodec();
  static const _bool = RemoteConfigBoolCodec();

  static bool _isPercentage(int value) => value >= 0 && value <= 100;

  /// Master switch. `false` stops replay everywhere without a release.
  static const enabled = RemoteConfigKey<bool>(
    name: 'session_replay_enabled',
    defaultValue: true,
    codec: _bool,
  );

  /// Share of installs recorded, 0-100.
  ///
  /// A stable per-install bucket, not a per-session dice roll, so lowering this
  /// narrows the recorded cohort instead of resampling it.
  static const percentOfUsers = RemoteConfigKey<int>(
    name: 'session_replay_percent',
    defaultValue: 0,
    codec: _int,
    isValid: _isPercentage,
  );

  /// Whether replay masks text. Changing SDK masking requires a restart.
  static const maskAllText = RemoteConfigKey<bool>(
    name: 'session_replay_mask_text',
    defaultValue: true,
    codec: _bool,
  );

  /// Whether replay masks all rendered images. Same reasoning as [maskAllText].
  static const maskAllImages = RemoteConfigKey<bool>(
    name: 'session_replay_mask_images',
    defaultValue: true,
    codec: _bool,
  );

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(enabled),
        remoteConfigKey(percentOfUsers),
        remoteConfigKey(maskAllText),
        remoteConfigKey(maskAllImages),
      ];

  /// Override bundled defaults without changing the shared key names.
  static List<RemoteConfigKey<Object?>> withDefaults(
          SessionReplayPolicy policy) =>
      [
        remoteConfigKey(RemoteConfigKey<bool>(
            name: enabled.name, defaultValue: policy.enabled, codec: _bool)),
        remoteConfigKey(RemoteConfigKey<int>(
            name: percentOfUsers.name,
            defaultValue: policy.boundedPercent,
            codec: _int,
            isValid: _isPercentage)),
        remoteConfigKey(RemoteConfigKey<bool>(
            name: maskAllText.name,
            defaultValue: policy.maskAllText,
            codec: _bool)),
        remoteConfigKey(RemoteConfigKey<bool>(
            name: maskAllImages.name,
            defaultValue: policy.maskAllImages,
            codec: _bool)),
      ];

  /// Reads a policy out of [snapshot].
  static SessionReplayPolicy policyFrom(RemoteConfigSnapshot snapshot) {
    return SessionReplayPolicy(
      enabled: snapshot.read(enabled),
      percentOfUsers: snapshot.read(percentOfUsers),
      maskAllText: snapshot.read(maskAllText),
      maskAllImages: snapshot.read(maskAllImages),
    );
  }
}
