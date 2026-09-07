import 'package:genrevibes_app_links/genrevibes_app_links.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

void main() {
  const config = AppLinksConfig(
    appName: 'Story Saver',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=x',
    appStoreUrl: 'https://apps.apple.com/app/id1',
    supportEmail: 'support@genrevibes.com',
    privacyPolicyUrl: 'https://genrevibes.com/privacy',
  );

  group('AppLinksConfig', () {
    test('picks the store for the platform and trims it', () {
      expect(config.storeUrlFor(isIos: false), contains('play.google.com'));
      expect(config.storeUrlFor(isIos: true), contains('apps.apple.com'));
    });

    test('reports a missing App Store URL only when required', () {
      const androidOnly = AppLinksConfig(
        appName: 'x',
        playStoreUrl: 'https://play.google.com/x',
        supportEmail: 'a@b.c',
        privacyPolicyUrl: 'https://x/privacy',
      );

      expect(androidOnly.validate(), isEmpty);
      expect(androidOnly.validate(requireAppStore: true),
          contains('appStoreUrl is required on iOS'));
    });

    test('rejects a stubbed privacy policy and a non-email support address',
        () {
      const bad = AppLinksConfig(
        appName: 'x',
        playStoreUrl: 'https://play.google.com/x',
        supportEmail: 'not-an-email',
        privacyPolicyUrl: 'TODO',
      );

      expect(bad.validate(), hasLength(2));
    });

    test('defaults the support subject and share text', () {
      expect(config.resolvedSupportSubject, 'Story Saver support');
      expect(
          config.shareTextFor('https://s'), 'Check out Story Saver: https://s');
    });
  });

  group('AppLinkActions', () {
    test('shares the platform store link', () async {
      final opener = _FakeOpener();
      final actions =
          AppLinkActions(config: config, opener: opener, isIos: false);

      final result = await actions.shareApp();

      expect(result.isSuccess, isTrue);
      expect(opener.shared, contains('play.google.com'));
    });

    test('a missing App Store URL fails loudly on iOS', () async {
      const androidOnly = AppLinksConfig(
        appName: 'x',
        playStoreUrl: 'https://play.google.com/x',
        supportEmail: 'a@b.c',
        privacyPolicyUrl: 'https://x/privacy',
      );
      final actions = AppLinkActions(
          config: androidOnly, opener: _FakeOpener(), isIos: true);

      final result = await actions.openStoreListing();

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.invalidConfiguration,
      );
    });

    test('contact support carries subject and diagnostics', () async {
      final opener = _FakeOpener();
      final actions =
          AppLinkActions(config: config, opener: opener, isIos: false);

      await actions.contactSupport(diagnostics: {'version': '1.5.1'});

      expect(opener.emailTo, 'support@genrevibes.com');
      expect(opener.emailSubject, 'Story Saver support');
      expect(opener.emailBody, contains('version: 1.5.1'));
    });

    test('opens privacy and reports missing terms', () async {
      final opener = _FakeOpener();
      final actions =
          AppLinkActions(config: config, opener: opener, isIos: false);

      await actions.openPrivacyPolicy();
      final terms = await actions.openTerms();

      expect(opener.opened.single.toString(), 'https://genrevibes.com/privacy');
      expect(terms.isFailure, isTrue);
    });

    test('notifies the observer with the outcome', () async {
      final observer = _RecordingObserver();
      final actions = AppLinkActions(
        config: config,
        opener: _FakeOpener()..fail = true,
        isIos: false,
        observer: observer,
      );

      await actions.openPrivacyPolicy();

      expect(observer.log, ['privacy:false']);
    });
  });
}

final class _RecordingObserver implements AppLinkObserver {
  final List<String> log = <String>[];
  @override
  void onAction(String action, {required bool succeeded}) =>
      log.add('$action:$succeeded');
}

final class _FakeOpener implements LinkOpener {
  bool fail = false;
  final List<Uri> opened = <Uri>[];
  String? shared;
  String? emailTo;
  String? emailSubject;
  String? emailBody;

  KitResult<void> get _result => fail
      ? const KitFailure<void>(
          KitError(code: KitErrorCode.unavailable, message: 'no handler'))
      : const KitSuccess<void>(null);

  @override
  String get providerId => 'fake';
  @override
  String get moduleId => 'app_links.fake';
  @override
  ModuleHealth get health => ModuleHealth(
      moduleId: moduleId, state: ModuleState.ready, observedAt: DateTime(2026));
  @override
  Stream<ModuleHealth> get healthChanges => const Stream<ModuleHealth>.empty();
  @override
  Future<KitResult<void>> initialize() async => const KitSuccess<void>(null);
  @override
  Future<KitResult<void>> dispose() async => const KitSuccess<void>(null);

  @override
  Future<KitResult<void>> openUrl(Uri uri, {bool external = true}) async {
    opened.add(uri);
    return _result;
  }

  @override
  Future<KitResult<void>> openEmail(
      {required String to, String? subject, String? body}) async {
    emailTo = to;
    emailSubject = subject;
    emailBody = body;
    return _result;
  }

  @override
  Future<KitResult<void>> share({required String text, String? subject}) async {
    shared = text;
    return _result;
  }
}
