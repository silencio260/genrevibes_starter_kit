import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/consent_debug_config.dart';

/// Optional capability of a `ConsentProvider`: showing the consent form as a
/// simulated region would see it.
///
/// A consent platform shows its form only where regulation requires it, so a
/// developer outside those regions never sees it. A provider implements this
/// when its normal request path cannot apply `ConsentDebugConfig` but its
/// platform can be reached directly. `ConsentGate.previewConsentForm` uses it.
///
/// Development only. Implementations must refuse in production builds: forcing
/// a region shows the form to users who would not otherwise see it.
abstract interface class ConsentFormPreviewProvider {
  /// Shows the form as [debug] describes. Completes when it is dismissed.
  ///
  /// The answer is stored like a real one; `ConsentProvider.reset` clears it.
  Future<KitResult<void>> previewConsentForm(ConsentDebugConfig debug);
}
