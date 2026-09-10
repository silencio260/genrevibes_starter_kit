/// Storage keys used by the session-replay controller.
///
/// Both are device-local and survive reinstall only as far as the platform's
/// backup does. Neither has a legacy equivalent: nothing before this owned a
/// replay decision.
abstract final class SessionReplayKeys {
  /// This install's stable rollout bucket, 0-99.
  ///
  /// Drawn once and kept, so lowering the rollout percentage narrows an
  /// existing cohort rather than reshuffling it. A user who was being recorded
  /// at 100% either keeps being recorded at 40% or stops for good; nobody
  /// enters the cohort as the number comes down.
  static const bucket = 'genrevibes.analytics.session_replay.bucket.v1';

  /// A developer's explicit force-on or force-off, when one is set.
  static const override = 'genrevibes.analytics.session_replay.override.v1';
}
