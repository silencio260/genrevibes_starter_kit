import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/document_query.dart';
import 'model/document_snapshot.dart';

/// Contract implemented by document database adapters.
///
/// Paths are alternating collection and document segments, so `users/u1` is a
/// document and `users/u1/notes` is a collection. Implementations validate
/// this at the boundary rather than passing a malformed path to the vendor.
abstract interface class DocumentStore implements StarterModule {
  /// Stable provider identifier, such as `firestore`.
  String get providerId;

  /// Reads one document.
  ///
  /// A missing document is a success carrying a snapshot whose `exists` is
  /// false, not a failure.
  Future<KitResult<DocumentSnapshot>> get(String path);

  /// Writes one document.
  ///
  /// With [merge], absent fields are left alone; without it the document is
  /// replaced.
  Future<KitResult<void>> set(
    String path,
    Map<String, Object?> data, {
    bool merge = false,
  });

  /// Updates fields of an existing document.
  ///
  /// Fails when the document does not exist; use [set] with `merge` to
  /// upsert.
  Future<KitResult<void>> update(String path, Map<String, Object?> data);

  /// Deletes one document. Deleting an absent document succeeds.
  Future<KitResult<void>> delete(String path);

  /// Reads a collection.
  Future<KitResult<List<DocumentSnapshot>>> query(
    String collectionPath, [
    DocumentQuery? query,
  ]);

  /// Watches one document.
  ///
  /// Emits the current value on subscription, then on every change.
  Stream<DocumentSnapshot> watch(String path);

  /// Watches a collection.
  Stream<List<DocumentSnapshot>> watchQuery(
    String collectionPath, [
    DocumentQuery? query,
  ]);
}
