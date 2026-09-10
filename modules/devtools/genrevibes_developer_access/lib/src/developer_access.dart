/// Why this install has developer access, if it does.
enum DeveloperAccessReason {
  /// No developer access: the production experience.
  none,

  /// A development build. Every development build has access.
  developmentBuild,

  /// This device's hash is on a developer device list.
  listedDevice,

  /// The passcode was entered in this process. Ends when the process does.
  passcode,
}

/// A list a developer device can be named on.
enum DeveloperDeviceList {
  /// Compiled into the application.
  hardcoded,

  /// The build's env file.
  environment,

  /// Remote configuration, which changes without a release.
  remote,
}

/// The result of one passcode attempt.
enum PasscodeOutcome {
  /// Correct. Access is granted until the process ends.
  granted,

  /// Wrong. Counted against the lockout.
  incorrect,

  /// Too many wrong attempts. No attempt is evaluated until the lockout clears.
  lockedOut,
}

/// What this install may do, and why.
final class DeveloperAccess {
  /// Creates a state.
  const DeveloperAccess({
    required this.reason,
    required this.lockedOut,
    required this.attemptsRemaining,
    this.deviceHash,
    this.listedIn = const <DeveloperDeviceList>{},
  });

  /// Why access is granted, or [DeveloperAccessReason.none].
  final DeveloperAccessReason reason;

  /// This device's hash, once its identifier has been read.
  ///
  /// Safe to show and to copy — it is what goes in the lists. The identifier it
  /// was made from is never kept.
  final String? deviceHash;

  /// Every list this device's hash appears on.
  final Set<DeveloperDeviceList> listedIn;

  /// Whether passcode entry is locked out.
  final bool lockedOut;

  /// Passcode attempts left before the lockout.
  final int attemptsRemaining;

  /// Whether the developer tools are available.
  bool get isGranted => reason != DeveloperAccessReason.none;

  /// Whether ads must come from test inventory.
  ///
  /// Follows access exactly. A device that can reach the developer tools is a
  /// device someone is poking at, and a live ad tapped there is invalid traffic
  /// on the account that owns it.
  bool get servesTestAds => isGranted;
}
