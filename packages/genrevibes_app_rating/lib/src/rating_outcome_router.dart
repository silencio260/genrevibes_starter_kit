import 'model/rating_outcome.dart';

/// Decides what happens after a rating prompt closes.
///
/// This is policy, not provider behavior, so it lives in the neutral package.
/// Both the store adapter and the feedback adapter are downstream of the
/// decision made here, and neither should be able to redefine it.
///
/// The routing rule is the standard rating gate: a satisfied user is sent to
/// the public store listing, while a dissatisfied user is offered a private
/// feedback channel instead. That keeps low-star reviews out of the store and
/// routes the underlying complaint somewhere it can be acted on.
final class RatingOutcomeRouter {
  /// Creates a router.
  ///
  /// [storeReviewThreshold] is the lowest rating still sent to the store.
  const RatingOutcomeRouter({this.storeReviewThreshold = 4});

  /// Lowest rating that still earns a store review request.
  final int storeReviewThreshold;

  /// Returns the follow-up for [outcome].
  ///
  /// [rating] is required for [RatingOutcome.submitted] and ignored otherwise.
  /// A submitted outcome with no rating routes to feedback, because an unknown
  /// score must not be assumed to be positive.
  RatingFollowUp route(RatingOutcome outcome, {int? rating}) {
    return switch (outcome) {
      RatingOutcome.maybeLater => RatingFollowUp.none,
      RatingOutcome.never => RatingFollowUp.none,
      RatingOutcome.submitted =>
        rating != null && rating >= storeReviewThreshold
            ? RatingFollowUp.storeReview
            : RatingFollowUp.feedback,
    };
  }
}
