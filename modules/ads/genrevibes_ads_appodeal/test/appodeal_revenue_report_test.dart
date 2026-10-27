import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_appodeal/genrevibes_ads_appodeal.dart';

void main() {
  group('DefaultAppodealClient.parseRevenueReport', () {
    test('reads a banner view report as a banner', () {
      final report = DefaultAppodealClient.parseRevenueReport(<Object?, Object?>{
        'adType': 64,
        'networkName': 'admob',
        'demandSource': 'admob',
        'adUnitName': 'unit',
        'placement': 'default',
        'revenue': 0.00042,
        'currency': 'USD',
        'revenuePrecision': 'exact',
      });

      expect(report, isNotNull);
      expect(report!.format, AdFormat.banner);
      expect(report.revenue, 0.00042);
      expect(report.currency, 'USD');
      expect(report.networkName, 'admob');
      expect(report.adUnitName, 'unit');
      expect(report.placementName, 'default');
      expect(report.precision, 'exact');
    });

    test('reads missing text fields as empty and integer revenue as double',
        () {
      final report = DefaultAppodealClient.parseRevenueReport(<Object?, Object?>{
        'adType': 64,
        'revenue': 1,
      });

      expect(report, isNotNull);
      expect(report!.revenue, 1.0);
      expect(report.currency, '');
      expect(report.networkName, '');
      expect(report.adUnitName, '');
      expect(report.placementName, '');
      expect(report.precision, '');
    });

    test('rejects arguments without a numeric ad type and revenue', () {
      expect(DefaultAppodealClient.parseRevenueReport(null), isNull);
      expect(DefaultAppodealClient.parseRevenueReport('report'), isNull);
      expect(
        DefaultAppodealClient.parseRevenueReport(<Object?, Object?>{
          'adType': 3,
        }),
        isNull,
      );
      expect(
        DefaultAppodealClient.parseRevenueReport(<Object?, Object?>{
          'adType': '3',
          'revenue': 0.01,
        }),
        isNull,
      );
    });
  });
}
