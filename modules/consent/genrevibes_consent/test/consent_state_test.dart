import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:test/test.dart';

void main() {
  group('ConsentState permissions', () {
    test('only consentRequired asks for a form', () {
      expect(ConsentState.consentRequired.requiresForm, isTrue);
      expect(ConsentState.obtained.requiresForm, isFalse);
      expect(ConsentState.notRequired.requiresForm, isFalse);
      expect(ConsentState.unknown.requiresForm, isFalse);
    });
  });

  group('ConsentDebugConfig', () {
    test('is inactive by default so production builds are unaffected', () {
      expect(const ConsentDebugConfig().isActive, isFalse);
    });

    test('is active when a geography or test device is supplied', () {
      expect(
        const ConsentDebugConfig(
          geography: ConsentDebugGeography.europeanEconomicArea,
        ).isActive,
        isTrue,
      );
      expect(
        const ConsentDebugConfig(testDeviceIds: <String>['ABC']).isActive,
        isTrue,
      );
    });
  });

  group('ConsentSnapshot', () {
    test('does not infer ad permission from a completed form', () {
      // Regression guard for the bug this API replaced. `obtained` means the
      // user answered the form; a user who rejected every purpose reaches this
      // state exactly like one who accepted. Reading agreement out of the
      // state claims consent from people who refused it.
      final refused = ConsentSnapshot(
        state: ConsentState.obtained,
        observedAt: DateTime.utc(2026),
      );

      expect(refused.canRequestAds, isFalse);
    });

    test('carries the platform answer when the platform gives one', () {
      final allowed = ConsentSnapshot(
        state: ConsentState.obtained,
        observedAt: DateTime.utc(2026),
        canRequestAds: true,
      );

      expect(allowed.canRequestAds, isTrue);
    });

    test('defaults to no form and no privacy-options requirement', () {
      final snapshot = ConsentSnapshot(
        state: ConsentState.unknown,
        observedAt: DateTime.utc(2026),
      );

      expect(snapshot.formAvailable, isFalse);
      expect(snapshot.privacyOptionsRequired, isFalse);
      expect(snapshot.canRequestAds, isFalse);
    });
  });
}
