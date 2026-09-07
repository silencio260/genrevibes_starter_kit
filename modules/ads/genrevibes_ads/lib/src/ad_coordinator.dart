import 'package:genrevibes_core/genrevibes_core.dart';

import 'ad_provider.dart';
import 'model/ad_placement.dart';
import 'model/ad_show_result.dart';
import 'policy/ad_policy.dart';

/// Coordinates provider calls with portfolio-wide ad display policy.
final class AdCoordinator {
  /// Creates an ad coordinator.
  const AdCoordinator({required this.provider, required this.policy});

  /// Selected compile-time provider adapter.
  final AdProvider provider;

  /// Premium, suppression, and frequency policy.
  final AdPolicyController policy;

  /// Loads [placement] unless the customer has ad-free entitlement.
  Future<KitResult<void>> load(AdPlacement placement) {
    if (policy.isPremium) {
      return Future<KitResult<void>>.value(const KitSuccess<void>(null));
    }
    return provider.load(placement);
  }

  /// Applies policy and displays [placement] without allowing overlaps.
  Future<KitResult<AdShowResult>> show(AdPlacement placement) async {
    final decision = policy.beginShow(placement);
    final blockReason = decision.blockReason;
    if (blockReason != null) {
      return KitSuccess<AdShowResult>(AdShowResult.blocked(blockReason));
    }
    try {
      if (!provider.isReady(placement)) {
        return const KitSuccess<AdShowResult>(
          AdShowResult(status: AdShowStatus.notReady),
        );
      }
      final result = await provider.show(placement);
      result.fold(
        onSuccess: (outcome) {
          if (outcome.wasShown) policy.recordShown(placement);
        },
        onFailure: (_) {},
      );
      return result;
    } finally {
      policy.finishShow(placement);
    }
  }

  /// Activates/deactivates premium and discards loaded inventory immediately.
  Future<KitResult<void>> setPremium(
    bool isPremium,
    Iterable<AdPlacement> configuredPlacements,
  ) async {
    policy.setPremium(isPremium);
    if (!isPremium) return const KitSuccess<void>(null);
    KitError? firstFailure;
    for (final placement in configuredPlacements) {
      final result = await provider.discard(placement);
      result.fold(
        onSuccess: (_) {},
        onFailure: (error) => firstFailure ??= error,
      );
    }
    return firstFailure == null
        ? const KitSuccess<void>(null)
        : KitFailure<void>(firstFailure!);
  }
}
