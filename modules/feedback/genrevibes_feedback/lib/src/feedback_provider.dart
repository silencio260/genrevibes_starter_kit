import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/feedback_submission.dart';

/// Contract implemented by feedback service adapters.
///
/// Adapters own transport and vendor SDKs. Deciding *when* to ask for feedback
/// belongs to the application, or to `genrevibes_app_rating` when the request
/// follows a low rating.
abstract interface class FeedbackProvider implements StarterModule {
  /// Stable provider identifier, such as `feedbacknest`.
  String get providerId;

  /// Sends [submission] to the feedback service.
  ///
  /// Implementations must reject an empty message with
  /// [KitErrorCode.invalidConfiguration] rather than sending a blank report.
  Future<KitResult<void>> submit(FeedbackSubmission submission);

  /// Sends a numeric rating with an optional written review.
  ///
  /// Separate from [submit] because rating services model scores as their own
  /// record type, and because a score without prose is still useful.
  Future<KitResult<void>> submitRatingAndReview({
    required int rating,
    String? review,
  });
}
