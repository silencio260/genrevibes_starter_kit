package com.genrevibes.ads_appodeal_native;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import com.appodeal.ads.Appodeal;
import com.appodeal.ads.NativeAd;
import com.appodeal.ads.NativeCallbacks;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

/**
 * Appodeal native ads for Flutter.
 *
 * <p>Appodeal's Flutter plugin initializes and caches native inventory but gives Flutter no way to
 * render it or hear its callbacks. This forwards the app-wide native callbacks and renders a loaded
 * ad in Appodeal's own {@code NativeAdView}, which is what reports impressions and clicks to the SDK.
 *
 * <p>Written in Java on purpose: it calls the SDK's native ad view accessors, and Java compiles
 * against them whether the SDK declared them as Kotlin properties or as methods.
 */
public final class GenRevibesAppodealNativePlugin
    implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private static final String CHANNEL = "com.genrevibes/appodeal_native";
  private static final String VIEW_TYPE = "com.genrevibes/appodeal_native_ad";

  private final Handler main = new Handler(Looper.getMainLooper());
  private MethodChannel channel;
  private Activity activity;

  private final NativeCallbacks callbacks =
      new NativeCallbacks() {
        @Override
        public void onNativeLoaded() {
          send("loaded");
        }

        @Override
        public void onNativeFailedToLoad() {
          send("failedToLoad");
        }

        @Override
        public void onNativeShown(NativeAd nativeAd) {
          send("shown");
        }

        @Override
        public void onNativeShowFailed(NativeAd nativeAd) {
          send("showFailed");
        }

        @Override
        public void onNativeClicked(NativeAd nativeAd) {
          send("clicked");
        }

        @Override
        public void onNativeExpired() {
          send("expired");
        }
      };

  @Override
  public void onAttachedToEngine(FlutterPlugin.FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
    binding.getPlatformViewRegistry().registerViewFactory(VIEW_TYPE, new Factory(this));
    Appodeal.setNativeCallbacks(callbacks);
  }

  @Override
  public void onDetachedFromEngine(FlutterPlugin.FlutterPluginBinding binding) {
    if (channel != null) channel.setMethodCallHandler(null);
    channel = null;
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    if ("availableCount".equals(call.method)) {
      result.success(Appodeal.getAvailableNativeAdsCount());
    } else {
      result.notImplemented();
    }
  }

  /** Reports what happened to one native ad view. */
  void sendViewEvent(int viewId, String event) {
    final Map<String, Object> arguments = new HashMap<>();
    arguments.put("viewId", viewId);
    arguments.put("event", event);
    main.post(
        () -> {
          if (channel != null) channel.invokeMethod("onView", arguments);
        });
  }

  private void send(String event) {
    main.post(
        () -> {
          if (channel != null) channel.invokeMethod("onNative", event);
        });
  }

  private static final class Factory extends PlatformViewFactory {
    private final GenRevibesAppodealNativePlugin plugin;

    Factory(GenRevibesAppodealNativePlugin plugin) {
      super(StandardMessageCodec.INSTANCE);
      this.plugin = plugin;
    }

    @Override
    public PlatformView create(Context context, int viewId, Object args) {
      // The activity, when there is one: ad clicks open from it.
      final Context host = plugin.activity != null ? plugin.activity : context;
      final Map<?, ?> arguments = args instanceof Map ? (Map<?, ?>) args : Collections.emptyMap();
      return new AppodealNativeAdPlatformView(host, viewId, arguments, plugin);
    }
  }
}
