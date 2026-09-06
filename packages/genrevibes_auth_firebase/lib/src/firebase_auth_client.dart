import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:genrevibes_auth/genrevibes_auth.dart';

import 'firebase_auth_mapping.dart';

/// Injectable boundary around the Firebase Authentication SDK.
///
/// Returns neutral [AuthUser] values rather than `User`, so the provider and
/// its tests never handle a Firebase type.
abstract interface class FirebaseAuthClient {
  /// The signed-in user, or `null`.
  AuthUser? get currentUser;

  /// Emits on sign-in, sign-out and token refresh.
  Stream<AuthUser?> get userChanges;

  /// Creates or resumes a guest account.
  Future<AuthUser> signInAnonymously();

  /// Signs in with a federated credential.
  Future<AuthUser> signInWithCredential(fb.AuthCredential credential);

  /// Signs in with an email address and password.
  Future<AuthUser> signInWithEmailAndPassword(String email, String password);

  /// Registers an email and password account.
  Future<AuthUser> createUserWithEmailAndPassword(
      String email, String password);

  /// Links a credential to the signed-in account.
  Future<AuthUser> linkWithCredential(fb.AuthCredential credential);

  /// Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email);

  /// Signs out.
  Future<void> signOut();

  /// Deletes the signed-in account.
  Future<void> deleteAccount();
}

/// Production Firebase client.
final class DefaultFirebaseAuthClient implements FirebaseAuthClient {
  /// Creates a client over [instance], defaulting to the shared instance.
  DefaultFirebaseAuthClient({fb.FirebaseAuth? instance})
      : _auth = instance ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  @override
  AuthUser? get currentUser => mapFirebaseUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _auth.userChanges().map(mapFirebaseUser);

  @override
  Future<AuthUser> signInAnonymously() async =>
      _require(await _auth.signInAnonymously());

  @override
  Future<AuthUser> signInWithCredential(fb.AuthCredential credential) async =>
      _require(await _auth.signInWithCredential(credential));

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return _require(
      await _auth.signInWithEmailAndPassword(email: email, password: password),
    );
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return _require(
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<AuthUser> linkWithCredential(fb.AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(code: 'no-current-user');
    }
    return _require(await user.linkWithCredential(credential));
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw fb.FirebaseAuthException(code: 'no-current-user');
    }
    await user.delete();
  }

  AuthUser _require(fb.UserCredential credential) {
    final user = mapFirebaseUser(credential.user);
    if (user == null) {
      throw fb.FirebaseAuthException(code: 'null-user');
    }
    return user;
  }
}
