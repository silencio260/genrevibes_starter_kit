import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

/// The remote-config key that names developer devices.
///
/// Holds hashes, never device identifiers: remote config is downloaded by every
/// install, so whatever is in it is public. See `DeveloperDeviceHash`.
///
/// This is the list that changes without a release. A phone added here gets
/// the developer tools and test ads on the store build as soon as it fetches.
abstract final class DeveloperAccessPolicyKeys {
  /// JSON array of developer device hashes.
  static const deviceHashes = RemoteConfigKey<List<String>>(
    name: 'developer_device_hashes',
    defaultValue: <String>[],
    codec: RemoteConfigStringListCodec(),
  );

  /// Every key, widened for a schema.
  static List<RemoteConfigKey<Object?>> get all => <RemoteConfigKey<Object?>>[
        remoteConfigKey(deviceHashes),
      ];

  /// The listed hashes in [snapshot]. Malformed entries are dropped by the
  /// controller, not here, so the Lab can still show what was sent.
  static List<String> hashesFrom(RemoteConfigSnapshot snapshot) =>
      snapshot.read(deviceHashes);
}
