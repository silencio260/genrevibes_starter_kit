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
    try {
      for (final attachment in attachments) {
        final file = File(
          '${Directory.systemTemp.path}/'
          '${DateTime.now().microsecondsSinceEpoch}_${attachment.filename}',
        );
        await file.writeAsBytes(attachment.bytes);
        staged.add(file);
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
    }
  }

  @override
  Future<void> submitRatingAndReview({required int rating, String? review}) {
    return Feedbacknest.submitRatingAndReview(rating: rating, review: review);
  }
}
