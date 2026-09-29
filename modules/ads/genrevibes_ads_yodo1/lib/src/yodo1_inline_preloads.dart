import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:genrevibes_ads/genrevibes_ads.dart';

import 'yodo1_ad_views.dart';

/// Bounded Android cache of detached inline views, consumed once by the matching
/// placement/size/style. Call only after provider startup and policy checks.
/// SDK readiness is not proof that a creative has been rendered or shown.
abstract final class Yodo1InlinePreloads {
  static const _channel = MethodChannel('genrevibes.ads.yodo1/control');

  /// Loads without mounting a hidden Flutter/Android view. A destination can
  /// also take over an in-flight request without issuing a duplicate load.
  static Future<bool> load(
    AdPlacement placement, {
    Yodo1BannerSize size = Yodo1BannerSize.standard,
    String? backgroundColor,
    int? widthPx,
    int? heightPx,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (placement.format != AdFormat.native &&
        placement.format != AdFormat.banner) {
      return false;
    }
    if (placement.format == AdFormat.native &&
        ((widthPx ?? 0) <= 0 || (heightPx ?? 0) <= 0)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('preloadInline', {
            'placementId': placement.id,
            'format': placement.format.name,
            if (placement.format == AdFormat.banner) 'size': size.name,
            if (placement.format == AdFormat.native)
              'backgroundColor': backgroundColor,
            if (placement.format == AdFormat.native) ...{
              'widthPx': widthPx,
              'heightPx': heightPx,
            },
          }).timeout(const Duration(seconds: 31)) ??
          false;
    } on Exception catch (error) {
      debugPrint('Yodo1 preload ${placement.id}: $error');
      return false;
    }
  }

  /// Destroys unused inventory, never a view already owned by a screen.
  static Future<void> clear() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel
          .invokeMethod<void>('clearPreloads')
          .timeout(const Duration(seconds: 2));
    } on Exception catch (error) {
      debugPrint('Yodo1 preload cleanup: $error');
    }
  }
}
