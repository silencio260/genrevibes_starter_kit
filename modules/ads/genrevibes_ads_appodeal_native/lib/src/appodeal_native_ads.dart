import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

/// Native callbacks Appodeal reports, once for the whole app.
enum AppodealNativeEventType {
  /// Native inventory finished loading.
  loaded,

  /// Loading failed.
  failedToLoad,

  /// A native ad was shown.
  shown,

  /// A native ad could not be shown.
  showFailed,

  /// A native ad was clicked.
  clicked,

  /// Loaded native inventory expired.
  expired,
}

/// Something that happened to one native ad view on Android.
enum AppodealNativeViewEvent {
  /// The view took an ad and registered it with the SDK.
  registered,

  /// No loaded ad was left for the view.
  unavailable,

  /// The SDK or a dashboard rule refused to show the ad.
  refused,
}

/// Appodeal's native inventory, as this package's Android plugin reports it.
///
/// Initialization, test mode, gating and caching are `AppodealAdProvider`'s;
/// this reports native callbacks and backs `AppodealNativeAdView`. It is a
/// single instance because Appodeal's native callbacks are app-wide.
final class AppodealNativeAds {
  AppodealNativeAds._();

  /// The instance.
  static final AppodealNativeAds instance = AppodealNativeAds._();

  static const MethodChannel _channel =
      MethodChannel('com.genrevibes/appodeal_native');

  final StreamController<AppodealNativeEventType> _events =
      StreamController<AppodealNativeEventType>.broadcast();
  final StreamController<({int viewId, AppodealNativeViewEvent event})>
      _viewEvents = StreamController<
          ({int viewId, AppodealNativeViewEvent event})>.broadcast();
  bool _listening = false;
  AdPlacement? _lastLoadRequested;
  AdPlacement? _lastViewPlacement;

  /// Whether native ads can render here. Android only.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Every native callback, app-wide.
  Stream<AppodealNativeEventType> get events {
    _listen();
    return _events.stream;
  }

  /// What happened to each native ad view, by platform view ID.
  Stream<({int viewId, AppodealNativeViewEvent event})> get viewEvents {
    _listen();
    return _viewEvents.stream;
  }

  /// Native callbacks as neutral ad events attributed to [placement].
  ///
  /// Loaded, shown and clicked map to [AdEventType.loaded],
  /// [AdEventType.impression] and [AdEventType.clicked]. Revenue comes from
  /// the provider's own stream, not here. An app with more than one native
  /// placement uses [attributedAdEvents] instead.
  Stream<AdEvent> adEvents(
    AdPlacement placement, {
    KitClock clock = const SystemKitClock(),
  }) {
    return events.expand((type) {
      final mapped = switch (type) {
        AppodealNativeEventType.loaded => AdEventType.loaded,
        AppodealNativeEventType.shown => AdEventType.impression,
        AppodealNativeEventType.clicked => AdEventType.clicked,
        _ => null,
      };
      return <AdEvent>[
        if (mapped != null)
          AdEvent(
            type: mapped,
            placement: placement,
            provider: 'appodeal',
            occurredAt: clock.now(),
          ),
      ];
    });
  }

  /// Records that a view asked for a native ad for [placement].
  ///
  /// Called by `AppodealNativeAdView`, for [attributedAdEvents].
  void noteLoadRequested(AdPlacement placement) =>
      _lastLoadRequested = placement;

  /// Records that a view for [placement] is taking an ad.
  ///
  /// Called by `AppodealNativeAdView`, for [attributedAdEvents].
  void noteViewCreated(AdPlacement placement) => _lastViewPlacement = placement;

  /// Native callbacks as neutral ad events, each attributed to its placement.
  ///
  /// Appodeal reports native callbacks app-wide, without a placement. A load is
  /// attributed to the placement whose view last asked for one, and an
  /// impression or a click to the placement whose view last took an ad;
  /// [fallback] before any view has. Listen once for every native placement:
  /// an [adEvents] listener per placement reports each callback once per
  /// listener.
  Stream<AdEvent> attributedAdEvents({
    required AdPlacement fallback,
    KitClock clock = const SystemKitClock(),
  }) {
    return events.expand((type) {
      final (mapped, placement) = switch (type) {
        AppodealNativeEventType.loaded => (
            AdEventType.loaded,
            _lastLoadRequested,
          ),
        AppodealNativeEventType.shown => (
            AdEventType.impression,
            _lastViewPlacement,
          ),
        AppodealNativeEventType.clicked => (
            AdEventType.clicked,
            _lastViewPlacement,
          ),
        _ => (null, null),
      };
      return <AdEvent>[
        if (mapped != null)
          AdEvent(
            type: mapped,
            placement: placement ?? fallback,
            provider: 'appodeal',
            occurredAt: clock.now(),
          ),
      ];
    });
  }

  /// How many loaded native ads the SDK holds.
  Future<int> availableCount() async {
    if (!isSupported) return 0;
    _listen();
    return await _channel.invokeMethod<int>('availableCount') ?? 0;
  }

  void _listen() {
    if (_listening || !isSupported) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      final arguments = call.arguments;
      switch (call.method) {
        case 'onNative':
          final type =
              AppodealNativeEventType.values.asNameMap()[arguments as String?];
          if (type != null && !_events.isClosed) _events.add(type);
        case 'onView':
          if (arguments is! Map) return;
          final viewId = arguments['viewId'];
          final event =
              AppodealNativeViewEvent.values.asNameMap()[arguments['event']];
          if (viewId is int && event != null && !_viewEvents.isClosed) {
            _viewEvents.add((viewId: viewId, event: event));
          }
      }
    });
  }
}
