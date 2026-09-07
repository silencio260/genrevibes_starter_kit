import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'preferences_client.dart';

/// Cross-launch [KeyValueStore] backed by SharedPreferences.
///
/// Keys are written verbatim. Capability packages already namespace their own
/// keys as `genrevibes.<capability>.<purpose>.v1`, and legacy key adoption is
/// handled by [MigratingKeyValueStore] rather than here, so this adapter stays a
/// thin, faithful mapping onto the plugin.
final class SharedPreferencesKeyValueStore implements KeyValueStore {
  /// Creates a store, optionally with an injected [client].
  SharedPreferencesKeyValueStore({PreferencesClient? client})
      : _client = client ?? DefaultPreferencesClient();

  final PreferencesClient _client;

  @override
  Future<KitResult<bool?>> getBool(String key) {
    return _guard(() => _client.readBool(key), 'read_bool');
  }

  @override
  Future<KitResult<int?>> getInt(String key) {
    return _guard(() => _client.readInt(key), 'read_int');
  }

  @override
  Future<KitResult<String?>> getString(String key) {
    return _guard(() => _client.readString(key), 'read_string');
  }

  @override
  Future<KitResult<List<String>?>> getStringList(String key) {
    return _guard(() => _client.readStringList(key), 'read_string_list');
  }

  @override
  Future<KitResult<void>> setStringList(String key, List<String> value) {
    return _guard(
      () => _client.writeStringList(key, List<String>.of(value)),
      'write_string_list',
    );
  }

  @override
  Future<KitResult<void>> setBool(String key, bool value) {
    return _guard(() => _client.writeBool(key, value), 'write_bool');
  }

  @override
  Future<KitResult<void>> setInt(String key, int value) {
    return _guard(() => _client.writeInt(key, value), 'write_int');
  }

  @override
  Future<KitResult<void>> setString(String key, String value) {
    return _guard(() => _client.writeString(key, value), 'write_string');
  }

  @override
  Future<KitResult<void>> remove(String key) {
    return _guard(() => _client.remove(key), 'remove');
  }

  Future<KitResult<T>> _guard<T>(
    Future<T> Function() action,
    String providerCode,
  ) async {
    try {
      return KitSuccess<T>(await action());
    } on Object catch (error, stackTrace) {
      return KitFailure<T>(
        KitError(
          code: KitErrorCode.provider,
          message: 'SharedPreferences $providerCode failed: $error',
          providerCode: 'shared_preferences_$providerCode',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
