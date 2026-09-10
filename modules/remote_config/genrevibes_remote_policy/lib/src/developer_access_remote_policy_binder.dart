import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_developer_access/genrevibes_developer_access.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'developer_access_policy_keys.dart';

/// Keeps a [DeveloperAccessController] on the current remote device list.
///
/// Applies the snapshot on initialization and on every change, so a phone added
/// in the console gains access — and test ads — on its next fetch, and a phone
/// removed loses them the same way, without a relaunch.
final class DeveloperAccessRemotePolicyBinder implements StarterModule {
  /// Creates a binder over any snapshot source.
  DeveloperAccessRemotePolicyBinder({
    required RemoteConfigSnapshot Function() current,
    required Stream<RemoteConfigSnapshot> changes,
    required DeveloperAccessController controller,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _current = current,
        _changes = changes,
        _controller = controller,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'developer_access.remote_policy',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Creates a binder over a [RemoteConfigCoordinator].
  factory DeveloperAccessRemotePolicyBinder.forCoordinator(
    RemoteConfigCoordinator coordinator, {
    required DeveloperAccessController controller,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  }) {
    return DeveloperAccessRemotePolicyBinder(
      current: () => coordinator.current,
      changes: coordinator.changes,
      controller: controller,
      clock: clock,
      logger: logger,
    );
  }

  final RemoteConfigSnapshot Function() _current;
  final Stream<RemoteConfigSnapshot> _changes;
  final DeveloperAccessController _controller;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  StreamSubscription<RemoteConfigSnapshot>? _subscription;
  ModuleHealth _health;
  int? _appliedCount;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'developer_access.remote_policy';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady();
    if (_initialized) return const KitSuccess<void>(null);
    _apply(_current());
    _subscription = _changes.listen(_apply);
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    await _subscription?.cancel();
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _apply(RemoteConfigSnapshot snapshot) {
    final hashes = DeveloperAccessPolicyKeys.hashesFrom(snapshot);
    _controller.setRemoteDeviceHashes(hashes);
    _appliedCount = hashes.length;
    _logger.log(
      KitLogLevel.debug,
      'Developer device list applied from remote configuration.',
      moduleId: moduleId,
      fields: <String, Object?>{'entries': hashes.length},
    );
    if (_initialized && !_disposed) _setHealth(ModuleState.ready);
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Developer access remote policy binder has been disposed.',
      ),
    );
  }

  void _setHealth(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      details: <String, Object?>{'remoteEntries': _appliedCount},
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
