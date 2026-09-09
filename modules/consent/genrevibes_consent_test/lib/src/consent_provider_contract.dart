import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

/// Creates a fresh consent provider backed by a deterministic client.
typedef ConsentProviderFactory = Future<ConsentProvider> Function();

/// Registers the behavior every consent provider adapter must satisfy.
///
/// An adapter that passes these tests can be substituted for any other without
/// changing application code.
void runConsentProviderContractTests({
  required String providerName,
  required ConsentProviderFactory createProvider,
}) {
  group('$providerName consent provider contract', () {
    late ConsentProvider provider;

    setUp(() async => provider = await createProvider());
    tearDown(() async => provider.dispose());

    test('reports a stable non-empty provider identifier', () {
      expect(provider.providerId, isNotEmpty);
    });

    test('rejects work before initialization', () async {
      final result = await provider.requestConsent();

      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.notInitialized,
      );
    });

    test('becomes ready after initialization', () async {
      expect((await provider.initialize()).isSuccess, isTrue);

      expect(provider.health.state, ModuleState.ready);
      expect(provider.health.moduleId, isNotEmpty);
    });

    test('initialization is idempotent', () async {
      expect((await provider.initialize()).isSuccess, isTrue);
      expect((await provider.initialize()).isSuccess, isTrue);
    });

    test('resolves consent to a settled state', () async {
      await provider.initialize();

      final result = await provider.requestConsent();

      expect(result.isSuccess, isTrue);
      final snapshot = result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );
      expect(snapshot, isNotNull);
      expect(snapshot!.state, isNot(ConsentState.unknown));
    });

    test('exposes the resolved snapshot after requesting consent', () async {
      await provider.initialize();

      final result = await provider.requestConsent();
      final resolved = result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );

      expect(provider.snapshot.state, resolved!.state);
    });

    test('never infers ad permission from the consent state', () {
      // Any provider joining the kit must report `canRequestAds` from its own
      // platform. Deriving it from the state serves personalized ads to users
      // who refused them: `obtained` says the form was answered, nothing more.
      for (final state in ConsentState.values) {
        final snapshot = ConsentSnapshot(
          state: state,
          observedAt: DateTime.utc(2026),
        );

        expect(snapshot.canRequestAds, isFalse);
      }
    });

    test('disposal is idempotent and reports disposed health', () async {
      await provider.initialize();

      expect((await provider.dispose()).isSuccess, isTrue);
      expect((await provider.dispose()).isSuccess, isTrue);
      expect(provider.health.state, ModuleState.disposed);
    });
  });
}
