import 'remote_config_codec.dart';
import 'remote_config_key.dart';

/// Immutable registry of every remote value an application accepts.
final class RemoteConfigSchema {
  /// Creates a schema and rejects blank or duplicate key names.
  RemoteConfigSchema(Iterable<RemoteConfigKey<Object?>> keys)
      : keys = List<RemoteConfigKey<Object?>>.unmodifiable(keys) {
    final names = <String>{};
    for (final key in this.keys) {
      if (key.name.trim().isEmpty) {
        throw ArgumentError.value(
            key.name, 'keys', 'Key names cannot be blank.');
      }
      if (!names.add(key.name)) {
        throw ArgumentError.value(
            key.name, 'keys', 'Key names must be unique.');
      }
      if (key.tryDecode(key.defaultValue) == null) {
        throw ArgumentError.value(
          key.defaultValue,
          key.name,
          'The bundled default does not satisfy its codec and validation rule.',
        );
      }
    }
  }

  /// Typed keys accepted by this application.
  final List<RemoteConfigKey<Object?>> keys;

  /// Keys indexed by provider name.
  Map<String, RemoteConfigKey<Object?>> get byName =>
      <String, RemoteConfigKey<Object?>>{
        for (final key in keys) key.name: key,
      };

  /// Provider-ready encoded defaults.
  Map<String, Object> get encodedDefaults => <String, Object>{
        for (final key in keys) key.name: key.codec.encode(key.defaultValue),
      };
}

/// Safely widens a typed key for inclusion in a heterogeneous schema.
RemoteConfigKey<Object?> remoteConfigKey<T>(RemoteConfigKey<T> key) {
  return RemoteConfigKey<Object?>(
    name: key.name,
    defaultValue: key.defaultValue,
    codec: _WidenedCodec<T>(key.codec),
    isValid: (value) {
      if (value is! T) return false;
      return key.isValid?.call(value) ?? true;
    },
  );
}

final class _WidenedCodec<T> implements RemoteConfigCodec<Object?> {
  const _WidenedCodec(this._codec);

  final RemoteConfigCodec<T> _codec;

  @override
  RemoteConfigValueKind get kind => _codec.kind;

  @override
  Object? decode(Object? value) => _codec.decode(value);

  @override
  Object encode(Object? value) {
    if (value is! T) {
      throw FormatException('Value does not match the remote config key type.');
    }
    return _codec.encode(value);
  }
}
