import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';

import 'admob_inline_ad_client.dart';

/// Builder used for inline ad loading and failure placeholders.
typedef AdMobInlinePlaceholderBuilder = Widget Function(
  BuildContext context,
  Object? error,
);

/// Lifecycle-safe inline AdMob view used for banner and native requests.
final class AdMobInlineAdView extends StatefulWidget {
  /// Creates an inline ad view.
  const AdMobInlineAdView({
    super.key,
    required this.request,
    required this.enabled,
    this.client,
    this.onEvent,
    this.placeholderBuilder,
    this.nativeConstraints = const BoxConstraints(
      minWidth: 320,
      minHeight: 90,
      maxWidth: 400,
      maxHeight: 320,
    ),
  });

  /// Banner or native request.
  final AdMobInlineAdRequest request;

  /// Explicit app-owned eligibility. Pass false for premium users, active ad
  /// suppression, disabled remote config, or a hidden route.
  final bool enabled;

  /// Optional fake or custom inline client.
  final AdMobInlineAdClient? client;

  /// Receives neutral loaded, impression, click, and paid events.
  final void Function(AdEvent event)? onEvent;

  /// Optional loading/error UI. The error is null while loading.
  final AdMobInlinePlaceholderBuilder? placeholderBuilder;

  /// Constraints used for native templates.
  final BoxConstraints nativeConstraints;

  @override
  State<AdMobInlineAdView> createState() => _AdMobInlineAdViewState();
}

class _AdMobInlineAdViewState extends State<AdMobInlineAdView> {
  late AdMobInlineAdClient _client;
  AdMobInlineAdHandle? _handle;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? DefaultAdMobInlineAdClient();
    if (widget.enabled) _load();
  }

  @override
  void didUpdateWidget(covariant AdMobInlineAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clientChanged = oldWidget.client != widget.client;
    if (clientChanged) {
      _client = widget.client ?? DefaultAdMobInlineAdClient();
    }
    final requestChanged = !_sameRequest(oldWidget.request, widget.request);
    if (!widget.enabled) {
      _invalidateAndDispose();
    } else if (!oldWidget.enabled || clientChanged || requestChanged) {
      _load();
    }
  }

  bool _sameRequest(
    AdMobInlineAdRequest previous,
    AdMobInlineAdRequest current,
  ) {
    if (previous.runtimeType != current.runtimeType ||
        previous.unit.placement != current.unit.placement ||
        previous.unit.adUnitId != current.unit.adUnitId ||
        previous.request != current.request ||
        previous.loadTimeout != current.loadTimeout) {
      return false;
    }
    if (previous case AdMobBannerRequest(size: final previousSize)) {
      return current is AdMobBannerRequest && previousSize == current.size;
    }
    if (previous
        case AdMobNativeRequest(
          templateStyle: final previousStyle,
          nativeAdOptions: final previousOptions,
        )) {
      return current is AdMobNativeRequest &&
          previousStyle == current.templateStyle &&
          previousOptions == current.nativeAdOptions;
    }
    return true;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final previous = _handle;
    _handle = null;
    _error = null;
    if (previous != null) await previous.dispose();
    if (!mounted || !widget.enabled || generation != _generation) return;
    if (mounted) setState(() {});
    try {
      final loaded = await _client.load(
        widget.request,
        onEvent: (event) => widget.onEvent?.call(event),
      );
      if (!mounted || !widget.enabled || generation != _generation) {
        await loaded.dispose();
        return;
      }
      setState(() => _handle = loaded);
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = error);
    }
  }

  void _invalidateAndDispose() {
    _generation += 1;
    final handle = _handle;
    _handle = null;
    _error = null;
    if (handle != null) unawaited(handle.dispose());
  }

  @override
  void dispose() {
    _invalidateAndDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final handle = _handle;
    if (!widget.enabled || handle == null) {
      return widget.placeholderBuilder?.call(context, _error) ??
          const SizedBox.shrink();
    }
    final size = handle.size;
    if (size != null) {
      return SizedBox(
          width: size.width, height: size.height, child: handle.widget);
    }
    return ConstrainedBox(
      constraints: widget.nativeConstraints,
      child: handle.widget,
    );
  }
}

/// Convenience banner view.
final class AdMobBannerView extends StatelessWidget {
  /// Creates a banner view.
  const AdMobBannerView({
    super.key,
    required this.request,
    required this.enabled,
    this.client,
    this.onEvent,
    this.placeholderBuilder,
  });

  /// Banner request.
  final AdMobBannerRequest request;

  /// Explicit app-owned display eligibility.
  final bool enabled;

  /// Optional inline client.
  final AdMobInlineAdClient? client;

  /// Neutral ad event callback.
  final void Function(AdEvent event)? onEvent;

  /// Optional loading/error placeholder.
  final AdMobInlinePlaceholderBuilder? placeholderBuilder;

  @override
  Widget build(BuildContext context) {
    return AdMobInlineAdView(
      request: request,
      enabled: enabled,
      client: client,
      onEvent: onEvent,
      placeholderBuilder: placeholderBuilder,
    );
  }
}

/// Convenience native-template view.
final class AdMobNativeView extends StatelessWidget {
  /// Creates a native-template view.
  const AdMobNativeView({
    super.key,
    required this.request,
    required this.enabled,
    this.client,
    this.onEvent,
    this.placeholderBuilder,
    this.constraints = const BoxConstraints(
      minWidth: 320,
      minHeight: 90,
      maxWidth: 400,
      maxHeight: 320,
    ),
  });

  /// Native request.
  final AdMobNativeRequest request;

  /// Explicit app-owned display eligibility.
  final bool enabled;

  /// Optional inline client.
  final AdMobInlineAdClient? client;

  /// Neutral ad event callback.
  final void Function(AdEvent event)? onEvent;

  /// Optional loading/error placeholder.
  final AdMobInlinePlaceholderBuilder? placeholderBuilder;

  /// Native template constraints.
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    return AdMobInlineAdView(
      request: request,
      enabled: enabled,
      client: client,
      onEvent: onEvent,
      placeholderBuilder: placeholderBuilder,
      nativeConstraints: constraints,
    );
  }
}
