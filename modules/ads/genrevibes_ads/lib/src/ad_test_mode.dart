import 'package:genrevibes_core/genrevibes_core.dart';

/// A provider that can move a running install between live and test inventory.
///
/// Optional, and discovered with `is`, so an adapter without a test mode still
/// satisfies [AdProvider]. How test inventory is served is the adapter's
/// business: AdMob swaps to Google's sample units, which never mediate, while a
/// mediation SDK would switch on its own test mode.
///
/// Switching must discard inventory loaded in the other mode. A live creative
/// loaded before a developer device was recognised must not be shown after.
abstract interface class AdTestModeProvider {
  /// Whether requests currently go to test inventory.
  bool get isTestMode;

  /// Moves every later request to test inventory, or back to live.
  Future<KitResult<void>> setTestMode(bool enabled);
}
