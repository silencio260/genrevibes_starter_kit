import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'model/rating_criteria.dart';
import 'model/rating_decision.dart';
import 'model/rating_outcome.dart';
import 'rating_keys.dart';
import 'rating_observer.dart';
import 'rating_outcome_router.dart';

/// Runs an action while ads are suppressed.
///
/// Supplied by the application so rating policy never imports an ads package.
/// A prompt shown over an interstitial is a bad experience, but that coupling
/// belongs at the composition root, not inside this module.
typedef RatingSuppressionHook = Future<void> Function(
  Future<void> Function() action,
);

/// Owns rating eligibility, cooldowns, and outcome recording.
///
/// This module decides *whether* to prompt and *what follows* a prompt. It never
/// presents UI and never talks to a store, so the rules are deterministic and
/// fully testable against an injected clock.
final class RatingCoordinator implements StarterModule {
  /// Creates a rating coordinator over [store].
  ///
  /// Wrap [store] in a `MigratingKeyValueStore` seeded with
  /// [RatingKeys.legacyKeys] when adopting this package in an app that already
  /// persisted rating state under its own key names.
  RatingCoordinator({
    required KeyValueStore store,
    this.criteria = const RatingCriteria(),
    this.router = const RatingOutcomeRouter(),
    RatingObserver observer = const NoopRatingObserver(),
    RatingSuppressionHook? suppressionHook,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _observer = observer,
        _suppressionHook = suppressionHook,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'app_rating',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  /// Thresholds deciding when a prompt may be shown.
  final RatingCriteria criteria;

  /// Routes what happens after a prompt closes.
  final RatingOutcomeRouter router;

  final KeyValueStore _store;
  final RatingObserver _observer;
  final RatingSuppressionHook? _suppressionHook;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'app_rating';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Records the install date on first run and counts this app open.
  ///
  /// Call once per launch. The install date is written only when absent, so an
  /// existing user's original date is never overwritten.
  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);

    final existing = await _readInt(RatingKeys.installedAt);
    if (existing.isFailure) return _degrade(existing);
    if (existing.valueOrNull == null) {
      final written = await _store.setInt(
        RatingKeys.installedAt,
        _clock.now().millisecondsSinceEpoch,
      );
      if (written.isFailure) return _degrade(written);
    }

    final opens = await _readInt(RatingKeys.appOpens);
    if (opens.isFailure) return _degrade(opens);
    final incremented = await _store.setInt(
      RatingKeys.appOpens,
      (opens.valueOrNull ?? 0) + 1,
    );
    if (incremented.isFailure) return _degrade(incremented);

    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Increments the counter named [name] and returns its new value.
  ///
  /// Use this for app-specific milestones, such as completed downloads, that an
  /// application wants to prompt on.
  Future<KitResult<int>> recordTrigger(String name) async {
    if (!_initialized || _disposed) return _notReady<int>();
    final key = RatingKeys.trigger(name);
    final current = await _readInt(key);
    if (current.isFailure) return KitFailure<int>(current.errorOrThrow);
    final next = (current.valueOrNull ?? 0) + 1;
    final written = await _store.setInt(key, next);
    if (written.isFailure) return KitFailure<int>(written.errorOrThrow);
    return KitSuccess<int>(next);
  }

  /// Evaluates whether a prompt may be shown right now.
  ///
  /// [force] bypasses the timing and app-open thresholds for an app-chosen
  /// milestone, but never overrides an explicit opt-out. A user who asked not to
  /// be prompted is not asked again.
  Future<KitResult<RatingDecision>> evaluate({bool force = false}) async {
    if (!_initialized || _disposed) return _notReady<RatingDecision>();

    final optedOut = await _store.getBool(RatingKeys.optedOut);
    if (optedOut.isFailure) return _blocked(RatingBlockReason.stateUnavailable);
    if (optedOut.fold(onSuccess: (v) => v, onFailure: (_) => null) ?? false) {
      return _blocked(RatingBlockReason.optedOut);
    }
    if (force) return _allowed();

    final installedAt = await _readInt(RatingKeys.installedAt);
    final appOpens = await _readInt(RatingKeys.appOpens);
    final lastPromptedAt = await _readInt(RatingKeys.lastPromptedAt);
    if (installedAt.isFailure ||
        appOpens.isFailure ||
        lastPromptedAt.isFailure) {
      return _blocked(RatingBlockReason.stateUnavailable);
    }

    final now = _clock.now();
    final installedMs = installedAt.valueOrNull;
    if (installedMs == null ||
        now.difference(_at(installedMs)) < criteria.minimumInstallAge) {
      return _blocked(RatingBlockReason.installTooRecent);
    }
    if ((appOpens.valueOrNull ?? 0) < criteria.minimumAppOpens) {
      return _blocked(RatingBlockReason.notEnoughAppOpens);
    }
    final promptedMs = lastPromptedAt.valueOrNull;
    if (promptedMs != null &&
        now.difference(_at(promptedMs)) <
            criteria.minimumIntervalBetweenPrompts) {
      return _blocked(RatingBlockReason.promptedRecently);
    }
    return _allowed();
  }

  /// Runs [present] with ads suppressed and records that a prompt was shown.
  Future<KitResult<void>> present(Future<void> Function() present) async {
    if (!_initialized || _disposed) return _notReady<void>();
    final hook = _suppressionHook;
    try {
      if (hook == null) {
        await present();
      } else {
        await hook(present);
      }
    } on Object catch (error, stackTrace) {
      return KitFailure<void>(
        KitError(
          code: KitErrorCode.unknown,
          message: 'Rating prompt presentation failed: $error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    _observer.onPrompted();
    return _markPromptedAt(_clock.now());
  }

  /// Records the user's answer and returns the follow-up the app should run.
  Future<KitResult<RatingFollowUp>> recordOutcome(
    RatingOutcome outcome, {
    int? rating,
  }) async {
    if (!_initialized || _disposed) return _notReady<RatingFollowUp>();
    _observer.onOutcome(outcome, rating: rating);

    final KitResult<void> stored = switch (outcome) {
      RatingOutcome.maybeLater => await _snooze(),
      // A user who answered has been asked. Asking again after they rated, or
      // after they declined, is the behavior that earns one-star reviews.
      RatingOutcome.never => await _store.setBool(RatingKeys.optedOut, true),
      RatingOutcome.submitted =>
        await _store.setBool(RatingKeys.optedOut, true),
    };
    if (stored.isFailure) {
      return KitFailure<RatingFollowUp>(stored.errorOrThrow);
    }
    return KitSuccess<RatingFollowUp>(router.route(outcome, rating: rating));
  }

  /// Clears all rating state. Intended for development and QA only.
  Future<KitResult<void>> reset() async {
    if (_disposed) return _notReady<void>();
    for (final key in <String>[
      RatingKeys.optedOut,
      RatingKeys.lastPromptedAt,
      RatingKeys.appOpens,
    ]) {
      final removed = await _store.remove(key);
      if (removed.isFailure) return removed;
    }
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

  /// Defers the next prompt by [RatingCriteria.snooze].
  ///
  /// Implemented by back-dating the last-prompt timestamp so that exactly the
  /// snooze duration remains before the normal interval elapses, rather than by
  /// introducing a second competing timestamp.
  Future<KitResult<void>> _snooze() {
    final remaining = criteria.minimumIntervalBetweenPrompts - criteria.snooze;
    return _markPromptedAt(_clock.now().subtract(remaining));
  }

  Future<KitResult<void>> _markPromptedAt(DateTime moment) {
    return _store.setInt(
      RatingKeys.lastPromptedAt,
      moment.millisecondsSinceEpoch,
    );
  }

  Future<KitResult<int?>> _readInt(String key) => _store.getInt(key);

  DateTime _at(int milliseconds) =>
      DateTime.fromMillisecondsSinceEpoch(milliseconds);

  KitResult<RatingDecision> _allowed() {
    const decision = RatingDecision.allowed();
    _observer.onEvaluated(decision);
    return const KitSuccess<RatingDecision>(decision);
  }

  KitResult<RatingDecision> _blocked(RatingBlockReason reason) {
    final decision = RatingDecision.blocked(reason);
    _observer.onEvaluated(decision);
    return KitSuccess<RatingDecision>(decision);
  }

  KitResult<void> _degrade(KitResult<Object?> failed) {
    final error = failed.errorOrThrow;
    _logger.log(
      KitLogLevel.warning,
      'Rating state could not be persisted.',
      moduleId: moduleId,
      error: error,
    );
    _setHealth(ModuleState.degraded, error: error);
    return KitFailure<void>(error);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Rating coordinator has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}

extension _ResultAccess<T> on KitResult<T> {
  T? get valueOrNull =>
      fold(onSuccess: (value) => value, onFailure: (_) => null);

  KitError get errorOrThrow => fold(
        onSuccess: (_) => throw StateError('Result is a success.'),
        onFailure: (error) => error,
      );
}
