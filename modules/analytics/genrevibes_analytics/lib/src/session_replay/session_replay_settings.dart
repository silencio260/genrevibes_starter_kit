/// A developer's manual answer to "should this device record?".
///
/// Persisted, so it survives the relaunch that a masking change needs, and
/// deliberately not scoped to development builds by the module: which builds
/// may set one is the application's decision, made where the dev surface is
/// wired.
enum SessionReplayOverride {
  /// No override. The rollout decides.
  followRemote,

  /// Record regardless of the rollout percentage.
  forceOn,

  /// Never record, whatever the rollout says.
  forceOff;

  /// Parses a stored value, treating anything unrecognized as no override.
  static SessionReplayOverride parse(String? stored) {
    return switch (stored) {
      'on' => SessionReplayOverride.forceOn,
      'off' => SessionReplayOverride.forceOff,
      _ => SessionReplayOverride.followRemote,
    };
  }

  /// The stored form of this override.
  String get storedValue => switch (this) {
        SessionReplayOverride.followRemote => 'remote',
        SessionReplayOverride.forceOn => 'on',
        SessionReplayOverride.forceOff => 'off',
      };
}

/// Why the current plan does or does not record.
///
/// Carried so a diagnostics surface can answer "why is this device not being
/// recorded?" without re-deriving the arithmetic and getting a different
/// answer than the controller did.
enum SessionReplayReason {
  /// A developer forced recording on.
  forcedOn,

  /// A developer forced recording off.
  forcedOff,

  /// The remote master switch is off.
  disabledRemotely,

  /// This install's bucket falls inside the rollout.
  inRollout,

  /// This install's bucket falls outside the rollout.
  outsideRollout,
}

/// What the rollout says, before this install's bucket is considered.
///
/// Provider-neutral by construction: where these values come from is the
/// application's business. Nothing here knows that remote configuration exists.
final class SessionReplayPolicy {
  /// Creates a policy.
  const SessionReplayPolicy({
    this.enabled = true,
    this.percentOfUsers = 0,
    this.maskAllText = false,
    this.maskAllImages = false,
  });

  /// Master switch. `false` stops every device recording, rollout or not.
  final bool enabled;

  /// Share of installs to record, 0-100.
  ///
  /// Defaults to zero so a policy nobody configured records nothing. An
  /// application that wants replay says so.
  final int percentOfUsers;

  /// Whether replay masks all rendered text.
  final bool maskAllText;

  /// Whether replay masks all rendered images.
  final bool maskAllImages;

  /// The percentage clamped into range, for arithmetic.
  int get boundedPercent => percentOfUsers < 0
      ? 0
      : percentOfUsers > 100
          ? 100
          : percentOfUsers;

  /// Copies this policy with the given overrides.
  SessionReplayPolicy copyWith({
    bool? enabled,
    int? percentOfUsers,
    bool? maskAllText,
    bool? maskAllImages,
  }) {
    return SessionReplayPolicy(
      enabled: enabled ?? this.enabled,
      percentOfUsers: percentOfUsers ?? this.percentOfUsers,
      maskAllText: maskAllText ?? this.maskAllText,
      maskAllImages: maskAllImages ?? this.maskAllImages,
    );
  }

  @override
  String toString() => 'SessionReplayPolicy(enabled: $enabled, '
      'percentOfUsers: $percentOfUsers, maskAllText: $maskAllText, '
      'maskAllImages: $maskAllImages)';
}

/// The resolved decision for this install.
final class SessionReplayPlan {
  /// Creates a plan.
  const SessionReplayPlan({
    required this.recording,
    required this.maskAllText,
    required this.maskAllImages,
    required this.reason,
    required this.manualOverride,
    required this.bucket,
    required this.percentOfUsers,
  });

  /// A plan that records nothing, for use before the controller resolves one.
  static const none = SessionReplayPlan(
    recording: false,
    maskAllText: false,
    maskAllImages: false,
    reason: SessionReplayReason.outsideRollout,
    manualOverride: SessionReplayOverride.followRemote,
    bucket: 0,
    percentOfUsers: 0,
  );

  /// Whether this install records.
  final bool recording;

  /// Whether replay masks all rendered text.
  ///
  /// Read when the SDK is configured. A provider that fixes masking at setup
  /// cannot honor a later change until the next launch.
  final bool maskAllText;

  /// Whether replay masks all rendered images. Same timing as [maskAllText].
  final bool maskAllImages;

  /// Why [recording] holds the value it does.
  final SessionReplayReason reason;

  /// The override in force, if any.
  ///
  /// Not named `override`: a field by that name shadows the `@override`
  /// annotation everywhere else in the class.
  final SessionReplayOverride manualOverride;

  /// This install's stable bucket, 0-99.
  final int bucket;

  /// The rollout percentage this plan was resolved against.
  final int percentOfUsers;

  /// Whether the rollout, ignoring any override, would record this install.
  bool get inRollout => bucket < percentOfUsers;

  @override
  String toString() => 'SessionReplayPlan(recording: $recording, '
      'reason: ${reason.name}, bucket: $bucket/$percentOfUsers, '
      'override: ${manualOverride.name}, maskAllText: $maskAllText, '
      'maskAllImages: $maskAllImages)';
}
