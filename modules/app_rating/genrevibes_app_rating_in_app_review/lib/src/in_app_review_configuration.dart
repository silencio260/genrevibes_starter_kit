/// Store listing URLs used when the in-app review flow is unavailable.
///
/// The platform review flow is quota-limited and silently declines to appear
/// once a user has seen it recently, so an explicit listing URL is the only
/// reliable way to reach a user who deliberately chose to leave a review.
final class InAppReviewConfiguration {
  /// Creates a configuration.
  const InAppReviewConfiguration({this.androidStoreUrl, this.iosStoreUrl});

  /// Play Store listing URL.
  final String? androidStoreUrl;

  /// App Store listing URL.
  final String? iosStoreUrl;

  /// Whether any fallback URL was supplied.
  bool get hasFallback =>
      (androidStoreUrl?.isNotEmpty ?? false) ||
      (iosStoreUrl?.isNotEmpty ?? false);
}
