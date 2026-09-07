/// Reward earned after a verified rewarded-ad callback.
final class AdReward {
  /// Creates a reward.
  const AdReward({required this.type, required this.amount});

  /// Provider-defined reward type mapped by application policy.
  final String type;

  /// Provider-confirmed reward amount.
  final num amount;
}
