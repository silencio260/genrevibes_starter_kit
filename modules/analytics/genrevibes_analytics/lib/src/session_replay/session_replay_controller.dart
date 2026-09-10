import 'dart:async';
import 'dart:math';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'session_replay_keys.dart';
import 'session_replay_recorder.dart';
import 'session_replay_settings.dart';

/// Decides whether this install records session replay, and enforces it.
///
/// Session replay is the most expensive thing an analytics provider bills for
/// and the most sensitive thing it stores, so the decision is deliberately not
/// left to the SDK. Three inputs, in strict order of authority:
///
/// 1. A developer's [SessionReplayOverride], persisted on the device.
/// 2. The rollout's master switch.
/// 3. This install's stable bucket against the rollout percentage.
///
/// The bucket is drawn once, on the first launch that asks, and kept. That is
/// the difference between a rollout and a coin toss: taking the percentage from
/// 100 down to 20 leaves a fifth of users recorded *continuously*, rather than
/// recording a different fifth every launch. A retention question needs the
/// former — the same users' sessions, before and after whatever changed.
///
/// The controller owns no SDK. Attach a [SessionReplayRecorder] once the
/// provider is configured and the controller keeps it in step with the plan
/// from then on; attach nothing and it still resolves a plan, which is what a
/// diagnostics screen reads and what the provider's own configuration is built
/// from at startup.
///
/// One thing it cannot enforce live: masking. Providers fix it when the SDK is
/// configured, so a masking change in [applyPolicy] lands on the next launch.
/// [plan] always reports the values the *next* configuration will use.
final class SessionReplayController implements StarterModule {
  /// Creates a controller.
  SessionReplayController({
    required KeyValueStore store,
    SessionReplayPolicy policy = const SessionReplayPolicy(),
    SessionReplayOverride? buildOverride,
    SessionReplayRecorder? recorder,
    Random? random,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _policy = policy,
        _buildOverride = buildOverride,
        _recorder = recorder,
        _random = random ?? Random(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics.session_replay',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final KeyValueStore _store;
  final SessionReplayOverride? _buildOverride;
  final Random _random;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final StreamController<SessionReplayPlan> _planChanges =
      StreamController<SessionReplayPlan>.broadcast();

  SessionReplayPolicy _policy;
  SessionReplayRecorder? _recorder;
  SessionReplayOverride _override = SessionReplayOverride.followRemote;
  SessionReplayPlan _plan = SessionReplayPlan.none;
  ModuleHealth _health;
  int _bucket = 0;
  bool _bucketResolved = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'analytics.session_replay';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// The current decision. Safe to read before initialization; records nothing.
  SessionReplayPlan get plan => _plan;

  /// Emits every re-resolved plan.
  Stream<SessionReplayPlan> get planChanges => _planChanges.stream;

  /// The rollout currently in force.
  SessionReplayPolicy get policy => _policy;

  /// The attached provider's id, or `null` when nothing is attached.
  String? get providerId => _recorder?.providerId;

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) return _notReady<void>();
    _setHealth(ModuleState.initializing);

    var degraded = false;
    final stored = await _store.getString(SessionReplayKeys.override);
    stored.fold(
      onSuccess: (value) => _override = SessionReplayOverride.parse(value),
      onFailure: (error) {
        degraded = true;
        _logFailure('Session replay override could not be read.', error);
      },
    );
    // A build-time force is a default, not a command: it seeds a device that
    // has never been told either way, and loses to whatever the developer
    // chose on the device itself.
    final seed = _buildOverride;
    if (seed != null &&
        seed != SessionReplayOverride.followRemote &&
        _override == SessionReplayOverride.followRemote) {
      _override = seed;
    }

    if (!await _resolveBucket()) degraded = true;

    _initialized = true;
    _publish(_resolve());
    _setHealth(degraded ? ModuleState.degraded : ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Binds a configured provider and brings it in line with the plan.
  ///
  /// Called after the SDK is set up. The provider was configured from this
  /// same plan, so the sync is usually a no-op; it exists for the case where
  /// the plan moved between configuration and now, and for a provider that
  /// starts recording on its own.
  Future<KitResult<void>> attach(SessionReplayRecorder recorder) async {
    if (!_initialized || _disposed) return _notReady<void>();
    _recorder = recorder;
    return _enforce();
  }

  /// Applies a new rollout and re-resolves.
  ///
  /// Recording starts or stops immediately. Masking is carried into the plan
  /// for the next launch, because no provider here can change it mid-session.
  Future<KitResult<void>> applyPolicy(SessionReplayPolicy policy) async {
    if (_disposed) return _notReady<void>();
    _policy = policy;
    if (!_initialized) return const KitSuccess<void>(null);
    _publish(_resolve());
    return _enforce();
  }

  /// Records a developer's manual decision and enforces it immediately.
  Future<KitResult<void>> setOverride(SessionReplayOverride override) async {
    if (!_initialized || _disposed) return _notReady<void>();
    final stored = override == SessionReplayOverride.followRemote
        ? await _store.remove(SessionReplayKeys.override)
        : await _store.setString(
            SessionReplayKeys.override,
            override.storedValue,
          );
    if (stored.isFailure) {
      final error = stored.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
      _logFailure('Session replay override could not be stored.', error);
      _setHealth(ModuleState.degraded, error: error);
      return KitFailure<void>(error);
    }
    _override = override;
    _publish(_resolve());
    return _enforce();
  }

  /// What the provider itself reports, which is not always what the plan says.
  ///
  /// A disagreement is the interesting case: it means a start or stop call
  /// failed, or the provider declined the request for a reason of its own —
  /// replay disabled on the project, for instance, which no amount of local
  /// configuration can override.
  Future<KitResult<bool>> providerIsRecording() async {
    final recorder = _recorder;
    if (recorder == null) {
      return const KitFailure<bool>(
        KitError(
          code: KitErrorCode.notInitialized,
          message: 'No session replay recorder is attached.',
        ),
      );
    }
    return recorder.isRecording();
  }

  /// Draws a fresh bucket, putting this install somewhere else in the rollout.
  ///
  /// For testing a rollout percentage on a real device without editing storage
  /// by hand. Nothing in production calls this: a bucket that moves is not a
  /// rollout.
  Future<KitResult<int>> reshuffleBucket() async {
    if (!_initialized || _disposed) return _notReady<int>();
    final drawn = _random.nextInt(100);
    final stored = await _store.setInt(SessionReplayKeys.bucket, drawn);
    if (stored.isFailure) {
      final error = stored.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
      _logFailure('Session replay bucket could not be stored.', error);
      return KitFailure<int>(error);
    }
    _bucket = drawn;
    _publish(_resolve());
    await _enforce();
    return KitSuccess<int>(drawn);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _initialized = false;
    _disposed = true;
    _recorder = null;
    _setHealth(ModuleState.disposed);
    await _planChanges.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  /// Reads this install's bucket, drawing and storing one the first time.
  ///
  /// Returns whether storage behaved. A device whose storage is unreadable
  /// keeps bucket zero, which is inside every non-empty rollout — the same
  /// answer it would have given before any of this existed, rather than
  /// silently dropping out of the sample.
  Future<bool> _resolveBucket() async {
    final read = await _store.getInt(SessionReplayKeys.bucket);
    final existing = read.fold(onSuccess: (value) => value, onFailure: (_) => null);
    if (read.isFailure) {
      final error = read.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
      _logFailure('Session replay bucket could not be read.', error);
      return false;
    }
    if (existing != null && existing >= 0 && existing < 100) {
      _bucket = existing;
      _bucketResolved = true;
      return true;
    }
    final drawn = _random.nextInt(100);
    final stored = await _store.setInt(SessionReplayKeys.bucket, drawn);
    if (stored.isFailure) {
      final error = stored.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
      _logFailure('Session replay bucket could not be stored.', error);
      // Used for this launch anyway. A device that cannot persist its bucket
      // is re-drawn on every launch, which is worse than a rollout and better
      // than no replay at all.
      _bucket = drawn;
      return false;
    }
    _bucket = drawn;
    _bucketResolved = true;
    return true;
  }

  SessionReplayPlan _resolve() {
    final percent = _policy.boundedPercent;
    final (bool recording, SessionReplayReason reason) = switch (_override) {
      SessionReplayOverride.forceOn => (true, SessionReplayReason.forcedOn),
      SessionReplayOverride.forceOff => (false, SessionReplayReason.forcedOff),
      SessionReplayOverride.followRemote when !_policy.enabled => (
          false,
          SessionReplayReason.disabledRemotely,
        ),
      SessionReplayOverride.followRemote => _bucket < percent
          ? (true, SessionReplayReason.inRollout)
          : (false, SessionReplayReason.outsideRollout),
    };
    return SessionReplayPlan(
      recording: recording,
      maskAllText: _policy.maskAllText,
      maskAllImages: _policy.maskAllImages,
      reason: reason,
      manualOverride: _override,
      bucket: _bucket,
      percentOfUsers: percent,
    );
  }

  void _publish(SessionReplayPlan plan) {
    final changed = _plan.recording != plan.recording ||
        _plan.reason != plan.reason ||
        _plan.maskAllText != plan.maskAllText ||
        _plan.maskAllImages != plan.maskAllImages ||
        _plan.bucket != plan.bucket ||
        _plan.percentOfUsers != plan.percentOfUsers;
    _plan = plan;
    if (changed && !_planChanges.isClosed) _planChanges.add(plan);
  }

  Future<KitResult<void>> _enforce() async {
    final recorder = _recorder;
    if (recorder == null) return const KitSuccess<void>(null);
    final result = _plan.recording
        ? await recorder.startRecording()
        : await recorder.stopRecording();
    result.fold(
      onSuccess: (_) => _logger.log(
        KitLogLevel.debug,
        _plan.recording
            ? 'Session replay recording.'
            : 'Session replay not recording.',
        moduleId: moduleId,
        fields: <String, Object?>{
          'reason': _plan.reason.name,
          'bucket': _plan.bucket,
          'percent': _plan.percentOfUsers,
        },
      ),
      onFailure: (error) => _logFailure(
        'Session replay could not be switched.',
        error,
      ),
    );
    _setHealth(
      result.isSuccess ? ModuleState.ready : ModuleState.degraded,
      error: result.fold(onSuccess: (_) => null, onFailure: (e) => e),
    );
    return result;
  }

  void _logFailure(String message, KitError error) {
    _logger.log(KitLogLevel.warning, message, moduleId: moduleId, error: error);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Session replay has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: _recorder?.providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'recording': _plan.recording,
        'reason': _plan.reason.name,
        'bucket': _bucket,
        'bucketPersisted': _bucketResolved,
        'percentOfUsers': _plan.percentOfUsers,
        'override': _override.name,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
