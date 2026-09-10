import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_analytics_posthog/genrevibes_analytics_posthog.dart';
import 'package:genrevibes_analytics_test/genrevibes_analytics_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

void main() {
  runAnalyticsSinkContractTests(
    sinkName: 'PostHog',
    createSink: () async => PostHogAnalyticsSink(
      configuration: const GenRevibesPostHogConfiguration(apiKey: 'test-key'),
      client: _FakePostHogClient(),
    ),
  );

  test('session replay records unmasked unless an application asks', () {
    // A masked replay is grey boxes moving around; it cannot show where a user
    // got stuck, which is the whole reason replay is paid for. Masking is
    // turned on for a reason, remotely, rather than being the resting state.
    final config = const GenRevibesPostHogConfiguration(
      apiKey: 'test-key',
      sessionReplayEnabled: true,
    ).toSdkConfiguration();

    expect(config.sessionReplay, isTrue);
    expect(config.sessionReplayConfig.maskAllTexts, isFalse);
    expect(config.sessionReplayConfig.maskAllImages, isFalse);
  });

  test('a plan carries masking through to the SDK configuration', () {
    final masked = const GenRevibesPostHogConfiguration(apiKey: 'test-key')
        .withSessionReplay(
          const SessionReplayPlan(
            recording: true,
            maskAllText: true,
            maskAllImages: true,
            reason: SessionReplayReason.inRollout,
            manualOverride: SessionReplayOverride.followRemote,
            bucket: 3,
            percentOfUsers: 100,
          ),
        )
        .toSdkConfiguration();

    expect(masked.sessionReplay, isTrue);
    expect(masked.sessionReplayConfig.maskAllTexts, isTrue);
    expect(masked.sessionReplayConfig.maskAllImages, isTrue);
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
