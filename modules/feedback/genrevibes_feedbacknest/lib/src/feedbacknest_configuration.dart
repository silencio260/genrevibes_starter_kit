/// FeedbackNest connection settings.
final class FeedbackNestConfiguration {
  /// Creates a configuration.
  const FeedbackNestConfiguration({
    required this.apiKey,
    this.userIdentifier = '',
  });

  /// Project API key.
  ///
  /// Supply this from the application's build-time configuration. Never commit
  /// it to a package or a repository.
  final String apiKey;

  /// Stable identifier correlating a user's reports across submissions.
  ///
  /// Leave empty to stay anonymous. Do not put an email or any other directly
  /// identifying value here unless the user asked to be identified.
  final String userIdentifier;

  /// Whether the configuration carries a usable key.
  bool get isValid => apiKey.trim().isNotEmpty;
}
