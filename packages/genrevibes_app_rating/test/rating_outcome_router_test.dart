import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:test/test.dart';

void main() {
  group('RatingOutcomeRouter', () {
    const router = RatingOutcomeRouter();

    test('sends satisfied users to the store', () {
      expect(
        router.route(RatingOutcome.submitted, rating: 5),
        RatingFollowUp.storeReview,
      );
      expect(
        router.route(RatingOutcome.submitted, rating: 4),
        RatingFollowUp.storeReview,
      );
    });

    test('sends dissatisfied users to private feedback', () {
      // The point of the gate: a complaint becomes actionable feedback rather
      // than a public one-star review.
      expect(
        router.route(RatingOutcome.submitted, rating: 3),
        RatingFollowUp.feedback,
      );
      expect(
        router.route(RatingOutcome.submitted, rating: 1),
        RatingFollowUp.feedback,
      );
    });

    test('an unknown score is treated as dissatisfied, not assumed positive',
        () {
      expect(router.route(RatingOutcome.submitted), RatingFollowUp.feedback);
    });

    test('deferring and declining trigger no follow-up', () {
      expect(router.route(RatingOutcome.maybeLater), RatingFollowUp.none);
      expect(router.route(RatingOutcome.never), RatingFollowUp.none);
    });

    test('the threshold is configurable', () {
      const strict = RatingOutcomeRouter(storeReviewThreshold: 5);

      expect(
        strict.route(RatingOutcome.submitted, rating: 4),
        RatingFollowUp.feedback,
      );
      expect(
        strict.route(RatingOutcome.submitted, rating: 5),
        RatingFollowUp.storeReview,
      );
    });
  });

  group('RatingDecision', () {
    test('an allowed decision has no block reason', () {
      const decision = RatingDecision.allowed();

      expect(decision.isAllowed, isTrue);
      expect(decision.blockReason, isNull);
    });

    test('a blocked decision reports why', () {
      const decision = RatingDecision.blocked(RatingBlockReason.optedOut);

      expect(decision.isAllowed, isFalse);
      expect(decision.toString(), contains('optedOut'));
    });
  });

  group('RatingKeys', () {
    test('current keys are namespaced and versioned', () {
      expect(RatingKeys.installedAt, startsWith('genrevibes.app_rating.'));
      expect(RatingKeys.installedAt, endsWith('.v1'));
    });

    test('trigger keys are derived per name', () {
      expect(RatingKeys.trigger('download'),
          'genrevibes.app_rating.trigger.download.v1');
      expect(
        RatingKeys.trigger('download'),
        isNot(RatingKeys.trigger('share')),
      );
    });

    test('every persisted key has a legacy mapping', () {
      // A key missing from this map silently resets that piece of state for
      // existing users on the release that adopts the package.
      expect(
        RatingKeys.legacyKeys.keys.toSet(),
        <String>{
          RatingKeys.installedAt,
          RatingKeys.appOpens,
          RatingKeys.optedOut,
          RatingKeys.lastPromptedAt,
        },
      );
    });
  });
}
