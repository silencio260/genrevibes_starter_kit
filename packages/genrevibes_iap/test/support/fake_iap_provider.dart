import 'dart:async';

import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:genrevibes_iap/genrevibes_iap.dart';

final class FakeIapProvider implements IapProvider {
  FakeIapProvider({required this.snapshot})
      : _health = ModuleHealth(
          moduleId: 'iap',
          provider: 'fake',
          state: ModuleState.idle,
          observedAt: snapshot.observedAt,
        );

  EntitlementSnapshot snapshot;
  final StreamController<EntitlementSnapshot> _entitlements =
      StreamController<EntitlementSnapshot>.broadcast();
  final StreamController<ModuleHealth> _healthChanges =
      StreamController<ModuleHealth>.broadcast();
  late ModuleHealth _health;

  @override
  IapCapabilities get capabilities => const IapCapabilities(
        hostedPaywall: true,
        customerCenter: true,
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
  String get providerId => 'fake';

  @override
  Future<KitResult<void>> initialize() async {
    _setState(ModuleState.ready);
    _entitlements.add(snapshot);
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<List<IapProduct>>> getProducts({
    Set<String> productIds = const <String>{},
    String? placementId,
  }) async {
    return const KitSuccess<List<IapProduct>>(<IapProduct>[]);
  }

  @override
  Future<KitResult<EntitlementSnapshot>> getEntitlements({
    bool forceRefresh = false,
  }) async {
    return KitSuccess<EntitlementSnapshot>(snapshot);
  }

  @override
  Future<KitResult<EntitlementSnapshot>> identify(String appUserId) async {
    snapshot = EntitlementSnapshot(
      entitlements: snapshot.entitlements,
      observedAt: snapshot.observedAt,
      provider: snapshot.provider,
      appUserId: appUserId,
    );
    _entitlements.add(snapshot);
    return KitSuccess<EntitlementSnapshot>(snapshot);
  }

  @override
  Future<KitResult<PurchaseResult>> presentPaywall({
    String? placementId,
    String? requiredEntitlementId,
  }) async {
    return KitSuccess<PurchaseResult>(
      PurchaseResult(
        status: PurchaseStatus.notPurchased,
        entitlements: snapshot,
      ),
    );
  }

  @override
  Future<KitResult<void>> presentCustomerCenter() async {
    return const KitSuccess<void>(null);
  }

  @override
  Future<KitResult<PurchaseResult>> purchase(String productId) async {
    return KitSuccess<PurchaseResult>(
      PurchaseResult(
        status: PurchaseStatus.purchased,
        productId: productId,
        entitlements: snapshot,
      ),
    );
  }

  @override
  Future<KitResult<EntitlementSnapshot>> resetIdentity() async {
    snapshot = EntitlementSnapshot(
      entitlements: snapshot.entitlements,
      observedAt: snapshot.observedAt,
      provider: snapshot.provider,
    );
    _entitlements.add(snapshot);
    return KitSuccess<EntitlementSnapshot>(snapshot);
  }

  @override
  Future<KitResult<EntitlementSnapshot>> restorePurchases() async {
    return KitSuccess<EntitlementSnapshot>(snapshot);
  }

  @override
  Future<KitResult<void>> dispose() async {
    _setState(ModuleState.disposed);
    await _entitlements.close();
    await _healthChanges.close();
    return const KitSuccess<void>(null);
  }

  void _setState(ModuleState state) {
    _health = ModuleHealth(
      moduleId: moduleId,
      provider: providerId,
      state: state,
      observedAt: snapshot.observedAt,
    );
    _healthChanges.add(_health);
  }
}
