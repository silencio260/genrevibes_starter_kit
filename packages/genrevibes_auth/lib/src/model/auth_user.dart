/// A signed-in identity, normalized across authentication providers.
final class AuthUser {
  /// Creates a user.
  AuthUser({
    required this.id,
    required this.isAnonymous,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    Set<String> providerIds = const <String>{},
  }) : providerIds = Set<String>.unmodifiable(providerIds);

  /// Stable provider-assigned identifier.
  final String id;

  /// Whether this is a guest identity that can still be upgraded.
  ///
  /// An anonymous user is a real, persistent account. Signing them out
  /// discards it permanently, so offer linking rather than sign-out.
  final bool isAnonymous;

  /// Email address, when the sign-in method supplies one.
  ///
  /// Absent for anonymous users and for Apple sign-ins where the user chose to
  /// hide their address.
  final String? email;

  /// Display name, when supplied.
  final String? displayName;

  /// Avatar URL, when supplied.
  final String? photoUrl;

  /// Whether the provider considers the email verified.
  final bool isEmailVerified;

  /// Identifiers of the methods linked to this account, such as `google.com`.
  final Set<String> providerIds;

  /// Whether [method] is already linked.
  bool hasProvider(String method) => providerIds.contains(method);

  @override
  String toString() => 'AuthUser(id: $id, anonymous: $isAnonymous)';
}
