import 'package:genrevibes_core/genrevibes_core.dart';

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
}
