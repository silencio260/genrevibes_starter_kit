import 'dart:typed_data';

/// A file a user attached to their feedback, most often a screenshot.
///
/// Content is carried as bytes rather than a path so the contract does not
/// assume a filesystem, and so a caller can attach something it generated in
/// memory such as a rendered screenshot or a redacted log.
final class FeedbackAttachment {
  /// Creates an attachment.
  FeedbackAttachment({
    required this.filename,
    required Uint8List bytes,
    this.mimeType = 'application/octet-stream',
  }) : bytes = Uint8List.fromList(bytes);

  /// Name shown to whoever reads the feedback.
  final String filename;

  /// File content.
  final Uint8List bytes;

  /// Media type, used by providers that need it for upload.
  final String mimeType;

  /// Size in bytes.
  int get sizeInBytes => bytes.length;
}
