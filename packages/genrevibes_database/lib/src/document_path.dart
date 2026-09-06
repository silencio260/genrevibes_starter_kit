/// Validates document and collection paths.
///
/// Document stores address data as alternating collection and document
/// segments: `users/u1` is a document, `users/u1/notes` is a collection. Using
/// one where the other belongs is the most common mistake against these APIs
/// and produces a confusing vendor error at runtime, so paths are checked at
/// the boundary instead.
abstract final class DocumentPath {
  /// Whether [path] addresses a document (an even number of segments).
  static bool isDocument(String path) => _segments(path).length.isEven;

  /// Whether [path] addresses a collection (an odd number of segments).
  static bool isCollection(String path) => _segments(path).length.isOdd;

  /// The path's segments, with empty segments removed.
  static List<String> segments(String path) => _segments(path);

  /// The document id, or `null` when [path] is not a document.
  static String? documentId(String path) {
    final parts = _segments(path);
    return parts.length.isEven && parts.isNotEmpty ? parts.last : null;
  }

  /// Why [path] is not a valid document path, or `null` when it is.
  static String? validateDocument(String path) {
    final parts = _segments(path);
    if (parts.isEmpty) return 'Document path must not be empty.';
    if (parts.length.isOdd) {
      return 'Document path must have an even number of segments, '
          'got ${parts.length} in "$path".';
    }
    return null;
  }

  /// Why [path] is not a valid collection path, or `null` when it is.
  static String? validateCollection(String path) {
    final parts = _segments(path);
    if (parts.isEmpty) return 'Collection path must not be empty.';
    if (parts.length.isEven) {
      return 'Collection path must have an odd number of segments, '
          'got ${parts.length} in "$path".';
    }
    return null;
  }

  static List<String> _segments(String path) =>
      path.split('/').where((segment) => segment.isNotEmpty).toList();
}
