import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';
import 'package:genrevibes_ads_admob/genrevibes_ads_admob.dart';
import 'package:genrevibes_core/genrevibes_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Configuration shared by inline AdMob requests.
sealed class AdMobInlineAdRequest {
  const AdMobInlineAdRequest({
    required this.unit,
    required this.request,
    required this.loadTimeout,
  });

  /// Provider unit mapped to a logical inline placement.
  final AdMobAdUnit unit;

  /// Google ad targeting request owned by the application.
  final AdRequest request;

  /// Maximum wait for a plugin load callback.
  final Duration loadTimeout;
}

/// Banner request configuration.
final class AdMobBannerRequest extends AdMobInlineAdRequest {
  /// Creates a banner request.
  const AdMobBannerRequest({
    required super.unit,
    this.size = AdSize.banner,
    super.request = const AdRequest(),
    super.loadTimeout = const Duration(minutes: 1),
  });

  /// Requested banner dimensions.
  final AdSize size;
}

/// Native-template request configuration.
final class AdMobNativeRequest extends AdMobInlineAdRequest {
  /// Creates a native-template request.
  AdMobNativeRequest({
    required super.unit,
    NativeTemplateStyle? templateStyle,
    this.nativeAdOptions,
    super.request = const AdRequest(),
    super.loadTimeout = const Duration(minutes: 1),
  }) : templateStyle = templateStyle ??
            NativeTemplateStyle(templateType: TemplateType.medium);

  /// Google-provided native-template styling.
  final NativeTemplateStyle templateStyle;

  /// Optional native asset and media request options.
  final NativeAdOptions? nativeAdOptions;
}

/// Loaded inline ad without exposing the underlying Google ad to widget state.
abstract interface class AdMobInlineAdHandle {
  /// Renderable Google platform view.
  Widget get widget;

  /// Fixed dimensions for banners, or `null` for constrained native views.
  Size? get size;

  /// Releases native resources. Repeated calls must be safe.
  Future<void> dispose();
}

/// Injectable boundary used to test inline widget lifecycle without platform ads.
abstract interface class AdMobInlineAdClient {
  /// Loads one banner or native request and returns its renderable handle.
  Future<AdMobInlineAdHandle> load(
    AdMobInlineAdRequest request, {
    required void Function(AdEvent event) onEvent,
  });
}

/// Production client backed by Google Mobile Ads banner and native templates.
final class DefaultAdMobInlineAdClient implements AdMobInlineAdClient {
  /// Creates an inline client.
  DefaultAdMobInlineAdClient({KitClock clock = const SystemKitClock()})
      : _clock = clock;

  final KitClock _clock;

  @override
  Future<AdMobInlineAdHandle> load(
    AdMobInlineAdRequest request, {
    required void Function(AdEvent event) onEvent,
  }) {
    return switch (request) {
      AdMobBannerRequest value => _loadBanner(value, onEvent),
      AdMobNativeRequest value => _loadNative(value, onEvent),
    };
  }

