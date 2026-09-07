import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:test/test.dart';

/// Creates a fresh, deterministic provider for one contract test.
typedef IapProviderFactory = Future<IapProvider> Function();

/// Inputs and expected identifiers used by the shared provider contract.
final class IapProviderContractScenario {
  /// Creates a contract scenario.
  const IapProviderContractScenario({
    required this.providerName,
    required this.productId,
    required this.appUserId,
  });

  /// Human-readable provider name used in the test group.
  final String providerName;

  /// Product the deterministic fixture makes available for purchase.
  final String productId;

  /// Non-empty application user ID accepted by the fixture.
  final String appUserId;
}

/// Registers the behavior every [IapProvider] adapter must satisfy.
///
/// The supplied provider should wrap a fake or sandbox client. Contract tests
/// must never create real customer transactions.
void runIapProviderContractTests({
  required IapProviderFactory createProvider,
  required IapProviderContractScenario scenario,
}) {
  group('${scenario.providerName} IAP provider contract', () {
    late IapProvider provider;

    setUp(() async {
      provider = await createProvider();
    });

    tearDown(() async {
      await provider.dispose();
    });

    test('initializes idempotently and reports ready health', () async {
      expect((await provider.initialize()).isSuccess, isTrue);
      expect((await provider.initialize()).isSuccess, isTrue);
      expect(provider.health.state, ModuleState.ready);
      expect(provider.providerId, isNotEmpty);
    });

    test('returns products and completes a deterministic purchase', () async {
      expect((await provider.initialize()).isSuccess, isTrue);

      final productsResult = await provider.getProducts(
        productIds: <String>{scenario.productId},
      );
      final products = _successValue(productsResult);
      expect(
          products.map((product) => product.id), contains(scenario.productId));

      final purchase = _successValue(
        await provider.purchase(scenario.productId),
      );
      expect(purchase.productId, scenario.productId);
      expect(purchase.status, PurchaseStatus.purchased);
      expect(purchase.entitlements, isNotNull);
    });

    test('identifies, restores, and resets a customer', () async {
      expect((await provider.initialize()).isSuccess, isTrue);

      final identified = _successValue(
        await provider.identify(scenario.appUserId),
      );
      expect(identified.appUserId, scenario.appUserId);

      final restored = _successValue(await provider.restorePurchases());
      expect(restored.provider, provider.providerId);

      final reset = _successValue(await provider.resetIdentity());
      expect(reset.appUserId, isNot(scenario.appUserId));
    });

    test('rejects operations before initialization', () async {
      final result = await provider.getEntitlements();

      expect(result.isFailure, isTrue);
      expect(
        result.fold(
          onSuccess: (_) => null,
          onFailure: (error) => error.code,
        ),
        KitErrorCode.notInitialized,
      );
    });
  });
}

T _successValue<T>(KitResult<T> result) {
  return result.fold(
    onSuccess: (value) => value,
    onFailure: (error) => throw TestFailure(
      'Expected success but received ${error.code.name}: ${error.message}',
    ),
  );
}
