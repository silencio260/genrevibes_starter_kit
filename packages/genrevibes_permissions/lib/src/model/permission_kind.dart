/// Runtime permissions the portfolio asks for, named by capability.
///
/// Adapters map these onto platform-specific permissions. Applications never
/// name a platform permission directly, so the same request code works on
/// Android 13's split media permissions and on the older single storage grant.
enum PermissionKind {
  /// Read photos.
  photos,

  /// Read videos.
  videos,

  /// Read audio files.
  audio,

  /// Legacy external storage (Android 12 and below).
  storage,

  /// All-files access (Android). Requires a manifest declaration and review.
  manageExternalStorage,

  /// Post notifications.
  notifications,

  /// Camera.
  camera,

  /// Microphone.
  microphone,

  /// Location while in use.
  location,
}
