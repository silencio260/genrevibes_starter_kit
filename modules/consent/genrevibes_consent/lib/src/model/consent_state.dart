import 'consent_snapshot.dart';

/// Privacy consent state, normalized across consent management platforms.
enum ConsentState {
  /// Consent has not been determined yet, typically before the first request.
  unknown,

  /// The user is in a regulated region and has not answered the form.
  consentRequired,

  /// The user answered the form and their choices have been recorded.
  obtained,

  /// No consent is required, typically because the user is outside a
  /// regulated region.
  notRequired,
}

/// Questions this state can actually answer.
///
/// Deliberately only one. [ConsentState] describes where the user is in the
/// consent *flow*, not what they agreed to, and the difference matters:
/// [ConsentState.obtained] means the form was answered, not that anything was
/// permitted. A user who opened the form and rejected every purpose is
/// `obtained` exactly like a user who accepted all of them.
///
/// An earlier version of this enum carried an `allowsPersonalizedWork` getter
/// that returned true for `obtained`, which quietly claimed consent from every
/// user who had refused it. Whether ads may be requested is a question only the
/// consent platform can answer — see [ConsentSnapshot.canRequestAds] — and
/// whether they are *personalized* is decided by the ad network from the
/// consent string, never by the application.
extension ConsentStatePermission on ConsentState {
  /// Whether a consent form should be presented to the user.
  bool get requiresForm => this == ConsentState.consentRequired;
}
