import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'firebase_remote_config_configuration.dart';

/// Values and per-key origins read from Firebase's activated namespace.
final class FirebaseRemoteConfigReadResult {
  /// Creates a Firebase read result.
  FirebaseRemoteConfigReadResult({
    required Map<String, Object?> values,
    required Map<String, RemoteConfigValueOrigin> origins,
  })  : values = Map<String, Object?>.unmodifiable(values),
        origins = Map<String, RemoteConfigValueOrigin>.unmodifiable(origins);

  /// Typed raw values expected by the neutral schema codecs.
  final Map<String, Object?> values;

  /// Origin reported by Firebase for each key.
  final Map<String, RemoteConfigValueOrigin> origins;
}

/// Injectable boundary around the Firebase Remote Config plugin.
abstract interface class FirebaseRemoteConfigClient {
  /// Configures the SDK, bundled defaults, and persisted activated values.
  Future<void> setup(
    GenreVibesFirebaseRemoteConfigConfiguration configuration,
    Map<String, Object> defaults,
  );

  /// Fetches and activates the latest Firebase values.
  Future<bool> fetchAndActivate();

  /// Reads every schema key from the activated Firebase namespace.
  FirebaseRemoteConfigReadResult read(
    RemoteConfigSchema schema, {
    required RemoteConfigValueOrigin remoteOrigin,
  });
}

/// Production client backed by `firebase_remote_config`.
final class DefaultFirebaseRemoteConfigClient
    implements FirebaseRemoteConfigClient {
  /// Creates a client for the default Firebase app or an injected instance.
  DefaultFirebaseRemoteConfigClient({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<void> setup(
    GenreVibesFirebaseRemoteConfigConfiguration configuration,
    Map<String, Object> defaults,
  ) async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: configuration.fetchTimeout,
        minimumFetchInterval: configuration.minimumFetchInterval,
      ),
    );
    await _remoteConfig.setDefaults(defaults);
    await _remoteConfig.ensureInitialized();
  }

  @override
  Future<bool> fetchAndActivate() => _remoteConfig.fetchAndActivate();

  @override
  FirebaseRemoteConfigReadResult read(
    RemoteConfigSchema schema, {
    required RemoteConfigValueOrigin remoteOrigin,
  }) {
    final values = <String, Object?>{};
    final origins = <String, RemoteConfigValueOrigin>{};
    for (final key in schema.keys) {
      final value = _remoteConfig.getValue(key.name);
      values[key.name] = switch (key.codec.kind) {
        RemoteConfigValueKind.string => value.asString(),
        RemoteConfigValueKind.boolean => value.asBool(),
        RemoteConfigValueKind.integer => value.asInt(),
        RemoteConfigValueKind.doubleValue => value.asDouble(),
        RemoteConfigValueKind.json => value.asString(),
      };
      origins[key.name] = switch (value.source) {
        ValueSource.valueRemote => remoteOrigin,
        ValueSource.valueDefault => RemoteConfigValueOrigin.defaultValue,
        ValueSource.valueStatic => RemoteConfigValueOrigin.defaultValue,
      };
    }
    return FirebaseRemoteConfigReadResult(values: values, origins: origins);
  }
}
