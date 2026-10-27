import 'package:genrevibes_core/genrevibes_core.dart';

/// A provider that can tell its ad network which app user is watching.
///
/// Optional, and discovered with `is`, so an adapter without the concept still
/// satisfies [AdProvider]. Networks that confirm rewards server-to-server
/// (Appodeal's S2S reward callback, AdMob's server-side verification) send this
/// id back to the app's backend with each reward, so the backend knows whose
/// account to credit.
///
/// Use an opaque account id such as a Firebase Auth uid. Never an email, phone
/// number, name or anything else that identifies a person: networks forbid it.
abstract interface class AdUserIdProvider {
  /// Sets the id sent with later ad requests and reward callbacks.
  ///
  /// Null clears it, for example on sign-out, so the next account's rewards are
  /// never reported under the previous user.
  Future<KitResult<void>> setUserId(String? userId);
}
