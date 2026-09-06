import 'consent_state.dart';

/// Immutable view of consent at a point in time.
final class ConsentSnapshot {
  /// Creates a consent snapshot.
  const ConsentSnapshot({
    required this.state,
    required this.observedAt,
    this.formAvailable = false,
    this.privacyOptionsRequired = false,
  });

  /// Normalized consent state.
  final ConsentState state;

  /// When the platform reported this state.
  final DateTime observedAt;

  /// Whether a consent form is currently available to present.
  final bool formAvailable;

  /// Whether the app must expose a persistent privacy-options entry point.
  ///
  /// Regulated regions generally require the user to be able to reopen their
  /// choices later, normally from a settings screen.
  final bool privacyOptionsRequired;

  /// Whether ads and analytics may initialize.
  bool get allowsPersonalizedWork => state.allowsPersonalizedWork;

  @override
  String toString() {
    return 'ConsentSnapshot(state: ${state.name}, '
        'formAvailable: $formAvailable, '
        'privacyOptionsRequired: $privacyOptionsRequired)';
  }
}
