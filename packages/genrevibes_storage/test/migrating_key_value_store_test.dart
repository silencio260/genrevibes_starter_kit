import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';
import 'package:test/test.dart';

void main() {
  group('MigratingKeyValueStore', () {
    test('returns the current value without consulting the legacy key',
        () async {
      final delegate = MemoryKeyValueStore(
        initialValues: {'new.key': true, 'old_key': false},
      );
      final store = _migrating(delegate);

      expect(await _bool(store, 'new.key'), isTrue);
    });

    test('falls back to the legacy key when the current key is absent',
        () async {
      final delegate = MemoryKeyValueStore(initialValues: {'old_key': true});
      final store = _migrating(delegate);

      expect(await _bool(store, 'new.key'), isTrue);
    });

    test('writes the legacy value forward so the fallback is paid once',
        () async {
      final delegate = MemoryKeyValueStore(initialValues: {'old_key': true});
      final store = _migrating(delegate);

      await store.getBool('new.key');

      expect(delegate.values['new.key'], isTrue);
    });

    test('keeps the legacy key by default so a rollback still finds it',
        () async {
      final delegate = MemoryKeyValueStore(initialValues: {'old_key': true});
      final store = _migrating(delegate);

      await store.getBool('new.key');

      expect(delegate.values.containsKey('old_key'), isTrue);
    });

    test('removes the legacy key when removeLegacyOnRead is set', () async {
      final delegate = MemoryKeyValueStore(initialValues: {'old_key': true});
      final store = _migrating(delegate, removeLegacy: true);

      await store.getBool('new.key');

      expect(delegate.values.containsKey('old_key'), isFalse);
    });

    test('migrates int and string values, not just booleans', () async {
      final delegate = MemoryKeyValueStore(
        initialValues: {'old_count': 42, 'old_name': 'story saver'},
      );
      final store = MigratingKeyValueStore(
        delegate: delegate,
        legacyKeys: const {'new.count': 'old_count', 'new.name': 'old_name'},
      );

      expect(await _int(store, 'new.count'), 42);
      expect(await _string(store, 'new.name'), 'story saver');
    });

    test('migrates a string list, which retention history depends on',
        () async {
      // Session timestamps and daily open dates are lists. Without list
      // support these could never be adopted from a legacy install.
      final delegate = MemoryKeyValueStore(
        initialValues: {
          'session_timestamps': <String>['2026-01-01T09:00:00Z'],
        },
      );
      final store = MigratingKeyValueStore(
        delegate: delegate,
        legacyKeys: const {'new.sessions': 'session_timestamps'},
      );

      final migrated = (await store.getStringList('new.sessions'))
          .fold(onSuccess: (v) => v, onFailure: (_) => null);

      expect(migrated, <String>['2026-01-01T09:00:00Z']);
      expect(delegate.values['new.sessions'], isNotNull);
    });

    test('a key with no legacy mapping simply reads as absent', () async {
      final store = _migrating(MemoryKeyValueStore());

      final result = await store.getBool('unmapped');

      expect(result.isSuccess, isTrue);
      expect(await _bool(store, 'unmapped'), isNull);
    });

    test('a corrupt legacy value does not fail the caller', () async {
      // The legacy key holds the wrong type. First run should look like a
      // normal absent value, not a hard failure.
      final delegate = MemoryKeyValueStore(initialValues: {'old_key': 'oops'});
      final store = _migrating(delegate);

      final result = await store.getBool('new.key');

      expect(result.isSuccess, isTrue);
      expect(result.fold(onSuccess: (v) => v, onFailure: (_) => true), isNull);
    });

    test('a failing current read is surfaced rather than masked', () async {
      final delegate = MemoryKeyValueStore(initialValues: {'new.key': 'oops'});
      final store = _migrating(delegate);

      final result = await store.getBool('new.key');

      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.provider,
      );
    });

    test('writes and removals target the current key only', () async {
      final delegate = MemoryKeyValueStore(initialValues: {'old_key': true});
      final store = _migrating(delegate);

      await store.setBool('new.key', false);
      await store.remove('new.key');

      expect(delegate.values.containsKey('new.key'), isFalse);
      expect(delegate.values['old_key'], isTrue);
    });
  });
}

MigratingKeyValueStore _migrating(
  KeyValueStore delegate, {
  bool removeLegacy = false,
}) {
  return MigratingKeyValueStore(
    delegate: delegate,
    legacyKeys: const {'new.key': 'old_key'},
    removeLegacyOnRead: removeLegacy,
  );
}

Future<bool?> _bool(KeyValueStore store, String key) async =>
    (await store.getBool(key))
        .fold(onSuccess: (v) => v, onFailure: (_) => null);

Future<int?> _int(KeyValueStore store, String key) async =>
    (await store.getInt(key)).fold(onSuccess: (v) => v, onFailure: (_) => null);

Future<String?> _string(KeyValueStore store, String key) async =>
    (await store.getString(key))
        .fold(onSuccess: (v) => v, onFailure: (_) => null);
