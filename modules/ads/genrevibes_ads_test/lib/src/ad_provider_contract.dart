import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:test/test.dart';

/// Provider and configured placement used by the shared contract.
typedef AdProviderFixture = ({AdProvider provider, AdPlacement placement});

/// Creates a fresh deterministic provider fixture.
typedef AdProviderFactory = Future<AdProviderFixture> Function();

/// Registers behavior every ad provider adapter must satisfy.
void runAdProviderContractTests({
  required String providerName,
  required AdProviderFactory createProvider,
}) {
  group('$providerName ad provider contract', () {
    late AdProviderFixture fixture;

    setUp(() async => fixture = await createProvider());
    tearDown(() async => fixture.provider.dispose());

    test('rejects loading before initialization', () async {
      final result = await fixture.provider.load(fixture.placement);
      expect(result.isFailure, isTrue);
      expect(
        result.fold(onSuccess: (_) => null, onFailure: (error) => error.code),
        KitErrorCode.notInitialized,
      );
    });

    test('initializes idempotently and declares supported formats', () async {
      expect((await fixture.provider.initialize()).isSuccess, isTrue);
      expect((await fixture.provider.initialize()).isSuccess, isTrue);
      expect(fixture.provider.health.state, ModuleState.ready);
      expect(fixture.provider.providerId, isNotEmpty);
      expect(
        fixture.provider.supportedFormats,
        contains(fixture.placement.format),
      );
    });

    test('loads, shows, consumes, and discards placement inventory', () async {
      await fixture.provider.initialize();
      expect(
          (await fixture.provider.load(fixture.placement)).isSuccess, isTrue);
      expect(fixture.provider.isReady(fixture.placement), isTrue);

      final shown = await fixture.provider.show(fixture.placement);
      expect(shown.isSuccess, isTrue);
      expect(
        shown.fold(
            onSuccess: (value) => value.wasShown, onFailure: (_) => false),
        isTrue,
      );
      expect(fixture.provider.isReady(fixture.placement), isFalse);

      expect(
        (await fixture.provider.discard(fixture.placement)).isSuccess,
        isTrue,
      );
    });
  });
}
