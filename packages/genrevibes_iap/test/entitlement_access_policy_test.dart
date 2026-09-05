import 'package:genrevibes_iap/genrevibes_iap.dart';
import 'package:test/test.dart';

void main() {
  final observedAt = DateTime.utc(2026);

  EntitlementSnapshot snapshot(Set<String> activeIds) {
    return EntitlementSnapshot(
      observedAt: observedAt,
      provider: 'fake',
      entitlements: activeIds
          .map(
            (id) => Entitlement(
              id: id,
              productId: 'product.$id',
              isActive: true,
              observedAt: observedAt,
            ),
          )
          .toList(),
    );
  }

  group('EntitlementAccessPolicy', () {
    test('unlocks a feature when any accepted entitlement is active', () {
      final policy = EntitlementAccessPolicy(const <FeatureEntitlementRule>[
        FeatureEntitlementRule(
          featureId: 'remove_ads',
          anyOf: <String>{'pro', 'lifetime'},
        ),
      ]);

      expect(policy.isUnlocked('remove_ads', snapshot({'pro'})), isTrue);
    });

    test('requires every allOf entitlement', () {
      final policy = EntitlementAccessPolicy(const <FeatureEntitlementRule>[
        FeatureEntitlementRule(
          featureId: 'creator_tools',
          allOf: <String>{'pro', 'creator'},
        ),
      ]);

      expect(policy.isUnlocked('creator_tools', snapshot({'pro'})), isFalse);
      expect(
        policy.isUnlocked('creator_tools', snapshot({'pro', 'creator'})),
        isTrue,
      );
    });

    test('denies unknown features', () {
      final policy = EntitlementAccessPolicy(const <FeatureEntitlementRule>[]);

      expect(policy.isUnlocked('unknown', snapshot({'pro'})), isFalse);
    });
  });
}
