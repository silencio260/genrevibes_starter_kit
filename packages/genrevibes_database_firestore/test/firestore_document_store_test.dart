import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_database/genrevibes_database.dart';
import 'package:genrevibes_database_firestore/genrevibes_database_firestore.dart';
import 'package:genrevibes_database_test/genrevibes_database_test.dart';

void main() {
  runDocumentStoreContractTests(
    providerName: 'Firestore',
    createStore: () async => FirestoreDocumentStore(client: _FakeClient()),
  );

  group('FirestoreDocumentStore error mapping', () {
    test('classifies transport, permission and cancellation separately',
        () async {
      Future<KitErrorCode?> codeFor(String firebaseCode) async {
        final store = FirestoreDocumentStore(
          client: _FakeClient()..failWith = firebaseCode,
        );
        await store.initialize();
        final result = await store.get('users/u1');
        return result.fold(
          onSuccess: (_) => null,
          onFailure: (error) => error.code,
        );
      }

      expect(await codeFor('unavailable'), KitErrorCode.network);
      expect(await codeFor('deadline-exceeded'), KitErrorCode.network);
      expect(await codeFor('permission-denied'), KitErrorCode.permissionDenied);
      expect(await codeFor('unauthenticated'), KitErrorCode.permissionDenied);
      expect(await codeFor('cancelled'), KitErrorCode.cancelled);
      expect(await codeFor('aborted'), KitErrorCode.provider);
    });

    test('a failure degrades health rather than staying ready', () async {
      final store = FirestoreDocumentStore(
        client: _FakeClient()..failWith = 'unavailable',
      );
      await store.initialize();

      await store.get('users/u1');

      expect(store.health.state, ModuleState.degraded);
    });
  });

  group('FirestoreDocumentStore path validation', () {
    test('a bad path never reaches the vendor', () async {
      final client = _FakeClient();
      final store = FirestoreDocumentStore(client: client);
      await store.initialize();

      await store.set('users', <String, Object?>{'x': 1});

      expect(client.writes, isEmpty);
    });

    test('watch surfaces a bad path as a stream error', () async {
      final store = FirestoreDocumentStore(client: _FakeClient());
      await store.initialize();

      expect(store.watch('users'), emitsError(isA<KitError>()));
    });

    test('watchQuery surfaces a malformed query as a stream error', () async {
      final store = FirestoreDocumentStore(client: _FakeClient());
      await store.initialize();

      expect(
        store.watchQuery(
          'notes',
          DocumentQuery(
            filters: <QueryFilter>[
              const QueryFilter('t', QueryOperator.whereIn, 'scalar'),
            ],
          ),
        ),
        emitsError(isA<KitError>()),
      );
    });
  });
}

final class _FakeClient implements FirestoreClient {
  final Map<String, Map<String, Object?>> docs = {};
  final List<String> writes = <String>[];
  String? failWith;
  final Map<String, StreamController<DocumentSnapshot>> _watchers = {};

  void _maybeThrow() {
    final code = failWith;
    if (code != null) {
      throw fs.FirebaseException(plugin: 'cloud_firestore', code: code);
    }
  }

  DocumentSnapshot _snapshot(String path) {
    final data = docs[path];
    return data == null
        ? DocumentSnapshot.missing(path)
        : DocumentSnapshot(path: path, data: data);
  }

  void _notify(String path) {
    _watchers[path]?.add(_snapshot(path));
  }

  @override
  Future<DocumentSnapshot> get(String path) async {
    _maybeThrow();
    return _snapshot(path);
  }

  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) async {
    _maybeThrow();
    writes.add(path);
    docs[path] = merge
        ? <String, Object?>{...?docs[path], ...data}
        : Map<String, Object?>.of(data);
    _notify(path);
  }

  @override
  Future<void> update(String path, Map<String, Object?> data) async {
    _maybeThrow();
    if (!docs.containsKey(path)) {
      throw fs.FirebaseException(plugin: 'cloud_firestore', code: 'not-found');
    }
    writes.add(path);
    docs[path] = <String, Object?>{...?docs[path], ...data};
    _notify(path);
  }

  @override
  Future<void> delete(String path) async {
    _maybeThrow();
    docs.remove(path);
    _notify(path);
  }

  @override
  Future<List<DocumentSnapshot>> query(String path, DocumentQuery query) async {
    _maybeThrow();
    var matches = docs.entries
        .where((entry) => entry.key.startsWith('$path/'))
        .where((entry) => query.filters.every((f) => _matches(entry.value, f)))
        .map((entry) => DocumentSnapshot(path: entry.key, data: entry.value))
        .toList();
    final limit = query.limit;
    if (limit != null && matches.length > limit) {
      matches = matches.sublist(0, limit);
    }
    return matches;
  }

  bool _matches(Map<String, Object?> data, QueryFilter filter) {
    final value = data[filter.field];
    return switch (filter.operator) {
      QueryOperator.isEqualTo => value == filter.value,
      QueryOperator.isNotEqualTo => value != filter.value,
      _ => true,
    };
  }

  @override
  Stream<DocumentSnapshot> watch(String path) {
    final controller = _watchers.putIfAbsent(
      path,
      StreamController<DocumentSnapshot>.broadcast,
    );
    return Stream<DocumentSnapshot>.multi((listener) {
      listener.add(_snapshot(path));
      final sub = controller.stream.listen(listener.add);
      listener.onCancel = sub.cancel;
    });
  }

  @override
  Stream<List<DocumentSnapshot>> watchQuery(
    String path,
    DocumentQuery query,
  ) async* {
    yield await this.query(path, query);
  }
}
