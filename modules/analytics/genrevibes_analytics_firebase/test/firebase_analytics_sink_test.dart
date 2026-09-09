import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_analytics_firebase/genrevibes_analytics_firebase.dart';
import 'package:genrevibes_analytics_test/genrevibes_analytics_test.dart';

void main() {
  runAnalyticsSinkContractTests(
    sinkName: 'Firebase',
    createSink: () async => FirebaseAnalyticsSink(
      client: _FakeFirebaseAnalyticsClient(),
    ),
  );

  test('collects by default without anyone enabling it', () async {
    final client = _FakeFirebaseAnalyticsClient();
    final sink = FirebaseAnalyticsSink(client: client);

    await sink.initialize();
    await sink.setCollectionEnabled(true);

    // Analytics is a core function: nothing about a default construction may
    // turn it off, and initialization must not need a caller to switch it on.
    expect(client.collectionCalls, isNot(contains(false)));
    expect(client.collectionCalls.last, isTrue);
  });

  test('a sink configured not to collect stays off when asked to collect',
      () async {
    final client = _FakeFirebaseAnalyticsClient();
    final sink = FirebaseAnalyticsSink(
      client: client,
      collectionEnabled: false,
    );

    await sink.initialize();
    // The pipeline asserts consent on every launch; configuration outranks it.
    await sink.setCollectionEnabled(true);

    expect(client.collectionCalls, everyElement(isFalse));
    expect(client.collectionCalls.first, isFalse,
        reason: 'must state its position at init, not inherit the disk flag');
  });

  test('normalizes Firebase event parameter values', () {
    final result = sanitizeFirebaseParameters(<String, Object?>{
      'name': 'starter kit',
      'count': 2,
      'enabled': true,
      'at': DateTime.utc(2026, 9, 5),
      'ignored': null,
    });

    expect(result, <String, Object>{
      'name': 'starter kit',
      'count': 2,
      'enabled': 1,
      'at': '2026-09-05T00:00:00.000Z',
    });
  });
}

final class _FakeFirebaseAnalyticsClient implements FirebaseAnalyticsClient {
  @override
  bool get isFirebaseInitialized => true;

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}

  @override
  Future<void> resetAnalyticsData() async {}

  /// Every value the sink pushed, in order.
  final List<bool> collectionCalls = <bool>[];

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionCalls.add(enabled);
  }

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}
