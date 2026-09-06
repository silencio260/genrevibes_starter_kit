/// Storage keys used by the onboarding controller.
abstract final class OnboardingKeys {
  /// Whether onboarding has been completed.
  static const completed = 'genrevibes.onboarding.completed.v1';

  /// Legacy key names to adopt, mapped from their current equivalents.
  ///
  /// Pass this to a `MigratingKeyValueStore`. Without it, adopting this package
  /// shows onboarding again to every user who had already finished it.
  static const legacyKeys = <String, String>{
    completed: 'has_seen_onboarding',
  };
}
