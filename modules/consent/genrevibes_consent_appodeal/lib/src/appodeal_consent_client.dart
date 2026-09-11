import 'dart:async';

import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

/// Consent status as Appodeal's consent manager reports it.
enum AppodealConsentStatus {
  /// Not determined yet.
  unknown,

  /// The user is in a regulated region and has not answered.
  required,

  /// No consent is required for this user.
  notRequired,

  /// The user answered the form.
  obtained,
}

/// Whether the app must offer a privacy-options entry point.
enum AppodealPrivacyOptions {
  /// Consent information has not been updated yet.
  unknown,

  /// An entry point is required.
  required,

  /// No entry point is required.
  notRequired,
}

/// Injectable boundary around Appodeal's consent manager.
abstract interface class AppodealConsentClient {
  /// Updates consent information and loads a form.
  ///
  /// Completes with the status, or with an error when either step fails —
  /// including when no form is offered to this user.
  Future<AppodealConsentStatus> load({
    required String appKey,
    required bool tagForUnderAgeOfConsent,
  });

  /// Presents the form loaded by [load]. Completes when it is dismissed.
  Future<void> show();

  /// Whether a privacy-options entry point is required.
  Future<AppodealPrivacyOptions> privacyOptions();

  /// Presents the privacy-options form. Completes when it is dismissed.
  Future<void> showPrivacyOptionsForm();

  /// Resets stored consent to unknown.
  Future<void> revoke();
}

/// Production client over `Appodeal.ConsentForm`.
final class DefaultAppodealConsentClient implements AppodealConsentClient {
  /// Creates the production client.
  const DefaultAppodealConsentClient();

  @override
  Future<AppodealConsentStatus> load({
    required String appKey,
    required bool tagForUnderAgeOfConsent,
  }) {
    final completer = Completer<AppodealConsentStatus>();
    Appodeal.ConsentForm.load(
      appKey: appKey,
      tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
      onConsentFormLoadSuccess: (status) {
        if (!completer.isCompleted) completer.complete(_mapStatus(status));
      },
      onConsentFormLoadFailure: (error) {
        if (!completer.isCompleted) {
          completer.completeError(StateError(error.description));
        }
      },
    );
    return completer.future;
  }

  @override
  Future<void> show() {
    final completer = Completer<void>();
    Appodeal.ConsentForm.show(
      onConsentFormDismissed: (error) => _dismissed(completer, error),
    );
    return completer.future;
  }

  @override
  Future<AppodealPrivacyOptions> privacyOptions() async {
    final status =
        await Appodeal.ConsentForm.getPrivacyOptionsRequirementStatus();
    return switch (status) {
      PrivacyOptionsRequirementStatus.required =>
        AppodealPrivacyOptions.required,
      PrivacyOptionsRequirementStatus.notRequired =>
        AppodealPrivacyOptions.notRequired,
      PrivacyOptionsRequirementStatus.unknown => AppodealPrivacyOptions.unknown,
    };
  }

  @override
  Future<void> showPrivacyOptionsForm() {
    final completer = Completer<void>();
    Appodeal.ConsentForm.showPrivacyOptionsForm(
      onConsentFormDismissed: (error) => _dismissed(completer, error),
    );
    return completer.future;
  }

  @override
  Future<void> revoke() async => Appodeal.ConsentForm.revoke();

  static void _dismissed(Completer<void> completer, ConsentError? error) {
    if (completer.isCompleted) return;
    if (error == null) {
      completer.complete();
    } else {
      completer.completeError(StateError(error.description));
    }
  }

  static AppodealConsentStatus _mapStatus(ConsentStatus status) =>
      switch (status) {
        ConsentStatus.unknown => AppodealConsentStatus.unknown,
        ConsentStatus.required => AppodealConsentStatus.required,
        ConsentStatus.notRequired => AppodealConsentStatus.notRequired,
        ConsentStatus.obtained => AppodealConsentStatus.obtained,
      };
}
