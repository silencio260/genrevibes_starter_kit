import 'dart:async';

import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_feedback/genrevibes_feedback.dart';

/// Records rating outcomes to FeedbackNest.
///
/// This is the second half of "one rating contract, several providers". The
/// store adapter presents a review request; this observer captures the score the
/// user actually gave, including the low scores that never reach a store and are
/// therefore invisible in store analytics.
///
/// Recording is fire-and-forget. A rating prompt must not stall or fail because
/// a reporting backend is unreachable, so failures are logged and dropped.
final class FeedbackNestRatingObserver implements RatingObserver {
  /// Creates an observer that reports through [provider].
  const FeedbackNestRatingObserver({
    required FeedbackProvider provider,
    KitLogger logger = const NoopKitLogger(),
  })  : _provider = provider,
        _logger = logger;

  final FeedbackProvider _provider;
  final KitLogger _logger;

  @override
  void onEvaluated(RatingDecision decision) {}

  @override
  void onPrompted() {}

  @override
  void onOutcome(RatingOutcome outcome, {int? rating}) {
    if (outcome != RatingOutcome.submitted || rating == null) return;
    unawaited(_report(rating));
  }

  Future<void> _report(int rating) async {
    final result = await _provider.submitRatingAndReview(rating: rating);
    result.fold(
      onSuccess: (_) {},
      onFailure: (error) => _logger.log(
        KitLogLevel.warning,
        'Rating capture failed.',
        moduleId: 'app_rating',
        error: error,
      ),
    );
  }
}
