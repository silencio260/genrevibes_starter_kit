import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:genrevibes_auth/genrevibes_auth.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'firebase_auth_client.dart';
import 'firebase_auth_mapping.dart';

/// Firebase implementation of [AuthProvider].
///
/// Firebase must already be initialized by the host application before this
/// module starts.
final class FirebaseAuthProvider implements AuthProvider {
  /// Creates a Firebase auth provider.
  FirebaseAuthProvider({
    FirebaseAuthClient? client,
    KitClock clock = const SystemKitClock(),
    KitLogger logger = const NoopKitLogger(),
  })  : _client = client ?? DefaultFirebaseAuthClient(),
        _clock = clock,
        _logger = logger,
        _health = ModuleHealth(
          moduleId: 'auth',
          provider: 'firebase',
          state: ModuleState.idle,
          observedAt: clock.now(),
        );

  final FirebaseAuthClient _client;
  final KitClock _clock;
  final KitLogger _logger;
  final StreamController<AuthUser?> _userChanges =
      StreamController<AuthUser?>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  StreamSubscription<AuthUser?>? _subscription;
  ModuleHealth _health;
  AuthUser? _currentUser;
  bool _initialized = false;
  bool _disposed = false;

  @override
  String get providerId => 'firebase';

  @override
  String get moduleId => 'auth';

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  AuthCapabilities get capabilities => const AuthCapabilities(
        anonymous: true,
        emailPassword: true,
        federated: true,
        linking: true,
        passwordReset: true,
        accountDeletion: true,
      );

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get userChanges async* {
    // Replay the current state so a listener that subscribes after sign-in is
    // not left waiting for a change that already happened.
    yield _currentUser;
    yield* _userChanges.stream;
  }

  @override
  Future<KitResult<void>> initialize() async {
    if (_disposed) return _notReady<void>();
    if (_initialized) return const KitSuccess<void>(null);
    try {
      _currentUser = _client.currentUser;
      _subscription = _client.userChanges.listen((user) {
        _currentUser = user;
        if (!_userChanges.isClosed) _userChanges.add(user);
        if (!_disposed) _setHealth(ModuleState.ready);
      });
      _initialized = true;
      _setHealth(ModuleState.ready);
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      final mapped = KitError(
        code: KitErrorCode.provider,
        message: 'Firebase auth initialization failed: $error',
        providerCode: 'firebase_auth_initialize',
        cause: error,
        stackTrace: stackTrace,
      );
      _setHealth(ModuleState.failed, error: mapped);
      return KitFailure<void>(mapped);
    }
  }

  @override
  Future<KitResult<AuthUser>> signIn(AuthCredentialRequest request) {
    return _guard('sign_in', () async {
      switch (request) {
        case AnonymousAuthRequest():
          return _client.signInAnonymously();
        case EmailPasswordAuthRequest(
            :final email,
            :final password,
            :final createIfMissing
          ):
          if (!createIfMissing) {
            return _client.signInWithEmailAndPassword(email, password);
          }
          // Only the provider can distinguish "new" from "existing" without a
          // race, so try signing in and register on user-not-found.
          try {
            return await _client.signInWithEmailAndPassword(email, password);
          } on fb.FirebaseAuthException catch (error) {
            if (mapAuthErrorCode(error.code) !=
                AuthFailureReason.userNotFound) {
              rethrow;
            }
            return _client.createUserWithEmailAndPassword(email, password);
          }
        case GoogleAuthRequest():
        case AppleAuthRequest():
          return _client.signInWithCredential(mapCredential(request)!);
      }
    });
  }

  @override
  Future<KitResult<AuthUser>> linkCredential(AuthCredentialRequest request) {
    return _guard('link_credential', () async {
      final credential = mapCredential(request);
      if (credential == null) {
        if (request
            case EmailPasswordAuthRequest(:final email, :final password)) {
          return _client.linkWithCredential(
            fb.EmailAuthProvider.credential(email: email, password: password),
          );
        }
        throw ArgumentError.value(
          request,
          'request',
          'An anonymous request cannot be linked to an account.',
        );
      }
      return _client.linkWithCredential(credential);
    });
  }

  @override
  Future<KitResult<void>> sendPasswordReset(String email) {
    return _guardVoid(
      'send_password_reset',
      () => _client.sendPasswordResetEmail(email),
    );
  }

  @override
  Future<KitResult<void>> signOut() {
    return _guardVoid('sign_out', () async {
      await _client.signOut();
      _currentUser = null;
    });
  }

  @override
  Future<KitResult<void>> deleteAccount() {
    return _guardVoid('delete_account', () async {
      await _client.deleteAccount();
      _currentUser = null;
    });
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_disposed) return const KitSuccess<void>(null);
    _disposed = true;
    await _subscription?.cancel();
    _setHealth(ModuleState.disposed);
    await _userChanges.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  Future<KitResult<AuthUser>> _guard(
    String providerCode,
    Future<AuthUser> Function() action,
  ) async {
    if (!_initialized || _disposed) return _notReady<AuthUser>();
    try {
      final user = await action();
      _currentUser = user;
      return KitSuccess<AuthUser>(user);
    } on Object catch (error, stackTrace) {
      return KitFailure<AuthUser>(_map(error, stackTrace, providerCode));
    }
  }

  Future<KitResult<void>> _guardVoid(
    String providerCode,
    Future<void> Function() action,
  ) async {
    if (!_initialized || _disposed) return _notReady<void>();
    try {
      await action();
      return const KitSuccess<void>(null);
    } on Object catch (error, stackTrace) {
      return KitFailure<void>(_map(error, stackTrace, providerCode));
    }
  }

  KitError _map(Object error, StackTrace stackTrace, String providerCode) {
    final code = error is fb.FirebaseAuthException ? error.code : '';
    final reason = mapAuthErrorCode(code);
    final mapped = KitError(
      code: error is ArgumentError
          ? KitErrorCode.invalidConfiguration
          : mapErrorCode(reason),
      message: 'Firebase auth $providerCode failed: $error',
      providerCode: code.isEmpty ? 'firebase_auth_$providerCode' : code,
      cause: error,
      stackTrace: stackTrace,
      metadata: <String, Object?>{authFailureReasonKey: reason},
    );
    _logger.log(
      KitLogLevel.warning,
      'Firebase auth operation failed.',
      moduleId: moduleId,
      error: mapped,
    );
    if (!_disposed) _setHealth(ModuleState.degraded, error: mapped);
    return mapped;
  }

  KitFailure<T> _notReady<T>() {
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Firebase auth provider has not been initialized.',
      ),
    );
  }

  void _setHealth(ModuleState state, {KitError? error}) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: _clock.now(),
      error: error,
      details: <String, Object?>{
        'signedIn': _currentUser != null,
        'anonymous': _currentUser?.isAnonymous,
      },
    );
    if (!_healthChanges.isClosed) _healthChanges.add(_health);
  }
}
