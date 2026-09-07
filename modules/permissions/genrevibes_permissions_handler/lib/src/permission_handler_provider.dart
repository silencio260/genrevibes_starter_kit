import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_permissions/genrevibes_permissions.dart';

import 'permission_handler_client.dart';
import 'permission_handler_mapping.dart';
import 'platform_facts_source.dart';

/// permission_handler implementation of [PermissionProvider].
final class PermissionHandlerProvider implements PermissionProvider {
  /// Creates a provider.
  PermissionHandlerProvider({
    PermissionHandlerClient client = const DefaultPermissionHandlerClient(),
    PlatformFactsSource platformFacts = const DeviceInfoPlatformFactsSource(),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _client = client,
        _platformFacts = platformFacts,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'permissions.permission_handler',
          provider: 'permission_handler',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final PermissionHandlerClient _client;
  final PlatformFactsSource _platformFacts;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  PlatformFacts _platform = const PlatformFacts(isAndroid: false, isIos: false);
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'permission_handler';

  @override
  String get moduleId => 'permissions.permission_handler';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  PlatformFacts get platform => _platform;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    try {
      _platform = await _platformFacts.load();
    } on Object catch (error, stackTrace) {
      // Unknown platform facts degrade policy (legacy storage is assumed) but
      // must not stop the app from asking at all.
      _logger.log(
        KitLogLevel.warning,
        'Platform facts unavailable; assuming no split media permissions.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<PermissionState>> check(PermissionKind kind) {
    return _guard(
      () async =>
          mapPermissionStatus(await _client.status(permissionFor(kind))),
      'status',
    );
  }

  @override
  Future<KitResult<PermissionState>> request(PermissionKind kind) {
    return _guard(
      () async =>
          mapPermissionStatus(await _client.request(permissionFor(kind))),
      'request',
    );
  }

  @override
  Future<KitResult<bool>> openSettings() {
    return _guard(_client.openAppSettings, 'open_settings');
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<T>> _guard<T>(
    Future<T> Function() action,
    String providerCode,
  ) async {
    if (!_initialized || _disposed) return _notReady<T>();
    try {
      return KitSuccess<T>(await action());
    } on Object catch (error, stackTrace) {
      final mapped = KitError(
        code: KitErrorCode.provider,
        message: 'permission_handler $providerCode failed: $error',
        providerCode: 'permission_handler_$providerCode',
        cause: error,
        stackTrace: stackTrace,
      );
      if (!_disposed) _setHealth(ModuleState.degraded, error: mapped);
      return KitFailure<T>(mapped);
    }
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Permission provider has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'androidSdkInt': _platform.androidSdkInt,
        'splitMedia': _platform.hasSplitMediaPermissions,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
