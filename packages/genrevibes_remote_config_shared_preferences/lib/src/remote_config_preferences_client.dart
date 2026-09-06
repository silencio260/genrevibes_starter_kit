import 'package:shared_preferences/shared_preferences.dart';

/// Injectable string-storage boundary around SharedPreferences.
abstract interface class RemoteConfigPreferencesClient {
  /// Reads a stored JSON string.
  Future<String?> readString(String key);

  /// Atomically replaces a stored JSON string as supported by the platform.
  Future<void> writeString(String key, String value);
}

/// Production preferences client.
final class DefaultRemoteConfigPreferencesClient
    implements RemoteConfigPreferencesClient {
  Future<SharedPreferences>? _preferences;

  Future<SharedPreferences> get _ready {
    return _preferences ??= SharedPreferences.getInstance();
  }

  @override
  Future<String?> readString(String key) async {
    return (await _ready).getString(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    final saved = await (await _ready).setString(key, value);
    if (!saved) throw StateError('SharedPreferences rejected the cache write.');
  }
}
