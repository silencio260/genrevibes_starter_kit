import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryKeyValueStore', () {
    test('an absent key reads as null rather than failing', () async {
      final store = MemoryKeyValueStore();

      final result = await store.getBool('missing');

      expect(result.isSuccess, isTrue);
      expect(result.fold(onSuccess: (v) => v, onFailure: (_) => 'x'), isNull);
    });

    test('round-trips every supported value type', () async {
      final store = MemoryKeyValueStore();

      await store.setBool('flag', true);
      await store.setInt('count', 7);
      await store.setString('name', 'genrevibes');

      expect(await _bool(store, 'flag'), isTrue);
      expect(await _int(store, 'count'), 7);
      expect(await _string(store, 'name'), 'genrevibes');
    });

    test('removing a key clears it and removing again still succeeds',
        () async {
      final store = MemoryKeyValueStore(initialValues: {'flag': true});

      expect((await store.remove('flag')).isSuccess, isTrue);
      expect(await _bool(store, 'flag'), isNull);
      expect((await store.remove('flag')).isSuccess, isTrue);
    });

    test('reading a key stored as another type reports a provider error',
        () async {
      final store = MemoryKeyValueStore(initialValues: {'count': 'not an int'});

      final result = await store.getInt('count');

      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.provider,
      );
    });

    test('seeded values are copied so the caller cannot mutate the store',
        () async {
      final seed = <String, Object?>{'flag': true};
      final store = MemoryKeyValueStore(initialValues: seed);

      seed['flag'] = false;

      expect(await _bool(store, 'flag'), isTrue);
    });
  });
}

Future<bool?> _bool(KeyValueStore store, String key) async =>
    (await store.getBool(key))
        .fold(onSuccess: (v) => v, onFailure: (_) => null);

Future<int?> _int(KeyValueStore store, String key) async =>
    (await store.getInt(key)).fold(onSuccess: (v) => v, onFailure: (_) => null);

Future<String?> _string(KeyValueStore store, String key) async =>
    (await store.getString(key))
        .fold(onSuccess: (v) => v, onFailure: (_) => null);
