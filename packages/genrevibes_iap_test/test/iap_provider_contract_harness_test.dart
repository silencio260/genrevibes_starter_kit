import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:genrevibes_iap_test/genrevibes_iap_test.dart';

void main() {
  runIapProviderContractTests(
    scenario: const IapProviderContractScenario(
      providerName: 'fixture',
      productId: 'pro.monthly',
      appUserId: 'portfolio-user-1',
    ),
    createProvider: () async => _ContractFixtureProvider(),
  );
}

final class _ContractFixtureProvider implements IapProvider {
  _ContractFixtureProvider()
      : _health = ModuleHealth(
          moduleId: 'iap',
          provider: 'fixture',
          state: ModuleState.idle,
          observedAt: DateTime.utc(2026),
        );

  final StreamController<EntitlementSnapshot> _entitlements =
      StreamController<EntitlementSnapshot>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;
  bool _initialized = false;
  String? _appUserId;

  @override
  IapCapabilities get capabilities => const IapCapabilities(
        hostedPaywall: false,
        customerCenter: false,
        accountIdentification: true,
        promotionalOffers: false,
      );

  @override
  Stream<EntitlementSnapshot> get entitlementChanges => _entitlements.stream;

  @override
  ModuleHealth get health => _health;

  @override
  Stream<ModuleHealth> get healthChanges => _healthChanges.stream;

  @override
  String get moduleId => 'iap';

  @override
  String get providerId => 'fixture';

  @override
  Future<KitResult<void>> initialize() async {
    _initialized = true;
    _setHealth(ModuleState.ready);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<List<IapProduct>>> getProducts({
    Set<String> productIds = const <String>{},
    String? placementId,
  }) async {
    final notReady = _requireReady<List<IapProduct>>();
    if (notReady != null) return notReady;
    return const KitSuccess<List<IapProduct>>(<IapProduct>[
      IapProduct(
        id: 'pro.monthly',
        title: 'Pro monthly',
        description: 'Monthly premium access',
        type: IapProductType.subscription,
        price: 4.99,
        priceString: r'$4.99',
        currencyCode: 'USD',
      ),
    ]);
  }

  @override
  Future<KitResult<PurchaseResult>> purchase(String productId) async {
    final notReady = _requireReady<PurchaseResult>();
    if (notReady != null) return notReady;
    final snapshot = _snapshot(entitlementId: 'pro');
    _entitlements.add(snapshot);
    return KitSuccess<PurchaseResult>(
      PurchaseResult(
        status: PurchaseStatus.purchased,
        productId: productId,
        entitlements: snapshot,
      ),
    );
  }

  @override
  Future<KitResult<PurchaseResult>> presentPaywall({
    String? placementId,
    String? requiredEntitlementId,
  }) async {
    return const KitFailure<PurchaseResult>(
      KitError(
        code: KitErrorCode.unsupported,
        message: 'Fixture has no UI.',
      ),
    );
  }

  @override
  Future<KitResult<void>> presentCustomerCenter() async {
    return const KitFailure<void>(
      KitError(
        code: KitErrorCode.unsupported,
        message: 'Fixture has no UI.',
      ),
    );
  }

  @override
  Future<KitResult<EntitlementSnapshot>> restorePurchases() async {
    final notReady = _requireReady<EntitlementSnapshot>();
    return notReady ?? KitSuccess<EntitlementSnapshot>(_snapshot());
  }

  @override
  Future<KitResult<EntitlementSnapshot>> getEntitlements({
    bool forceRefresh = false,
  }) async {
    final notReady = _requireReady<EntitlementSnapshot>();
    return notReady ?? KitSuccess<EntitlementSnapshot>(_snapshot());
  }

  @override
  Future<KitResult<EntitlementSnapshot>> identify(String appUserId) async {
    final notReady = _requireReady<EntitlementSnapshot>();
    if (notReady != null) return notReady;
    _appUserId = appUserId;
    return KitSuccess<EntitlementSnapshot>(_snapshot());
  }

  @override
  Future<KitResult<EntitlementSnapshot>> resetIdentity() async {
    final notReady = _requireReady<EntitlementSnapshot>();
    if (notReady != null) return notReady;
    _appUserId = null;
    return KitSuccess<EntitlementSnapshot>(_snapshot());
  }

  @override
  Future<KitResult<void>> dispose() async {
    if (_health.state == ModuleState.disposed) {
      return const KitSuccess<void>(null);
    }
    _setHealth(ModuleState.disposed);
    await _entitlements.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  EntitlementSnapshot _snapshot({String? entitlementId}) {
    final observedAt = DateTime.utc(2026);
    return EntitlementSnapshot(
      entitlements: entitlementId == null
          ? const <Entitlement>[]
          : <Entitlement>[
              Entitlement(
                id: entitlementId,
                productId: 'pro.monthly',
                isActive: true,
                observedAt: observedAt,
              ),
            ],
      observedAt: observedAt,
      provider: providerId,
      appUserId: _appUserId,
    );
  }

  KitFailure<T>? _requireReady<T>() {
    if (_initialized) return null;
    return KitFailure<T>(
      const KitError(
        code: KitErrorCode.notInitialized,
        message: 'Initialize first.',
      ),
    );
  }

  void _setHealth(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: DateTime.utc(2026),
    );
    _healthChanges.add(_health);
  }
}
