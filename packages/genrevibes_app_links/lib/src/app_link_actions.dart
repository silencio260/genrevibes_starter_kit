import 'package:genrevibes_core/genrevibes_core.dart';

import 'app_links_config.dart';
import 'link_opener.dart';

/// Receives link actions for analytics.
abstract interface class AppLinkObserver {
  /// An action was performed. [action] is one of `share`, `store`, `support`,
  /// `privacy`, `terms`.
  void onAction(String action, {required bool succeeded});
}

/// [AppLinkObserver] that records nothing.
final class NoopAppLinkObserver implements AppLinkObserver {
  /// Creates a no-op observer.
  const NoopAppLinkObserver();

  @override
  void onAction(String action, {required bool succeeded}) {}
}

/// The share / rate / contact / privacy / terms actions every app exposes.
///
/// Policy lives here: which URL for which platform, what the share text says,
/// what a support email carries. The opener only knows how to launch things.
/// A missing link is a configuration failure, never a silent no-op.
final class AppLinkActions {
  /// Creates actions over [config] and [opener].
  const AppLinkActions({
    required AppLinksConfig config,
    required LinkOpener opener,
    required bool isIos,
    AppLinkObserver observer = const NoopAppLinkObserver(),
  })  : _config = config,
        _opener = opener,
        _isIos = isIos,
        _observer = observer;

  final AppLinksConfig _config;
  final LinkOpener _opener;
  final bool _isIos;
  final AppLinkObserver _observer;

  /// Opens the share sheet with the store link.
  Future<KitResult<void>> shareApp() async {
    final url = _config.storeUrlFor(isIos: _isIos);
    if (url == null) return _missing('share', 'store URL');
    return _run('share', () => _opener.share(text: _config.shareTextFor(url)));
  }

  /// Opens the store listing for the running platform.
  Future<KitResult<void>> openStoreListing() async {
    final url = _config.storeUrlFor(isIos: _isIos);
    if (url == null) return _missing('store', 'store URL');
    return _run('store', () => _opener.openUrl(Uri.parse(url)));
  }

  /// Opens the mail client addressed to support.
  ///
  /// [diagnostics] are appended to the body so the user does not have to
  /// describe their device; keep them non-sensitive.
  Future<KitResult<void>> contactSupport({
    String? subject,
    Map<String, String> diagnostics = const <String, String>{},
  }) {
    final body = diagnostics.isEmpty
        ? null
        : '\n\n---\n${diagnostics.entries.map((e) => '${e.key}: ${e.value}').join('\n')}';
    return _run(
      'support',
      () => _opener.openEmail(
        to: _config.supportEmail,
        subject: subject ?? _config.resolvedSupportSubject,
        body: body,
      ),
    );
  }

  /// Opens the privacy policy.
  Future<KitResult<void>> openPrivacyPolicy() {
    return _run(
      'privacy',
      () => _opener.openUrl(Uri.parse(_config.privacyPolicyUrl)),
    );
  }

  /// Opens the terms page.
  Future<KitResult<void>> openTerms() async {
    final url = _config.termsUrl;
    if (url == null || url.trim().isEmpty) {
      return _missing('terms', 'terms URL');
    }
    return _run('terms', () => _opener.openUrl(Uri.parse(url.trim())));
  }

  Future<KitResult<void>> _run(
    String action,
    Future<KitResult<void>> Function() body,
  ) async {
    final result = await body();
    _observer.onAction(action, succeeded: result.isSuccess);
    return result;
  }

  KitFailure<void> _missing(String action, String what) {
    _observer.onAction(action, succeeded: false);
    return KitFailure<void>(
      KitError(
        code: KitErrorCode.invalidConfiguration,
        message: 'AppLinksConfig has no $what for this platform.',
      ),
    );
  }
}
