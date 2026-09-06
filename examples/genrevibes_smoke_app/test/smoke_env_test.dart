import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_smoke_app/smoke_env.dart';

void main() {
  group('SmokeEnv safety properties', () {
    test('every credential-backed provider is unconfigured by default', () {
      // No --dart-define-from-file is supplied during tests, so an absent key
      // must degrade to "not configured" rather than a committed fallback.
      expect(SmokeEnv.revenueCatConfiguration(), isNull);
      expect(SmokeEnv.oneSignalConfiguration(), isNull);
      expect(SmokeEnv.postHogConfiguration(), isNull);
      expect(SmokeEnv.mixpanelConfiguration(), isNull);
    });

    test('no credential constant carries a committed default', () {
      expect(SmokeEnv.revenueCatAndroidKey, isEmpty);
      expect(SmokeEnv.revenueCatIosKey, isEmpty);
      expect(SmokeEnv.oneSignalAppId, isEmpty);
      expect(SmokeEnv.postHogApiKey, isEmpty);
      expect(SmokeEnv.mixpanelToken, isEmpty);
    });

    test('ad units are always Google test units, never a real account', () {
      // Serving a production unit from a non-store build is invalid traffic
      // and can suspend the AdMob account that owns the unit.
      const googleTestAccount = 'ca-app-pub-3940256099942544';
      final configuration = SmokeEnv.adMobConfiguration();

      expect(configuration.adUnits, isNotEmpty);
      for (final unit in configuration.adUnits.values) {
        expect(
          unit.adUnitId,
          startsWith(googleTestAccount),
          reason: '${unit.placement.id} must use a Google test unit',
        );
      }
    });

    test('AdMob reports configured because its test units are committed', () {
      expect(SmokeEnv.status['AdMob (committed test units)'], isTrue);
      expect(SmokeEnv.status['RevenueCat'], isFalse);
    });
  });
}
