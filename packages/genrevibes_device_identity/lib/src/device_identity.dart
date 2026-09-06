/// Tracking authorization state, normalized across platforms.
enum TrackingAuthorization {
  /// The user has not been asked.
  notDetermined,

  /// The user allowed tracking; an advertising identifier is available.
  authorized,

  /// The user declined.
  denied,

  /// Blocked by device policy.
  restricted,

  /// Not applicable on this platform or OS version.
  notSupported,
}

/// Identifiers describing this install.
///
/// [installId] is the one every app feature should key on: it is generated
/// once, persisted, and survives everything short of a reinstall. The other
/// two are best-effort and may be absent.
final class DeviceIdentity {
  /// Creates an identity.
  const DeviceIdentity({
    required this.installId,
    required this.tracking,
    this.vendorId,
    this.advertisingId,
  });

  /// Stable per-install identifier.
  final String installId;

  /// Platform vendor identifier, when the platform exposes one.
  final String? vendorId;

  /// Advertising identifier, only when tracking is authorized.
  final String? advertisingId;

  /// Tracking authorization at the time of resolution.
  final TrackingAuthorization tracking;

  /// Whether an advertising identifier is usable.
  bool get canTrack =>
      tracking == TrackingAuthorization.authorized &&
      (advertisingId?.isNotEmpty ?? false);
}
