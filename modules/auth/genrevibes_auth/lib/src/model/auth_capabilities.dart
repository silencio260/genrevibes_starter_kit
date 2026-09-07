/// Optional behaviors an authentication adapter implements.
final class AuthCapabilities {
  /// Creates capabilities.
  const AuthCapabilities({
    required this.anonymous,
    required this.emailPassword,
    required this.federated,
    required this.linking,
    required this.passwordReset,
    required this.accountDeletion,
  });

  /// Guest accounts.
  final bool anonymous;

  /// Email and password accounts.
  final bool emailPassword;

  /// Google and Apple credentials.
  final bool federated;

  /// Linking a method to an existing account.
  final bool linking;

  /// Sending a password reset email.
  final bool passwordReset;

  /// Deleting the signed-in account.
  final bool accountDeletion;
}
