import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/review_flow_report.dart';

/// Contract implemented by store review adapters.
///
/// Presenting a review request is provider work; deciding whether to present one
/// is policy and belongs to [RatingCoordinator]. Keeping them apart means the
/// eligibility rules are tested without a platform channel and survive a change
/// of review provider.
abstract interface class StoreReviewProvider implements StarterModule {
  /// Stable provider identifier, such as `in_app_review`.
  String get providerId;

  /// Whether an in-app review request can currently be presented.
  Future<KitResult<bool>> isAvailable();

  /// Requests the platform's in-app review flow.
  ///
  /// Platforms may silently decline to show anything, for example when a quota
  /// is exhausted. A success means the request was accepted, never that a form
  /// was displayed.
  Future<KitResult<void>> requestReview();

  /// Opens the public store listing as a fallback.
  Future<KitResult<void>> openStoreListing();

  /// The path for a user who agreed to rate: requests the in-app review
  /// sheet, waits for it to close, then always opens the store listing.
  ///
  /// Platforms quota-limit the sheet and decline silently, and never report
  /// whether it appeared, so the listing is opened every time to guarantee the
  /// user a place to rate. Succeeds when either step worked; fails only when
  /// neither did.
  Future<KitResult<ReviewFlowReport>> requestReviewThenOpenListing();
}
