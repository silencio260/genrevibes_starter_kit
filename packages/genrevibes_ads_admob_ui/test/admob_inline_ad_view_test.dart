import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_admob/genrevibes_ads_admob.dart';
import 'package:genrevibes_ads_admob_ui/genrevibes_ads_admob_ui.dart';

void main() {
  const placement = AdPlacement(id: 'home_banner', format: AdFormat.banner);
  const unit = AdMobAdUnit(placement: placement, adUnitId: 'test-banner');
  const request = AdMobBannerRequest(unit: unit);

  testWidgets('disposes a loaded handle when eligibility becomes false', (
    tester,
  ) async {
    final client = _FakeInlineClient();
    final handle = _FakeHandle();

    await tester.pumpWidget(
      _host(AdMobBannerView(request: request, enabled: true, client: client)),
    );
    client.completeNext(handle);
    await tester.pumpAndSettle();
    expect(find.byKey(_FakeHandle.contentKey), findsOneWidget);

    await tester.pumpWidget(
      _host(AdMobBannerView(request: request, enabled: false, client: client)),
    );
    await tester.pump();

    expect(find.byKey(_FakeHandle.contentKey), findsNothing);
    expect(handle.disposeCalls, 1);
  });

  testWidgets('late load after premium transition is disposed and never shown',
      (
    tester,
  ) async {
    final client = _FakeInlineClient();
    final handle = _FakeHandle();

    await tester.pumpWidget(
      _host(AdMobBannerView(request: request, enabled: true, client: client)),
    );
    await tester.pumpWidget(
      _host(AdMobBannerView(request: request, enabled: false, client: client)),
    );
    client.completeNext(handle);
    await tester.pumpAndSettle();

    expect(handle.disposeCalls, 1);
    expect(find.byKey(_FakeHandle.contentKey), findsNothing);
  });

  testWidgets('removing the widget disposes loaded native resources', (
    tester,
  ) async {
    final client = _FakeInlineClient();
    final handle = _FakeHandle(size: null);
    final nativeRequest = AdMobNativeRequest(
      unit: const AdMobAdUnit(
        placement: AdPlacement(id: 'feed_native', format: AdFormat.native),
        adUnitId: 'test-native',
      ),
    );

    await tester.pumpWidget(
      _host(AdMobNativeView(
        request: nativeRequest,
        enabled: true,
        client: client,
      )),
    );
    client.completeNext(handle);
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.pump();

    expect(handle.disposeCalls, 1);
  });
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    );

final class _FakeInlineClient implements AdMobInlineAdClient {
  final List<Completer<AdMobInlineAdHandle>> _loads =
      <Completer<AdMobInlineAdHandle>>[];

  @override
  Future<AdMobInlineAdHandle> load(
    AdMobInlineAdRequest request, {
    required void Function(AdEvent event) onEvent,
  }) {
    final completer = Completer<AdMobInlineAdHandle>();
    _loads.add(completer);
    return completer.future;
  }

  void completeNext(AdMobInlineAdHandle handle) {
    _loads.removeAt(0).complete(handle);
  }
}

final class _FakeHandle implements AdMobInlineAdHandle {
  _FakeHandle({this.size = const Size(320, 50)});

  static const contentKey = Key('fake-inline-ad');
  int disposeCalls = 0;

  @override
  final Size? size;

  @override
  Widget get widget => const SizedBox(key: contentKey);

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}
