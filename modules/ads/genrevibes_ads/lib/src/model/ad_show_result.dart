import '../policy/ad_policy.dart';
import 'ad_reward.dart';

/// Result state for a non-error ad show attempt.
enum AdShowStatus {
  /// Provider displayed the ad.
  shown,

  /// No loaded ad was available.
  notReady,

  /// Provider call was deliberately skipped by application policy.
  blocked,
}

/// Provider-neutral outcome of an ad show request.
final class AdShowResult {
  /// Creates a show result.
  const AdShowResult({
    required this.status,
    this.reward,
    this.blockReason,
  });

  /// Display outcome.
  final AdShowStatus status;

  /// Verified reward, present only when earned.
  final AdReward? reward;

  /// Policy reason when [status] is [AdShowStatus.blocked].
  final AdPolicyBlockReason? blockReason;

  /// Whether the provider displayed the requested ad.
  bool get wasShown => status == AdShowStatus.shown;

  /// Creates a policy-blocked result.
  factory AdShowResult.blocked(AdPolicyBlockReason reason) {
    return AdShowResult(status: AdShowStatus.blocked, blockReason: reason);
  }
}
