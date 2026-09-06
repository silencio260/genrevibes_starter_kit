import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_analytics_posthog/genrevibes_analytics_posthog.dart';
import 'package:genrevibes_analytics_test/genrevibes_analytics_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

void main() {
  runAnalyticsSinkContractTests(
    sinkName: 'PostHog',
    createSink: () async => PostHogAnalyticsSink(
      configuration: const GenreVibesPostHogConfiguration(apiKey: 'test-key'),
      client: _FakePostHogClient(),
    ),
  );

  test('session replay remains privacy masked by default', () {
    final config = const GenreVibesPostHogConfiguration(
      apiKey: 'test-key',
      sessionReplayEnabled: true,
    ).toSdkConfiguration();

    expect(config.sessionReplay, isTrue);
    expect(config.sessionReplayConfig.maskAllTexts, isTrue);
    expect(config.sessionReplayConfig.maskAllImages, isTrue);
  });
}

final class _FakePostHogClient implements PostHogAnalyticsClient {
  @override
  Future<void> capture(String name, Map<String, Object>? properties) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> disable() async {}

  @override
  Future<void> enable() async {}

  @override
  Future<void> flush() async {}

  @override
  Future<void> identify(String userId, Map<String, Object>? properties) async {}

  @override
  Future<void> reset() async {}

  @override
  Future<void> setup(PostHogConfig configuration) async {}
}
