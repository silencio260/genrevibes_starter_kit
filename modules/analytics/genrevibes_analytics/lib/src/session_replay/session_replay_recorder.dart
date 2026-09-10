import 'package:genrevibes_core/genrevibes_core.dart';

/// Provider-neutral runtime control over session replay capture.
///
/// Separate from the analytics sink contract on purpose: replay is not an event, most
/// analytics providers do not offer it, and the one that does here can start
/// and stop it independently of whether events are flowing. An application
/// that has no replay provider attaches nothing and the controller still
/// resolves a plan, which is what the diagnostics surface reads.
///
/// Implementations must never throw across this boundary.
abstract interface class SessionReplayRecorder {
  /// The provider behind this recorder, for diagnostics.
  String get providerId;

  /// Begins capture on the current session.
  Future<KitResult<void>> startRecording();

  /// Stops capture. Anything already queued is still uploaded.
  Future<KitResult<void>> stopRecording();

  /// Whether the provider reports capture as active.
  Future<KitResult<bool>> isRecording();
}
