/// What happened when a user who agreed to rate was sent to review.
///
/// Platform review APIs never report whether their sheet appeared or whether
/// the user rated, so this records only what the app can observe.
final class ReviewFlowReport {
  /// Creates a report.
  const ReviewFlowReport({
    required this.sheetRequested,
    required this.listingOpened,
    this.sheetDuration,
  });

  /// Whether the in-app review request returned without error. Not proof that
  /// a sheet was displayed.
  final bool sheetRequested;

  /// How long the in-app review request took to return, when it was made.
  ///
  /// A shown sheet keeps the request open until the user closes it, so a very
  /// short duration usually means the platform showed nothing. Log it so the
  /// split can be measured on real devices.
  final Duration? sheetDuration;

  /// Whether the store listing was opened after the request.
  final bool listingOpened;

  @override
  String toString() =>
      'ReviewFlowReport(sheetRequested: $sheetRequested, '
      'sheetDurationMs: ${sheetDuration?.inMilliseconds}, '
      'listingOpened: $listingOpened)';
}
