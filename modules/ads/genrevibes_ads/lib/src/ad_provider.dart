import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/ad_event.dart';
import 'model/ad_format.dart';
import 'model/ad_placement.dart';
import 'model/ad_show_result.dart';

/// Contract implemented by AdMob and future mediation adapters.
abstract interface class AdProvider implements StarterModule {
  /// Stable provider identifier, such as `admob` or `appodeal`.
  String get providerId;

  /// Formats implemented by this adapter.
  Set<AdFormat> get supportedFormats;

  /// Provider events, including paid and click callbacks.
  Stream<AdEvent> get events;

  /// Loads inventory for [placement]. Repeated concurrent loads must be safe.
  Future<KitResult<void>> load(AdPlacement placement);

  /// Whether inventory is ready for [placement].
  bool isReady(AdPlacement placement);

  /// Displays loaded inventory for [placement].
  Future<KitResult<AdShowResult>> show(AdPlacement placement);

  /// Disposes any loaded inventory for [placement].
  Future<KitResult<void>> discard(AdPlacement placement);
}
