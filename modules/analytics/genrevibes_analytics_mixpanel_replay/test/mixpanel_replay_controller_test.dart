import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_analytics_mixpanel_replay/genrevibes_analytics_mixpanel_replay.dart';

void main() {
  test('defaults to privacy masking and zero-percent recording', () {
    const configuration = GenRevibesMixpanelReplayConfiguration(
      token: 'token',
      distinctId: 'anonymous-id',
    );

    expect(configuration.maskAllText, isTrue);
    expect(configuration.maskAllImages, isTrue);
    expect(configuration.sessionsPercent, 0);
  });

  test('initializes idempotently and supports privacy stop', () async {
    final client = _FakeReplayClient();
    final controller = MixpanelReplayController(
      configuration: const GenRevibesMixpanelReplayConfiguration(
        token: 'token',
        distinctId: 'anonymous-id',
        sessionsPercent: 25,
      ),
      client: client,
    );

    expect((await controller.initialize()).isSuccess, isTrue);
    expect((await controller.initialize()).isSuccess, isTrue);
    expect((await controller.start()).isSuccess, isTrue);
    expect((await controller.stop()).isSuccess, isTrue);

    expect(client.setupCalls, 1);
    expect(client.startedPercent, 25);
    expect(client.stopCalls, 1);
  });
}

final class _FakeReplayClient implements MixpanelReplayClient {
  int setupCalls = 0;
  int stopCalls = 0;
  double? startedPercent;

  @override
  Future<void> flush() async {}

  @override
  Future<void> identify(String distinctId) async {}

  @override
  Future<void> setup(
    GenRevibesMixpanelReplayConfiguration configuration,
  ) async {
    setupCalls += 1;
  }

  @override
  Future<void> start({required double sessionsPercent}) async {
    startedPercent = sessionsPercent;
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
  }

  @override
  Widget wrap(Widget child) => child;
}
