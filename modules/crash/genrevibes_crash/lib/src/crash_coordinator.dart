import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'crash_observer.dart';
import 'crash_reporter.dart';
import 'model/crash_report.dart';
import 'model/crash_reporting_config.dart';

/// Owns crash reporting policy and fans reports out to the reporter.
///
/// The coordinator is what an application's error handlers call. It applies the
/// collection decision once, forwards to the provider, notifies observers, and
/// keeps health so a broken reporter is visible in diagnostics rather than
/// silently dropping reports.
final class CrashCoordinator implements StarterModule {
  /// Creates a coordinator over [reporter].
  CrashCoordinator({
    required CrashReporter reporter,
    required CrashReportingConfig config,
    CrashObserver observer = const NoopCrashObserver(),
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _reporter = reporter,
        _config = config,
        _observer = observer,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'crash',
          provider: reporter.providerId,
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final CrashReporter _reporter;
  final CrashReportingConfig _config;
  final CrashObserver _observer;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get moduleId => 'crash';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  /// Whether reports are being sent.
  bool get collectionEnabled => _config.collectionEnabled;

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    _setHealth(ModuleState.initializing);
    final started = await _reporter.initialize();
    if (started.isFailure) return _fail(started);
    final gated = await _reporter.setCollectionEnabled(
      _config.collectionEnabled,
    );
    if (gated.isFailure) return _fail(gated);
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  /// Records [report] and notifies observers.
  ///
  /// Safe to call from an error handler: it never throws, and a reporter
  /// failure degrades health instead of propagating.
  Future<KitResult<void>> report(CrashReport report) async {
    if (!_initialized || _disposed) return _notReady<void>();
    final result = await _reporter.record(report);
    result.fold(
      onSuccess: (_) {
        if (_health.state == ModuleState.degraded) {
          _setHealth(ModuleState.ready);
        }
      },
      onFailure: (error) => _degrade(error),
    );
    try {
      _observer.onReported(report);
    } on Object catch (error, stackTrace) {
      _logger.log(
        KitLogLevel.warning,
        'Crash observer threw.',
        moduleId: moduleId,
        error: error,
        stackTrace: stackTrace,
      );
    }
    return result;
  }

  /// Associates subsequent reports with [identifier].
  Future<KitResult<void>> identify(String identifier) async {
    if (!_initialized || _disposed) return _notReady<void>();
    return _reporter.setUserIdentifier(identifier);
  }

  /// Attaches a key/value to every subsequent report.
  Future<KitResult<void>> setCustomKey(String key, Object value) async {
    if (!_initialized || _disposed) return _notReady<void>();
    return _reporter.setCustomKey(key, value);
  }

  /// Adds a breadcrumb.
  Future<KitResult<void>> log(String message) async {
    if (!_initialized || _disposed) return _notReady<void>();
    return _reporter.log(message);
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    final result = await _reporter.dispose();
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return result;
  }

  KitResult<void> _fail(KitResult<void> failed) {
    final error = failed.fold(onSuccess: (_) => null, onFailure: (e) => e)!;
    _logger.log(
      KitLogLevel.error,
      'Crash reporter failed to start.',
      moduleId: moduleId,
      error: error,
    );
    _setHealth(ModuleState.failed, error: error);
    return KitFailure<void>(error);
  }

  void _degrade(KitError error) {
    _logger.log(
      KitLogLevel.warning,
      'Crash report was not recorded.',
      moduleId: moduleId,
      error: error,
    );
    _setHealth(ModuleState.degraded, error: error);
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Crash coordinator has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: _reporter.providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'collectionEnabled': _config.collectionEnabled,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
