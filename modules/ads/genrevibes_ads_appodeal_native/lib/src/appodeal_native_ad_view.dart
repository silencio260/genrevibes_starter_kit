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
    this.adBuilder,
    this.preloadNext = false,
    this.logger = const NoopKitLogger(),
    this.retryDelay,
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

  /// Wraps the sized ad only when inventory is available and eligible.
  /// Use this for padding or safe areas that must collapse with an empty slot.
  /// Keep [ad] mounted in the returned widget so it can register with the SDK.
  final Widget Function(BuildContext context, Widget ad)? adBuilder;

  /// Whether to load the next ad as soon as this view shows one.
  ///
  /// A view takes its ad out of the SDK's cache, so a view built next — the
  /// next ad page of a flow that alternates pages with and without an ad —
  /// would otherwise wait for a load and appear late. Costs a load that may go
  /// unused if no further view is built.
  final bool preloadNext;

  /// Optional diagnostics for slot eligibility, requests and view registration.
  final KitLogger logger;

  /// Delay after a failed load before retrying without an attempt limit.
  /// Null disables automatic retries. Eligibility and disposal stop retries.
  final Duration? retryDelay;

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
  String? _lastEligibility;
  int? _lastCount;
  Timer? _retryTimer;

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _scheduleRetry() {
    _loadRequested = false;
    final delay = widget.retryDelay;
    if (!mounted || !_eligible || delay == null || _retryTimer != null) return;
    if (_available && !widget.preloadNext) return;
    _log('retry scheduled in ${delay.inMilliseconds}ms');
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!mounted || !_eligible) return;
      if (_available && widget.preloadNext) {
        unawaited(_requestLoad(reason: 'retry preload'));
      } else {
        unawaited(_refresh());
      }
    });
  }

  void _log(String message, {KitLogLevel level = KitLogLevel.debug}) {
    widget.logger.log(
      level,
      'Native ${widget.placement.id}: $message',
      moduleId: 'ads.appodeal.native',
    );
  }

  void _logEligibility() {
    if (!_eligible) _cancelRetry();
    final state = 'supported=${_ads.isSupported}, enabled=${widget.enabled}, '
        'eligible=$_eligible, inventory=${widget.provider.servesInventory}, '
        'testMode=${widget.provider.isTestMode}';
    if (state == _lastEligibility) return;
    _lastEligibility = state;
    _log(state);
  }

  Future<void> _requestLoad({required String reason}) async {
    if (!mounted || !_eligible) return;
    _loadRequested = true;
    _ads.noteLoadRequested(widget.placement);
    _log('cache request ($reason)');
    final result = await widget.provider.load(widget.placement);
    result.fold<void>(
      // An accepted cache request does not mean native inventory loaded.
      // The SDK's app-wide loaded/failedToLoad callback confirms that.
      onSuccess: (_) => _log('cache request accepted; awaiting SDK callback'),
      onFailure: (error) {
        _log(
          'cache request rejected: ${error.code.name}, '
          'providerCode=${error.providerCode}',
          level: KitLogLevel.warning,
        );
        _scheduleRetry();
      },
    );
  }

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
    // The Android view reads its style only when it is created, so a new style
    // needs a new view, which takes the next loaded ad.
    if (!mapEquals(
      oldWidget.style.toCreationParams(),
      widget.style.toCreationParams(),
    )) {
      _generation++;
    }
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.placement != widget.placement) {
      unawaited(_refresh());
    }
  }

  @override
  void dispose() {
    _cancelRetry();
    unawaited(_nativeEvents?.cancel());
    unawaited(_viewEvents?.cancel());
    super.dispose();
  }

  bool get _eligible =>
      widget.enabled && widget.provider.canShowInline(widget.placement);

  Future<void> _refresh() async {
    _logEligibility();
    if (!_ads.isSupported || !_eligible || _available || _retryTimer != null) {
      return;
    }
    final count = await _ads.availableCount();
    if (!mounted || !_eligible || _retryTimer != null) return;
    if (count != _lastCount) {
      _lastCount = count;
      _log('available inventory=$count');
    }
    if (count > 0) {
      _cancelRetry();
      _loadRequested = false;
      setState(() => _available = true);
    } else if (!_loadRequested) {
      _loadRequested = true;
      unawaited(_requestLoad(reason: 'empty slot'));
    }
  }

  void _onNative(AppodealNativeEventType type) {
    if (!mounted) return;
    if (type == AppodealNativeEventType.loaded) {
      _cancelRetry();
      _loadRequested = false;
      unawaited(_refresh());
    } else if (type == AppodealNativeEventType.failedToLoad && _loadRequested) {
      _scheduleRetry();
    }
  }

  void _onView(({int viewId, AppodealNativeViewEvent event}) update) {
    if (update.viewId != _viewId || !mounted) return;
    _log('view ${update.viewId}: ${update.event.name}');
    switch (update.event) {
      case AppodealNativeViewEvent.registered:
        // The ad left the cache; the next view needs a fresh load.
        _loadRequested = false;
        if (widget.preloadNext && _eligible) {
          unawaited(_requestLoad(reason: 'preload next'));
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
    _logEligibility();
    final placeholder = widget.placeholder ?? const SizedBox.shrink();
    if (!_ads.isSupported || !widget.enabled) return placeholder;
    return StreamBuilder<ModuleHealth>(
      stream: widget.provider.healthChanges,
      initialData: widget.provider.health,
      builder: (context, _) {
        _logEligibility();
        final name = widget.provider.placementNameFor(widget.placement);
        if (name == null || !_eligible) return placeholder;
        if (!_available) {
          unawaited(_refresh());
          return placeholder;
        }
        final ad = SizedBox(
          height: widget.style.resolvedHeight,
          child: _NativePlatformView(
            key: ValueKey<int>(_generation),
            creationParams: <String, Object?>{
              'placement': name,
              ...widget.style.toCreationParams(),
            },
            onCreated: (id) {
              _viewId = id;
              _log('creating Android view $id');
              // Before the ad registers, so its impression is attributed here.
              _ads.noteViewCreated(widget.placement);
            },
          ),
        );
        return widget.adBuilder?.call(context, ad) ?? ad;
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
