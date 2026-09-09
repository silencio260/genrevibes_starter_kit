import 'consent_state.dart';

/// Immutable view of consent at a point in time.
final class ConsentSnapshot {
  /// Creates a consent snapshot.
  const ConsentSnapshot({
    required this.state,
    required this.observedAt,
    this.formAvailable = false,
    this.privacyOptionsRequired = false,
    this.canRequestAds = false,
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

  /// Whether the consent platform permits requesting ads at all.
  ///
  /// This is the platform's own answer, not something inferred from [state]:
  /// UMP reports it directly, and it is false until consent has been resolved.
  /// It says nothing about *personalization* — the ad network decides that from
  /// the consent string, and an application that branches on personalization
  /// itself is reimplementing the network's job and will get it wrong.
  ///
  /// Nothing but ad loading should consult this. Analytics is a first-party
  /// function of the application and is not gated on it.
  final bool canRequestAds;

  @override
  String toString() {
    return 'ConsentSnapshot(state: ${state.name}, '
        'formAvailable: $formAvailable, '
        'privacyOptionsRequired: $privacyOptionsRequired, '
        'canRequestAds: $canRequestAds)';
  }
}
