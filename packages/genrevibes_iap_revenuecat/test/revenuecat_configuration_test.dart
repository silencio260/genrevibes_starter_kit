import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_iap_revenuecat/genrevibes_iap_revenuecat.dart';

void main() {
  test('configuration rejects blank key for the current platform', () {
    const configuration = RevenueCatConfiguration(
      androidApiKey: ' ',
      iosApiKey: ' ',
      macosApiKey: ' ',
      webApiKey: ' ',
    );

    expect(configuration.apiKeyForCurrentPlatform(), isNull);
  });
}
