/// A request to sign in or to link a method to the current account.
///
/// Federated requests carry tokens rather than performing the vendor sign-in
/// flow themselves. Acquiring a Google or Apple token is a separate concern
/// with its own plugin, platform setup and release cadence, so an app that
/// only uses email and password never compiles a social sign-in SDK.
sealed class AuthCredentialRequest {
  const AuthCredentialRequest();

  /// Identifier of the method this request represents.
  String get method;
}

/// Creates or resumes a guest account.
final class AnonymousAuthRequest extends AuthCredentialRequest {
  /// Creates an anonymous request.
  const AnonymousAuthRequest();

  @override
  String get method => 'anonymous';
}

/// Signs in with tokens obtained from Google Sign-In.
final class GoogleAuthRequest extends AuthCredentialRequest {
  /// Creates a Google request.
  const GoogleAuthRequest({this.idToken, this.accessToken});

  /// OpenID Connect identity token.
  final String? idToken;

  /// OAuth access token.
  final String? accessToken;

  /// Whether at least one token was supplied.
  bool get hasToken =>
      (idToken?.isNotEmpty ?? false) || (accessToken?.isNotEmpty ?? false);

  @override
  String get method => 'google.com';
}

/// Signs in with tokens obtained from Sign in with Apple.
final class AppleAuthRequest extends AuthCredentialRequest {
  /// Creates an Apple request.
  const AppleAuthRequest({
    required this.identityToken,
    this.authorizationCode,
    this.rawNonce,
  });

  /// Apple identity token.
  final String identityToken;

  /// Single-use authorization code.
  final String? authorizationCode;

  /// Unhashed nonce matching the hashed value sent to Apple.
  ///
  /// Required whenever the request was nonced, which it should be: without it
  /// the identity token cannot be bound to this sign-in attempt.
  final String? rawNonce;

  @override
  String get method => 'apple.com';
}

/// Signs in with an email address and password.
final class EmailPasswordAuthRequest extends AuthCredentialRequest {
  /// Creates an email and password request.
  const EmailPasswordAuthRequest({
    required this.email,
    required this.password,
    this.createIfMissing = false,
  });

  /// Email address.
  final String email;

  /// Password.
  final String password;

  /// Whether to register the account when no user exists.
  ///
  /// Registration and sign-in are deliberately one call with a flag, because
  /// the provider is the only party that can tell the two apart without a
  /// race.
  final bool createIfMissing;

  @override
  String get method => 'password';
}
