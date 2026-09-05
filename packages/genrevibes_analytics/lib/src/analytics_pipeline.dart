import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'analytics_sink.dart';
import 'model/analytics_consent.dart';
import 'model/analytics_delivery_report.dart';
import 'model/analytics_event.dart';
import 'model/analytics_user.dart';

/// Consent-aware analytics dispatcher with per-sink failure isolation.
final class AnalyticsPipeline implements StarterModule {
  /// Creates an analytics pipeline.
  AnalyticsPipeline({
    required Iterable<AnalyticsSink> sinks,
    AnalyticsConsent initialConsent = AnalyticsConsent.unknown,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _sinks = List<AnalyticsSink>.unmodifiable(sinks),
        _consent = initialConsent,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final List<AnalyticsSink> _sinks;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final Set<String> _activeSinkIds = <String>{};
  late ModuleHealth _health;
  AnalyticsConsent _consent;
  bool _initialized = false;
  bool _disposed = false;

  /// Current application-level consent state.
  AnalyticsConsent get consent => _consent;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  String get moduleId => 'analytics';

  /// Configured analytics sinks.
  List<AnalyticsSink> get sinks => _sinks;

  @override
  Future<KitResult<void>> initialize() async {
    if (_initialized) return const KitSuccess<void>(null);
    if (_disposed) {
      return const KitFailure<void>(
        KitError(
          code: KitErrorCode.notInitialized,
          message: 'Analytics pipeline has already been disposed.',
        ),
      );
    }
    if (_sinks.isEmpty || _consent != AnalyticsConsent.granted) {
      _initialized = true;
      _setHealth(ModuleState.disabled);
      return const KitSuccess<void>(null);
    }
    return _initializeSinks();
  }

  /// Updates consent and enables or disables all configured sinks.
  Future<KitResult<AnalyticsDeliveryReport>> setConsent(
    AnalyticsConsent consent,
  ) async {
    if (_disposed) return _notReady<AnalyticsDeliveryReport>();
    _consent = consent;
    if (consent == AnalyticsConsent.granted) {
      if (!_initialized || _health.state == ModuleState.disabled) {
        final initialized = await _initializeSinks();
        if (initialized.isFailure) {
          return initialized.map(
            (_) => const AnalyticsDeliveryReport(
              operation: 'consent.granted',
              attemptedSinks: <String>{},
              successfulSinks: <String>{},
              failures: <String, KitError>{},
            ),
          );
        }
      }
      return _dispatch('consent.granted', (sink) {
        return sink.setCollectionEnabled(true);
      });
    }

    if (!_initialized || _health.state == ModuleState.disabled) {
      _initialized = true;
      _setHealth(ModuleState.disabled);
      return KitSuccess<AnalyticsDeliveryReport>(
        _suppressedReport('consent.${consent.name}'),
      );
    }
    final report = await _dispatch('consent.${consent.name}', (sink) async {
      final disabled = await sink.setCollectionEnabled(false);
      if (disabled.isFailure) return disabled;
      return sink.resetIdentity();
    });
    _setHealth(ModuleState.disabled);
    return report;
  }

  /// Sends [event] to every configured sink concurrently.
  Future<KitResult<AnalyticsDeliveryReport>> track(AnalyticsEvent event) {
    if (_consent != AnalyticsConsent.granted) {
      return Future<KitResult<AnalyticsDeliveryReport>>.value(
        KitSuccess<AnalyticsDeliveryReport>(_suppressedReport(event.name)),
      );
    }
    return _dispatch(event.name, (sink) => sink.track(event));
  }

  /// Identifies [user] in every configured sink.
  Future<KitResult<AnalyticsDeliveryReport>> identify(AnalyticsUser user) {
    if (_consent != AnalyticsConsent.granted) {
      return Future<KitResult<AnalyticsDeliveryReport>>.value(
        KitSuccess<AnalyticsDeliveryReport>(_suppressedReport('identify')),
      );
    }
    return _dispatch('identify', (sink) => sink.identify(user));
  }

  /// Updates user properties in every configured sink.
  Future<KitResult<AnalyticsDeliveryReport>> setUserProperties(
    Map<String, Object?> properties,
  ) {
    if (_consent != AnalyticsConsent.granted) {
      return Future<KitResult<AnalyticsDeliveryReport>>.value(
        KitSuccess<AnalyticsDeliveryReport>(
          _suppressedReport('set_user_properties'),
        ),
      );
    }
    return _dispatch(
      'set_user_properties',
      (sink) => sink.setUserProperties(properties),
    );
  }

  /// Flushes buffered events in every active sink.
  Future<KitResult<AnalyticsDeliveryReport>> flush() {
    return _dispatch('flush', (sink) => sink.flush());
  }

  Future<KitResult<void>> _initializeSinks() async {
    _setHealth(ModuleState.initializing);
    final report = await _dispatch(
      'initialize',
      (sink) => sink.initialize(),
      requireInitialized: false,
    );
    final delivery = report.fold(
      onSuccess: (value) => value,
      onFailure: (_) => null,
    );
    _initialized = true;
    if (delivery == null || !delivery.wasDelivered) {
      final error = const KitError(
        code: KitErrorCode.provider,
        message: 'No analytics sink initialized successfully.',
      );
      _setHealth(ModuleState.failed, error: error);
      return KitFailure<void>(error);
    }
    _activeSinkIds
      ..clear()
      ..addAll(delivery.successfulSinks);
    _setHealth(
      delivery.isCompleteSuccess ? ModuleState.ready : ModuleState.degraded,
    );
    return const KitSuccess<void>(null);
  }

  Future<KitResult<AnalyticsDeliveryReport>> _dispatch(
    String operation,
    Future<KitResult<void>> Function(AnalyticsSink sink) action, {
    bool requireInitialized = true,
  }) async {
    if (requireInitialized &&
        (!_initialized || !_health.isOperational || _disposed)) {
      return _notReady<AnalyticsDeliveryReport>();
    }

    final targets = requireInitialized
        ? _sinks.where((sink) => _activeSinkIds.contains(sink.sinkId)).toList()
        : _sinks;
    final attempted = targets.map((sink) => sink.sinkId).toSet();
    final outcomes = await Future.wait(
      targets.map((sink) async {
        try {
          return (sink: sink, result: await action(sink));
        } on Object catch (error, stackTrace) {
          return (
            sink: sink,
            result: KitFailure<void>(
              KitError(
                code: KitErrorCode.unknown,
                message: 'Analytics sink ${sink.sinkId} threw: $error',
                cause: error,
                stackTrace: stackTrace,
              ),
            ),
          );
        }
      }),
    );
    final successes = <String>{};
    final failures = <String, KitError>{};
    for (final outcome in outcomes) {
      outcome.result.fold(
        onSuccess: (_) {
          successes.add(outcome.sink.sinkId);
        },
        onFailure: (error) {
          failures[outcome.sink.sinkId] = error;
          _logger.log(
            KitLogLevel.warning,
            'Analytics sink failed during $operation.',
            moduleId: outcome.sink.sinkId,
            error: error,
          );
        },
      );
    }
    if (requireInitialized && failures.isNotEmpty) {
      _setHealth(ModuleState.degraded, error: failures.values.first);
    }
    return KitSuccess<AnalyticsDeliveryReport>(
      AnalyticsDeliveryReport(
        operation: operation,
        attemptedSinks: attempted,
        successfulSinks: successes,
        failures: failures,
      ),
    );
  }

  AnalyticsDeliveryReport _suppressedReport(String operation) {
    return AnalyticsDeliveryReport(
      operation: operation,
      attemptedSinks: const <String>{},
      successfulSinks: const <String>{},
      failures: const <String, KitError>{},
      suppressedByConsent: true,
    );
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Analytics pipeline is not operational.',
      ),
    );
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    await Future.wait(_sinks.map((sink) => sink.dispose()));
    _activeSinkIds.clear();
    _disposed = true;
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'sink_count': _sinks.length,
        'consent': _consent.name,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
