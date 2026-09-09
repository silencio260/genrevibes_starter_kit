import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Injectable boundary around the Google User Messaging Platform SDK.
///
/// Tests substitute this so they never touch platform channels.
abstract interface class UmpClient {
  /// Refreshes consent information, completing when the SDK reports a result.
  Future<void> requestConsentInfoUpdate(ConsentRequestParameters parameters);

  /// Loads and presents the consent form only when one is required.
  Future<void> loadAndShowConsentFormIfRequired();

  /// Presents the persistent privacy-options form.
  Future<void> showPrivacyOptionsForm();

  /// Returns the current consent status.
  Future<ConsentStatus> getConsentStatus();

  /// Returns whether a privacy-options entry point must be shown.
  Future<PrivacyOptionsRequirementStatus> getPrivacyOptionsRequirementStatus();

  /// Returns whether a consent form is currently available.
  Future<bool> isConsentFormAvailable();

  /// Returns whether ads may be requested under the recorded consent.
  ///
  /// UMP's own answer, and the only honest one. The consent *status* cannot
  /// stand in for it: `obtained` means the form was answered, not that the
  /// user agreed to anything.
  Future<bool> canRequestAds();

  /// Clears stored consent. Intended for development and QA only.
  Future<void> reset();
}

/// Production UMP client.
final class DefaultUmpClient implements UmpClient {
  /// Creates a client over the shared [ConsentInformation] instance.
  const DefaultUmpClient();

  ConsentInformation get _information => ConsentInformation.instance;

  @override
  Future<void> requestConsentInfoUpdate(
    ConsentRequestParameters parameters,
  ) {
    // The SDK is callback-based here; bridge it to a Future exactly once.
    final completer = Completer<void>();
    _information.requestConsentInfoUpdate(
      parameters,
      () {
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('${error.errorCode}: ${error.message}'),
          );
        }
      },
    );
    return completer.future;
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() {
    // Google's own helper. It presents the form only while consent is still
    // required, which is what prevents the dismissal/re-show loop that manual
    // load-then-show implementations fall into.
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (completer.isCompleted) return;
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          StateError('${error.errorCode}: ${error.message}'),
        );
      }
    });
    return completer.future;
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (completer.isCompleted) return;
      if (error == null) {
        completer.complete();
      } else {
        completer.completeError(
          StateError('${error.errorCode}: ${error.message}'),
        );
      }
    });
    return completer.future;
  }

  @override
  Future<ConsentStatus> getConsentStatus() => _information.getConsentStatus();

  @override
  Future<PrivacyOptionsRequirementStatus>
      getPrivacyOptionsRequirementStatus() =>
          _information.getPrivacyOptionsRequirementStatus();

  @override
  Future<bool> isConsentFormAvailable() =>
      _information.isConsentFormAvailable();

  @override
  Future<bool> canRequestAds() => _information.canRequestAds();

  @override
  Future<void> reset() => _information.reset();
}
