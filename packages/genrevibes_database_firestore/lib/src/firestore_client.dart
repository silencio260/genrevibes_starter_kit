import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:genrevibes_database/genrevibes_database.dart';

import 'firestore_mapping.dart';

/// Injectable boundary around the Cloud Firestore SDK.
///
/// Returns neutral snapshots rather than Firestore types, so the store and its
/// tests never handle a vendor object.
abstract interface class FirestoreClient {
  /// Reads one document.
  Future<DocumentSnapshot> get(String path);

  /// Writes one document.
  Future<void> set(String path, Map<String, Object?> data,
      {bool merge = false});

  /// Updates fields of an existing document.
  Future<void> update(String path, Map<String, Object?> data);

  /// Deletes one document.
  Future<void> delete(String path);

  /// Reads a collection.
  Future<List<DocumentSnapshot>> query(String path, DocumentQuery query);

  /// Watches one document.
  Stream<DocumentSnapshot> watch(String path);

  /// Watches a collection.
  Stream<List<DocumentSnapshot>> watchQuery(String path, DocumentQuery query);
}

/// Production Firestore client.
final class DefaultFirestoreClient implements FirestoreClient {
  /// Creates a client over [instance], defaulting to the shared instance.
  DefaultFirestoreClient({fs.FirebaseFirestore? instance})
      : _firestore = instance ?? fs.FirebaseFirestore.instance;

  final fs.FirebaseFirestore _firestore;

  @override
  Future<DocumentSnapshot> get(String path) async =>
      mapDocument(path, await _firestore.doc(path).get());

  @override
  Future<void> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  }) {
    return _firestore.doc(path).set(data, fs.SetOptions(merge: merge));
  }

  @override
  Future<void> update(String path, Map<String, Object?> data) =>
      _firestore.doc(path).update(data);

  @override
  Future<void> delete(String path) => _firestore.doc(path).delete();

  @override
  Future<List<DocumentSnapshot>> query(String path, DocumentQuery query) async {
    final snapshot = await applyQuery(_firestore.collection(path), query).get();
    return snapshot.docs
        .map((doc) => mapDocument(doc.reference.path, doc))
        .toList();
  }

  @override
  Stream<DocumentSnapshot> watch(String path) =>
      _firestore.doc(path).snapshots().map((doc) => mapDocument(path, doc));

  @override
  Stream<List<DocumentSnapshot>> watchQuery(String path, DocumentQuery query) {
    return applyQuery(_firestore.collection(path), query).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => mapDocument(doc.reference.path, doc))
              .toList(),
        );
  }
}
