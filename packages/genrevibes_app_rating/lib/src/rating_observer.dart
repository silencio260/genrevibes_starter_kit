import 'model/rating_decision.dart';
import 'model/rating_outcome.dart';

/// Receives rating lifecycle events for analytics.
///
/// The coordinator reports through this interface rather than importing an
/// analytics package. Rating policy must not depend on a measurement provider,
/// and an application that does not measure rating behavior should not be
/// forced to install one.
abstract interface class RatingObserver {
  /// Called when eligibility was evaluated.
  void onEvaluated(RatingDecision decision);

  /// Called when a prompt was presented.
  void onPrompted();

  /// Called when the user answered a prompt.
  ///
  /// [rating] is present only for [RatingOutcome.submitted].
  void onOutcome(RatingOutcome outcome, {int? rating});
}

/// [RatingObserver] that records nothing.
final class NoopRatingObserver implements RatingObserver {
  /// Creates a no-op observer.
  const NoopRatingObserver();

  @override
  void onEvaluated(RatingDecision decision) {}

  @override
  void onPrompted() {}

  @override
  void onOutcome(RatingOutcome outcome, {int? rating}) {}
}
