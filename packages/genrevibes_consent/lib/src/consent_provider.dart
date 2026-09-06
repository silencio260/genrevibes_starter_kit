import 'package:genrevibes_core/genrevibes_core.dart';

import 'model/consent_snapshot.dart';

/// Contract implemented by Google UMP and other consent-platform adapters.
///
/// Consent platforms are normally bundled with an ad network's SDK, so each ad
/// network ships its own adapter. Applications depend on this contract and
/// select one adapter during composition.
abstract interface class ConsentProvider implements StarterModule {
  /// Stable provider identifier, such as `ump`.
  String get providerId;

  /// Most recent consent snapshot.
  ConsentSnapshot get snapshot;

  /// Emits refreshed snapshots as consent changes.
  Stream<ConsentSnapshot> get snapshotChanges;

  /// Requests an updated consent status and presents the form when required.
  ///
  /// Implementations must complete after a single presentation. Re-requesting
  /// because the user dismissed a still-required form re-presents it forever.
  Future<KitResult<ConsentSnapshot>> requestConsent();

  /// Presents the persistent privacy-options form.
  ///
  /// Used by a settings screen so a user can revisit earlier choices.
  Future<KitResult<void>> showPrivacyOptions();

  /// Clears stored consent. Intended for development and QA only.
  Future<KitResult<void>> reset();
}
