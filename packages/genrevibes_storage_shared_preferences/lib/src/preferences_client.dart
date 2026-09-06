import 'package:shared_preferences/shared_preferences.dart';

/// Injectable boundary around the SharedPreferences plugin.
///
/// Tests substitute this so they never touch platform channels.
abstract interface class PreferencesClient {
  /// Reads a boolean, or `null` when [key] is absent.
  Future<bool?> readBool(String key);

  /// Reads an integer, or `null` when [key] is absent.
  Future<int?> readInt(String key);

  /// Reads a string, or `null` when [key] is absent.
  Future<String?> readString(String key);

  /// Reads a string list, or `null` when [key] is absent.
  Future<List<String>?> readStringList(String key);

  /// Stores a boolean under [key].
  Future<void> writeBool(String key, bool value);

  /// Stores an integer under [key].
  Future<void> writeInt(String key, int value);

  /// Stores a string under [key].
  Future<void> writeString(String key, String value);

  /// Stores a string list under [key].
  Future<void> writeStringList(String key, List<String> value);

  /// Removes [key].
  Future<void> remove(String key);
}

/// Production preferences client.
final class DefaultPreferencesClient implements PreferencesClient {
  Future<SharedPreferences>? _preferences;

  Future<SharedPreferences> get _ready {
    return _preferences ??= SharedPreferences.getInstance();
  }

  @override
  Future<bool?> readBool(String key) async => (await _ready).getBool(key);

  @override
  Future<int?> readInt(String key) async => (await _ready).getInt(key);

  @override
  Future<String?> readString(String key) async => (await _ready).getString(key);

  @override
  Future<List<String>?> readStringList(String key) async =>
      (await _ready).getStringList(key);

  @override
  Future<void> writeBool(String key, bool value) async {
    _confirm(await (await _ready).setBool(key, value), key);
  }

  @override
  Future<void> writeInt(String key, int value) async {
    _confirm(await (await _ready).setInt(key, value), key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    _confirm(await (await _ready).setString(key, value), key);
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    _confirm(await (await _ready).setStringList(key, value), key);
  }

  @override
  Future<void> remove(String key) async {
    _confirm(await (await _ready).remove(key), key);
  }

  void _confirm(bool saved, String key) {
    if (!saved) throw StateError('SharedPreferences rejected the write: $key.');
  }
}
