/// Storage keys used by `DeveloperAccessController`.
///
/// Neither holds the passcode, an attempt, or a device identifier.
abstract final class DeveloperAccessKeys {
  /// Wrong passcode attempts so far.
  static const failedPasscodeAttempts =
      'genrevibes.developer_access.failed_passcode_attempts.v1';

  /// The install the attempts were counted on.
  ///
  /// Android's Auto Backup restores shared preferences into a reinstalled app,
  /// which would carry a lockout across the reinstall that is supposed to clear
  /// it. Attempts recorded against a different install are ignored.
  static const failuresInstallMarker =
      'genrevibes.developer_access.failures_install_marker.v1';
}
