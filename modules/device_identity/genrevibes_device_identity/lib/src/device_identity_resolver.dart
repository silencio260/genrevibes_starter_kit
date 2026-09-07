import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'device_identity.dart';
import 'device_identity_keys.dart';
import 'identity_sources.dart';
import 'install_id_generator.dart';

/// Establishes a stable install identifier and optional platform identifiers.
///
/// The install id is generated once and persisted. The vendor and advertising
/// identifiers are read best-effort on every [resolve] and never block it: a
/// failing platform source yields `null`, not an error, because identity must
/// be available before anything that could report the error is running.
final class DeviceIdentityResolver implements StarterModule {
  /// Creates a resolver.
  DeviceIdentityResolver({
    required KeyValueStore store,
    AdvertisingIdSource advertising = const UnsupportedAdvertisingIdSource(),
    VendorIdSource vendor = const NoVendorIdSource(),
    InstallIdGenerator generator = const SecureUuidGenerator(),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _advertising = advertising,
        _vendor = vendor,
        _generator = generator,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'device_identity',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final KeyValueStore _store;
  final AdvertisingIdSource _advertising;
  final VendorIdSource _vendor;
  final InstallIdGenerator _generator;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final StreamController<DeviceIdentity> _changes =
      StreamController<DeviceIdentity>.broadcast();
  ModuleHealth _health;
  DeviceIdentity? _current;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'device_identity';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The most recently resolved identity, if any.
  DeviceIdentity? get current => _current;

  /// Emits each newly resolved identity.
  Stream<DeviceIdentity> get changes => _changes.stream;

  /// Resolves the install id without prompting for tracking.
  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    _initialized = true;
    final result = await resolve();
    return result.fold(
      onSuccess: (_) => const KitSuccess<void>(null),
      onFailure: KitFailure<void>.new,
    );
  }

  /// Resolves identifiers.
  ///
  /// Pass [promptTracking] only from a screen where the request has context;
  /// an out-of-context prompt at launch is rejected by App Store review. Call
  /// again after onboarding to upgrade from a bare install id to one with an
  /// advertising identifier.
  Future<KitResult<DeviceIdentity>> resolve({
    bool promptTracking = false,
  }) async {
    if (!_initialized || _disposed) return _notReady<DeviceIdentity>();

    final installId = await _ensureInstallId();
    if (installId == null) {
      const error = KitError(
        code: KitErrorCode.unavailable,
        message: 'Install identifier could not be read or persisted.',
      );
      _setHealth(ModuleState.failed, error: error);
      return const KitFailure<DeviceIdentity>(error);
    }

    final vendorId = await _quietly(_vendor.vendorId, 'vendor_id');
    var tracking =
        await _quietly(_advertising.authorization, 'authorization') ??
            TrackingAuthorization.notSupported;
    if (promptTracking && tracking == TrackingAuthorization.notDetermined) {
      tracking = await _quietly(
            _advertising.requestAuthorization,
            'request_authorization',
          ) ??
          tracking;
    }
    final advertisingId = tracking == TrackingAuthorization.authorized
        ? await _quietly(_advertising.advertisingId, 'advertising_id')
        : null;

    final identity = DeviceIdentity(
      installId: installId,
      vendorId: vendorId,
      advertisingId: advertisingId,
      tracking: tracking,
    );
    _current = identity;
    if (!_changes.isClosed) _changes.add(identity);
    _setHealth(ModuleState.ready);
    return KitSuccess<DeviceIdentity>(identity);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _changes.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<String?> _ensureInstallId() async {
    final existing =
        (await _store.getString(DeviceIdentityKeys.installId)).fold(
      onSuccess: (v) => v,
      onFailure: (_) => null,
    );
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final generated = _generator.generate();
    final written =
        await _store.setString(DeviceIdentityKeys.installId, generated);
    return written.fold(onSuccess: (_) => generated, onFailure: (_) => null);
  }

  Future<T?> _quietly<T>(Future<T?> Function() read, String what) async {
    try {
      return await read();
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.debug,
        'Identity source unavailable: $what.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Device identity resolver has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'tracking': _current?.tracking.name,
        'hasVendorId': _current?.vendorId != null,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
