import 'dart:async';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_remote_config/genrevibes_remote_config.dart';

import 'analytics_sink_policy_keys.dart';

/// Keeps each [SwitchableAnalyticsSink] on or off according to its
/// `analytics_<sinkId>_enabled` remote key.
///
/// Applies the snapshot on initialization and again on every change, so
/// setting `analytics_mixpanel_enabled` to `false` in Firebase stops Mixpanel
/// on a running device as soon as it activates the fetch — no release, no
/// relaunch. Only the sinks passed in are switched; wrap just the providers
/// that should be remotely controllable.
final class AnalyticsSinkRemotePolicyBinder implements StarterModule {
  /// Creates a binder over any snapshot source.
  AnalyticsSinkRemotePolicyBinder({
    required RemoteConfigSnapshot Function() current,
    required Stream<RemoteConfigSnapshot> changes,
    required Iterable<SwitchableAnalyticsSink> sinks,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _current = current,
        _changes = changes,
        _sinks = List<SwitchableAnalyticsSink>.unmodifiable(sinks),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics.sinks.remote_policy',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Creates a binder over a [RemoteConfigCoordinator].
  factory AnalyticsSinkRemotePolicyBinder.forCoordinator(
    RemoteConfigCoordinator coordinator, {
    required Iterable<SwitchableAnalyticsSink> sinks,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  }) {
    return AnalyticsSinkRemotePolicyBinder(
      current: () => coordinator.current,
      changes: coordinator.changes,
      sinks: sinks,
      clock: clock,
      logger: logger,
    );
  }

  final RemoteConfigSnapshot Function() _current;
  final Stream<RemoteConfigSnapshot> _changes;
  final List<SwitchableAnalyticsSink> _sinks;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  StreamSubscription<RemoteConfigSnapshot>? _subscription;
  ModuleHealth _health;
  Map<String, bool> _applied = const <String, bool>{};
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'analytics.sinks.remote_policy';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The most recently applied switch per sink id.
  Map<String, bool> get applied => _applied;

  /// Reads whether the snapshot switches [sinkId] on, without applying it.
  ///
  /// Startup uses this to construct each [SwitchableAnalyticsSink] in the right
  /// position from cached values, so a provider that is off stays
  /// uninitialized instead of starting and then being switched off.
  static bool enabledFrom(RemoteConfigSnapshot snapshot, String sinkId) =>
      snapshot.read(AnalyticsSinkPolicyKeys.keyFor(sinkId));

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
    if (_disposed) return;
    final applied = <String, bool>{};
    KitError? firstError;
    for (final sink in _sinks) {
      final enabled = enabledFrom(snapshot, sink.sinkId);
      applied[sink.sinkId] = enabled;
      final result = await sink.setEnabled(enabled);
      result.fold(
        onSuccess: (_) {},
        onFailure: (error) {
          firstError ??= error;
          _logger.log(
            KitLogLevel.warning,
            'Analytics sink switch could not be applied.',
            moduleId: moduleId,
            error: error,
            fields: <String, Object?>{
              'sink': sink.sinkId,
              'enabled': enabled,
            },
          );
        },
      );
    }
    _applied = Map<String, bool>.unmodifiable(applied);
    _logger.log(
      KitLogLevel.debug,
      'Analytics sink switches applied from remote configuration.',
      moduleId: moduleId,
      fields: _applied,
    );
    if (_initialized && !_disposed) {
      _setHealth(
        firstError == null ? ModuleState.ready : ModuleState.degraded,
        error: firstError,
      );
    }
  }

  KitFailure<void> _notReady() {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.notInitialized,
        message: 'Analytics sink remote policy binder has been disposed.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    if (_disposed && state != ModuleState.disposed) return;
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        for (final entry in _applied.entries) entry.key: entry.value,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
