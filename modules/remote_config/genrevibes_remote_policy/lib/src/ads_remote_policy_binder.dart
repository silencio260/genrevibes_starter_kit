import 'dart:async';

import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'ads_policy_config.dart';

/// Keeps an [AdPolicyController] tuned to the current remote configuration.
///
/// Applies the snapshot at startup and again on every change, through
/// `updatePlacements`, so a tuning change lands live without recreating the
/// controller and losing its suppression state.
final class AdsRemotePolicyBinder implements StarterModule {
  /// Creates a binder over any snapshot source.
  AdsRemotePolicyBinder({
    required RemoteConfigSnapshot Function() current,
    required Stream<RemoteConfigSnapshot> changes,
    required AdPolicyController policy,
    required Iterable<AdPlacement> placements,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _current = current,
        _changes = changes,
        _policy = policy,
        _placements = List<AdPlacement>.unmodifiable(placements),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'ads.remote_policy',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Creates a binder over a [RemoteConfigCoordinator].
  factory AdsRemotePolicyBinder.forCoordinator(
    RemoteConfigCoordinator coordinator, {
    required AdPolicyController policy,
    required Iterable<AdPlacement> placements,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  }) {
    return AdsRemotePolicyBinder(
      current: () => coordinator.current,
      changes: coordinator.changes,
      policy: policy,
      placements: placements,
      clock: clock,
      logger: logger,
    );
  }

  final RemoteConfigSnapshot Function() _current;
  final Stream<RemoteConfigSnapshot> _changes;
  final AdPolicyController _policy;
  final List<AdPlacement> _placements;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  StreamSubscription<RemoteConfigSnapshot>? _subscription;
  ModuleHealth _health;
  AdsPolicyConfig? _applied;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'ads.remote_policy';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The most recently applied config.
  AdsPolicyConfig? get applied => _applied;

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
    final config = AdsPolicyConfig.fromSnapshot(snapshot);
    _policy.updatePlacements(config.toPlacementPolicies(_placements));
    _applied = config;
    _logger.log(
      KitLogLevel.debug,
      'Ads policy applied from remote configuration.',
      moduleId: moduleId,
      fields: <String, Object?>{'enabled': config.enabled},
    );
    if (_initialized && !_disposed) _setHealth(ModuleState.ready);
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Ads remote policy binder has been disposed.',
      ),
    );
  }

  void _setHealth(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      details: <String, Object?>{'adsEnabled': _applied?.enabled},
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
