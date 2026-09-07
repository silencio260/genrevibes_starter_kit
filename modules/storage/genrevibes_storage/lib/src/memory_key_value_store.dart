import 'package:genrevibes_core/genrevibes_core.dart';

import 'key_value_store.dart';

/// In-memory [KeyValueStore] for tests and for apps that opt out of a plugin.
///
/// Values do not survive a process restart. A capability that requires
/// cross-launch persistence should document that this implementation is not a
/// production default.
final class MemoryKeyValueStore implements KeyValueStore {
  /// Creates a store, optionally seeded with [initialValues].
  MemoryKeyValueStore({Map<String, Object?> initialValues = const {}})
      : _values = Map<String, Object?>.of(initialValues);

  final Map<String, Object?> _values;

  /// Current contents, for assertions in tests.
  Map<String, Object?> get values => Map<String, Object?>.unmodifiable(_values);

  @override
  Future<KitResult<bool?>> getBool(String key) async => _read<bool>(key);

  @override
  Future<KitResult<int?>> getInt(String key) async => _read<int>(key);

  @override
  Future<KitResult<String?>> getString(String key) async => _read<String>(key);

  @override
  Future<KitResult<List<String>?>> getStringList(String key) async =>
      _read<List<String>>(key);

  @override
  Future<KitResult<void>> setBool(String key, bool value) async =>
      _write(key, value);

  @override
  Future<KitResult<void>> setInt(String key, int value) async =>
      _write(key, value);

  @override
  Future<KitResult<void>> setString(String key, String value) async =>
      _write(key, value);

  @override
  Future<KitResult<void>> setStringList(String key, List<String> value) async =>
      _write(key, List<String>.unmodifiable(value));

  @override
  Future<KitResult<void>> remove(String key) async {
    _values.remove(key);
    return const KitSuccess<void>(null);
  }

  KitResult<T?> _read<T extends Object>(String key) {
    final value = _values[key];
    if (value == null) return const KitSuccess(null);
    if (value is! T) {
      return KitFailure<T?>(
        KitError(
          code: KitErrorCode.provider,
          message: 'Stored value for $key is ${value.runtimeType}, not $T.',
          providerCode: 'memory_type_mismatch',
        ),
      );
    }
    return KitSuccess<T?>(value);
  }

  KitResult<void> _write(String key, Object value) {
    _values[key] = value;
    return const KitSuccess<void>(null);
  }
}
