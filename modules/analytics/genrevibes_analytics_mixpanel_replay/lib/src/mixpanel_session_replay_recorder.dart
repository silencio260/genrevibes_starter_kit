import 'package:flutter/widgets.dart';
import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'mixpanel_replay_controller.dart';

/// Mixpanel implementation of the runtime session-replay contract.
///
/// Attach it to a `SessionReplayController` so the shared rollout decides
/// which installs record: `session_replay_enabled`, `session_replay_percent`
/// and developer overrides then start and stop Mixpanel replay without a
/// release, exactly as they do for PostHog.
///
/// The controller has already chosen this install when it calls
/// [startRecording], so this starts at 100% rather than letting Mixpanel
/// sample a second time. For the same reason the replay configuration must
/// leave `sessionsPercent` at 0 (use
/// `GenRevibesMixpanelReplayConfiguration.withSessionReplay`): a non-zero value
/// makes the SDK start recording on every foreground on its own, outside the
/// rollout.
///
/// Mixpanel ends its recording whenever the app goes to the background and
/// only restarts on its own at the configured percentage. With that at 0,
/// this recorder restarts recording on resume while the rollout still wants
/// it, so one install keeps recording across app switches.
///
/// Masking is fixed when the SDK is set up; it is not controlled here.
final class MixpanelSessionReplayRecorder implements SessionReplayRecorder {
  /// Creates a recorder over an initialized or initializing [controller].
  MixpanelSessionReplayRecorder({
    required MixpanelReplayController controller,
    KitLogger logger = const NoopKitLogger(),
  })  : _controller = controller,
        _logger = logger {
    if (controller.configuration.sessionsPercent > 0) {
      _logger.log(
        KitLogLevel.warning,
        'Mixpanel replay sessionsPercent is above 0; the SDK will also start '
        'recording on its own, outside the shared rollout.',
        moduleId: _moduleId,
        fields: <String, Object?>{
          'sessionsPercent': controller.configuration.sessionsPercent,
        },
      );
    }
  }

  static const _moduleId = 'analytics.session_replay.mixpanel';

  final MixpanelReplayController _controller;
  final KitLogger _logger;
  AppLifecycleListener? _lifecycle;
  bool _wanted = false;

  @override
  String get providerId => 'mixpanel';

  @override
  Future<KitResult<void>> startRecording() {
    _wanted = true;
    _lifecycle ??= AppLifecycleListener(onResume: _resume);
    return _start();
  }

  @override
  Future<KitResult<void>> stopRecording() {
    _wanted = false;
    return _log(_controller.stop(), 'stop');
  }

  @override
  Future<KitResult<bool>> isRecording() =>
      Future<KitResult<bool>>.value(_controller.isRecording());

  /// Stops listening for app resumes. Call when the replay runtime is torn
  /// down; the controller's own `dispose` stops the SDK.
  void dispose() {
    _wanted = false;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  void _resume() {
    if (_wanted) _start();
  }

  Future<KitResult<void>> _start() =>
      _log(_controller.start(sessionsPercent: 100), 'start');

  Future<KitResult<void>> _log(
    Future<KitResult<void>> operation,
    String action,
  ) async {
    final result = await operation;
    result.fold(
      onSuccess: (_) {},
      onFailure: (error) => _logger.log(
        KitLogLevel.warning,
        'Mixpanel session replay could not $action.',
        moduleId: _moduleId,
        error: error,
      ),
    );
    return result;
  }
}
