package com.genrevibes.ads_appodeal_native;

import android.content.Context;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import com.appodeal.ads.Appodeal;
import com.appodeal.ads.NativeAd;
import com.appodeal.ads.nativead.NativeAdView;
import io.flutter.plugin.platform.PlatformView;
import java.util.List;
import java.util.Map;

/**
 * One loaded native ad inside a Flutter platform view.
 *
 * <p>Takes a single ad out of the SDK's cache, so each view shows one ad for as long as it exists,
 * and destroys it on dispose.
 */
final class AppodealNativeAdPlatformView implements PlatformView {
  private final FrameLayout root;
  private NativeAdView adView;

  AppodealNativeAdPlatformView(
      Context context, int viewId, Map<?, ?> args, GenRevibesAppodealNativePlugin plugin) {
    root = new FrameLayout(context);
    final Object placementArgument = args.get("placement");
    final String placement =
        placementArgument instanceof String ? (String) placementArgument : "default";

    final List<NativeAd> ads = Appodeal.getNativeAds(1);
    final NativeAd ad = ads == null || ads.isEmpty() ? null : ads.get(0);
    if (ad == null) {
      plugin.sendViewEvent(viewId, "unavailable");
      return;
    }
    // Dashboard rules for the placement, such as a frequency cap, can refuse a loaded ad.
    if (!ad.canShow(context, placement)) {
      ad.destroy();
      plugin.sendViewEvent(viewId, "refused");
      return;
    }

    final NativeAdView view =
        NativeAdTemplate.build(context, NativeAdStyle.from(args, context), ad);
    root.addView(
        view,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    if (view.registerView(ad, placement)) {
      adView = view;
      plugin.sendViewEvent(viewId, "registered");
    } else {
      root.removeView(view);
      view.destroy();
      plugin.sendViewEvent(viewId, "refused");
    }
  }

  @Override
  public View getView() {
    return root;
  }

  @Override
  public void dispose() {
    if (adView != null) {
      adView.unregisterView();
      adView.destroy();
      adView = null;
    }
    root.removeAllViews();
  }
}
