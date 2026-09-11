import 'package:genrevibes_ads/genrevibes_ads.dart';

/// A logical placement served through an Appodeal placement.
final class AppodealPlacement {
  /// Creates an Appodeal placement mapping.
  const AppodealPlacement({required this.placement, this.name = 'default'});

  /// Logical placement used by application code and policy.
  final AdPlacement placement;

  /// Placement name in the Appodeal dashboard.
  ///
  /// `default` exists in every Appodeal app. A named placement carries its own
  /// dashboard rules, such as a frequency cap, and has to be created in the
  /// dashboard before it is used here.
  final String name;
}

/// Application-owned Appodeal configuration.
///
/// Appodeal has no ad-unit IDs. Inventory belongs to the app key and the ad
/// type; placements only select dashboard rules. So, unlike AdMob, nothing here
/// changes between live and test inventory — see `AppodealAdProvider`.
final class GenRevibesAppodealConfiguration {
  /// Creates Appodeal configuration.
  GenRevibesAppodealConfiguration({
    required this.appKey,
    required Iterable<AppodealPlacement> placements,
    this.initializationTimeout = const Duration(seconds: 30),
    this.loadTimeout = const Duration(seconds: 60),
    this.fullScreenShowTimeout = const Duration(minutes: 2),
    this.verboseLogging = false,
    this.childDirectedTreatment = false,
  }) : placements = _index(placements);

  /// Appodeal app key for the platform this build runs on.
  ///
  /// Android and iOS apps have separate keys in the dashboard.
  final String appKey;

  /// Placements indexed by logical placement ID.
  final Map<String, AppodealPlacement> placements;

  /// Maximum wait for the SDK to report initialization.
  final Duration initializationTimeout;

  /// Maximum wait for a full-screen load to be reported.
  final Duration loadTimeout;

  /// Maximum wait for a full-screen dismissal or failure callback.
  final Duration fullScreenShowTimeout;

  /// Verbose SDK logging under the `Appodeal` logcat tag. Development only.
  final bool verboseLogging;

  /// Marks the app as directed at children, which restricts data collection.
  final bool childDirectedTreatment;

  /// Formats the SDK is initialized for.
  Set<AdFormat> get formats => <AdFormat>{
        for (final configured in placements.values) configured.placement.format,
      };

  /// Looks up the Appodeal placement for [placement].
  AppodealPlacement? placementFor(AdPlacement placement) {
    final configured = placements[placement.id];
    return configured?.placement.format == placement.format ? configured : null;
  }

  /// The placement an SDK report for [format] belongs to.
  ///
  /// The one named [name] when there is one, otherwise the first placement of
  /// that format. Appodeal reports banner callbacks and revenue per format, not
  /// per view, so this is the best attribution the SDK allows.
  AppodealPlacement? placementReportedAs(AdFormat format, [String? name]) {
    AppodealPlacement? first;
    for (final configured in placements.values) {
      if (configured.placement.format != format) continue;
      if (name != null && configured.name == name) return configured;
      first ??= configured;
    }
    return first;
  }

  static Map<String, AppodealPlacement> _index(
    Iterable<AppodealPlacement> values,
  ) {
    final indexed = <String, AppodealPlacement>{};
    for (final configured in values) {
      if (indexed.containsKey(configured.placement.id)) {
        throw ArgumentError.value(
          configured.placement.id,
          'placements',
          'Logical Appodeal placement IDs must be unique.',
        );
      }
      indexed[configured.placement.id] = configured;
    }
    return Map<String, AppodealPlacement>.unmodifiable(indexed);
  }

  @override
  String toString() => 'GenRevibesAppodealConfiguration('
      'placements: ${placements.keys.toList()}, '
      'verboseLogging: $verboseLogging)';
}
