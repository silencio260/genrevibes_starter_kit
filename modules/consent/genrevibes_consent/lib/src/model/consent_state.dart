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

/// Whether personalization-gated work may proceed in this state.
extension ConsentStatePermission on ConsentState {
  /// Whether ads and analytics may initialize.
  ///
  /// [ConsentState.notRequired] permits work. Treating it as a denial is a
  /// common and costly bug: it silently disables monetization and measurement
  /// for every user outside a regulated region, which is usually most of them.
  bool get allowsPersonalizedWork {
    return this == ConsentState.obtained || this == ConsentState.notRequired;
  }

  /// Whether a consent form should be presented to the user.
  bool get requiresForm => this == ConsentState.consentRequired;
}
