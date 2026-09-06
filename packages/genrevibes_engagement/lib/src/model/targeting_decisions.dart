/// Which engagement-driven prompts are appropriate right now.
///
/// These are recommendations. The application decides whether and where to act
/// on them, and other policies (rating cooldowns, consent, premium) still apply.
final class TargetingDecisions {
  /// Creates decisions.
  const TargetingDecisions({
    required this.welcomeOffer,
    required this.onboardingTips,
    required this.retentionOffer,
    required this.loyaltyReward,
    required this.reEngagementOffer,
    required this.winbackOffer,
    required this.advancedFeatures,
    required this.premiumUpsell,
    required this.ratingPrompt,
    required this.notificationRequest,
    required this.helpTutorial,
  });

  /// First session ever.
  final bool welcomeOffer;

  /// Within the first three days.
  final bool onboardingTips;

  /// Day three with little activity.
  final bool retentionOffer;

  /// Day seven with strong D7 retention.
  final bool loyaltyReward;

  /// At risk of churn.
  final bool reEngagementOffer;

  /// Back today after being churned.
  final bool winbackOffer;

  /// Engaged enough for advanced features.
  final bool advancedFeatures;

  /// Engaged enough for a premium upsell.
  final bool premiumUpsell;

  /// A rating prompt is timely.
  final bool ratingPrompt;

  /// A notification permission request is timely.
  final bool notificationRequest;

  /// Low engagement; a tutorial may help.
  final bool helpTutorial;

  /// Property map for analytics.
  Map<String, bool> toProperties() => <String, bool>{
        'welcome_offer': welcomeOffer,
        'onboarding_tips': onboardingTips,
        'retention_offer': retentionOffer,
        'loyalty_reward': loyaltyReward,
        're_engagement_offer': reEngagementOffer,
        'winback_offer': winbackOffer,
        'advanced_features': advancedFeatures,
        'premium_upsell': premiumUpsell,
        'rating_prompt': ratingPrompt,
        'notification_request': notificationRequest,
        'help_tutorial': helpTutorial,
      };
}
