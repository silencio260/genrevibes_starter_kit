import 'remote_config_codec.dart';

/// Typed remote-config key with a bundled default and validation rule.
final class RemoteConfigKey<T> {
  /// Creates a typed key.
  const RemoteConfigKey({
    required this.name,
    required this.defaultValue,
    required this.codec,
    this.isValid,
  });

  /// Stable provider key.
  final String name;

  /// Value used when no valid cache or provider value exists.
  final T defaultValue;

  /// Codec used to parse untrusted values.
  final RemoteConfigCodec<T> codec;

  /// Optional domain constraint, such as a non-negative ad interval.
  final bool Function(T value)? isValid;

  /// Decodes and validates [raw], or returns `null` when it is unsafe.
  T? tryDecode(Object? raw) {
    try {
      final value = codec.decode(raw);
      if (!(isValid?.call(value) ?? true)) return null;
      return value;
    } on Object {
      return null;
    }
  }
}
