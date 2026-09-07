/// What a user is trying to do when they write to the developer.
///
/// Providers route these differently: feedback usually lands in a product
/// backlog, while a support request expects a reply. Collapsing them loses that
/// distinction and leaves people waiting for answers that never come.
enum FeedbackKind {
  /// Unsolicited product feedback.
  feedback,

  /// A support or contact request that expects a response.
  contact,
}
