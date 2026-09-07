import 'dart:async';

import 'package:genrevibes_app_links/genrevibes_app_links.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'launcher_client.dart';

/// url_launcher and share_plus implementation of [LinkOpener].
final class UrlLauncherLinkOpener implements LinkOpener {
  /// Creates an opener.
  UrlLauncherLinkOpener({
    LauncherClient client = const DefaultLauncherClient(),
    KitClock clock = const SystemKitClock(),
  })  : _client = client,
        _clock = clock,
        _health = ModuleHealth(
          moduleId: 'app_links.url_launcher',
          provider: 'url_launcher',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final LauncherClient _client;
  final KitClock _clock;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'url_launcher';

  @override
  String get moduleId => 'app_links.url_launcher';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady();
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> openUrl(Uri uri, {bool external = true}) {
    return _guard('open_url', () async {
      if (!await _client.canLaunch(uri)) {
        throw StateError('No handler for ${uri.scheme}');
      }
      if (!await _client.launch(uri, external: external)) {
        throw StateError('Launch rejected for $uri');
      }
    });
  }

  @override
  Future<KitResult<void>> openEmail({
    required String to,
    String? subject,
    String? body,
  }) {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      queryParameters: <String, String>{
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );
    return _guard('open_email', () async {
      if (!await _client.launch(uri, external: true)) {
        throw StateError('No mail client available');
      }
    });
  }

  @override
  Future<KitResult<void>> share({required String text, String? subject}) {
    return _guard('share', () => _client.share(text, subject: subject));
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<void>> _guard(
    String providerCode,
    Future<void> Function() action,
  ) async {
    if (!_initialized || _disposed) return _notReady();
    try {
      await action();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.unavailable,
          message: 'Link $providerCode failed: $error',
          providerCode: 'url_launcher_$providerCode',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Link opener has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