  Future<AdMobInlineAdHandle> _loadBanner(
    AdMobBannerRequest request,
    void Function(AdEvent event) onEvent,
  ) async {
    _validateFormat(request.unit, AdFormat.banner);
    _validateTimeout(request.loadTimeout);
    final completer = Completer<AdMobInlineAdHandle>();
    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: request.unit.adUnitId,
      size: request.size,
      request: request.request,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _emit(onEvent, AdEventType.loaded, request.unit.placement);
          if (!completer.isCompleted) {
            completer.complete(
              _GoogleInlineAdHandle(
                ad,
                Size(
                  request.size.width.toDouble(),
                  request.size.height.toDouble(),
                ),
              ),
            );
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          unawaited(failedAd.dispose());
          if (!completer.isCompleted) {
            completer.completeError(StateError(error.message));
          }
        },
        onAdImpression: (_) => _emit(
          onEvent,
          AdEventType.impression,
          request.unit.placement,
        ),
        onAdClicked: (_) => _emit(
          onEvent,
          AdEventType.clicked,
          request.unit.placement,
        ),
        onPaidEvent: (paidAd, valueMicros, _, currencyCode) => _emitPaid(
          onEvent,
          request.unit.placement,
          paidAd,
          valueMicros,
          currencyCode,
        ),
      ),
    );
    try {
      await ad.load();
      return completer.future.timeout(
        request.loadTimeout,
        onTimeout: () => throw TimeoutException('AdMob banner load timed out.'),
      );
    } on Object catch (error, stackTrace) {
      await ad.dispose();
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      rethrow;
    }
  }

  Future<AdMobInlineAdHandle> _loadNative(
    AdMobNativeRequest request,
    void Function(AdEvent event) onEvent,
  ) async {
    _validateFormat(request.unit, AdFormat.native);
    _validateTimeout(request.loadTimeout);
    final completer = Completer<AdMobInlineAdHandle>();
    late final NativeAd ad;
    ad = NativeAd(
      adUnitId: request.unit.adUnitId,
      request: request.request,
      nativeAdOptions: request.nativeAdOptions,
      nativeTemplateStyle: request.templateStyle,
      listener: NativeAdListener(
        onAdLoaded: (_) {
          _emit(onEvent, AdEventType.loaded, request.unit.placement);
          if (!completer.isCompleted) {
            completer.complete(_GoogleInlineAdHandle(ad, null));
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          unawaited(failedAd.dispose());
          if (!completer.isCompleted) {
            completer.completeError(StateError(error.message));
          }
        },
        onAdImpression: (_) => _emit(
          onEvent,
          AdEventType.impression,
          request.unit.placement,
        ),
        onAdClicked: (_) => _emit(
          onEvent,
          AdEventType.clicked,
          request.unit.placement,
        ),
        onPaidEvent: (paidAd, valueMicros, _, currencyCode) => _emitPaid(
          onEvent,
          request.unit.placement,
          paidAd,
          valueMicros,
          currencyCode,
        ),
      ),
    );
    try {
      await ad.load();
      return completer.future.timeout(
        request.loadTimeout,
        onTimeout: () => throw TimeoutException('AdMob native load timed out.'),
      );
    } on Object catch (error, stackTrace) {
      await ad.dispose();
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
      rethrow;
    }
  }

  void _validateFormat(AdMobAdUnit unit, AdFormat expected) {
    if (unit.placement.format != expected) {
      throw ArgumentError.value(
        unit.placement.format,
        'unit',
        'Expected an ${expected.name} placement.',
      );
    }
    if (unit.placement.id.trim().isEmpty || unit.adUnitId.trim().isEmpty) {
      throw ArgumentError('Placement and AdMob ad-unit IDs must not be empty.');
    }
  }

  void _validateTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(
        timeout,
        'loadTimeout',
        'Inline ad load timeout must be positive.',
      );
    }
  }

  void _emit(
    void Function(AdEvent event) callback,
    AdEventType type,
    AdPlacement placement,
  ) {
    callback(
      AdEvent(
        type: type,
        placement: placement,
        provider: 'admob',
        occurredAt: _clock.now(),
      ),
    );
  }

  void _emitPaid(
    void Function(AdEvent event) callback,
    AdPlacement placement,
    Ad ad,
    double valueMicros,
    String currencyCode,
  ) {
    callback(
      AdEvent(
        type: AdEventType.paid,
        placement: placement,
        provider: 'admob',
        occurredAt: _clock.now(),
        revenue: AdRevenue(
          valueMicros: valueMicros,
          currencyCode: currencyCode,
          provider: 'admob',
          mediationNetwork: ad.responseInfo?.mediationAdapterClassName,
        ),
      ),
    );
  }
}

final class _GoogleInlineAdHandle implements AdMobInlineAdHandle {
  _GoogleInlineAdHandle(this._ad, this.size);

  final AdWithView _ad;
  bool _disposed = false;

  @override
  final Size? size;

  @override
  Widget get widget => AdWidget(ad: _ad);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _ad.dispose();
  }
}
