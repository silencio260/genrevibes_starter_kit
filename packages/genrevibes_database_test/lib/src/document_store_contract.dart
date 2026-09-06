import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_database/genrevibes_database.dart';
import 'package:test/test.dart';

/// Creates a fresh document store backed by a deterministic client.
typedef DocumentStoreFactory = Future<DocumentStore> Function();

/// Registers the behavior every document store adapter must satisfy.
void runDocumentStoreContractTests({
  required String providerName,
  required DocumentStoreFactory createStore,
}) {
  group('$providerName document store contract', () {
    late DocumentStore store;

    setUp(() async => store = await createStore());
    tearDown(() async => store.dispose());

    Future<DocumentSnapshot> read(String path) async {
      final result = await store.get(path);
      return result.fold(
        onSuccess: (value) => value,
        onFailure: (error) => throw StateError('get failed: $error'),
      );
    }

    test('reports a stable non-empty provider identifier', () {
      expect(store.providerId, isNotEmpty);
    });

    test('rejects work before initialization', () async {
      final result = await store.get('users/u1');

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.notInitialized,
      );
    });

    test('becomes ready after initialization', () async {
      expect((await store.initialize()).isSuccess, isTrue);

      expect(store.health.state, ModuleState.ready);
    });

    test('initialization is idempotent', () async {
      expect((await store.initialize()).isSuccess, isTrue);
      expect((await store.initialize()).isSuccess, isTrue);
    });

    test('a missing document reads as absent, not as an error', () async {
      await store.initialize();

      final snapshot = await read('users/nobody');

      expect(snapshot.exists, isFalse);
      expect(snapshot.data, isNull);
    });

    test('round-trips a document', () async {
      await store.initialize();

      await store.set('users/u1', <String, Object?>{'name': 'Ada', 'age': 36});
      final snapshot = await read('users/u1');

      expect(snapshot.exists, isTrue);
      expect(snapshot.field<String>('name'), 'Ada');
      expect(snapshot.id, 'u1');
    });

    test('set without merge replaces the document', () async {
      await store.initialize();
      await store.set('users/u1', <String, Object?>{'name': 'Ada', 'age': 36});

      await store.set('users/u1', <String, Object?>{'name': 'Grace'});

      final snapshot = await read('users/u1');
      expect(snapshot.field<String>('name'), 'Grace');
      expect(snapshot.data!.containsKey('age'), isFalse);
    });

    test('set with merge leaves absent fields alone', () async {
      await store.initialize();
      await store.set('users/u1', <String, Object?>{'name': 'Ada', 'age': 36});

      await store.set(
        'users/u1',
        <String, Object?>{'name': 'Grace'},
        merge: true,
      );

      final snapshot = await read('users/u1');
      expect(snapshot.field<String>('name'), 'Grace');
      expect(snapshot.field<int>('age'), 36);
    });

    test('update fails on a document that does not exist', () async {
      await store.initialize();

      final result =
          await store.update('users/ghost', <String, Object?>{'name': 'x'});

      expect(result.isFailure, isTrue);
    });

    test('deleting an absent document succeeds', () async {
      await store.initialize();

      expect((await store.delete('users/ghost')).isSuccess, isTrue);
    });

    test('rejects a collection path where a document is required', () async {
      await store.initialize();

      final result = await store.get('users');

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.invalidConfiguration,
      );
    });

    test('rejects a document path where a collection is required', () async {
      await store.initialize();

      final result = await store.query('users/u1');

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.invalidConfiguration,
      );
    });

    test('queries a collection with a filter and a limit', () async {
      await store.initialize();
      await store.set('notes/n1', <String, Object?>{'done': true, 'order': 1});
      await store.set('notes/n2', <String, Object?>{'done': false, 'order': 2});
      await store.set('notes/n3', <String, Object?>{'done': true, 'order': 3});

      final result = await store.query(
        'notes',
        DocumentQuery(
          filters: <QueryFilter>[
            const QueryFilter('done', QueryOperator.isEqualTo, true),
          ],
          limit: 5,
        ),
      );

      final docs = result.fold(onSuccess: (v) => v, onFailure: (_) => null);
      expect(docs, hasLength(2));
      expect(docs!.every((d) => d.field<bool>('done') == true), isTrue);
    });

    test('rejects a malformed query rather than passing it to the vendor',
        () async {
      await store.initialize();

      final result = await store.query(
        'notes',
        DocumentQuery(
          filters: <QueryFilter>[
            const QueryFilter('tag', QueryOperator.whereIn, 'not-a-list'),
          ],
        ),
      );

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.invalidConfiguration,
      );
    });

    test('watch emits the current value on subscription', () async {
      await store.initialize();
      await store.set('users/u1', <String, Object?>{'name': 'Ada'});

      final first = await store.watch('users/u1').first;

      expect(first.field<String>('name'), 'Ada');
    });

    test('disposal is idempotent and reports disposed health', () async {
      await store.initialize();

      expect((await store.dispose()).isSuccess, isTrue);
      expect((await store.dispose()).isSuccess, isTrue);
      expect(store.health.state, ModuleState.disposed);
    });
  });
}
