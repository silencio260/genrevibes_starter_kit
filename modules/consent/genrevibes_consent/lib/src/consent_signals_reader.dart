import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/consent_signals.dart';

/// Optional capability of a `ConsentProvider`: reading the consent signals its
/// platform stored for ad SDKs.
///
/// A consent answer reaches the ad networks as IAB strings in shared storage,
/// not through the provider, so this is how development tools confirm what
/// the networks will actually see. `ConsentGate.readConsentSignals` uses it.
abstract interface class ConsentSignalsReader {
  /// Reads the stored IAB consent signals.
  Future<KitResult<ConsentSignals>> readConsentSignals();
}
