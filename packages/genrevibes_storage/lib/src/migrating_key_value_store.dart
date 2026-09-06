import 'package:genrevibes_core/genrevibes_core.dart';

import 'key_value_store.dart';

/// Reads legacy keys written by a pre-package implementation, then writes the
/// value forward under the current key.
///
/// This exists so adopting a GenRevibes capability does not reset state that an
/// application already persisted under its own key names. Without it, a user who
/// finished onboarding or dismissed a rating prompt would be treated as brand
/// new on the release that adopts the package.
///
/// Lookup order for a read is current key, then legacy key. A value found under
/// the legacy key is copied to the current key before it is returned, so the
/// fallback is paid at most once per key per install.
///
/// Writes and removals always target the current key. Set [removeLegacyOnRead]
/// to also delete the legacy key once it has been migrated; leave it `false`
/// while a rollback to an older app version is still possible, because deleting
/// it makes that rollback lose the value.
final class MigratingKeyValueStore implements KeyValueStore {
  /// Wraps [delegate], mapping current key names to their legacy equivalents.
  MigratingKeyValueStore({
    required KeyValueStore delegate,
    required Map<String, String> legacyKeys,
    this.removeLegacyOnRead = false,
  })  : _delegate = delegate,
        _legacyKeys = Map<String, String>.unmodifiable(legacyKeys);

  final KeyValueStore _delegate;
  final Map<String, String> _legacyKeys;

  /// Whether a migrated legacy key is deleted after it is read.
  final bool removeLegacyOnRead;

  @override
  Future<KitResult<bool?>> getBool(String key) {
    return _readWithFallback(key, _delegate.getBool, _delegate.setBool);
  }

  @override
  Future<KitResult<int?>> getInt(String key) {
    return _readWithFallback(key, _delegate.getInt, _delegate.setInt);
  }

  @override
  Future<KitResult<String?>> getString(String key) {
    return _readWithFallback(key, _delegate.getString, _delegate.setString);
  }

  @override
  Future<KitResult<void>> setBool(String key, bool value) =>
      _delegate.setBool(key, value);

  @override
  Future<KitResult<void>> setInt(String key, int value) =>
      _delegate.setInt(key, value);

  @override
  Future<KitResult<void>> setString(String key, String value) =>
      _delegate.setString(key, value);

  @override
  Future<KitResult<void>> remove(String key) => _delegate.remove(key);

  Future<KitResult<T?>> _readWithFallback<T extends Object>(
    String key,
    Future<KitResult<T?>> Function(String key) read,
    Future<KitResult<void>> Function(String key, T value) write,
  ) async {
    final current = await read(key);
    if (current.isFailure) return current;
    final currentValue = current.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (currentValue != null) return current;

    final legacyKey = _legacyKeys[key];
    if (legacyKey == null) return current;

    final legacy = await read(legacyKey);
    // A broken legacy read must not fail the caller: the current key is simply
    // absent, which is a normal first-run state.
    final legacyValue = legacy.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    if (legacyValue == null) return current;

    await write(key, legacyValue);
    if (removeLegacyOnRead) await _delegate.remove(legacyKey);
    return KitSuccess<T?>(legacyValue);
  }
}
