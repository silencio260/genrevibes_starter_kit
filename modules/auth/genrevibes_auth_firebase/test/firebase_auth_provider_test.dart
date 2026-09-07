import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_auth/genrevibes_auth.dart';
import 'package:genrevibes_auth_firebase/genrevibes_auth_firebase.dart';
import 'package:genrevibes_auth_test/genrevibes_auth_test.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

void main() {
  runAuthProviderContractTests(
    providerName: 'Firebase',
    createProvider: () async => FirebaseAuthProvider(client: _FakeClient()),
  );

  group('error mapping', () {
    test('maps the codes an app has to branch on', () {
      expect(mapAuthErrorCode('wrong-password'),
          AuthFailureReason.invalidCredential);
      expect(
          mapAuthErrorCode('user-not-found'), AuthFailureReason.userNotFound);
      expect(mapAuthErrorCode('email-already-in-use'),
          AuthFailureReason.emailAlreadyInUse);
      expect(mapAuthErrorCode('requires-recent-login'),
          AuthFailureReason.requiresRecentLogin);
      expect(mapAuthErrorCode('credential-already-in-use'),
          AuthFailureReason.credentialAlreadyLinked);
      expect(mapAuthErrorCode('network-request-failed'),
          AuthFailureReason.network);
      expect(mapAuthErrorCode('something-new'), AuthFailureReason.unknown);
    });

    test('network and cancellation are not lumped into provider errors', () {
      expect(mapErrorCode(AuthFailureReason.network), KitErrorCode.network);
      expect(mapErrorCode(AuthFailureReason.cancelled), KitErrorCode.cancelled);
      expect(mapErrorCode(AuthFailureReason.unsupported),
          KitErrorCode.unsupported);
      expect(
          mapErrorCode(AuthFailureReason.weakPassword), KitErrorCode.provider);
    });
  });

  group('credential mapping', () {
    test('non-federated requests produce no credential', () {
      expect(mapCredential(const AnonymousAuthRequest()), isNull);
      expect(
        mapCredential(
          const EmailPasswordAuthRequest(email: 'a@b.c', password: 'x'),
        ),
        isNull,
      );
    });

    test('a tokenless Google request is a programming error', () {
      expect(
        () => mapCredential(const GoogleAuthRequest()),
        throwsArgumentError,
      );
    });

    test('Apple credentials carry the raw nonce', () {
      final credential = mapCredential(
        const AppleAuthRequest(identityToken: 'tok', rawNonce: 'nonce'),
      );

      expect(credential, isA<fb.AuthCredential>());
      expect(credential!.providerId, 'apple.com');
    });
  });

  group('FirebaseAuthProvider', () {
    test('declares full Firebase capability', () {
      final capabilities =
          FirebaseAuthProvider(client: _FakeClient()).capabilities;

      expect(capabilities.linking, isTrue);
      expect(capabilities.accountDeletion, isTrue);
      expect(capabilities.federated, isTrue);
    });

    test('adopts an already signed-in user at initialization', () async {
      final client = _FakeClient()
        ..user = AuthUser(id: 'existing', isAnonymous: false);
      final provider = FirebaseAuthProvider(client: client);

      await provider.initialize();

      expect(provider.currentUser?.id, 'existing');
    });

    test('registers only when sign-in reports no such user', () async {
      final client = _FakeClient()..throwOnSignIn = 'user-not-found';
      final provider = await _ready(client);

      final result = await provider.signIn(
        const EmailPasswordAuthRequest(
          email: 'a@b.c',
          password: 'x',
          createIfMissing: true,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(client.created, isTrue);
    });

    test('a wrong password does not silently register a new account', () async {
      final client = _FakeClient()..throwOnSignIn = 'wrong-password';
      final provider = await _ready(client);

      final result = await provider.signIn(
        const EmailPasswordAuthRequest(
          email: 'a@b.c',
          password: 'x',
          createIfMissing: true,
        ),
      );

      expect(result.isFailure, isTrue);
      expect(client.created, isFalse);
      expect(
        result.fold(
          onSuccess: (_) => null,
          onFailure: (e) => e.metadata[authFailureReasonKey],
        ),
        AuthFailureReason.invalidCredential,
      );
    });

    test('linking an email credential keeps the account id', () async {
      final client = _FakeClient();
      final provider = await _ready(client);
      await provider.signIn(const AnonymousAuthRequest());

      final linked = await provider.linkCredential(
        const EmailPasswordAuthRequest(email: 'a@b.c', password: 'x'),
      );

      final user = linked.fold(onSuccess: (v) => v, onFailure: (_) => null);
      expect(user!.id, 'guest-1');
      expect(user.isAnonymous, isFalse);
    });

    test('linking an anonymous request is rejected as configuration', () async {
      final provider = await _ready(_FakeClient());
      await provider.signIn(const AnonymousAuthRequest());

      final result =
          await provider.linkCredential(const AnonymousAuthRequest());

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (e) => e.code),
        KitErrorCode.invalidConfiguration,
      );
    });

    test('a stale session surfaces requiresRecentLogin on deletion', () async {
      final client = _FakeClient()..throwOnDelete = 'requires-recent-login';
      final provider = await _ready(client);
      await provider.signIn(const AnonymousAuthRequest());

      final result = await provider.deleteAccount();

      expect(
        result.fold(
          onSuccess: (_) => null,
          onFailure: (e) => e.metadata[authFailureReasonKey],
        ),
        AuthFailureReason.requiresRecentLogin,
      );
      expect(provider.health.state, ModuleState.degraded);
    });

    test('external sign-out from the SDK reaches userChanges', () async {
      final client = _FakeClient();
      final provider = await _ready(client);
      await provider.signIn(const AnonymousAuthRequest());

      client.emit(null);
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentUser, isNull);
    });
  });
}

Future<FirebaseAuthProvider> _ready(_FakeClient client) async {
  final provider = FirebaseAuthProvider(client: client);
  await provider.initialize();
  return provider;
}

final class _FakeClient implements FirebaseAuthClient {
  AuthUser? user;
  String? throwOnSignIn;
  String? throwOnDelete;
  bool created = false;
  final _controller = StreamController<AuthUser?>.broadcast();

  void emit(AuthUser? next) {
    user = next;
    _controller.add(next);
  }

  Never _fail(String code) => throw fb.FirebaseAuthException(code: code);

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get userChanges => _controller.stream;

  @override
  Future<AuthUser> signInAnonymously() async {
    final next = AuthUser(id: 'guest-1', isAnonymous: true);
    emit(next);
    return next;
  }

  @override
  Future<AuthUser> signInWithCredential(fb.AuthCredential credential) async {
    final next = AuthUser(
      id: 'federated-1',
      isAnonymous: false,
      providerIds: <String>{credential.providerId},
    );
    emit(next);
    return next;
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final code = throwOnSignIn;
    if (code != null) _fail(code);
    final next = AuthUser(id: 'email-1', isAnonymous: false, email: email);
    emit(next);
    return next;
  }

  @override
  Future<AuthUser> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    created = true;
    final next = AuthUser(id: 'email-new', isAnonymous: false, email: email);
    emit(next);
    return next;
  }

  @override
  Future<AuthUser> linkWithCredential(fb.AuthCredential credential) async {
    final existing = user;
    if (existing == null) _fail('no-current-user');
    final next = AuthUser(
      id: existing.id,
      isAnonymous: false,
      providerIds: <String>{credential.providerId},
    );
    emit(next);
    return next;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signOut() async => emit(null);

  @override
  Future<void> deleteAccount() async {
    final code = throwOnDelete;
    if (code != null) _fail(code);
    emit(null);
  }
}
