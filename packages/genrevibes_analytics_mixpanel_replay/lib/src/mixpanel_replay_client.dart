import 'package:flutter/widgets.dart';
import 'package:mixpanel_flutter_session_replay/mixpanel_flutter_session_replay.dart';

import 'mixpanel_replay_configuration.dart';

/// Injectable boundary around the Mixpanel session-replay plugin.
abstract interface class MixpanelReplayClient {
  /// Initializes replay storage, sampling, and upload services.
  Future<void> setup(GenRevibesMixpanelReplayConfiguration configuration);

  /// Wraps the application tree with the replay capture widget when ready.
  Widget wrap(Widget child);

  /// Starts a replay recording after applying [sessionsPercent].
  Future<void> start({required double sessionsPercent});

  /// Stops capturing the current replay.
  Future<void> stop();

  /// Updates the distinct ID for future replay events.
  Future<void> identify(String distinctId);

  /// Flushes queued replay events.
  Future<void> flush();
}

/// Production client backed by `mixpanel_flutter_session_replay`.
final class DefaultMixpanelReplayClient implements MixpanelReplayClient {
  MixpanelSessionReplay? _instance;

  MixpanelSessionReplay get _readyInstance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('Mixpanel session replay has not been initialized.');
    }
    return instance;
  }

  @override
  Future<void> setup(
    GenRevibesMixpanelReplayConfiguration configuration,
  ) async {
    final result = await MixpanelSessionReplay.initialize(
      token: configuration.token.trim(),
      distinctId: configuration.distinctId.trim(),
      options: configuration.toSdkOptions(),
    );
    final instance = result.instance;
    if (!result.success || instance == null) {
      throw StateError(
        result.errorMessage ?? 'Mixpanel session replay initialization failed.',
      );
    }
    _instance = instance;
  }

  @override
  Widget wrap(Widget child) {
    return MixpanelSessionReplayWidget(instance: _instance, child: child);
  }

  @override
  Future<void> start({required double sessionsPercent}) async {
    _readyInstance.startRecording(sessionsPercent: sessionsPercent);
  }

  @override
  Future<void> stop() async => _readyInstance.stopRecording();

  @override
  Future<void> identify(String distinctId) async {
    _readyInstance.identify(distinctId);
  }

  @override
  Future<void> flush() async {
    await _readyInstance.flush();
  }
}
