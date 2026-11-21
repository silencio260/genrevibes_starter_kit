import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_analytics_firebase/genrevibes_analytics_firebase.dart';
import 'package:genrevibes_analytics_test/genrevibes_analytics_test.dart';

void main() {
  runAnalyticsSinkContractTests(
    sinkName: 'Firebase',
    createSink: () async => FirebaseAnalyticsSink(
      client: _FakeFirebaseAnalyticsClient(),
      isGoogleTestDevice: () async => false,
    ),
  );

  test('collects by default without anyone enabling it', () async {
    final client = _FakeFirebaseAnalyticsClient();
    final sink = FirebaseAnalyticsSink(
        client: client, isGoogleTestDevice: () async => false);

    await sink.initialize();
    await sink.setCollectionEnabled(true);

    // Analytics is a core function: nothing about a default construction may
    // turn it off, and initialization must not need a caller to switch it on.
    expect(client.collectionCalls, isNot(contains(false)));
    expect(client.collectionCalls.last, isTrue);
  });

  test('cannot be turned off', () async {
    final client = _FakeFirebaseAnalyticsClient();
    final sink = FirebaseAnalyticsSink(
        client: client, isGoogleTestDevice: () async => false);

    await sink.initialize();
    // Consent changes, remote switches and hosts all reach the sink through
    // this method. Firebase collection is not theirs to disable.
    await sink.setCollectionEnabled(false);

    expect(client.collectionCalls, everyElement(isTrue));
    expect(client.collectionCalls.first, isTrue,
        reason: 'init must repair an install an older build left disabled');
  });

  test('stays silent and off on a Google test device', () async {
    final client = _FakeFirebaseAnalyticsClient();
    final sink = FirebaseAnalyticsSink(
      client: client,
      isGoogleTestDevice: () async => true,
    );

    await sink.initialize();
    await sink.setCollectionEnabled(true);
    await sink.track(const AnalyticsEvent(name: 'sign_up'));
    await sink.identify(const AnalyticsUser(id: 'robot'));

    expect(sink.onGoogleTestDevice, isTrue);
    expect(client.collectionCalls, everyElement(isFalse));
    expect(client.events, isEmpty);
    expect(client.userIds, isEmpty);
  });

  test('a failing test-device check counts as a real phone', () async {
    final client = _FakeFirebaseAnalyticsClient();
    final sink = FirebaseAnalyticsSink(
      client: client,
      isGoogleTestDevice: () async => throw StateError('no channel'),
    );

    await sink.initialize();

    expect(sink.onGoogleTestDevice, isFalse);
    expect(client.collectionCalls, <bool>[true]);
  });

  test("skips Appodeal's ad_impression by default, keeps AdMob's", () async {
    final client = _FakeFirebaseAnalyticsClient();
    final sink = FirebaseAnalyticsSink(
      client: client,
      isGoogleTestDevice: () async => false,
    );
    await sink.initialize();

    await sink.track(const AnalyticsEvent(
      name: 'ad_impression',
      properties: {'ad_platform': 'appodeal', 'value': 0.01},
    ));
    await sink.track(const AnalyticsEvent(
      name: 'ad_impression',
      properties: {'ad_platform': 'admob', 'value': 0.02},
    ));
    await sink.track(const AnalyticsEvent(
      name: 'custom_ad_click',
      properties: {'ad_platform': 'appodeal'},
    ));

    expect(client.events, ['ad_impression', 'custom_ad_click']);
  });

  test('normalizes Firebase event parameter values', () {
    final result = sanitizeFirebaseParameters(<String, Object?>{
      'name': 'starter kit',
      'count': 2,
      'enabled': true,
      'disabled': false,
      'at': DateTime.utc(2026, 9, 5),
      'ignored': null,
    });

    expect(result, <String, Object>{
      'name': 'starter kit',
      'count': 2,
      'enabled': 'true',
      'disabled': 'false',
      'at': '2026-09-05T00:00:00.000Z',
    });
  });
}

final class _FakeFirebaseAnalyticsClient implements FirebaseAnalyticsClient {
  @override
  bool get isFirebaseInitialized => true;

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    events.add(name);
  }

  final List<String> events = <String>[];
  final List<String?> userIds = <String?>[];

  @override
  Future<void> resetAnalyticsData() async {}

  /// Every value the sink pushed, in order.
  final List<bool> collectionCalls = <bool>[];

  @override
  Future<void> enableCollection() async {
    collectionCalls.add(true);
  }

  @override
  Future<void> disableCollectionOnTestDevice() async {
    collectionCalls.add(false);
  }

  @override
  Future<void> setUserId(String? userId) async {
    userIds.add(userId);
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}
