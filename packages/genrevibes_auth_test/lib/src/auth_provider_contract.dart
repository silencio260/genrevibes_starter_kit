import 'package:genrevibes_auth/genrevibes_auth.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

/// Creates a fresh authentication provider backed by a deterministic client.
typedef AuthProviderFactory = Future<AuthProvider> Function();

/// Registers the behavior every authentication adapter must satisfy.
void runAuthProviderContractTests({
  required String providerName,
  required AuthProviderFactory createProvider,
}) {
  group('$providerName auth provider contract', () {
    late AuthProvider provider;

    setUp(() async => provider = await createProvider());
    tearDown(() async => provider.dispose());

    test('reports a stable non-empty provider identifier', () {
      expect(provider.providerId, isNotEmpty);
    });

    test('rejects work before initialization', () async {
      final result = await provider.signIn(const AnonymousAuthRequest());

      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.notInitialized,
      );
    });

    test('becomes ready and starts signed out', () async {
      expect((await provider.initialize()).isSuccess, isTrue);

      expect(provider.health.state, ModuleState.ready);
      expect(provider.currentUser, isNull);
    });

    test('initialization is idempotent', () async {
      expect((await provider.initialize()).isSuccess, isTrue);
      expect((await provider.initialize()).isSuccess, isTrue);
    });

    test('a guest sign-in produces an anonymous user', () async {
      await provider.initialize();

      final result = await provider.signIn(const AnonymousAuthRequest());

      final user = result.fold(onSuccess: (v) => v, onFailure: (_) => null);
      expect(user, isNotNull);
      expect(user!.isAnonymous, isTrue);
      expect(user.id, isNotEmpty);
      expect(provider.currentUser?.id, user.id);
    });

    test('userChanges replays the current state to a late listener', () async {
      await provider.initialize();
      await provider.signIn(const AnonymousAuthRequest());

      final first = await provider.userChanges.first;

      expect(first?.isAnonymous, isTrue);
    });

    test('linking upgrades the account without changing its identity',
        () async {
      if (!provider.capabilities.linking) return;
      await provider.initialize();
      final guest = (await provider.signIn(const AnonymousAuthRequest()))
          .fold(onSuccess: (v) => v, onFailure: (_) => null)!;

      final linked = await provider.linkCredential(
        const EmailPasswordAuthRequest(
          email: 'linked@example.com',
          password: 'sufficiently-long',
        ),
      );

      final user = linked.fold(onSuccess: (v) => v, onFailure: (_) => null);
      expect(user, isNotNull, reason: 'linking is declared supported');
      // The whole point of linking: same account, no longer a guest.
      expect(user!.id, guest.id);
      expect(user.isAnonymous, isFalse);
    });

    test('signing out clears the current user', () async {
      await provider.initialize();
      await provider.signIn(const AnonymousAuthRequest());

      expect((await provider.signOut()).isSuccess, isTrue);
      expect(provider.currentUser, isNull);
    });

    test('an unsupported request fails rather than silently succeeding',
        () async {
      if (provider.capabilities.federated) return;
      await provider.initialize();

      final result = await provider.signIn(const GoogleAuthRequest());

      expect(result.isFailure, isTrue);
    });

    test('disposal is idempotent and reports disposed health', () async {
      await provider.initialize();

      expect((await provider.dispose()).isSuccess, isTrue);
      expect((await provider.dispose()).isSuccess, isTrue);
      expect(provider.health.state, ModuleState.disposed);
    });
  });
}
