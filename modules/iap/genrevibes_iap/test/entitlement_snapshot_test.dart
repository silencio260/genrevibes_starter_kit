import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:test/test.dart';

void main() {
  test('activeEntitlementIds excludes inactive entitlements', () {
    final observedAt = DateTime.utc(2026);
    final snapshot = EntitlementSnapshot(
      observedAt: observedAt,
      provider: 'fake',
      entitlements: <Entitlement>[
        Entitlement(
          id: 'pro',
          productId: 'monthly',
          isActive: true,
          observedAt: observedAt,
        ),
        Entitlement(
          id: 'expired',
          productId: 'old-monthly',
          isActive: false,
          observedAt: observedAt,
        ),
      ],
    );

    expect(snapshot.activeEntitlementIds, <String>{'pro'});
    expect(snapshot.hasActiveEntitlement('expired'), isFalse);
  });
}
