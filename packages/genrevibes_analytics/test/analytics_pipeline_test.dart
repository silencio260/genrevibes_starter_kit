import 'dart:async';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

void main() {
  test('does not initialize or track sinks before consent', () async {
    final sink = _FakeAnalyticsSink('firebase');
    final pipeline = AnalyticsPipeline(sinks: <AnalyticsSink>[sink]);

    expect((await pipeline.initialize()).isSuccess, isTrue);
    final report = _value(
      await pipeline.track(const AnalyticsEvent(name: 'app_open')),
    );

    expect(sink.initializeCount, 0);
    expect(sink.events, isEmpty);
    expect(report.suppressedByConsent, isTrue);
    await pipeline.dispose();
  });

  test('isolates a failed sink while delivering to healthy sinks', () async {
    final firebase = _FakeAnalyticsSink('firebase');
    final posthog = _FakeAnalyticsSink('posthog', failTracking: true);
    final pipeline = AnalyticsPipeline(
      sinks: <AnalyticsSink>[firebase, posthog],
      initialConsent: AnalyticsConsent.granted,
    );

    expect((await pipeline.initialize()).isSuccess, isTrue);
    final report = _value(
      await pipeline.track(const AnalyticsEvent(name: 'purchase')),
    );

    expect(report.successfulSinks, <String>{'firebase'});
    expect(report.failures.keys, <String>{'posthog'});
    expect(firebase.events.single.name, 'purchase');
    expect(pipeline.health.state, ModuleState.degraded);
    await pipeline.dispose();
  });

  test('granted consent starts sinks after a disabled initialization',
      () async {
    final sink = _FakeAnalyticsSink('firebase');
    final pipeline = AnalyticsPipeline(sinks: <AnalyticsSink>[sink]);
    await pipeline.initialize();

    final report = _value(
      await pipeline.setConsent(AnalyticsConsent.granted),
    );

    expect(sink.initializeCount, 1);
    expect(sink.collectionEnabled, isTrue);
    expect(report.wasDelivered, isTrue);
    expect(pipeline.health.state, ModuleState.ready);
    await pipeline.dispose();
  });

  test('event names are resolved before reaching any sink', () async {
    final sink = _FakeAnalyticsSink('firebase');
    final pipeline = AnalyticsPipeline(
      sinks: <AnalyticsSink>[sink],
      initialConsent: AnalyticsConsent.granted,
      names: MappedAnalyticsEventNames(<String, String>{
        'rating_submitted': 'custom_rating_submitted',
      }),
    );
    await pipeline.initialize();

    await pipeline.track(const AnalyticsEvent(name: 'rating_submitted'));
    await pipeline.track(const AnalyticsEvent(name: 'app_open'));

    expect(
      sink.events.map((e) => e.name),
      <String>['custom_rating_submitted', 'app_open'],
    );
  });

  test('a blank override keeps the canonical name', () {
    final names = MappedAnalyticsEventNames(<String, String>{'x': '  '});

    expect(names.resolve('x'), 'x');
    expect(const CanonicalAnalyticsEventNames().resolve('x'), 'x');
  });
}

T _value<T>(KitResult<T> result) {
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw StateError(error.message),
  );
}

final class _FakeAnalyticsSink implements AnalyticsSink {
  _FakeAnalyticsSink(this.sinkId, {this.failTracking = false})
      : _health = ModuleHealth(
          moduleId: 'analytics.$sinkId',
          provider: sinkId,
          state: ModuleState.idle,
          observedAt: DateTime.utc(2026),
        );

  @override
  final String sinkId;
  final bool failTracking;
  final List<AnalyticsEvent> events = <AnalyticsEvent>[];
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  int initializeCount = 0;
  bool collectionEnabled = false;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  String get moduleId => 'analytics.$sinkId';

  @override
  Future<KitResult<void>> initialize() async {
    initializeCount += 1;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> track(AnalyticsEvent event) async {
    if (failTracking) {
      return const KitFailure<void>(
        KitError(code: KitErrorCode.provider, message: 'sink failed'),
      );
    }
    events.add(event);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> identify(AnalyticsUser user) async {
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> setUserProperties(
    Map<String, Object?> properties,
  ) async {
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> resetIdentity() async {
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> flush() async {
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<void>> dispose() async {
    _setHealth(ModuleState.disposed);
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _setHealth(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: sinkId,
      state: state,
      observedAt: DateTime.utc(2026),
    );
    _healthChanges.add(_health);
  }
}
