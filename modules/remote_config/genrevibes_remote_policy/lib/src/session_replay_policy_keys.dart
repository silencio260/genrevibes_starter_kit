import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// The remote-config keys that govern session replay.
///
/// Session replay is billed per recording and stores what the user's screen
/// looked like, so both the volume and the privacy of it are things a portfolio
/// needs to change without shipping a release. These four are that lever.
///
/// The percentage defaults to 100 because that is what every app in the
/// portfolio does today: replay is on for everyone in release. A key whose
/// default silently cut recording to zero would look like an outage the first
/// time an app adopted this and Firebase had no value set for it. Turning the
/// number *down* is the deliberate act, done remotely, watching the bill.
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
    defaultValue: 100,
    codec: _int,
    isValid: _isPercentage,
  );

  /// Whether replay masks all rendered text.
  ///
  /// Off by default, which is what the portfolio ships today: a replay of a
  /// masked screen shows grey boxes moving around, and cannot answer the
  /// question replay is paid for — where a user got stuck and what they were
  /// looking at when they did.
  ///
  /// It is a remote key rather than a constant so it can be turned on for
  /// everyone, immediately and without a release, if a screen ever renders
  /// something that should not be recorded.
  static const maskAllText = RemoteConfigKey<bool>(
    name: 'session_replay_mask_text',
    defaultValue: false,
    codec: _bool,
  );

  /// Whether replay masks all rendered images. Same reasoning as [maskAllText].
  static const maskAllImages = RemoteConfigKey<bool>(
    name: 'session_replay_mask_images',
    defaultValue: false,
    codec: _bool,
  );

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(enabled),
        remoteConfigKey(percentOfUsers),
        remoteConfigKey(maskAllText),
        remoteConfigKey(maskAllImages),
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
