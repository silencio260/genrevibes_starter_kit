import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:test/test.dart';

void main() {
  group('ConsentState permissions', () {
    test('obtained permits personalized work', () {
      expect(ConsentState.obtained.allowsPersonalizedWork, isTrue);
    });

    test('notRequired permits personalized work', () {
      // Regression guard. Defining permission as "obtained only" silently
      // disables ads and analytics for every user outside a regulated region.
      expect(ConsentState.notRequired.allowsPersonalizedWork, isTrue);
    });

    test('unknown and consentRequired withhold personalized work', () {
      expect(ConsentState.unknown.allowsPersonalizedWork, isFalse);
      expect(ConsentState.consentRequired.allowsPersonalizedWork, isFalse);
    });

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
    test('delegates permission to its state', () {
      final snapshot = ConsentSnapshot(
        state: ConsentState.notRequired,
        observedAt: DateTime.utc(2026),
      );

      expect(snapshot.allowsPersonalizedWork, isTrue);
    });

    test('defaults to no form and no privacy-options requirement', () {
      final snapshot = ConsentSnapshot(
        state: ConsentState.unknown,
        observedAt: DateTime.utc(2026),
      );

      expect(snapshot.formAvailable, isFalse);
      expect(snapshot.privacyOptionsRequired, isFalse);
    });
  });
}
