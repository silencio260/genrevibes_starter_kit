/// Why an authentication attempt did not succeed.
///
/// Normalized so application code can react without matching vendor error
/// strings, which differ between providers and change without notice.
enum AuthFailureReason {
  /// The credential was rejected.
  invalidCredential,

  /// No account exists for the supplied identifier.
  userNotFound,

  /// An account already exists with that email under another method.
  emailAlreadyInUse,

  /// The password does not meet the provider's policy.
  weakPassword,

  /// The account has been disabled.
  userDisabled,

  /// The operation needs a fresh sign-in before it is allowed.
  ///
  /// Account deletion typically returns this after a long session; re-run the
  /// sign-in flow and retry.
  requiresRecentLogin,

  /// The method is already linked to this or another account.
  credentialAlreadyLinked,

  /// The user dismissed the flow.
  cancelled,

  /// The network was unavailable.
  network,

  /// The provider does not support this request.
  unsupported,

  /// Unclassified provider failure.
  unknown,
}

/// Metadata key carrying [AuthFailureReason] on a `KitError`.
const authFailureReasonKey = 'authFailureReason';
