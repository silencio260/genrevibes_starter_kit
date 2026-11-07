import 'package:flutter/foundation.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'tutorial_progress.dart';
import 'tutorial_progress_store.dart';

/// State for one named tutorial. Not a StarterModule: the owning runtime or
/// screen calls initialize and disposes this ChangeNotifier when finished.
/// Controllers for different IDs can share one TutorialProgressStore.
final class TutorialController extends ChangeNotifier {
  TutorialController(
      {required this.tutorialId,
      required List<String> stepIds,
      required TutorialProgressStore store})
      : stepIds = List.unmodifiable(stepIds),
        _store = store {
    if (tutorialId.trim().isEmpty ||
        stepIds.isEmpty ||
        stepIds.any((id) => id.trim().isEmpty) ||
        stepIds.toSet().length != stepIds.length) {
      throw ArgumentError(
          'Tutorial and step IDs must be nonempty; step IDs must be unique.');
    }
    _progress = TutorialProgress(stepId: stepIds.first);
  }

  final String tutorialId;
  final List<String> stepIds;
  final TutorialProgressStore _store;
  late TutorialProgress _progress;
  bool _initialized = false;
  bool _busy = false;
  bool _disposed = false;
  bool _paused = false;
  int _activationEpoch = 0;
  final _active = ValueNotifier<bool>(false);
  KitError? _lastError;

  /// Observe this for app-owned ad/rating/prompt suppression, including pauses.
  ValueListenable<bool> get active => _active;
  bool get isActive => _active.value;
  bool get isPaused => _paused;
  bool get isInitialized => _initialized;
  bool get isBusy => _busy;
  bool get isCompleted => _progress.isCompleted;
  TutorialOutcome get outcome => _progress.outcome;
  String get currentStepId => _progress.stepId;
  int get currentIndex => stepIds.indexOf(currentStepId);
  bool get isFirstStep => currentIndex == 0;
  bool get isLastStep => currentIndex == stepIds.length - 1;
  KitError? get lastError => _lastError;

  /// Read without displaying anything. A failed read can be retried; it never
  /// silently treats unreadable completion as a confirmed new user.
  Future<KitResult<void>> initialize() => _run(() async {
        if (_initialized) return const KitSuccess(null);
        final result = await _store.read(tutorialId);
        if (result case KitFailure(:final error)) return KitFailure(error);
        if (_disposed) return _unavailable();
        final saved =
            result.fold(onSuccess: (value) => value, onFailure: (_) => null);
        if (saved != null) {
          // Removing a step restarts an unfinished tutorial at its first step;
          // completed/skipped tutorials never restart just because IDs changed.
          _progress = TutorialProgress(
            stepId:
                stepIds.contains(saved.stepId) ? saved.stepId : stepIds.first,
            outcome: saved.outcome,
          );
        }
        _initialized = true;
        return const KitSuccess(null);
      }, requiresInitialization: false);

  /// Resume unfinished state. Completed tutorials remain inactive; call replay
  /// explicitly when the user asks to see one again.
  Future<KitResult<void>> start() => _run(() async {
        if (isCompleted) return const KitSuccess(null);
        final epoch = _activationEpoch;
        final result = await _store.write(tutorialId, _progress);
        if (result.isSuccess && !_disposed && epoch == _activationEpoch) {
          _paused = false;
          _active.value = true;
        }
        return result;
      });

  Future<KitResult<void>> goTo(String stepId) => _run(() async {
        if (!isActive) return _unavailable();
        if (!stepIds.contains(stepId)) {
          return KitFailure(KitError(
              code: KitErrorCode.invalidConfiguration,
              message: 'Unknown tutorial step: $stepId'));
        }
        return _save(TutorialProgress(stepId: stepId));
      });

  Future<KitResult<void>> next() => _run(() async {
        if (!isActive) return _unavailable();
        return _save(isLastStep
            ? TutorialProgress(
                stepId: currentStepId, outcome: TutorialOutcome.completed)
            : TutorialProgress(stepId: stepIds[currentIndex + 1]));
      });

  Future<KitResult<void>> previous() => _run(() async {
        if (!isActive) return _unavailable();
        if (isFirstStep) return const KitSuccess(null);
        return _save(TutorialProgress(stepId: stepIds[currentIndex - 1]));
      });

  /// Guards route-return and other asynchronous events against a stale step.
  /// A mismatched event is a no-op and cannot advance a different instruction.
  Future<KitResult<void>> advanceFrom(String expectedStepId) {
    if (_busy || !isActive || currentStepId != expectedStepId) {
      return Future.value(const KitSuccess(null));
    }
    return next();
  }

  Future<KitResult<void>> complete() => _run(() => _save(TutorialProgress(
      stepId: currentStepId, outcome: TutorialOutcome.completed)));

  /// Skip counts as completed, while preserving a distinct outcome for hosts.
  Future<KitResult<void>> skip() => _run(() => _save(TutorialProgress(
      stepId: currentStepId, outcome: TutorialOutcome.skipped)));

  /// Writes an unfinished first step instead of deleting a key. This prevents
  /// a reset tutorial from re-adopting a legacy completion flag.
  Future<KitResult<void>> reset() => _run(() async {
        final result = await _save(TutorialProgress(stepId: stepIds.first));
        if (result.isSuccess && !_disposed) {
          _initialized = true;
          _paused = false;
          _active.value = false;
        }
        return result;
      }, requiresInitialization: false);

  Future<KitResult<void>> replay() => _run(() async {
        final epoch = _activationEpoch;
        final result = await _save(TutorialProgress(stepId: stepIds.first));
        if (result.isSuccess && !_disposed && epoch == _activationEpoch) {
          _initialized = true;
          _paused = false;
          _active.value = true;
        }
        return result;
      }, requiresInitialization: false);

  /// Pause hides UI without completing it or releasing active-session policy.
  void pause() {
    if (!_disposed && !_paused) {
      _paused = true;
      notifyListeners();
    }
  }

  void resume() {
    if (!_disposed && _paused) {
      _paused = false;
      notifyListeners();
    }
  }

  /// Leave without completion; the saved step can be resumed with start().
  void stop() {
    if (!_disposed) {
      _activationEpoch++;
      _active.value = false;
      notifyListeners();
    }
  }

  Future<KitResult<void>> _save(TutorialProgress next) async {
    final result = await _store.write(tutorialId, next);
    if (result.isSuccess && !_disposed) {
      _progress = next;
      if (next.isCompleted) _active.value = false;
    }
    return result;
  }

  /// Single-flight persistence. Repeated taps cannot queue several advances.
  Future<KitResult<void>> _run(Future<KitResult<void>> Function() action,
      {bool requiresInitialization = true}) async {
    if (_disposed || _busy) return _unavailable();
    if (requiresInitialization && !_initialized) {
      return const KitFailure(KitError(
          code: KitErrorCode.notInitialized,
          message: 'Initialize the tutorial first.'));
    }
    _busy = true;
    _lastError = null;
    notifyListeners();
    KitResult<void> result;
    try {
      result = await action();
    } catch (error, stack) {
      result = KitFailure(KitError(
          code: KitErrorCode.provider,
          message: 'Tutorial operation failed.',
          cause: error,
          stackTrace: stack));
    }
    if (!_disposed) {
      _lastError =
          result.fold(onSuccess: (_) => null, onFailure: (error) => error);
      _busy = false;
      notifyListeners();
    }
    return result;
  }

  KitFailure<void> _unavailable() => const KitFailure(KitError(
      code: KitErrorCode.unavailable,
      message: 'Tutorial is busy, inactive or disposed.'));

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active.dispose();
    super.dispose();
  }
}
