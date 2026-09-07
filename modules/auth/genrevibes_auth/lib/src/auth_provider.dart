import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/auth_capabilities.dart';
import 'model/auth_credential_request.dart';
import 'model/auth_user.dart';

/// Contract implemented by authentication adapters.
abstract interface class AuthProvider implements StarterModule {
  /// Stable provider identifier, such as `firebase`.
  String get providerId;

  /// Behaviors this adapter supports.
  AuthCapabilities get capabilities;

  /// The signed-in user, or `null`.
  AuthUser? get currentUser;

  /// Emits on every sign-in, sign-out and token refresh.
  ///
  /// Emits the current value on subscription so a late listener is never left
  /// waiting for a state change that already happened.
  Stream<AuthUser?> get userChanges;

  /// Signs in with [request].
  Future<KitResult<AuthUser>> signIn(AuthCredentialRequest request);

  /// Links [request] to the signed-in account.
  ///
  /// This is how a guest becomes a permanent user without losing their data.
  /// Signing in with a second method instead of linking creates a separate
  /// account and orphans everything the guest created.
  Future<KitResult<AuthUser>> linkCredential(AuthCredentialRequest request);

  /// Sends a password reset email.
  Future<KitResult<void>> sendPasswordReset(String email);

  /// Signs out.
  Future<KitResult<void>> signOut();

  /// Permanently deletes the signed-in account.
  ///
  /// May fail with [AuthFailureReason.requiresRecentLogin]; re-authenticate
  /// and retry rather than treating it as terminal.
  Future<KitResult<void>> deleteAccount();
}
