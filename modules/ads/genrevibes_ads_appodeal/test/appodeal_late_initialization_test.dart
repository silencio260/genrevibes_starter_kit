import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_appodeal/genrevibes_ads_appodeal.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

const _interstitial = AdPlacement(
  id: 'test_interstitial',
  format: AdFormat.interstitial,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppodealAdProvider providerFor(_SlowAppodealClient client) =>
      AppodealAdProvider(
        configuration: GenRevibesAppodealConfiguration(
          appKey: 'key',
          placements: const [AppodealPlacement(placement: _interstitial)],
          initializationTimeout: const Duration(milliseconds: 20),
        ),
        client: client,
        testMode: false,
      );

  test('a start that outlasts the timeout becomes ready when it finishes',
      () async {
    final client = _SlowAppodealClient();
    final provider = providerFor(client);

    final first = await provider.initialize();
    expect(first.isFailure, isTrue);
    expect(provider.health.state, ModuleState.failed);

    client.finish();
    await pumpEventQueue();

    expect(provider.health.state, ModuleState.ready);
    expect(provider.health.isOperational, isTrue);
    expect(client.initializeCalls, 1);
    await provider.dispose();
  });

  test('a retry after a timeout waits on the same SDK start', () async {
    final client = _SlowAppodealClient();
    final provider = providerFor(client);

    expect((await provider.initialize()).isFailure, isTrue);
    final retry = provider.initialize();
    client.finish();

    expect((await retry).isSuccess, isTrue);
    expect(provider.health.state, ModuleState.ready);
    expect(client.initializeCalls, 1);
    await provider.dispose();
  });
}

/// An Appodeal client whose SDK start completes only when [finish] is called.
final class _SlowAppodealClient implements AppodealClient {
  final Completer<List<String>> _started = Completer<List<String>>();
  int initializeCalls = 0;

  void finish() => _started.complete(const <String>[]);

  @override
  Stream<AppodealCallback> get callbacks => const Stream.empty();

  @override
  Stream<AppodealRevenueReport> get revenue => const Stream.empty();

  @override
  Future<List<String>> initialize({
    required String appKey,
    required Set<AdFormat> formats,
    required bool testMode,
    required bool verboseLogging,
    required bool childDirectedTreatment,
  }) {
    initializeCalls++;
    return _started.future;
  }

  @override
  Future<bool> isInitialized(AdFormat format) async => true;

  @override
  Future<void> cache(AdFormat format) async {}

  @override
  Future<bool> isLoaded(AdFormat format) async => false;

  @override
  Future<bool> canShow(AdFormat format, String placementName) async => false;

  @override
  Future<bool> show(AdFormat format, String placementName) async => false;

  @override
  Future<double> predictedEcpm(AdFormat format) async => 0;

  @override
  Future<void> setUserId(String userId) async {}

  @override
  Future<void> dispose() async {}
}
