import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'engagement_keys.dart';
import 'engagement_observer.dart';
import 'model/engagement_snapshot.dart';
import 'model/retention_milestone.dart';
import 'model/user_profile.dart';
import 'user_targeting_policy.dart';

/// Records opens and sessions, derives retention, and evaluates the profile.
///
/// State lives in a [KeyValueStore]; wrap it in a `MigratingKeyValueStore`
/// seeded with [EngagementKeys.legacyKeys] to adopt an existing install's
/// history. Time comes from an injected clock, so every rule is deterministic.
final class RetentionTracker implements StarterModule {
  /// Creates a tracker over [store].
  ///
  /// [sessionHistoryLimit] bounds the persisted session list; older instants
  /// are dropped. Only "today" is ever read from it, so the cap costs nothing.
  RetentionTracker({
    required KeyValueStore store,
    EngagementObserver observer = const NoopEngagementObserver(),
    UserTargetingPolicy policy = const UserTargetingPolicy(),
    this.sessionHistoryLimit = 500,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _observer = observer,
        _policy = policy,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'engagement',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Maximum persisted session instants.
  final int sessionHistoryLimit;

  final KeyValueStore _store;
  final EngagementObserver _observer;
  final UserTargetingPolicy _policy;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  DateTime? _installedAt;
  DateTime? _lastOpenedAt;
  int _totalOpens = 0;
  List<DateTime> _sessions = <DateTime>[];
  List<DateTime> _activeDates = <DateTime>[];
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'engagement';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Current history, computed against the injected clock.
  EngagementSnapshot get snapshot => EngagementSnapshot.compute(
        now: _clock.now(),
        installedAt: _installedAt,
        lastOpenedAt: _lastOpenedAt,
        totalOpens: _totalOpens,
        sessionTimestamps: _sessions,
        activeDates: _activeDates,
      );

  /// Segment, level, score and decisions for the current snapshot.
  UserProfile get profile => _policy.profile(snapshot);

  /// Loads persisted history. Writes nothing.
  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    try {
      _installedAt = await _readDate(EngagementKeys.installedAt);
      _lastOpenedAt = await _readDate(EngagementKeys.lastOpenedAt);
      _totalOpens = await _readInt(EngagementKeys.totalOpens) ?? 0;
      _sessions = await _readDates(EngagementKeys.sessionTimestamps);
      _activeDates = await _readDates(EngagementKeys.dailyOpenDates);
    } on _StorageFailure catch (failure) {
      // Unreadable history is treated as an empty history rather than a hard
      // failure: losing retention data is far better than failing startup.
      _logger.log(
        KitLogLevel.warning,
        'Engagement history could not be read. Starting fresh.',
        moduleId: moduleId,
        error: failure.error,
      );
      _initialized = true;
      _setHealth(ModuleState.degraded, error: failure.error);
      return const KitSuccess<void>(null);
    }
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Records an app open, reports milestones, and evaluates the profile.
  ///
  /// Call once per launch. The install date is written only when absent.
  Future<KitResult<EngagementSnapshot>> recordAppOpen() async {
    if (!_initialized || _disposed) return _notReady<EngagementSnapshot>();
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      if (_installedAt == null) {
        _installedAt = now;
        await _writeDate(EngagementKeys.installedAt, now);
      }
      _lastOpenedAt = now;
      await _writeDate(EngagementKeys.lastOpenedAt, now);
      _totalOpens += 1;
      await _write(_store.setInt(EngagementKeys.totalOpens, _totalOpens));
      await _appendSession(now);
      if (!_activeDates.contains(today)) {
        _activeDates = <DateTime>[..._activeDates, today];
        await _writeDates(EngagementKeys.dailyOpenDates, _activeDates);
      }
    } on _StorageFailure catch (failure) {
      return _degradeWith<EngagementSnapshot>(failure.error);
    }

    final current = snapshot;
    _observer.onAppOpened(current);
    await _reportMilestone(current);
    _observer.onProfileEvaluated(_policy.profile(current));
    return KitSuccess<EngagementSnapshot>(current);
  }

  /// Records a session start, typically on app resume.
  Future<KitResult<EngagementSnapshot>> recordSession() async {
    if (!_initialized || _disposed) return _notReady<EngagementSnapshot>();
    try {
      await _appendSession(_clock.now());
    } on _StorageFailure catch (failure) {
      return _degradeWith<EngagementSnapshot>(failure.error);
    }
    final current = snapshot;
    _observer.onSessionStarted(current);
    return KitSuccess<EngagementSnapshot>(current);
  }

  /// Clears all history. Intended for QA.
  Future<KitResult<void>> reset() async {
    if (_disposed) return _notReady<void>();
    for (final key in <String>[
      EngagementKeys.installedAt,
      EngagementKeys.lastOpenedAt,
      EngagementKeys.totalOpens,
      EngagementKeys.sessionTimestamps,
      EngagementKeys.dailyOpenDates,
      for (final m in RetentionMilestone.values) EngagementKeys.milestone(m),
    ]) {
      final removed = await _store.remove(key);
      if (removed.isFailure) return removed;
    }
    _installedAt = null;
    _lastOpenedAt = null;
    _totalOpens = 0;
    _sessions = <DateTime>[];
    _activeDates = <DateTime>[];
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  /// Reports the milestone for today's day-since-install at most once.
  ///
  /// The hand-rolled trackers re-emit on every open of that day, and their
  /// day-7 cap means day 30 never fires. Both are fixed here on purpose.
  Future<void> _reportMilestone(EngagementSnapshot current) async {
    final milestone = RetentionMilestone.forDay(current.daysSinceInstall);
    if (milestone == null) return;
    final key = EngagementKeys.milestone(milestone);
    final already = (await _store.getBool(key)).fold(
      onSuccess: (v) => v ?? false,
      onFailure: (_) => true, // unreadable: do not risk a duplicate
    );
    if (already) return;
    final marked = await _store.setBool(key, true);
    if (marked.isFailure) return;
    _observer.onMilestone(milestone, current);
  }

  Future<void> _appendSession(DateTime instant) async {
    final next = <DateTime>[..._sessions, instant];
    _sessions = next.length > sessionHistoryLimit
        ? next.sublist(next.length - sessionHistoryLimit)
        : next;
    await _writeDates(EngagementKeys.sessionTimestamps, _sessions);
  }

  Future<DateTime?> _readDate(String key) async {
    final raw = _unwrap(await _store.getString(key));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<int?> _readInt(String key) async => _unwrap(await _store.getInt(key));

  Future<List<DateTime>> _readDates(String key) async {
    final raw = _unwrap(await _store.getStringList(key)) ?? const <String>[];
    return <DateTime>[
      for (final value in raw)
        if (DateTime.tryParse(value) case final parsed?) parsed,
    ];
  }

  Future<void> _writeDate(String key, DateTime value) =>
      _write(_store.setString(key, value.toIso8601String()));

  Future<void> _writeDates(String key, List<DateTime> values) => _write(
        _store.setStringList(
          key,
          values.map((v) => v.toIso8601String()).toList(growable: false),
        ),
      );

  Future<void> _write(Future<KitResult<void>> pending) async {
    _unwrap(await pending);
  }

  T? _unwrap<T>(KitResult<T?> result) => result.fold(
        onSuccess: (value) => value,
        onFailure: (error) => throw _StorageFailure(error),
      );

  KitFailure<T> _degradeWith<T>(KitError error) {
    _logger.log(
      KitLogLevel.warning,
      'Engagement history could not be persisted.',
      moduleId: moduleId,
      error: error,
    );
    _setHealth(ModuleState.degraded, error: error);
    return KitFailure<T>(error);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Retention tracker has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{'totalOpens': _totalOpens},
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}

final class _StorageFailure implements Exception {
  const _StorageFailure(this.error);
  final KitError error;
}
