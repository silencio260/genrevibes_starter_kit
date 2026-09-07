import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_analytics_mixpanel/genrevibes_analytics_mixpanel.dart';
import 'package:genrevibes_analytics_test/genrevibes_analytics_test.dart';

void main() {
  runAnalyticsSinkContractTests(
    sinkName: 'Mixpanel',
    createSink: () async => MixpanelAnalyticsSink(
      configuration: const GenRevibesMixpanelConfiguration(token: 'test-token'),
      client: _FakeMixpanelClient(),
    ),
  );

  test('rejects an invalid flush batch size before SDK setup', () async {
    final client = _FakeMixpanelClient();
    final sink = MixpanelAnalyticsSink(
      configuration: const GenRevibesMixpanelConfiguration(
        token: 'test-token',
        flushBatchSize: 51,
      ),
      client: client,
    );

    final result = await sink.initialize();

    expect(result.isFailure, isTrue);
    expect(client.setupCalls, 0);
  });
}

final class _FakeMixpanelClient implements MixpanelAnalyticsClient {
  int setupCalls = 0;

  @override
  Future<void> flush() async {}

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> setCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setPeopleProperties(Map<String, Object> properties) async {}

  @override
  Future<void> setup(GenRevibesMixpanelConfiguration configuration) async {
    setupCalls += 1;
  }

  @override
  Future<void> track(String name, Map<String, Object>? properties) async {}
}
