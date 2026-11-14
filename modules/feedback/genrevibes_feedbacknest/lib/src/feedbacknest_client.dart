import 'dart:async';
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
    // feedbacknest_core 0.0.8 fires its "/user/submit/log" telemetry POST
    // without awaiting or catching it (lib/src/feedbacknest.dart:44), and
    // ApiClient.post rethrows every failure. An offline device or a non-2xx
    // response therefore completes a future nobody listens to, and that error
    // surfaces in the host application's root zone -- where a Crashlytics
    // handler records an ordinary network hiccup as a fatal crash on startup.
    //
    // An unhandled async error is delivered to the zone its future was created
    // in, so running init inside a child zone keeps the stray POST contained.
    // Initialization's own failures still reach the caller: they travel through
    // the await below rather than through the zone.
    final completer = Completer<void>();
    runZonedGuarded(
      () async {
        try {
          await Feedbacknest.init(apiKey, userIdentifier: userIdentifier);
          if (!completer.isCompleted) completer.complete();
        } on Object catch (error, stackTrace) {
          if (!completer.isCompleted) completer.completeError(error, stackTrace);
        }
      },
      (error, stackTrace) {
        // Reached only by the stray telemetry POST, which lands after init has
        // already settled the completer. Dropping it is the point of the zone.
        if (!completer.isCompleted) completer.completeError(error, stackTrace);
      },
    );
    return completer.future;
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
