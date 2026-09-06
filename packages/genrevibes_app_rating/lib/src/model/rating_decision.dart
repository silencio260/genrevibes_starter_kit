/// Why a rating prompt was withheld.
enum RatingBlockReason {
  /// The user asked never to be prompted again.
  optedOut,

  /// The app has not been installed long enough.
  installTooRecent,

  /// The app has not been opened enough times.
  notEnoughAppOpens,

  /// A prompt was shown too recently.
  promptedRecently,

  /// Stored eligibility state could not be read.
  stateUnavailable,
}

/// Outcome of evaluating rating eligibility.
final class RatingDecision {
  /// Creates an allowing decision.
  const RatingDecision.allowed() : blockReason = null;

  /// Creates a blocking decision.
  const RatingDecision.blocked(RatingBlockReason this.blockReason);

  /// Why the prompt was withheld, or `null` when it is permitted.
  final RatingBlockReason? blockReason;

  /// Whether the prompt may be shown.
  bool get isAllowed => blockReason == null;

  @override
  String toString() {
    return isAllowed
        ? 'RatingDecision.allowed()'
        : 'RatingDecision.blocked(${blockReason!.name})';
  }
}
