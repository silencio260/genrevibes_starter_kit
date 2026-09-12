import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_appodeal/genrevibes_ads_appodeal.dart';
import 'package:genrevibes_core/genrevibes_core.dart';

import 'appodeal_native_ad_style.dart';
import 'appodeal_native_ads.dart';

const String _viewType = 'com.genrevibes/appodeal_native_ad';

/// One Appodeal native ad, laid out in the SDK's Android `NativeAdView`.
///
/// Renders [placeholder] — nothing by default — while [enabled] is false, while
/// [provider] does not serve inventory for [placement], and while no native ad
/// is loaded. So not before the SDK initializes, not for a user the provider's
/// `canRequestAds` gates off, and not after a test-mode change that waits for a
/// relaunch. With no ad loaded it asks the provider to load one and appears on
/// the next native load.
///
/// Eligibility the provider cannot know, such as a premium user, belongs to
/// [enabled]. The view keeps its ad for as long as it stays mounted, so an ad
/// kept on screen across page changes counts once.
///
/// Android only; elsewhere this renders [placeholder].
final class AppodealNativeAdView extends StatefulWidget {
  /// Creates a native ad view.
  const AppodealNativeAdView({
    required this.provider,
    required this.placement,
    required this.enabled,
    super.key,
    this.style = const AppodealNativeAdStyle(),
    this.placeholder,
    this.preloadNext = false,
  });

  /// The provider that initialized the SDK, with [placement] configured.
  final AppodealAdProvider provider;

  /// A native placement.
  final AdPlacement placement;

  /// Application-owned display eligibility.
  final bool enabled;

  /// Layout, colors and sizes.
  final AppodealNativeAdStyle style;

  /// Shown instead of an ad. Null shows nothing.
  final Widget? placeholder;

  /// Whether to load the next ad as soon as this view shows one.
  ///
  /// A view takes its ad out of the SDK's cache, so a view built next — the
  /// next ad page of a flow that alternates pages with and without an ad —
  /// would otherwise wait for a load and appear late. Costs a load that may go
  /// unused if no further view is built.
  final bool preloadNext;

  @override
  State<AppodealNativeAdView> createState() => _AppodealNativeAdViewState();
}

class _AppodealNativeAdViewState extends State<AppodealNativeAdView> {
  final AppodealNativeAds _ads = AppodealNativeAds.instance;
  StreamSubscription<AppodealNativeEventType>? _nativeEvents;
  StreamSubscription<({int viewId, AppodealNativeViewEvent event})>?
      _viewEvents;
  bool _available = false;
  bool _loadRequested = false;
  int _generation = 0;
  int? _viewId;

  @override
  void initState() {
    super.initState();
    if (!_ads.isSupported) return;
    _nativeEvents = _ads.events.listen(_onNative);
    _viewEvents = _ads.viewEvents.listen(_onView);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant AppodealNativeAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.placement != widget.placement) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    unawaited(_nativeEvents?.cancel());
    unawaited(_viewEvents?.cancel());
    super.dispose();
  }

  bool get _eligible =>
      widget.enabled && widget.provider.canShowInline(widget.placement);

  Future<void> _refresh() async {
    if (!_ads.isSupported || !_eligible || _available) return;
    final count = await _ads.availableCount();
    if (!mounted) return;
    if (count > 0) {
      setState(() => _available = true);
    } else if (!_loadRequested) {
      _loadRequested = true;
      _ads.noteLoadRequested(widget.placement);
      unawaited(widget.provider.load(widget.placement));
    }
  }

  void _onNative(AppodealNativeEventType type) {
    if (type == AppodealNativeEventType.loaded) unawaited(_refresh());
  }

  void _onView(({int viewId, AppodealNativeViewEvent event}) update) {
    if (update.viewId != _viewId || !mounted) return;
    switch (update.event) {
      case AppodealNativeViewEvent.registered:
        // The ad left the cache; the next view needs a fresh load.
        _loadRequested = false;
        if (widget.preloadNext && _eligible) {
          _ads.noteLoadRequested(widget.placement);
          unawaited(widget.provider.load(widget.placement));
        }
      case AppodealNativeViewEvent.unavailable:
      case AppodealNativeViewEvent.refused:
        // Wait for the next load rather than retrying at once, which would
        // loop on an ad a dashboard rule keeps refusing.
        setState(() {
          _available = false;
          _loadRequested = false;
          _generation++;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.placeholder ?? const SizedBox.shrink();
    if (!_ads.isSupported || !widget.enabled) return placeholder;
    return StreamBuilder<ModuleHealth>(
      stream: widget.provider.healthChanges,
      initialData: widget.provider.health,
      builder: (context, _) {
        final name = widget.provider.placementNameFor(widget.placement);
        if (name == null || !_eligible) return placeholder;
        if (!_available) {
          unawaited(_refresh());
          return placeholder;
        }
        return SizedBox(
          height: widget.style.resolvedHeight,
          child: _NativePlatformView(
            key: ValueKey<int>(_generation),
            creationParams: <String, Object?>{
              'placement': name,
              ...widget.style.toCreationParams(),
            },
            onCreated: (id) {
              _viewId = id;
              // Before the ad registers, so its impression is attributed here.
              _ads.noteViewCreated(widget.placement);
            },
          ),
        );
      },
    );
  }
}

/// Hybrid composition, which ad SDKs need to measure visibility and take
/// clicks the way they do in a native app.
class _NativePlatformView extends StatelessWidget {
  const _NativePlatformView({
    required this.creationParams,
    required this.onCreated,
    super.key,
  });

  final Map<String, Object?> creationParams;
  final ValueChanged<int> onCreated;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return PlatformViewLink(
      viewType: _viewType,
      surfaceFactory: (context, controller) => AndroidViewSurface(
        controller: controller as AndroidViewController,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
      ),
      onCreatePlatformView: (params) {
        onCreated(params.id);
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: _viewType,
          layoutDirection: direction,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
      },
    );
  }
}
