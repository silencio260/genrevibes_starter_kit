import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_storage/genrevibes_storage.dart';

import 'onboarding_keys.dart';

/// Tracks whether a user has completed onboarding.
///
/// Deliberately small. Onboarding content, wording, imagery, and navigation are
/// application concerns; only the completion flag is portfolio-reusable, and
/// getting its persistence wrong is what shows onboarding twice.
final class OnboardingController implements StarterModule {
  /// Creates a controller over [store].
  ///
  /// Wrap [store] in a `MigratingKeyValueStore` seeded with
  /// [OnboardingKeys.legacyKeys] when adopting this package in an app that
  /// already recorded completion under its own key name.
  OnboardingController({
    required KeyValueStore store,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _store = store,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'onboarding',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final KeyValueStore _store;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _completed = false;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'onboarding';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Whether onboarding has been completed, as of the last read.
  bool get isCompleted => _completed;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);

    final stored = await _store.getBool(OnboardingKeys.completed);
    if (stored.isFailure) {
      final error = stored.fold(
        onSuccess: (_) => null,
        onFailure: (value) => value,
      );
      // Unreadable state means "not yet onboarded". Showing onboarding twice
      // is a far better failure than skipping it for a genuinely new user.
      _completed = false;
      _initialized = true;
      _logger.log(
        KitLogLevel.warning,
        'Onboarding state could not be read. Treating the user as new.',
        moduleId: moduleId,
        error: error,
      );
      _setHealth(ModuleState.degraded, error: error);
      return const KitSuccess<void>(null);
    }

    _completed =
        stored.fold(onSuccess: (v) => v, onFailure: (_) => null) ?? false;
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Marks onboarding complete.
  Future<KitResult<void>> complete() async {
    if (!_initialized || _disposed) return _notReady<void>();
    final written = await _store.setBool(OnboardingKeys.completed, true);
    if (written.isSuccess) _completed = true;
    return written;
  }

  /// Clears completion so onboarding runs again. Intended for QA.
  Future<KitResult<void>> reset() async {
    if (!_initialized || _disposed) return _notReady<void>();
    final removed = await _store.remove(OnboardingKeys.completed);
    if (removed.isSuccess) _completed = false;
    return removed;
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Onboarding controller has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{'completed': _completed},
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
