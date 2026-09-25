import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';

/// Banner shapes MAS offers.
enum Yodo1BannerSize {
  /// 320x50.
  standard('standard', 320, 50),

  /// 320x100.
  large('large', 320, 100),

  /// 300x250.
  mediumRectangle('mediumRectangle', 300, 250),

  /// Full-width, height chosen by the SDK from the screen.
  smart('smart', double.infinity, 50),

  /// Full-width, height chosen by the SDK for the device.
  adaptive('adaptive', double.infinity, 50);

  const Yodo1BannerSize(this.name, this.width, this.height);

  /// Value passed to the platform view.
  final String name;

  /// Nominal width in logical pixels.
  final double width;

  /// Nominal height in logical pixels, which the widget reserves.
  final double height;
}

/// A Yodo1 MAS banner, placed inside the app's own layout.
///
/// The official plugin never implemented banners — the request is dropped
/// natively — so this embeds `Yodo1MasBannerAdView` through this package's
/// platform view instead. Space is reserved before the creative arrives, so
/// filling it does not push the surrounding UI around, and the view is
/// destroyed with the widget.
class Yodo1BannerView extends StatefulWidget {
  /// Creates a banner.
  const Yodo1BannerView({
    super.key,
    this.placement,
    this.size = Yodo1BannerSize.standard,
    this.onEvent,
    this.placeholder,
    this.onLoadFailed,
  });

  /// Placement this banner is reported under, for the app's own analytics.
  final AdPlacement? placement;

  /// Shape to request.
  final Yodo1BannerSize size;

  /// SDK/platform failure details for the host's retry and fallback handling.
  final void Function(String message)? onLoadFailed;

  /// Called for load, click and revenue events.
  final void Function(AdEvent event)? onEvent;

  /// Shown until the first creative loads, and after a failure.
  final Widget? placeholder;

  @override
  State<Yodo1BannerView> createState() => _Yodo1BannerViewState();
}

class _Yodo1BannerViewState extends State<Yodo1BannerView> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final height = widget.size.height;
    return SizedBox(
      height: height,
      width: widget.size.width == double.infinity ? null : widget.size.width,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (!_loaded) widget.placeholder ?? const SizedBox.shrink(),
          _Yodo1AdPlatformView(
            viewType: 'genrevibes.ads.yodo1/banner',
            creationParams: <String, Object?>{
              'size': widget.size.name,
              'placementId': widget.placement?.id,
            },
            placement: widget.placement ??
                const AdPlacement(id: 'banner', format: AdFormat.banner),
            onEvent: widget.onEvent,
            onLoadFailed: widget.onLoadFailed,
            onLoadedChanged: (loaded) {
              if (mounted) setState(() => _loaded = loaded);
            },
          ),
        ],
      ),
    );
  }
}

/// A Yodo1 MAS native ad, rendered into this package's Android layout.
class Yodo1NativeView extends StatefulWidget {
  /// Creates a native ad view.
  const Yodo1NativeView({
    super.key,
    this.placement,
    this.height = 320,
    this.backgroundColor,
    this.onEvent,
    this.placeholder,
    this.onLoadFailed,
  });

  /// Placement this ad is reported under.
  final AdPlacement? placement;

  /// Height reserved for the creative.
  final double height;

  /// Background passed to the SDK, as `#RRGGBB`.
  final String? backgroundColor;

  /// Receives SDK and platform-channel failures, including their diagnostic text.
  final void Function(String message)? onLoadFailed;

  /// Called for load and revenue events.
  final void Function(AdEvent event)? onEvent;

  /// Shown until the first creative loads, and after a failure.
  final Widget? placeholder;

  @override
  State<Yodo1NativeView> createState() => _Yodo1NativeViewState();
}

class _Yodo1NativeViewState extends State<Yodo1NativeView> {
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (!_loaded) widget.placeholder ?? const SizedBox.shrink(),
          _Yodo1AdPlatformView(
            viewType: 'genrevibes.ads.yodo1/native',
            creationParams: <String, Object?>{
              'placementId': widget.placement?.id,
              'backgroundColor': widget.backgroundColor,
            },
            placement: widget.placement ??
                const AdPlacement(id: 'native', format: AdFormat.native),
            onEvent: widget.onEvent,
            onLoadFailed: widget.onLoadFailed,
            onLoadedChanged: (loaded) {
              if (mounted) setState(() => _loaded = loaded);
            },
          ),
        ],
      ),
    );
  }
}

/// Hosts one MAS ad view and turns its platform callbacks into [AdEvent]s.
class _Yodo1AdPlatformView extends StatefulWidget {
  const _Yodo1AdPlatformView({
    required this.viewType,
    required this.creationParams,
    required this.placement,
    required this.onLoadedChanged,
    this.onEvent,
    this.onLoadFailed,
  });

  final String viewType;
  final Map<String, Object?> creationParams;
  final AdPlacement placement;
  final void Function(bool loaded) onLoadedChanged;
  final void Function(AdEvent event)? onEvent;
  final void Function(String message)? onLoadFailed;

  @override
  State<_Yodo1AdPlatformView> createState() => _Yodo1AdPlatformViewState();
}

class _Yodo1AdPlatformViewState extends State<_Yodo1AdPlatformView> {
  MethodChannel? _channel;

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _attach(int viewId) async {
    if (!mounted) return;
    final channel = MethodChannel('genrevibes.ads.yodo1/view_$viewId');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted) return null;
      switch (call.method) {
        case 'loaded':
          widget.onLoadedChanged(true);
          _emit(AdEventType.loaded);
        case 'failed':
          widget.onLoadedChanged(false);
          widget.onLoadFailed?.call(call.arguments?.toString() ?? 'unknown');
        case 'clicked':
          _emit(AdEventType.clicked);
        case 'paid':
          final payload = (call.arguments as Map?)?.cast<String, Object?>();
          _emit(
            AdEventType.paid,
            revenue: payload == null ? null : _revenueFrom(payload),
          );
      }
      return null;
    });
    // Native ads start only after the Dart listener exists, even for cached ads.
    if (mounted) {
      try {
        await channel.invokeMethod<void>('load');
      } catch (error) {
        if (mounted) widget.onLoadFailed?.call('platform_load: $error');
      }
    }
  }

  AdRevenue? _revenueFrom(Map<String, Object?> payload) {
    final value = payload['value'];
    if (value is! num) return null;
    return AdRevenue(
      // MAS reports whole currency units; the kit's contract is micros.
      valueMicros: (value * 1000000).round(),
      currencyCode: payload['currency'] as String? ?? 'USD',
      provider: 'yodo1',
      mediationNetwork: payload['network'] as String?,
      precision: payload['precision'] as String?,
    );
  }

  void _emit(AdEventType type, {AdRevenue? revenue}) {
    widget.onEvent?.call(
      AdEvent(
        type: type,
        placement: widget.placement,
        provider: 'yodo1',
        occurredAt: DateTime.now(),
        revenue: revenue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      // iOS has no bridge yet; showing nothing is better than a broken view.
      return const SizedBox.shrink();
    }
    return AndroidView(
      viewType: widget.viewType,
      creationParams: widget.creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _attach,
      // The creative handles its own taps.
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
    );
  }
}
