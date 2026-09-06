import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:genrevibes_auth/genrevibes_auth.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

/// Converts a Firebase user into the neutral [AuthUser].
AuthUser? mapFirebaseUser(fb.User? user) {
  if (user == null) return null;
  return AuthUser(
    id: user.uid,
    isAnonymous: user.isAnonymous,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
    isEmailVerified: user.emailVerified,
    providerIds: user.providerData.map((info) => info.providerId).toSet(),
  );
}

/// Builds the Firebase credential for a federated [request].
///
/// Returns `null` for requests that are not credential-based, and throws
/// [ArgumentError] when a federated request carries no usable token, which is
/// a programming error rather than a provider failure.
fb.AuthCredential? mapCredential(AuthCredentialRequest request) {
  switch (request) {
    case AnonymousAuthRequest():
    case EmailPasswordAuthRequest():
      return null;
    case GoogleAuthRequest(:final idToken, :final accessToken):
      if (!request.hasToken) {
        throw ArgumentError.value(
          request,
          'request',
          'GoogleAuthRequest requires an idToken or accessToken.',
        );
      }
      return fb.GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
    case AppleAuthRequest(:final identityToken, :final rawNonce):
      return fb.OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: rawNonce,
      );
  }
}

/// Maps a Firebase error code to a neutral [AuthFailureReason].
AuthFailureReason mapAuthErrorCode(String code) => switch (code) {
      'invalid-credential' ||
      'invalid-email' ||
      'wrong-password' ||
      'invalid-verification-code' =>
        AuthFailureReason.invalidCredential,
      'user-not-found' => AuthFailureReason.userNotFound,
      'email-already-in-use' ||
      'account-exists-with-different-credential' =>
        AuthFailureReason.emailAlreadyInUse,
      'weak-password' => AuthFailureReason.weakPassword,
      'user-disabled' => AuthFailureReason.userDisabled,
      'requires-recent-login' => AuthFailureReason.requiresRecentLogin,
      'provider-already-linked' ||
      'credential-already-in-use' =>
        AuthFailureReason.credentialAlreadyLinked,
      'network-request-failed' => AuthFailureReason.network,
      'operation-not-allowed' => AuthFailureReason.unsupported,
      'web-context-cancelled' || 'cancelled' => AuthFailureReason.cancelled,
      _ => AuthFailureReason.unknown,
    };

/// The `KitErrorCode` a [reason] maps to.
KitErrorCode mapErrorCode(AuthFailureReason reason) => switch (reason) {
      AuthFailureReason.network => KitErrorCode.network,
      AuthFailureReason.cancelled => KitErrorCode.cancelled,
      AuthFailureReason.unsupported => KitErrorCode.unsupported,
      AuthFailureReason.invalidCredential ||
      AuthFailureReason.userNotFound ||
      AuthFailureReason.emailAlreadyInUse ||
      AuthFailureReason.weakPassword ||
      AuthFailureReason.userDisabled ||
      AuthFailureReason.requiresRecentLogin ||
      AuthFailureReason.credentialAlreadyLinked =>
        KitErrorCode.provider,
      AuthFailureReason.unknown => KitErrorCode.unknown,
    };
