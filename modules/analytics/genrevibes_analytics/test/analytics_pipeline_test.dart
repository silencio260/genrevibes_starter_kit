import 'dart:async';

import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

void main() {
  test('an app that opts into consent gating is silenced until it grants',
      () async {
    // Opt-in: only a pipeline constructed with an ungranted consent waits.
    final sink = _FakeAnalyticsSink('firebase');
    final pipeline = AnalyticsPipeline(
      sinks: <AnalyticsSink>[sink],
      initialConsent: AnalyticsConsent.unknown,
    );

    expect((await pipeline.initialize()).isSuccess, isTrue);
    final report = _value(
      await pipeline.track(const AnalyticsEvent(name: 'app_open')),
    );

    expect(sink.initializeCount, 0);
    expect(sink.events, isEmpty);
    expect(report.suppressedByConsent, isTrue);
    await pipeline.dispose();
  });

  test('delivers without anyone granting consent first', () async {
    // The default. Forgetting to call setConsent used to mean no analytics at
    // all, silently, which is a worse default than the one it protected.
    final sink = _FakeAnalyticsSink('firebase');
    final pipeline = AnalyticsPipeline(sinks: <AnalyticsSink>[sink]);

    expect((await pipeline.initialize()).isSuccess, isTrue);
    final report = _value(
      await pipeline.track(const AnalyticsEvent(name: 'app_open')),
    );

    expect(sink.events.single.name, 'app_open');
    expect(report.suppressedByConsent, isFalse);
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
    final pipeline = AnalyticsPipeline(
      sinks: <AnalyticsSink>[sink],
      initialConsent: AnalyticsConsent.unknown,
    );
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

  test('initialization turns provider collection back on when granted',
      () async {
    // Regression: a provider that persists its collection flag across launches
    // — Firebase writes `measurement_enabled_from_api` to its own preferences —
    // used to keep a stale `false` forever, because collection was only ever
    // set on a consent transition and a pipeline that starts granted makes no
    // transition. Every sink reported healthy while Firebase dropped the lot.
    final sink = _FakeAnalyticsSink('firebase')..collectionEnabled = false;
    final pipeline = AnalyticsPipeline(
      sinks: <AnalyticsSink>[sink],
      initialConsent: AnalyticsConsent.granted,
    );

    await pipeline.initialize();

    expect(sink.collectionEnabled, isTrue);
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

  group('delivery observer', () {
    test('reports each delivered event with its per-sink outcome', () async {
      final good = _FakeAnalyticsSink('good');
      final bad = _FakeAnalyticsSink('bad', failTracking: true);
      final observer = _RecordingObserver();
      final pipeline = AnalyticsPipeline(
        sinks: <AnalyticsSink>[good, bad],
        observer: observer,
      );
      await pipeline.initialize();
      await pipeline.setConsent(AnalyticsConsent.granted);

      await pipeline.track(const AnalyticsEvent(name: 'checkout'));

      expect(observer.events, hasLength(1));
      final (event, report) = observer.events.single;
      expect(event.name, 'checkout');
      // The point of the observer: which sink took it, and which did not.
      expect(report.successfulSinks, contains('good'));
      expect(report.failures.keys, contains('bad'));
    });

    test('reports an event suppressed by consent rather than staying silent',
        () async {
      final observer = _RecordingObserver();
      final pipeline = AnalyticsPipeline(
        sinks: <AnalyticsSink>[_FakeAnalyticsSink('sink')],
        initialConsent: AnalyticsConsent.unknown,
        observer: observer,
      );
      await pipeline.initialize();

      // Consent never granted, so nothing reaches a sink. A diagnostics screen
      // still has to be able to say why.
      await pipeline.track(const AnalyticsEvent(name: 'blocked'));

      expect(observer.events, hasLength(1));
      expect(observer.events.single.$2.suppressedByConsent, isTrue);
      expect(observer.events.single.$2.successfulSinks, isEmpty);
    });

    test('an observer that throws cannot break delivery', () async {
      final sink = _FakeAnalyticsSink('sink');
      final pipeline = AnalyticsPipeline(
        sinks: <AnalyticsSink>[sink],
        observer: _ThrowingObserver(),
      );
      await pipeline.initialize();
      await pipeline.setConsent(AnalyticsConsent.granted);

      final result = await pipeline.track(const AnalyticsEvent(name: 'safe'));

      expect(result.isSuccess, isTrue);
      expect(sink.events, hasLength(1));
    });
  });
}

final class _RecordingObserver implements AnalyticsDeliveryObserver {
  final List<(AnalyticsEvent, AnalyticsDeliveryReport)> events =
      <(AnalyticsEvent, AnalyticsDeliveryReport)>[];

  @override
  void onEventDelivered(AnalyticsEvent event, AnalyticsDeliveryReport report) {
    events.add((event, report));
  }

  @override
  void onOperationDelivered(AnalyticsDeliveryReport report) {}
}

final class _ThrowingObserver implements AnalyticsDeliveryObserver {
  @override
  void onEventDelivered(AnalyticsEvent event, AnalyticsDeliveryReport report) {
    throw StateError('observer is broken');
  }

  @override
  void onOperationDelivered(AnalyticsDeliveryReport report) {
    throw StateError('observer is broken');
  }
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
