import 'package:genrevibes_analytics/genrevibes_analytics.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Injectable boundary around PostHog's manual replay controls.
abstract interface class PostHogSessionReplayClient {
  /// Starts recording the current session.
  Future<void> start();

  /// Stops recording.
  Future<void> stop();

  /// Whether the SDK reports replay as active.
  Future<bool> isActive();
}

/// Production client backed by the PostHog singleton.
final class DefaultPostHogSessionReplayClient
    implements PostHogSessionReplayClient {
  /// Creates a production replay client.
  DefaultPostHogSessionReplayClient({Posthog? posthog})
      : _posthog = posthog ?? Posthog();

  final Posthog _posthog;

  @override
  Future<bool> isActive() => _posthog.isSessionReplayActive();

  /// Resumes the current session rather than starting a new one.
  ///
  /// A new session would split one user's visit into two recordings at the
  /// moment the rollout changed, which is the moment the recording is least
  /// useful to cut in half.
  @override
  Future<void> start() => _posthog.startSessionRecording();

  @override
  Future<void> stop() => _posthog.stopSessionRecording();
}

/// PostHog implementation of the runtime session-replay contract.
///
/// The SDK's own `sessionReplay` config flag only decides whether recording is
/// running when the app starts. These calls move it afterwards, which is what
/// lets a rollout percentage change, or a developer's switch, land without a
/// relaunch.
///
/// Masking is not here, and cannot be: PostHog builds its mask parsers when the
/// SDK is configured. `GenRevibesPostHogConfiguration.withSessionReplay` is
/// where that half of the plan is applied, before setup.
final class PostHogSessionReplayRecorder implements SessionReplayRecorder {
  /// Creates a recorder.
  PostHogSessionReplayRecorder({
    PostHogSessionReplayClient? client,
    KitLogger logger = const NoopKitLogger(),
  })  : _client = client ?? DefaultPostHogSessionReplayClient(),
        _logger = logger;

  final PostHogSessionReplayClient _client;
  final KitLogger _logger;

  @override
  String get providerId => 'posthog';

  @override
  Future<KitResult<void>> startRecording() => _guard(_client.start, 'start');

  @override
  Future<KitResult<void>> stopRecording() => _guard(_client.stop, 'stop');

  @override
  Future<KitResult<bool>> isRecording() async {
    try {
      return KitSuccess<bool>(await _client.isActive());
    } on Object catch (error, stackTrace) {
      return KitFailure<bool>(_error('read', error, stackTrace));
    }
  }

  Future<KitResult<void>> _guard(
    Future<void> Function() operation,
    String action,
  ) async {
    try {
      await operation();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      final mapped = _error(action, error, stackTrace);
      _logger.log(
        KitLogLevel.warning,
        'PostHog session replay could not $action.',
        moduleId: 'analytics.session_replay.posthog',
        error: mapped,
        stackTrace: stackTrace,
      );
      return KitFailure<void>(mapped);
    }
  }

  KitError _error(String action, Object error, StackTrace stackTrace) {
    return KitError(
      code: KitErrorCode.provider,
      message: 'PostHog session replay $action failed: $error',
      cause: error,
      stackTrace: stackTrace,
    );
  }
}
