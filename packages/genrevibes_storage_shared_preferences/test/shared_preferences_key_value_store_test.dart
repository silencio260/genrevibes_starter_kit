import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:genrevibes_storage_shared_preferences/genrevibes_storage_shared_preferences.dart';

void main() {
  group('SharedPreferencesKeyValueStore', () {
    test('round-trips every supported value type', () async {
      final store = SharedPreferencesKeyValueStore(client: _FakeClient());

      await store.setBool('flag', true);
      await store.setInt('count', 7);
      await store.setString('name', 'genrevibes');

      expect(await _value(store.getBool('flag')), isTrue);
      expect(await _value(store.getInt('count')), 7);
      expect(await _value(store.getString('name')), 'genrevibes');
    });

    test('round-trips a string list', () async {
      final store = SharedPreferencesKeyValueStore(client: _FakeClient());

      await store.setStringList('days', <String>['a', 'b']);

      expect(await _value(store.getStringList('days')), <String>['a', 'b']);
    });

    test('an absent key reads as null rather than failing', () async {
      final store = SharedPreferencesKeyValueStore(client: _FakeClient());

      final result = await store.getBool('missing');

      expect(result.isSuccess, isTrue);
      expect(await _value(Future.value(result)), isNull);
    });

    test('a plugin fault becomes a provider error instead of throwing',
        () async {
      final client = _FakeClient()..failWith = StateError('channel down');
      final store = SharedPreferencesKeyValueStore(client: client);

      final result = await store.getBool('flag');

      expect(result.isFailure, isTrue);
      result.fold(
        onSuccess: (_) => fail('expected a failure'),
        onFailure: (error) {
          expect(error.code, KitErrorCode.provider);
          expect(error.providerCode, 'shared_preferences_read_bool');
          expect(error.cause, isA<StateError>());
        },
      );
    });

    test('a rejected write is reported rather than silently dropped', () async {
      final client = _FakeClient()..failWith = StateError('disk full');
      final store = SharedPreferencesKeyValueStore(client: client);

      final result = await store.setString('name', 'x');

      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.providerCode),
        'shared_preferences_write_string',
      );
    });

    test('removing a key clears it', () async {
      final store = SharedPreferencesKeyValueStore(client: _FakeClient());
      await store.setBool('flag', true);

      await store.remove('flag');

      expect(await _value(store.getBool('flag')), isNull);
    });

    test('satisfies the migrating decorator it is normally wrapped in',
        () async {
      final client = _FakeClient()..values['has_seen_onboarding'] = true;
      final store = MigratingKeyValueStore(
        delegate: SharedPreferencesKeyValueStore(client: client),
        legacyKeys: const {
          'genrevibes.onboarding.completed.v1': 'has_seen_onboarding',
        },
      );

      final migrated =
          await store.getBool('genrevibes.onboarding.completed.v1');

      expect(await _value(Future.value(migrated)), isTrue);
      expect(client.values['genrevibes.onboarding.completed.v1'], isTrue);
    });
  });
}

Future<Object?> _value(Future<KitResult<Object?>> result) async =>
    (await result).fold(onSuccess: (v) => v, onFailure: (_) => null);

final class _FakeClient implements PreferencesClient {
  final Map<String, Object?> values = <String, Object?>{};
  Object? failWith;

  void _maybeThrow() {
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<bool?> readBool(String key) async {
    _maybeThrow();
    return values[key] as bool?;
  }

  @override
  Future<int?> readInt(String key) async {
    _maybeThrow();
    return values[key] as int?;
  }

  @override
  Future<String?> readString(String key) async {
    _maybeThrow();
    return values[key] as String?;
  }

  @override
  Future<List<String>?> readStringList(String key) async {
    _maybeThrow();
    return values[key] as List<String>?;
  }

  @override
  Future<void> writeStringList(String key, List<String> value) async {
    _maybeThrow();
    values[key] = value;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    _maybeThrow();
    values[key] = value;
  }

  @override
  Future<void> writeInt(String key, int value) async {
    _maybeThrow();
    values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    _maybeThrow();
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _maybeThrow();
    values.remove(key);
  }
}
