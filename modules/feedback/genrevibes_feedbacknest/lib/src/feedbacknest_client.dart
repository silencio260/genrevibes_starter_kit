import 'dart:io';

import 'package:feedbacknest_core/feedbacknest.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';

/// Injectable boundary around the FeedbackNest SDK.
///
/// Tests substitute this so they never touch the network or the filesystem.
abstract interface class FeedbackNestClient {
  /// Initializes the SDK.
  Future<void> initialize(String apiKey, {String userIdentifier});

  /// Submits a message with an optional reply address and attachments.
  Future<void> submitCommunication({
    required String message,
    required String type,
    String? email,
    List<FeedbackAttachment> attachments,
  });

  /// Submits a numeric rating with an optional written review.
  Future<void> submitRatingAndReview({required int rating, String? review});
}

/// Production FeedbackNest client.
final class DefaultFeedbackNestClient implements FeedbackNestClient {
  /// Creates a client over the FeedbackNest static API.
  const DefaultFeedbackNestClient();

  @override
  Future<void> initialize(String apiKey, {String userIdentifier = ''}) {
    return Feedbacknest.init(apiKey, userIdentifier: userIdentifier);
  }

  @override
  Future<void> submitCommunication({
    required String message,
    required String type,
    String? email,
    List<FeedbackAttachment> attachments = const <FeedbackAttachment>[],
  }) async {
    // The SDK takes dart:io files while the neutral contract carries bytes, so
    // attachments are staged in the system temp directory and removed again
    // once the request completes, successfully or not.
    final staged = <File>[];
    Directory? directory;
    try {
      if (attachments.isNotEmpty) {
        directory =
            await Directory.systemTemp.createTemp('genrevibes_feedback_');
      }
      for (final attachment in attachments) {
        if (attachment.sizeInBytes > 10 * 1024 * 1024) {
          throw ArgumentError('Feedback attachment exceeds 10 MB.');
        }
        final safeName =
            attachment.filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final file = File(
            '${directory!.path}/${staged.length}_${safeName.isEmpty ? 'attachment' : safeName}');
        staged.add(file);
        await file.writeAsBytes(attachment.bytes);
      }
      await Feedbacknest.submitCommunication(
        message: message,
        type: type,
        email: email,
        files: staged.isEmpty ? null : staged,
      );
    } finally {
      for (final file in staged) {
        try {
          if (file.existsSync()) await file.delete();
        } on Object {
          // A leftover temp file is not worth failing a submission over.
        }
      }
      if (directory != null) {
        try {
          await directory.delete(recursive: true);
        } on Object {
          // Cleanup failure must not change the submission result.
        }
      }
    }
  }

  @override
  Future<void> submitRatingAndReview({required int rating, String? review}) {
    return Feedbacknest.submitRatingAndReview(rating: rating, review: review);
  }
}
