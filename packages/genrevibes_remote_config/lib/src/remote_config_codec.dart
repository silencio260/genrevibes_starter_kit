import 'dart:convert';

/// Primitive storage representation requested from a provider SDK.
enum RemoteConfigValueKind {
  /// UTF-8 text or a provider string value.
  string,

  /// Boolean value.
  boolean,

  /// Integer value.
  integer,

  /// Floating-point value.
  doubleValue,

  /// JSON object or array, commonly transported as a string.
  json,
}

/// Converts untrusted provider or cache values into an application type.
abstract interface class RemoteConfigCodec<T> {
  /// Value representation a provider adapter should request.
  RemoteConfigValueKind get kind;

  /// Decodes [value], throwing [FormatException] when it is invalid.
  T decode(Object? value);

  /// Encodes a typed default or cache value for a provider SDK.
  Object encode(T value);
}

/// Strict string codec.
final class RemoteConfigStringCodec implements RemoteConfigCodec<String> {
  /// Creates a string codec.
  const RemoteConfigStringCodec();

  @override
  RemoteConfigValueKind get kind => RemoteConfigValueKind.string;

  @override
  String decode(Object? value) {
    if (value is String) return value;
    throw FormatException(
        'Expected a String but received ${value.runtimeType}.');
  }

  @override
  Object encode(String value) => value;
}

/// Boolean codec supporting provider-native booleans and true/false strings.
final class RemoteConfigBoolCodec implements RemoteConfigCodec<bool> {
  /// Creates a boolean codec.
  const RemoteConfigBoolCodec();

  @override
  RemoteConfigValueKind get kind => RemoteConfigValueKind.boolean;

  @override
  bool decode(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    throw FormatException('Expected a bool but received ${value.runtimeType}.');
  }

  @override
  Object encode(bool value) => value;
}

/// Integer codec that rejects fractional numeric values.
final class RemoteConfigIntCodec implements RemoteConfigCodec<int> {
  /// Creates an integer codec.
  const RemoteConfigIntCodec();

  @override
  RemoteConfigValueKind get kind => RemoteConfigValueKind.integer;

  @override
  int decode(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Expected an int but received ${value.runtimeType}.');
  }

  @override
  Object encode(int value) => value;
}

/// Double codec supporting numeric provider values and numeric strings.
final class RemoteConfigDoubleCodec implements RemoteConfigCodec<double> {
  /// Creates a double codec.
  const RemoteConfigDoubleCodec();

  @override
  RemoteConfigValueKind get kind => RemoteConfigValueKind.doubleValue;

  @override
  double decode(Object? value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    throw FormatException(
        'Expected a double but received ${value.runtimeType}.');
  }

  @override
  Object encode(double value) => value;
}

/// JSON codec returning maps, lists, and JSON scalar values.
final class RemoteConfigJsonCodec implements RemoteConfigCodec<Object?> {
  /// Creates a JSON codec.
  const RemoteConfigJsonCodec();

  @override
  RemoteConfigValueKind get kind => RemoteConfigValueKind.json;

  @override
  Object? decode(Object? value) {
    final decoded = value is String ? jsonDecode(value) : value;
    if (_isJsonValue(decoded)) return decoded;
    throw FormatException('Remote config value is not valid JSON.');
  }

  @override
  Object encode(Object? value) {
    if (!_isJsonValue(value)) {
      throw FormatException('Remote config default is not valid JSON.');
    }
    return jsonEncode(value);
  }
}

bool _isJsonValue(Object? value) {
  if (value == null || value is String || value is bool || value is num) {
    return true;
  }
  if (value is List<Object?>) return value.every(_isJsonValue);
  if (value is Map<String, Object?>) return value.values.every(_isJsonValue);
  return false;
}
