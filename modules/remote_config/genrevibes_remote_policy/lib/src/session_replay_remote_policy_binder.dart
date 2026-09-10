import 'dart:async';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'session_replay_policy_keys.dart';

/// Keeps a [SessionReplayController] tuned to the current remote configuration.
///
/// Applies the snapshot on initialization and again on every change, so pulling
/// the rollout percentage down in Firebase stops recording on devices that fall
/// outside the new number as soon as they see it — no release, and for a device
/// already running, no relaunch.
///
/// Masking is the exception, and not because of this binder: providers fix it
/// when the SDK is configured. A masking change reaches the plan here and the
/// SDK on the next launch.
final class SessionReplayRemotePolicyBinder implements StarterModule {
  /// Creates a binder over any snapshot source.
  SessionReplayRemotePolicyBinder({
    required RemoteConfigSnapshot Function() current,
    required Stream<RemoteConfigSnapshot> changes,
    required SessionReplayController controller,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _current = current,
        _changes = changes,
        _controller = controller,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics.session_replay.remote_policy',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Creates a binder over a [RemoteConfigCoordinator].
  factory SessionReplayRemotePolicyBinder.forCoordinator(
    RemoteConfigCoordinator coordinator, {
    required SessionReplayController controller,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  }) {
    return SessionReplayRemotePolicyBinder(
      current: () => coordinator.current,
      changes: coordinator.changes,
      controller: controller,
      clock: clock,
      logger: logger,
    );
  }

  final RemoteConfigSnapshot Function() _current;
  final Stream<RemoteConfigSnapshot> _changes;
  final SessionReplayController _controller;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  StreamSubscription<RemoteConfigSnapshot>? _subscription;
  ModuleHealth _health;
  SessionReplayPolicy? _applied;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'analytics.session_replay.remote_policy';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The most recently applied policy.
  SessionReplayPolicy? get applied => _applied;

  /// Reads the policy the current snapshot describes, without applying it.
  ///
  /// Startup needs this before the controller exists: the provider's SDK is
  /// configured from the resolved plan, and masking has to be right at that
  /// moment because no provider can change it later.
  static SessionReplayPolicy policyFrom(RemoteConfigSnapshot snapshot) =>
      SessionReplayPolicyKeys.policyFrom(snapshot);

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady();
    if (_initialized) return const KitSuccess<void>(null);
    await _apply(_current());
    _subscription = _changes.listen(
      (snapshot) => unawaited(_apply(snapshot)),
    );
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

  Future<void> _apply(RemoteConfigSnapshot snapshot) async {
    final policy = SessionReplayPolicyKeys.policyFrom(snapshot);
    _applied = policy;
    final result = await _controller.applyPolicy(policy);
    result.fold(
      onSuccess: (_) => _logger.log(
        KitLogLevel.debug,
        'Session replay policy applied from remote configuration.',
        moduleId: moduleId,
        fields: <String, Object?>{
          'enabled': policy.enabled,
          'percentOfUsers': policy.percentOfUsers,
          'recording': _controller.plan.recording,
        },
      ),
      onFailure: (error) => _logger.log(
        KitLogLevel.warning,
        'Session replay policy could not be applied.',
        moduleId: moduleId,
        error: error,
      ),
    );
    if (_initialized && !_disposed) _setHealth(ModuleState.ready);
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Session replay remote policy binder has been disposed.',
      ),
    );
  }

  void _setHealth(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      details: <String, Object?>{
        'enabled': _applied?.enabled,
        'percentOfUsers': _applied?.percentOfUsers,
        'maskAllText': _applied?.maskAllText,
        'maskAllImages': _applied?.maskAllImages,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
