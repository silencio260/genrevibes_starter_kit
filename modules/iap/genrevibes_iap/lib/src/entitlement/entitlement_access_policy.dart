import '../model/entitlement_snapshot.dart';

/// Entitlement requirements for one application feature.
final class FeatureEntitlementRule {
  /// Creates a feature access rule.
  const FeatureEntitlementRule({
    required this.featureId,
    this.anyOf = const <String>{},
    this.allOf = const <String>{},
    this.accessWhenNoEntitlementsRequired = false,
  });

  /// Application feature controlled by this rule.
  final String featureId;

  /// At least one of these entitlement identifiers must be active.
  final Set<String> anyOf;

  /// Every one of these entitlement identifiers must be active.
  final Set<String> allOf;

  /// Access returned when both [anyOf] and [allOf] are empty.
  final bool accessWhenNoEntitlementsRequired;
}

/// Provider-independent mapping from entitlements to application features.
final class EntitlementAccessPolicy {
  /// Creates an access policy from [rules].
  EntitlementAccessPolicy(Iterable<FeatureEntitlementRule> rules)
      : _rules = <String, FeatureEntitlementRule>{
          for (final rule in rules) rule.featureId: rule,
        };

  final Map<String, FeatureEntitlementRule> _rules;

  /// Whether [featureId] is unlocked by [snapshot].
  ///
  /// Unknown features are denied by default.
  bool isUnlocked(String featureId, EntitlementSnapshot snapshot) {
    final rule = _rules[featureId];
    if (rule == null) return false;

    final active = snapshot.activeEntitlementIds;
    if (rule.anyOf.isEmpty && rule.allOf.isEmpty) {
      return rule.accessWhenNoEntitlementsRequired;
    }

    final satisfiesAny = rule.anyOf.isEmpty || rule.anyOf.any(active.contains);
    final satisfiesAll = rule.allOf.every(active.contains);
    return satisfiesAny && satisfiesAll;
  }
}
