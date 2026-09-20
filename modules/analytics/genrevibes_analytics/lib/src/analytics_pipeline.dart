import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';

import 'analytics_delivery_observer.dart';
import 'analytics_event_names.dart';
import 'analytics_sink.dart';
import 'model/analytics_delivery_report.dart';
import 'model/analytics_event.dart';
import 'model/analytics_user.dart';

/// Analytics dispatcher with per-sink failure isolation.
///
/// There is no consent gate here, by portfolio decision: product analytics is
/// a condition of using these apps and is disclosed in their privacy policies.
/// The only supported way to hold a provider back is the developer's own
/// remote kill switch on a paid sink (`SwitchableAnalyticsSink`); Firebase
/// cannot be turned off at all. Consent forms in this portfolio belong to ad
/// networks and talk to the ad SDKs, not to this pipeline.
final class AnalyticsPipeline implements StarterModule {
  /// Creates an analytics pipeline.
  AnalyticsPipeline({
    required Iterable<AnalyticsSink> sinks,
    AnalyticsEventNames names = const CanonicalAnalyticsEventNames(),
    AnalyticsDeliveryObserver? observer,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _sinks = List<AnalyticsSink>.unmodifiable(sinks),
        _observer = observer,
        _names = names,
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'analytics',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final List<AnalyticsSink> _sinks;
  final AnalyticsEventNames _names;

  /// Watches deliveries. Null in production; a diagnostics build supplies one.
  final AnalyticsDeliveryObserver? _observer;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  final Set<String> _activeSinkIds = <String>{};
  late ModuleHealth _health;
  bool _initialized = false;
  bool _disposed = false;

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
    if (_sinks.isEmpty) {
      _initialized = true;
      _setHealth(ModuleState.disabled);
      return const KitSuccess<void>(null);
    }
    return _initializeSinks();
  }

  /// Sends [event] to every configured sink concurrently.
  ///
  /// The event name is passed through [AnalyticsEventNames] first, so a
  /// remote or per-app rename applies to every sink and every kit emitter.
  Future<KitResult<AnalyticsDeliveryReport>> track(AnalyticsEvent event) {
    final outgoing = _resolveName(event);
    return _dispatch(outgoing.name, (sink) => sink.track(outgoing))
        .then((result) {
      result.fold(
        onSuccess: (report) => _notifyEvent(outgoing, report),
        onFailure: (error) => _notifyEvent(
            outgoing,
            AnalyticsDeliveryReport(
              operation: outgoing.name,
              attemptedSinks: const <String>{},
              successfulSinks: const <String>{},
              failures: {'pipeline': error},
            )),
      );
      return result;
    });
  }

  void _notifyEvent(AnalyticsEvent event, AnalyticsDeliveryReport report) {
    final observer = _observer;
    if (observer == null) return;
    // An observer is a development aid and must never affect delivery.
    try {
      observer.onEventDelivered(event, report);
    } on Object {
      // Intentionally ignored.
    }
  }

  AnalyticsEvent _resolveName(AnalyticsEvent event) {
    final resolved = _names.resolve(event.name);
    if (resolved == event.name || resolved.trim().isEmpty) return event;
    return AnalyticsEvent(
      name: resolved,
      properties: event.properties,
      occurredAt: event.occurredAt,
    );
  }

  /// Identifies [user] in every configured sink.
  Future<KitResult<AnalyticsDeliveryReport>> identify(AnalyticsUser user) {
    return _dispatch('identify', (sink) => sink.identify(user));
  }

  /// Updates user properties in every configured sink.
  Future<KitResult<AnalyticsDeliveryReport>> setUserProperties(
    Map<String, Object?> properties,
  ) {
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
    if (_disposed) return _notReady<void>();
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

    // Turn collection on in every sink that just came up.
    //
    // Provider-side collection flags are durable. Firebase writes
    // `setAnalyticsCollectionEnabled` to its own preferences
    // (`measurement_enabled_from_api`) and honours it on every later launch,
    // logging `Event not sent since app measurement is disabled` and dropping
    // everything, so an install an older build left disabled stays dark with
    // every sink reporting healthy unless startup asserts its position. A
    // paid sink switched off by the developer's remote kill switch ignores
    // this and stays off.
    await _dispatch(
      'set_collection_enabled',
      (sink) => sink.setCollectionEnabled(true),
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
    _disposed = true;
    _initialized = false;
    _activeSinkIds.clear();
    KitError? firstError;
    await Future.wait(_sinks.map((sink) async {
      try {
        final result = await sink.dispose().timeout(const Duration(seconds: 5));
        result.fold(
            onSuccess: (_) {}, onFailure: (error) => firstError ??= error);
      } on Object catch (error, stack) {
        firstError ??= KitError(
            code: KitErrorCode.provider,
            message: 'Analytics sink cleanup failed.',
            cause: error,
            stackTrace: stack);
      }
    }));
    _setHealth(ModuleState.disposed, error: firstError);
    await _healthChanges.close();
    return firstError == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(firstError!);
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    if (_disposed && state != ModuleState.disposed) return;
    _health = ModuleHealth(
      moduleId: moduleId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{'sink_count': _sinks.length},
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
