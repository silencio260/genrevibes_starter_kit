import 'dart:convert';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'tutorial_progress.dart';

/// Storage boundary for tutorials. Implementations return failures, not throws.
abstract interface class TutorialProgressStore {
  Future<KitResult<TutorialProgress?>> read(String tutorialId);
  Future<KitResult<void>> write(String tutorialId, TutorialProgress progress);
}

/// Provider-neutral JSON snapshots over the kit's normal key/value store.
/// Give each tutorial a stable ID. Each gets its own key under [namespace].
final class KeyValueTutorialProgressStore implements TutorialProgressStore {
  KeyValueTutorialProgressStore({
    required KeyValueStore store,
    this.namespace = 'genrevibes.tutorial',
    this.legacyKeys = const {},
  }) : _store = store;

  final KeyValueStore _store;
  final String namespace;

  /// Explicit app-owned migrations, indexed by tutorial ID. Old keys are kept
  /// for rollback; once present, the new snapshot always takes precedence.
  final Map<String, TutorialLegacyKeys> legacyKeys;

  String storageKey(String tutorialId) => '$namespace.$tutorialId.progress.v1';

  @override
  Future<KitResult<TutorialProgress?>> read(String tutorialId) async {
    try {
      final saved = await _store.getString(storageKey(tutorialId));
      if (saved case KitFailure(:final error)) return KitFailure(error);
      final json =
          saved.fold(onSuccess: (value) => value, onFailure: (_) => null);
      if (json != null) {
        return KitSuccess(TutorialProgress.fromJson(
            jsonDecode(json) as Map<String, dynamic>));
      }
      final legacy = legacyKeys[tutorialId];
      if (legacy == null) return const KitSuccess(null);
      final done = await _store.getBool(legacy.completedKey);
      if (done case KitFailure(:final error)) return KitFailure(error);
      final completed =
          done.fold(onSuccess: (value) => value, onFailure: (_) => null);
      String? step;
      if (legacy.stepKey != null) {
        final savedStep = await _store.getString(legacy.stepKey!);
        if (savedStep case KitFailure(:final error)) return KitFailure(error);
        step =
            savedStep.fold(onSuccess: (value) => value, onFailure: (_) => null);
      }
      if (completed == null && step == null) return const KitSuccess(null);
      final progress = TutorialProgress(
        stepId: step ?? legacy.firstStepId,
        outcome: completed == true
            ? TutorialOutcome.completed
            : TutorialOutcome.inProgress,
      );
      final migrated = await write(tutorialId, progress);
      if (migrated case KitFailure(:final error)) return KitFailure(error);
      return KitSuccess(progress);
    } catch (error, stack) {
      return KitFailure(KitError(
          code: KitErrorCode.provider,
          message: 'Tutorial progress could not be read.',
          cause: error,
          stackTrace: stack));
    }
  }

  @override
  Future<KitResult<void>> write(
      String tutorialId, TutorialProgress progress) async {
    try {
      return await _store.setString(
          storageKey(tutorialId), jsonEncode(progress.toJson()));
    } catch (error, stack) {
      return KitFailure(KitError(
          code: KitErrorCode.provider,
          message: 'Tutorial progress could not be saved.',
          cause: error,
          stackTrace: stack));
    }
  }
}

/// An app supplies the actual historical keys; the kit knows no app names.
final class TutorialLegacyKeys {
  const TutorialLegacyKeys(
      {required this.completedKey, required this.firstStepId, this.stepKey});
  final String completedKey;
  final String? stepKey;
  final String firstStepId;
}

/// Isolated, non-persistent state for previews and examples.
final class MemoryTutorialProgressStore implements TutorialProgressStore {
  final Map<String, TutorialProgress> _values = {};

  @override
  Future<KitResult<TutorialProgress?>> read(String tutorialId) async =>
      KitSuccess(_values[tutorialId]);

  @override
  Future<KitResult<void>> write(
      String tutorialId, TutorialProgress progress) async {
    _values[tutorialId] = progress;
    return const KitSuccess(null);
  }
}
