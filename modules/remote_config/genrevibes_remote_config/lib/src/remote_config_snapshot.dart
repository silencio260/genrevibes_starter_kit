import 'remote_config_key.dart';

/// Origin of an accepted value in a remote-config snapshot.
enum RemoteConfigValueOrigin {
  /// Bundled application default.
  defaultValue,

  /// Application-owned last-known-good cache.
  cache,

  /// Provider SDK's persisted activated value.
  providerCache,

  /// Successful provider refresh.
  remote,
}

/// Immutable, validated configuration visible to application features.
final class RemoteConfigSnapshot {
  /// Creates a snapshot.
  RemoteConfigSnapshot({
    required Map<String, Object?> values,
    required Map<String, RemoteConfigValueOrigin> origins,
    required this.observedAt,
  })  : values = Map<String, Object?>.unmodifiable(values),
        origins = Map<String, RemoteConfigValueOrigin>.unmodifiable(origins);

  /// Accepted typed values by provider key.
  final Map<String, Object?> values;

  /// Per-key origins.
  final Map<String, RemoteConfigValueOrigin> origins;

  /// Time this snapshot was created.
  final DateTime observedAt;

  /// Reads [key], falling back to its bundled default defensively.
  T read<T>(RemoteConfigKey<T> key) {
    return key.tryDecode(values[key.name]) ?? key.defaultValue;
  }

  /// Returns where the currently accepted [key] value came from.
  RemoteConfigValueOrigin originOf<T>(RemoteConfigKey<T> key) {
    return origins[key.name] ?? RemoteConfigValueOrigin.defaultValue;
  }
}
