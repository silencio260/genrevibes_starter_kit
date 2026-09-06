import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_admob/genrevibes_ads_admob.dart';
import 'package:genrevibes_ads_test/genrevibes_ads_test.dart';

void main() {
  const placement = AdPlacement(
    id: 'download_complete',
    format: AdFormat.interstitial,
  );

  runAdProviderContractTests(
    providerName: 'AdMob',
    createProvider: () async {
      final provider = AdMobAdProvider(
        configuration: GenreVibesAdMobConfiguration(
          adUnits: const <AdMobAdUnit>[
            AdMobAdUnit(placement: placement, adUnitId: 'test-unit'),
          ],
        ),
        client: _FakeAdMobClient(),
      );
      return (provider: provider, placement: placement);
    },
  );

  test('unknown placement fails without calling the client', () async {
    final client = _FakeAdMobClient();
    final provider = AdMobAdProvider(
      configuration: GenreVibesAdMobConfiguration(
        adUnits: const <AdMobAdUnit>[
          AdMobAdUnit(placement: placement, adUnitId: 'test-unit'),
        ],
      ),
      client: client,
    );
    await provider.initialize();

    final result = await provider.load(
      const AdPlacement(id: 'other', format: AdFormat.interstitial),
    );

    expect(result.isFailure, isTrue);
    expect(client.loadCalls, 0);
  });
}

final class _FakeAdMobClient implements AdMobClient {
  final StreamController<AdEvent> _events =
      StreamController<AdEvent>.broadcast();
  final Set<AdPlacement> _ready = <AdPlacement>{};
  int loadCalls = 0;

  @override
  Stream<AdEvent> get events => _events.stream;

  @override
  Future<void> discard(AdPlacement placement) async {
    _ready.remove(placement);
  }

  @override
  Future<void> dispose() async {
    _ready.clear();
    await _events.close();
  }

  @override
  Future<void> initialize(GenreVibesAdMobConfiguration configuration) async {}

  @override
  bool isReady(AdPlacement placement) => _ready.contains(placement);

  @override
  Future<void> load(AdMobAdUnit unit) async {
    loadCalls += 1;
    _ready.add(unit.placement);
  }

  @override
  Future<AdShowResult> show(AdPlacement placement) async {
    if (!_ready.remove(placement)) {
      return const AdShowResult(status: AdShowStatus.notReady);
    }
    return const AdShowResult(status: AdShowStatus.shown);
  }
}
