import 'dart:convert';

import 'remote_config_codec.dart';

/// A JSON array of strings, for lists maintained in a console.
///
/// A blank value is an empty list. An unset parameter arrives from some
/// providers as an empty string, and that should mean "nothing listed", not an
/// invalid value that falls back to a default.
final class RemoteConfigStringListCodec
    implements RemoteConfigCodec<List<String>> {
  /// Creates the codec.
  const RemoteConfigStringListCodec();

  @override
  RemoteConfigValueKind get kind => RemoteConfigValueKind.json;

  @override
  List<String> decode(Object? value) {
    final Object? decoded = value is String
        ? (value.trim().isEmpty ? const <Object?>[] : jsonDecode(value))
        : value;
    if (decoded is List<Object?> && decoded.every((item) => item is String)) {
      return List<String>.unmodifiable(decoded.cast<String>());
    }
    throw const FormatException('Expected a JSON array of strings.');
  }

  @override
  Object encode(List<String> value) => jsonEncode(value);
}
