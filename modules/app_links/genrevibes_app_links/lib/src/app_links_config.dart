/// Where an app lives and how to reach its developer.
///
/// One value object instead of constants scattered through the app, so a
/// missing App Store URL or a stubbed privacy policy is a validation failure
/// at composition rather than a dead button in production.
final class AppLinksConfig {
  /// Creates a config.
  const AppLinksConfig({
    required this.appName,
    required this.playStoreUrl,
    required this.supportEmail,
    required this.privacyPolicyUrl,
    this.appStoreUrl,
    this.termsUrl,
    this.supportSubject,
    this.shareMessage,
  });

  /// Display name used in share text and email subjects.
  final String appName;

  /// Google Play listing.
  final String playStoreUrl;

  /// App Store listing. Required on iOS; validated, not assumed.
  final String? appStoreUrl;

  /// Support inbox.
  final String supportEmail;

  /// Subject line for support email. Defaults to "<appName> support".
  final String? supportSubject;

  /// Privacy policy page. Required by both stores.
  final String privacyPolicyUrl;

  /// Terms page, when the app has one.
  final String? termsUrl;

  /// Builds the share text for a store URL. Defaults to a plain sentence.
  final String Function(String storeUrl)? shareMessage;

  /// The store listing for the running platform, or `null` when missing.
  String? storeUrlFor({required bool isIos}) {
    final url = isIos ? appStoreUrl : playStoreUrl;
    return url == null || url.trim().isEmpty ? null : url.trim();
  }

  /// Share text for [storeUrl].
  String shareTextFor(String storeUrl) =>
      shareMessage?.call(storeUrl) ?? 'Check out $appName: $storeUrl';

  /// Email subject for support requests.
  String get resolvedSupportSubject =>
      (supportSubject?.trim().isNotEmpty ?? false)
          ? supportSubject!.trim()
          : '$appName support';

  /// Configuration problems, empty when the config is usable.
  ///
  /// [requireAppStore] should be true for any app that ships on iOS.
  List<String> validate({bool requireAppStore = false}) {
    final problems = <String>[];
    if (appName.trim().isEmpty) {
      problems.add('appName is blank');
    }
    if (!_isHttp(playStoreUrl)) {
      problems.add('playStoreUrl is not an http(s) URL');
    }
    if (requireAppStore && !_isHttp(appStoreUrl)) {
      problems.add('appStoreUrl is required on iOS');
    }
    if (!supportEmail.contains('@')) {
      problems.add('supportEmail is not an email');
    }
    if (!_isHttp(privacyPolicyUrl)) {
      problems.add('privacyPolicyUrl is not an http(s) URL');
    }
    if (termsUrl != null && !_isHttp(termsUrl)) {
      problems.add('termsUrl is not an http(s) URL');
    }
    return problems;
  }

  static bool _isHttp(String? value) {
    if (value == null) return false;
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }
}
