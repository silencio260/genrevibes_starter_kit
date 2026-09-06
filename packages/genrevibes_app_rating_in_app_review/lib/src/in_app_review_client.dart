import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

/// Injectable boundary around the review and launcher plugins.
///
/// Tests substitute this so they never touch platform channels.
abstract interface class ReviewClient {
  /// Whether the platform in-app review flow can be presented.
  Future<bool> isAvailable();

  /// Requests the platform in-app review flow.
  Future<void> requestReview();

  /// Opens the platform store listing through the review plugin.
  Future<void> openStoreListing();

  /// Opens [url] in an external application.
  Future<bool> launchStoreUrl(String url);
}

/// Production review client.
final class DefaultReviewClient implements ReviewClient {
  /// Creates a client over the shared plugin instances.
  const DefaultReviewClient();

  InAppReview get _review => InAppReview.instance;

  @override
  Future<bool> isAvailable() => _review.isAvailable();

  @override
  Future<void> requestReview() => _review.requestReview();

  @override
  Future<void> openStoreListing() => _review.openStoreListing();

  @override
  Future<bool> launchStoreUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
