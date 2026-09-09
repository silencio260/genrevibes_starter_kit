import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_consent/genrevibes_consent.dart';
import 'package:genrevibes_consent_test/genrevibes_consent_test.dart';
import 'package:genrevibes_consent_ump/genrevibes_consent_ump.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  runConsentProviderContractTests(
    providerName: 'UMP',
    createProvider: () async => UmpConsentProvider(client: _FakeUmpClient()),
  );

  group('UMP consent status mapping', () {
    test('notRequired maps to notRequired', () {
      // Regression guard for the classic bug: collapsing "no consent needed"
      // into a denial disables ads for every user outside a regulated region.
      expect(
        mapUmpConsentStatus(ConsentStatus.notRequired),
        ConsentState.notRequired,
      );
    });

    test('obtained maps to obtained', () {
      expect(
          mapUmpConsentStatus(ConsentStatus.obtained), ConsentState.obtained);
    });

    test('required maps to a state that asks for a form', () {
      final mapped = mapUmpConsentStatus(ConsentStatus.required);

      expect(mapped, ConsentState.consentRequired);
      expect(mapped.requiresForm, isTrue);
    });

    test('no mapped state claims to answer whether ads may be requested', () {
      // The mapping describes the flow only. Deriving permission from it is
      // what previously served personalized ads to users who refused them.
      for (final status in ConsentStatus.values) {
        expect(mapUmpConsentStatus(status).requiresForm,
            status == ConsentStatus.required);
      }
    });

    test('privacy options are required only when the SDK says so', () {
      expect(
        mapUmpPrivacyOptionsRequired(PrivacyOptionsRequirementStatus.required),
        isTrue,
      );
      expect(
        mapUmpPrivacyOptionsRequired(
            PrivacyOptionsRequirementStatus.notRequired),
        isFalse,
      );
      expect(
        mapUmpPrivacyOptionsRequired(PrivacyOptionsRequirementStatus.unknown),
        isFalse,
      );
    });
  });

  group('UMP debug configuration', () {
    test('an inactive config produces no debug settings', () {
      final parameters = mapUmpDebugConfig(const ConsentDebugConfig());

      expect(parameters.consentDebugSettings, isNull);
    });

    test('an EEA config produces debug settings', () {
      final parameters = mapUmpDebugConfig(
        const ConsentDebugConfig(
          geography: ConsentDebugGeography.europeanEconomicArea,
          testDeviceIds: <String>['ABC123'],
        ),
      );

      expect(parameters.consentDebugSettings, isNotNull);
      expect(
        parameters.consentDebugSettings!.debugGeography,
        DebugGeography.debugGeographyEea,
      );
    });
  });

  group('UmpConsentProvider', () {
    test('presents the form only through the SDK helper that guards re-showing',
        () async {
      final client = _FakeUmpClient();
      final provider = UmpConsentProvider(client: client);
      await provider.initialize();

      await provider.requestConsent();
      await provider.requestConsent();

      // Two explicit requests, two helper calls, and no manual load/show pair.
      // The helper itself declines to present when consent is already settled.
      expect(client.loadAndShowCount, 2);
    });

    test('reports the privacy-options requirement from the SDK', () async {
      final client = _FakeUmpClient()
        ..privacyOptions = PrivacyOptionsRequirementStatus.required;
      final provider = UmpConsentProvider(client: client);
      await provider.initialize();

      final result = await provider.requestConsent();

      final snapshot = result.fold(
        onSuccess: (value) => value,
        onFailure: (_) => null,
      );
      expect(snapshot!.privacyOptionsRequired, isTrue);
    });

    test('an SDK fault becomes a provider error and degrades health', () async {
      final client = _FakeUmpClient()..failWith = StateError('1: network');
      final provider = UmpConsentProvider(client: client);
      await provider.initialize();

      final result = await provider.requestConsent();

      expect(result.isFailure, isTrue);
      result.fold(
        onSuccess: (_) => fail('expected a failure'),
        onFailure: (error) {
          expect(error.code, KitErrorCode.provider);
          expect(error.providerCode, 'ump_request_consent');
        },
      );
      expect(provider.health.state, ModuleState.degraded);
    });

    test('reset returns the snapshot to unknown', () async {
      final client = _FakeUmpClient();
      final provider = UmpConsentProvider(client: client);
      await provider.initialize();
      await provider.requestConsent();

      expect((await provider.reset()).isSuccess, isTrue);
      expect(provider.snapshot.state, ConsentState.unknown);
    });

    test('emits snapshot changes for the gate to observe', () async {
      final provider = UmpConsentProvider(client: _FakeUmpClient());
      await provider.initialize();
      final emitted = <ConsentState>[];
      provider.snapshotChanges.listen((s) => emitted.add(s.state));

      await provider.requestConsent();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, <ConsentState>[ConsentState.obtained]);
    });

    test('reads ad permission from the SDK, not from the consent status',
        () async {
      // A user who opened the form and refused every purpose is `obtained`
      // just like one who accepted. Only the SDK knows the difference.
      final client = _FakeUmpClient()
        ..status = ConsentStatus.obtained
        ..adsAllowed = false;
      final provider = UmpConsentProvider(client: client);

      await provider.initialize();
      await provider.requestConsent();

      expect(provider.snapshot.state, ConsentState.obtained);
      expect(provider.snapshot.canRequestAds, isFalse);

      client.adsAllowed = true;
      await provider.requestConsent();

      expect(provider.snapshot.canRequestAds, isTrue);
    });

    test('composes with ConsentGate to release dependent modules', () async {
      final gate = ConsentGate(
        provider: UmpConsentProvider(client: _FakeUmpClient()),
      );

      await gate.initialize();

      expect((await gate.ready).canRequestAds, isTrue);
    });
  });
}

final class _FakeUmpClient implements UmpClient {
  ConsentStatus status = ConsentStatus.obtained;
  PrivacyOptionsRequirementStatus privacyOptions =
      PrivacyOptionsRequirementStatus.notRequired;
  bool formAvailable = false;
  bool adsAllowed = true;
  Object? failWith;
  int loadAndShowCount = 0;

  void _maybeThrow() {
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<void> requestConsentInfoUpdate(
    ConsentRequestParameters parameters,
  ) async {
    _maybeThrow();
  }

  @override
  Future<void> loadAndShowConsentFormIfRequired() async {
    _maybeThrow();
    loadAndShowCount++;
  }

  @override
  Future<void> showPrivacyOptionsForm() async => _maybeThrow();

  @override
  Future<ConsentStatus> getConsentStatus() async => status;

  @override
  Future<PrivacyOptionsRequirementStatus>
      getPrivacyOptionsRequirementStatus() async => privacyOptions;

  @override
  Future<bool> isConsentFormAvailable() async => formAvailable;

  @override
  Future<bool> canRequestAds() async {
    _maybeThrow();
    return adsAllowed;
  }

  @override
  Future<void> reset() async => _maybeThrow();
}
