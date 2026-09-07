import 'package:genrevibes_database/genrevibes_database.dart';
import 'package:test/test.dart';

void main() {
  group('DocumentPath', () {
    test('even segments address a document, odd address a collection', () {
      expect(DocumentPath.isDocument('users/u1'), isTrue);
      expect(DocumentPath.isCollection('users'), isTrue);
      expect(DocumentPath.isCollection('users/u1/notes'), isTrue);
      expect(DocumentPath.isDocument('users/u1/notes/n1'), isTrue);
    });

    test('tolerates leading and trailing slashes', () {
      expect(DocumentPath.segments('/users/u1/'), <String>['users', 'u1']);
      expect(DocumentPath.isDocument('/users/u1/'), isTrue);
    });

    test('extracts the document id', () {
      expect(DocumentPath.documentId('users/u1/notes/n1'), 'n1');
      expect(DocumentPath.documentId('users/u1/notes'), isNull);
    });

    test('explains why a path is wrong rather than just rejecting it', () {
      expect(DocumentPath.validateDocument('users/u1'), isNull);
      expect(DocumentPath.validateDocument('users'), contains('even'));
      expect(DocumentPath.validateDocument(''), contains('empty'));
      expect(DocumentPath.validateCollection('users'), isNull);
      expect(DocumentPath.validateCollection('users/u1'), contains('odd'));
    });
  });

  group('DocumentSnapshot', () {
    test('distinguishes a missing document from an empty one', () {
      final missing = DocumentSnapshot.missing('users/u1');
      final empty = DocumentSnapshot(path: 'users/u2', data: const {});

      expect(missing.exists, isFalse);
      expect(empty.exists, isTrue);
      expect(empty.data, isEmpty);
    });

    test('copies its data so a read cannot be mutated after the fact', () {
      final data = <String, Object?>{'title': 'note'};
      final snapshot = DocumentSnapshot(path: 'notes/n1', data: data);

      data['title'] = 'changed';

      expect(snapshot.data!['title'], 'note');
      expect(() => snapshot.data!['x'] = 1, throwsUnsupportedError);
    });

    test('reads typed fields and returns null on a type mismatch', () {
      final snapshot = DocumentSnapshot(
        path: 'notes/n1',
        data: const {'title': 'note', 'count': 3},
      );

      expect(snapshot.field<String>('title'), 'note');
      expect(snapshot.field<int>('count'), 3);
      expect(snapshot.field<int>('title'), isNull);
      expect(snapshot.field<String>('absent'), isNull);
    });

    test('exposes its id and cache origin', () {
      final snapshot = DocumentSnapshot(
        path: 'users/u1/notes/n1',
        data: const {},
        isFromCache: true,
      );

      expect(snapshot.id, 'n1');
      expect(snapshot.isFromCache, isTrue);
    });
  });

  group('DocumentQuery', () {
    test('an empty query is unbounded', () {
      expect(DocumentQuery().isUnbounded, isTrue);
      expect(DocumentQuery(limit: 10).isUnbounded, isFalse);
    });

    test('copies its filters and orders', () {
      final filters = <QueryFilter>[
        const QueryFilter('done', QueryOperator.isEqualTo, false),
      ];
      final query = DocumentQuery(filters: filters);

      expect(() => query.filters.clear(), throwsUnsupportedError);
    });

    test('catches a set operator given a scalar', () {
      final query = DocumentQuery(
        filters: <QueryFilter>[
          const QueryFilter('tag', QueryOperator.whereIn, 'single'),
        ],
      );

      expect(query.validate().single, contains('expects a list'));
    });

    test('accepts a set operator given a list', () {
      final query = DocumentQuery(
        filters: <QueryFilter>[
          const QueryFilter('tag', QueryOperator.whereIn, <String>['a', 'b']),
        ],
      );

      expect(query.validate(), isEmpty);
    });

    test('rejects a non-positive limit', () {
      expect(DocumentQuery(limit: 0).validate().single, contains('positive'));
    });

    test('scalar operators accept scalar values', () {
      expect(
        const QueryFilter('n', QueryOperator.isGreaterThan, 3).expectsList,
        isFalse,
      );
      expect(
        const QueryFilter('t', QueryOperator.arrayContainsAny, <int>[1])
            .expectsList,
        isTrue,
      );
    });
  });
}
