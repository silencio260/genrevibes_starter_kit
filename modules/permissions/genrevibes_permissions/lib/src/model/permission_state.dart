/// Normalized permission status.
enum PermissionState {
  /// Fully granted.
  granted,

  /// Granted for a subset (iOS limited photo library).
  limited,

  /// Granted provisionally (iOS quiet notifications).
  provisional,

  /// Denied, and the user can be asked again.
  denied,

  /// Denied, and the OS will not show the prompt again. Only the settings
  /// screen can change it.
  permanentlyDenied,

  /// Blocked by device policy or parental controls.
  restricted,

  /// Could not be determined.
  unknown,
}

/// Whether a state lets the feature proceed.
extension PermissionStateAccess on PermissionState {
  /// Granted in any form that unblocks the feature.
  bool get isUsable =>
      this == PermissionState.granted ||
      this == PermissionState.limited ||
      this == PermissionState.provisional;

  /// Asking again is pointless; only settings can help.
  bool get needsSettings =>
      this == PermissionState.permanentlyDenied ||
      this == PermissionState.restricted;
}
