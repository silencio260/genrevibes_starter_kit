import 'package:genrevibes_app_rating/genrevibes_app_rating.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

/// Creates a fresh store review provider backed by a deterministic client.
typedef StoreReviewProviderFactory = Future<StoreReviewProvider> Function();

/// Registers the behavior every store review adapter must satisfy.
void runStoreReviewProviderContractTests({
  required String providerName,
  required StoreReviewProviderFactory createProvider,
}) {
  group('$providerName store review contract', () {
    late StoreReviewProvider provider;

    setUp(() async => provider = await createProvider());
    tearDown(() async => provider.dispose());

    test('reports a stable non-empty provider identifier', () {
      expect(provider.providerId, isNotEmpty);
    });

    test('rejects work before initialization', () async {
      final result = await provider.requestReview();

      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.notInitialized,
      );
    });

    test('becomes ready after initialization', () async {
      expect((await provider.initialize()).isSuccess, isTrue);

      expect(provider.health.state, ModuleState.ready);
    });

    test('initialization is idempotent', () async {
      expect((await provider.initialize()).isSuccess, isTrue);
      expect((await provider.initialize()).isSuccess, isTrue);
    });

    test('reports availability without throwing', () async {
      await provider.initialize();

      final result = await provider.isAvailable();

      expect(result.isSuccess, isTrue);
    });

    test('accepts a review request when available', () async {
      await provider.initialize();

      expect((await provider.requestReview()).isSuccess, isTrue);
    });

    test('opens the store listing as a fallback path', () async {
      await provider.initialize();

      expect((await provider.openStoreListing()).isSuccess, isTrue);
    });

    test('disposal is idempotent and reports disposed health', () async {
      await provider.initialize();

      expect((await provider.dispose()).isSuccess, isTrue);
      expect((await provider.dispose()).isSuccess, isTrue);
      expect(provider.health.state, ModuleState.disposed);
    });
  });
}
