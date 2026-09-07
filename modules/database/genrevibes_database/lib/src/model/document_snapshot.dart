/// An immutable read of one document.
final class DocumentSnapshot {
  /// Creates a snapshot.
  DocumentSnapshot({
    required this.path,
    Map<String, Object?>? data,
    this.isFromCache = false,
  }) : data = data == null ? null : Map<String, Object?>.unmodifiable(data);

  /// Creates a snapshot for a document that does not exist.
  DocumentSnapshot.missing(this.path)
      : data = null,
        isFromCache = false;

  /// Full path to the document.
  final String path;

  /// Field values, or `null` when the document does not exist.
  ///
  /// An absent document is not an error. Distinguishing "no document" from
  /// "empty document" matters, so [exists] reads this rather than the map
  /// being empty.
  final Map<String, Object?>? data;

  /// Whether this read came from a local cache rather than the server.
  ///
  /// Offline-capable stores answer from cache. A write-then-read that returns
  /// cached data has not necessarily reached the server yet.
  final bool isFromCache;

  /// Whether the document exists.
  bool get exists => data != null;

  /// The document's id.
  String get id => path.split('/').where((s) => s.isNotEmpty).last;

  /// Reads [field] as [T], or `null` when absent or of another type.
  T? field<T extends Object>(String field) {
    final value = data?[field];
    return value is T ? value : null;
  }

  @override
  String toString() => 'DocumentSnapshot($path, exists: $exists)';
}
