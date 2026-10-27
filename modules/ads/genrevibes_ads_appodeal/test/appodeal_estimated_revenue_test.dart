import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_appodeal/genrevibes_ads_appodeal.dart';

const _interstitial = AdPlacement(
  id: 'test_interstitial',
  format: AdFormat.interstitial,
);

const _wait = Duration(milliseconds: 40);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeAppodealClient client;
  late List<AdEvent> paid;

  Future<AppodealAdProvider> start({bool testMode = false}) async {
    final provider = AppodealAdProvider(
      configuration: GenRevibesAppodealConfiguration(
        appKey: 'key',
        placements: const [AppodealPlacement(placement: _interstitial)],
        revenueReportWait: _wait,
      ),
      client: client,
      testMode: testMode,
    );
    provider.events
        .where((event) => event.type == AdEventType.paid)
        .listen(paid.add);
    expect((await provider.initialize()).isSuccess, isTrue);
    expect((await provider.load(_interstitial)).isSuccess, isTrue);
    return provider;
  }

  Future<void> showOnce(AppodealAdProvider provider) async {
    expect((await provider.show(_interstitial)).isSuccess, isTrue);
  }

  Future<void> pastTheWait() => Future<void>.delayed(_wait * 3);

  AppodealRevenueReport report(double revenue) => AppodealRevenueReport(
        format: AdFormat.interstitial,
        placementName: 'default',
        revenue: revenue,
        currency: 'USD',
        networkName: 'Max',
        adUnitName: 'unit',
        precision: 'exact',
      );

  void hideApp() {
    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    client = _FakeAppodealClient();
    paid = <AdEvent>[];
  });

  tearDown(() {
    if (binding.lifecycleState == AppLifecycleState.hidden) {
      binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
  });

  test('estimates at once when the app is hidden after the ad closes',
      () async {
    final provider = await start();
    await showOnce(provider);
    hideApp();
    await Future<void>.delayed(Duration.zero);

    expect(paid, hasLength(1));
    expect(
      paid.single.revenue!.precision,
      AppodealAdProvider.estimatedRevenuePrecision,
    );

    // The cancelled wait does not count it a second time.
    await pastTheWait();
    expect(paid, hasLength(1));
    await provider.dispose();
  });

  test('a full-screen ad hiding the app keeps waiting for the report',
      () async {
    client.autoClose = false;
    final provider = await start();
    final shown = provider.show(_interstitial);
    await Future<void>.delayed(Duration.zero);
    hideApp();
    await Future<void>.delayed(Duration.zero);
    client.reportRevenue(report(0.0031));
    client.closeAd(AdFormat.interstitial);
    expect((await shown).isSuccess, isTrue);

    await pastTheWait();
    expect(paid, hasLength(1));
    expect(paid.single.revenue!.precision, 'exact');
    await provider.dispose();
  });

  test('estimates revenue from predicted eCPM when no report arrives',
      () async {
    final provider = await start();
    await showOnce(provider);
    expect(paid, isEmpty);

    await pastTheWait();

    expect(paid, hasLength(1));
    final revenue = paid.single.revenue!;
    expect(revenue.valueMicros, 2280);
    expect(revenue.value, closeTo(0.00228, 1e-9));
    expect(revenue.currencyCode, 'USD');
    expect(revenue.precision, AppodealAdProvider.estimatedRevenuePrecision);
    expect(paid.single.placement, _interstitial);
    await provider.dispose();
  });

  test('a report within the wait replaces the estimate', () async {
    final provider = await start();
    await showOnce(provider);
    client.reportRevenue(report(0.0031));

    await pastTheWait();

    expect(paid, hasLength(1));
    expect(paid.single.revenue!.valueMicros, 3100);
    expect(paid.single.revenue!.precision, 'exact');
    await provider.dispose();
  });

  test('a report after the estimate is not counted again', () async {
    final provider = await start();
    await showOnce(provider);
    await pastTheWait();
    client.reportRevenue(report(0.0031));

    expect(paid, hasLength(1));
    expect(
      paid.single.revenue!.precision,
      AppodealAdProvider.estimatedRevenuePrecision,
    );
    await provider.dispose();
  });

  test('a report with no impression waiting or estimated is counted',
      () async {
    final provider = await start();
    client.reportRevenue(report(0.0031));

    expect(paid, hasLength(1));
    expect(paid.single.revenue!.precision, 'exact');
    await provider.dispose();
  });

  test('test inventory is never estimated', () async {
    final provider = await start(testMode: true);
    await showOnce(provider);
    await pastTheWait();

    expect(paid, isEmpty);
    expect(client.ecpmReads, 0);
    await provider.dispose();
  });

  test('no estimate without a predicted eCPM', () async {
    client.ecpm = 0;
    final provider = await start();
    await showOnce(provider);
    await pastTheWait();

    expect(paid, isEmpty);
    await provider.dispose();
  });
}

/// Serves interstitials that show at once and, unless [autoClose] is off,
/// close at once.
final class _FakeAppodealClient implements AppodealClient {
  final StreamController<AppodealCallback> _callbacks =
      StreamController<AppodealCallback>.broadcast(sync: true);
  final StreamController<AppodealRevenueReport> _revenue =
      StreamController<AppodealRevenueReport>.broadcast(sync: true);

  double ecpm = 2.28;
  int ecpmReads = 0;
  bool autoClose = true;

  void reportRevenue(AppodealRevenueReport report) => _revenue.add(report);

  void closeAd(AdFormat format) => _callbacks.add(
        AppodealCallback(type: AppodealCallbackType.closed, format: format),
      );

  @override
  Stream<AppodealCallback> get callbacks => _callbacks.stream;

  @override
  Stream<AppodealRevenueReport> get revenue => _revenue.stream;

  @override
  Future<List<String>> initialize({
    required String appKey,
    required Set<AdFormat> formats,
    required bool testMode,
    required bool verboseLogging,
    required bool childDirectedTreatment,
  }) async =>
      const <String>[];

  @override
  Future<bool> isInitialized(AdFormat format) async => true;

  @override
  Future<void> cache(AdFormat format) async {}

  @override
  Future<bool> isLoaded(AdFormat format) async => true;

  @override
  Future<bool> canShow(AdFormat format, String placementName) async => true;

  @override
  Future<bool> show(AdFormat format, String placementName) async {
    _callbacks.add(
      AppodealCallback(type: AppodealCallbackType.shown, format: format),
    );
    if (autoClose) closeAd(format);
    return true;
  }

  @override
  Future<double> predictedEcpm(AdFormat format) async {
    ecpmReads++;
    return ecpm;
  }

  @override
  Future<void> setUserId(String userId) async {}

  @override
  Future<void> dispose() async {
    await _callbacks.close();
    await _revenue.close();
  }
}
