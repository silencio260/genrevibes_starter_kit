/// Storage keys used by [DeviceIdentityResolver].
abstract final class DeviceIdentityKeys {
  /// The persisted install identifier.
  static const installId = 'genrevibes.device_identity.install_id.v1';

  /// Legacy key names to adopt, mapped from their current equivalents.
  ///
  /// Hand-rolled identifiers stored whichever id won their cascade under
  /// `device_uuid`. Adopting it keeps analytics continuity for existing users.
  static const legacyKeys = <String, String>{installId: 'device_uuid'};
}
