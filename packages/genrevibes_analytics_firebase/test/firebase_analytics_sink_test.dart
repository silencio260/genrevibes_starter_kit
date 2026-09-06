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

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}
