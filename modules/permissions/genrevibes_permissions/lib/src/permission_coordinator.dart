import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'model/permission_flow_result.dart';
import 'model/permission_kind.dart';
import 'model/permission_state.dart';
import 'permission_keys.dart';
import 'permission_observer.dart';
import 'permission_provider.dart';
import 'permission_request_throttle.dart';

/// Runs the check → request → re-check flow with throttling and persistence.
///
/// Deciding *which* permissions to ask for is [MediaPermissionPolicy]'s job;
/// prompting is the provider's. This module owns the sequence in between and
/// the memory of how often the user has already been asked.
final class PermissionCoordinator implements StarterModule {
  /// Creates a coordinator.
  PermissionCoordinator({
    required PermissionProvider provider,
    required KeyValueStore store,
    PermissionRequestThrottle throttle = const PermissionRequestThrottle(),
    PermissionObserver observer = const NoopPermissionObserver(),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _provider = provider,
        _store = store,
        _throttle = throttle,
        _observer = observer,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'permissions',
          provider: provider.providerId,
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final PermissionProvider _provider;
  final KeyValueStore _store;
  final PermissionRequestThrottle _throttle;
  final PermissionObserver _observer;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'permissions';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The underlying provider, for platform facts.
  PermissionProvider get provider => _provider;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    final started = await _provider.initialize();
    if (started.isFailure) {
      final error = started.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
      _setHealth(ModuleState.failed, error: error);
      return started;
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Current states without prompting.
  Future<KitResult<PermissionFlowResult>> check(
    Iterable<PermissionKind> kinds,
  ) async {
    if (!_initialized || _disposed) return _notReady<PermissionFlowResult>();
    final states = await _statesFor(kinds, _provider.check);
    return KitSuccess<PermissionFlowResult>(_classify(states));
  }

  /// Checks, prompts for whatever is missing, and re-checks.
  ///
  /// Already-usable permissions are never re-prompted. A request that would
  /// exceed the throttle returns [PermissionFlowStatus.throttled] with a retry
  /// time instead of nagging.
  Future<KitResult<PermissionFlowResult>> request(
    Iterable<PermissionKind> kinds,
  ) async {
    if (!_initialized || _disposed) return _notReady<PermissionFlowResult>();
    final wanted = kinds.toList(growable: false);
    final before = await _statesFor(wanted, _provider.check);
    final missing = before.entries
        .where((e) => !e.value.isUsable)
        .map((e) => e.key)
        .toList(growable: false);
    if (missing.isEmpty) {
      return KitSuccess<PermissionFlowResult>(_classify(before));
    }
    if (missing.any((k) => before[k]!.needsSettings)) {
      return KitSuccess<PermissionFlowResult>(_classify(before));
    }

    final now = _clock.now();
    DateTime? retryAt;
    for (final kind in missing) {
      final count = await _readInt(PermissionKeys.requestCount(kind)) ?? 0;
      final lastMs = await _readInt(PermissionKeys.lastRequestedAt(kind));
      final last =
          lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
      final candidate = _throttle.retryAt(
        previousRequests: count,
        lastRequestedAt: last,
        now: now,
      );
      if (candidate != null &&
          (retryAt == null || candidate.isAfter(retryAt))) {
        retryAt = candidate;
      }
    }
    if (retryAt != null) {
      final result = PermissionFlowResult(
        status: PermissionFlowStatus.throttled,
        states: before,
        retryAt: retryAt,
      );
      _observer.onResolved(result);
      return KitSuccess<PermissionFlowResult>(result);
    }

    _observer.onRequested(missing);
    for (final kind in missing) {
      final count = await _readInt(PermissionKeys.requestCount(kind)) ?? 0;
      await _store.setInt(PermissionKeys.requestCount(kind), count + 1);
      await _store.setInt(
        PermissionKeys.lastRequestedAt(kind),
        now.millisecondsSinceEpoch,
      );
      final requested = await _provider.request(kind);
      if (requested.isFailure) {
        final error =
            requested.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
        _logger.log(
          KitLogLevel.warning,
          'Permission request failed.',
          moduleId: moduleId,
          error: error,
        );
        _setHealth(ModuleState.degraded, error: error);
        final result = PermissionFlowResult(
          status: PermissionFlowStatus.failed,
          states: before,
          error: error,
        );
        _observer.onResolved(result);
        return KitSuccess<PermissionFlowResult>(result);
      }
    }

    final after = await _statesFor(wanted, _provider.check);
    final result = _classify(after);
    _observer.onResolved(result);
    return KitSuccess<PermissionFlowResult>(result);
  }

  /// Opens the app's system settings page.
  Future<KitResult<bool>> openSettings() async {
    if (!_initialized || _disposed) return _notReady<bool>();
    return _provider.openSettings();
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    final result = await _provider.dispose();
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return result;
  }

  Future<Map<PermissionKind, PermissionState>> _statesFor(
    Iterable<PermissionKind> kinds,
    Future<KitResult<PermissionState>> Function(PermissionKind) read,
  ) async {
    final states = <PermissionKind, PermissionState>{};
    for (final kind in kinds) {
      states[kind] = (await read(kind)).fold(
        onSuccess: (state) => state,
        onFailure: (_) => PermissionState.unknown,
      );
    }
    return states;
  }

  PermissionFlowResult _classify(Map<PermissionKind, PermissionState> states) {
    final values = states.values;
    final status = values.every((s) => s.isUsable)
        ? PermissionFlowStatus.granted
        : values.any((s) => s.needsSettings)
            ? PermissionFlowStatus.needsSettings
            : PermissionFlowStatus.denied;
    return PermissionFlowResult(status: status, states: states);
  }

  Future<int?> _readInt(String key) async => (await _store.getInt(key))
      .fold(onSuccess: (v) => v, onFailure: (_) => null);

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Permission coordinator has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: _provider.providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
