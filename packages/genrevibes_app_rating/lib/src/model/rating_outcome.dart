/// What the user chose when a rating prompt was shown.
enum RatingOutcome {
  /// Deferred. Ask again after the snooze period.
  maybeLater,

  /// Declined permanently. Never ask again.
  never,

  /// Gave a rating.
  submitted,
}

/// What the application should do after a rating prompt closes.
enum RatingFollowUp {
  /// Do nothing further.
  none,

  /// Send the user to the store review flow.
  storeReview,

  /// Collect private feedback instead of a public review.
  feedback,
}
