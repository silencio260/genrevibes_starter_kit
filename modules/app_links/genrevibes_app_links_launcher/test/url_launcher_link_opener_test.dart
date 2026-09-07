import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_app_links/genrevibes_app_links.dart';
import 'package:genrevibes_app_links_launcher/genrevibes_app_links_launcher.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

void main() {
  group('UrlLauncherLinkOpener', () {
    test('rejects work before initialization', () async {
      final result = await UrlLauncherLinkOpener(client: _FakeClient())
          .openUrl(Uri.parse('https://x'));

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.notInitialized,
      );
    });

    test('opens a URL externally when a handler exists', () async {
      final client = _FakeClient();
      final opener = await _ready(client);

      final result = await opener.openUrl(Uri.parse('https://x/privacy'));

      expect(result.isSuccess, isTrue);
      expect(client.launched.single.external, isTrue);
    });

    test('reports unavailable when nothing can handle the URL', () async {
      final client = _FakeClient()..canLaunchResult = false;
      final opener = await _ready(client);

      final result = await opener.openUrl(Uri.parse('https://x'));

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.providerCode),
        'url_launcher_open_url',
      );
    });

    test('builds a mailto URI with subject and body', () async {
      final client = _FakeClient();
      final opener = await _ready(client);

      await opener.openEmail(to: 'a@b.c', subject: 'Help', body: 'v 1.0');

      final uri = client.launched.single.uri;
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'a@b.c');
      expect(uri.queryParameters['subject'], 'Help');
      expect(uri.queryParameters['body'], 'v 1.0');
    });

    test('shares text through the client', () async {
      final client = _FakeClient();
      final opener = await _ready(client);

      await opener.share(text: 'hello');

      expect(client.shared, 'hello');
    });

    test('composes with AppLinkActions', () async {
      final client = _FakeClient();
      final actions = AppLinkActions(
        config: const AppLinksConfig(
          appName: 'x',
          playStoreUrl: 'https://play.google.com/x',
          supportEmail: 'a@b.c',
          privacyPolicyUrl: 'https://x/privacy',
        ),
        opener: await _ready(client),
        isIos: false,
      );

      expect((await actions.shareApp()).isSuccess, isTrue);
      expect(client.shared, contains('play.google.com'));
    });
  });
}

Future<UrlLauncherLinkOpener> _ready(_FakeClient client) async {
  final opener = UrlLauncherLinkOpener(client: client);
  await opener.initialize();
  return opener;
}

final class _Launch {
  _Launch(this.uri, this.external);
  final Uri uri;
  final bool external;
}

final class _FakeClient implements LauncherClient {
  bool canLaunchResult = true;
  final List<_Launch> launched = <_Launch>[];
  String? shared;

  @override
  Future<bool> canLaunch(Uri uri) async => canLaunchResult;

  @override
  Future<bool> launch(Uri uri, {required bool external}) async {
    launched.add(_Launch(uri, external));
    return true;
  }

  @override
  Future<void> share(String text, {String? subject}) async => shared = text;
}
