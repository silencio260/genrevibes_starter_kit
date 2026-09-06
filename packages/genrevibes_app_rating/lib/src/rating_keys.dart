/// Storage keys used by the rating coordinator.
///
/// Current keys are namespaced. The legacy names are the ones commonly written
/// by hand-rolled rating services before this package existed; mapping them
/// means adopting the package does not reset eligibility and re-prompt every
/// existing user on the release that adopts it.
abstract final class RatingKeys {
  /// First launch timestamp, in milliseconds since epoch.
  static const installedAt = 'genrevibes.app_rating.installed_at.v1';

  /// Number of times the app has been opened.
  static const appOpens = 'genrevibes.app_rating.app_opens.v1';

  /// Whether the user asked never to be prompted again.
  static const optedOut = 'genrevibes.app_rating.opted_out.v1';

  /// Last prompt timestamp, in milliseconds since epoch.
  static const lastPromptedAt = 'genrevibes.app_rating.last_prompted_at.v1';

  /// Prefix for named trigger counters.
  static const triggerPrefix = 'genrevibes.app_rating.trigger.';

  /// Returns the storage key counting occurrences of [name].
  static String trigger(String name) => '$triggerPrefix$name.v1';

  /// Legacy key names to adopt, mapped from their current equivalents.
  ///
  /// Pass this to a `MigratingKeyValueStore`. Extend it with an application's
  /// own trigger keys where those differ.
  static const legacyKeys = <String, String>{
    installedAt: 'app_install_date',
    appOpens: 'app_opens_count',
    optedOut: 'never_show_rating',
    lastPromptedAt: 'last_rating_shown_date',
  };
}
