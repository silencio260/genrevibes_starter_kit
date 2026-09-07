import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';
import 'package:genrevibes_remote_config_shared_preferences/genrevibes_remote_config_shared_preferences.dart';

void main() {
  test('round-trips a last-known-good cache entry', () async {
    final client = _MemoryPreferencesClient();
    final cache = SharedPreferencesRemoteConfigCache(client: client);
    final entry = RemoteConfigCacheEntry(
      values: <String, Object?>{
        'enabled': true,
        'interval': 8,
        'payload': <String, Object?>{'variant': 'a'},
      },
      storedAt: DateTime.utc(2026, 9, 6),
    );

    expect((await cache.write(entry)).isSuccess, isTrue);
    final result = await cache.read();
    final restored = result.fold(
      onSuccess: (value) => value,
      onFailure: (error) => throw error,
    );

    expect(restored?.values, entry.values);
    expect(restored?.storedAt, entry.storedAt);
  });

  test('returns a normalized failure for corrupt cache data', () async {
    final client = _MemoryPreferencesClient()..value = 'not-json';
    final cache = SharedPreferencesRemoteConfigCache(client: client);

    expect((await cache.read()).isFailure, isTrue);
  });
}

final class _MemoryPreferencesClient implements RemoteConfigPreferencesClient {
  String? value;

  @override
  Future<String?> readString(String key) async => value;

  @override
  Future<void> writeString(String key, String value) async {
    this.value = value;
  }
}
