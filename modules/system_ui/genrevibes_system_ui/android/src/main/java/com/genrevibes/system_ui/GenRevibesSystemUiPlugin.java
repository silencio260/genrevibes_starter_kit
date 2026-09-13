package com.genrevibes.system_ui;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Shows and hides the system navigation bar: the back, home and recents
 * buttons, or the gesture handle. The app's own status bar is left alone.
 *
 * Flutter's SystemChrome can hide the navigation bar on its own only without
 * Android's immersive behavior, so the first touch anywhere brings it back for
 * good. Hidden here, a swipe from the bottom edge shows it for a moment and it
 * hides again by itself.
 *
 * Android undoes a hidden bar in places the app does not control: older
 * versions clear it when another window takes focus, and Flutter rewrites the
 * legacy system UI flags whenever the activity resumes. The requested state is
 * kept and applied again each time the window regains focus, after that work.
 *
 * Full-screen ads are not drawn by Flutter: ad SDKs open activities of their
 * own, with their own windows and both system bars showing. Once Dart asks,
 * every other activity in the process is shown full screen from the moment it
 * starts, before its window is drawn, so no bar ever flashes. The status bar is
 * hidden, and the navigation bar too unless Dart says the developer switch
 * shows it.
 */
public final class GenRevibesSystemUiPlugin
    implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private static final String CHANNEL = "com.genrevibes/system_ui";
  private static final String FLUTTER_ACTIVITIES = "io.flutter.embedding.android.";

  private MethodChannel channel;
  private Application application;
  private Activity activity;
  private View observedDecorView;

  /** Null until Dart asks for a state: nothing is changed before then. */
  private Boolean requestedVisible;

  /** Null until Dart asks: activities over the app are left alone until then. */
  private Boolean overlayNavigationBarVisible;

  private List<String> overlayExclusions = Collections.emptyList();

  /** Activities over the app that are open now, with their focus listeners. */
  private final Map<Activity, OverlayWindow> overlays = new HashMap<>();

  private final ViewTreeObserver.OnWindowFocusChangeListener focusListener =
      hasFocus -> {
        if (hasFocus) {
          applyAfterCurrentWork();
        }
      };

  private final Application.ActivityLifecycleCallbacks overlayCallbacks =
      new Application.ActivityLifecycleCallbacks() {
        @Override
        public void onActivityCreated(Activity created, Bundle savedInstanceState) {}

        /** Before the window is first drawn, so the bars never show. */
        @Override
        public void onActivityStarted(Activity started) {
          watchOverlay(started);
        }

        /** After the activity's own resume work, which may reset the bars. */
        @Override
        public void onActivityResumed(Activity resumed) {
          OverlayWindow overlay = overlays.get(resumed);
          if (overlay != null) {
            overlay.decorView.post(() -> applyOverlay(resumed));
          }
        }

        @Override
        public void onActivityPaused(Activity paused) {}

        @Override
        public void onActivityStopped(Activity stopped) {}

        @Override
        public void onActivitySaveInstanceState(Activity saved, Bundle outState) {}

        @Override
        public void onActivityDestroyed(Activity destroyed) {
          unwatchOverlay(destroyed);
        }
      };

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
    Context context = binding.getApplicationContext();
    if (context instanceof Application) {
      application = (Application) context;
      application.registerActivityLifecycleCallbacks(overlayCallbacks);
    }
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    if (application != null) {
      application.unregisterActivityLifecycleCallbacks(overlayCallbacks);
      application = null;
    }
    for (Activity open : new ArrayList<>(overlays.keySet())) {
      unwatchOverlay(open);
    }
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    attach(binding.getActivity());
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    detach();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
    attach(binding.getActivity());
  }

  @Override
  public void onDetachedFromActivity() {
    detach();
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    if ("setNavigationBarVisible".equals(call.method)) {
      Boolean visible = call.argument("visible");
      if (visible == null) {
        result.error("invalid_argument", "visible is required.", null);
        return;
      }
      requestedVisible = visible;
      // Without an activity the state is kept and applied when one attaches.
      apply();
      result.success(null);
    } else if ("setFullScreenOverlays".equals(call.method)) {
      Boolean navigationBarVisible = call.argument("navigationBarVisible");
      if (navigationBarVisible == null) {
        result.error("invalid_argument", "navigationBarVisible is required.", null);
        return;
      }
      List<String> excluded = call.argument("excludedActivityPrefixes");
      overlayExclusions =
          excluded == null ? Collections.emptyList() : new ArrayList<>(excluded);
      overlayNavigationBarVisible = navigationBarVisible;
      for (Activity open : new ArrayList<>(overlays.keySet())) {
        applyOverlay(open);
      }
      result.success(null);
    } else {
      result.notImplemented();
    }
  }

  private void attach(Activity activity) {
    detach();
    this.activity = activity;
    Window window = activity.getWindow();
    if (window == null) {
      return;
    }
    View decorView = window.getDecorView();
    decorView.getViewTreeObserver().addOnWindowFocusChangeListener(focusListener);
    observedDecorView = decorView;
    applyAfterCurrentWork();
  }

  private void detach() {
    if (observedDecorView != null) {
      ViewTreeObserver observer = observedDecorView.getViewTreeObserver();
      if (observer.isAlive()) {
        observer.removeOnWindowFocusChangeListener(focusListener);
      }
      observedDecorView = null;
    }
    activity = null;
  }

  /** Runs after the work in progress, such as Flutter's own resume handling. */
  private void applyAfterCurrentWork() {
    if (requestedVisible == null || observedDecorView == null) {
      return;
    }
    observedDecorView.post(this::apply);
  }

  private void apply() {
    Activity activity = this.activity;
    Boolean visible = requestedVisible;
    if (activity == null || visible == null) {
      return;
    }
    Window window = activity.getWindow();
    if (window == null) {
      return;
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      WindowInsetsController controller = window.getInsetsController();
      if (controller == null) {
        return;
      }
      if (visible) {
        controller.show(WindowInsets.Type.navigationBars());
      } else {
        controller.setSystemBarsBehavior(
            WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        controller.hide(WindowInsets.Type.navigationBars());
      }
    } else {
      applyLegacy(window.getDecorView(), visible);
    }
  }

  /** Android 10 and older: the system UI flags, with sticky immersive behavior. */
  @SuppressWarnings("deprecation")
  private static void applyLegacy(View decorView, boolean visible) {
    int flags = decorView.getSystemUiVisibility();
    if (visible) {
      flags &= ~View.SYSTEM_UI_FLAG_HIDE_NAVIGATION;
    } else {
      flags |= View.SYSTEM_UI_FLAG_HIDE_NAVIGATION | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
    }
    decorView.setSystemUiVisibility(flags);
  }

  /**
   * Starts following an activity opened over the app. Android shows its bars
   * again when its window regains focus on older versions, so they are hidden
   * again each time.
   */
  private void watchOverlay(Activity started) {
    if (started == activity || isFlutterActivity(started)) {
      return;
    }
    if (!overlays.containsKey(started)) {
      Window window = started.getWindow();
      if (window == null) {
        return;
      }
      View decorView = window.getDecorView();
      ViewTreeObserver.OnWindowFocusChangeListener listener =
          hasFocus -> {
            if (hasFocus) {
              decorView.post(() -> applyOverlay(started));
            }
          };
      decorView.getViewTreeObserver().addOnWindowFocusChangeListener(listener);
      overlays.put(started, new OverlayWindow(decorView, listener));
    }
    applyOverlay(started);
  }

  private void unwatchOverlay(Activity destroyed) {
    OverlayWindow overlay = overlays.remove(destroyed);
    if (overlay == null) {
      return;
    }
    ViewTreeObserver observer = overlay.decorView.getViewTreeObserver();
    if (observer.isAlive()) {
      observer.removeOnWindowFocusChangeListener(overlay.focusListener);
    }
  }

  private void applyOverlay(Activity overlay) {
    Boolean navigationBarVisible = overlayNavigationBarVisible;
    if (navigationBarVisible == null || isExcluded(overlay)) {
      return;
    }
    Window window = overlay.getWindow();
    if (window == null) {
      return;
    }
    // Before the window is attached this returns a pending controller, which
    // Android applies as the window is added.
    View decorView = window.getDecorView();
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      WindowInsetsController controller = window.getInsetsController();
      if (controller == null) {
        return;
      }
      controller.setSystemBarsBehavior(
          WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
      if (navigationBarVisible) {
        controller.hide(WindowInsets.Type.statusBars());
        controller.show(WindowInsets.Type.navigationBars());
      } else {
        controller.hide(WindowInsets.Type.systemBars());
      }
    } else {
      applyOverlayLegacy(decorView, navigationBarVisible);
    }
  }

  /** Android 10 and older: the status bar always hidden, sticky immersive. */
  @SuppressWarnings("deprecation")
  private static void applyOverlayLegacy(View decorView, boolean navigationBarVisible) {
    int flags =
        decorView.getSystemUiVisibility()
            | View.SYSTEM_UI_FLAG_FULLSCREEN
            | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
    if (navigationBarVisible) {
      flags &= ~View.SYSTEM_UI_FLAG_HIDE_NAVIGATION;
    } else {
      flags |= View.SYSTEM_UI_FLAG_HIDE_NAVIGATION;
    }
    decorView.setSystemUiVisibility(flags);
  }

  private boolean isExcluded(Activity overlay) {
    String name = overlay.getClass().getName();
    for (String prefix : overlayExclusions) {
      if (name.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  /** Flutter's own activities are the app's screens, which Dart decides. */
  private static boolean isFlutterActivity(Activity candidate) {
    for (Class<?> type = candidate.getClass(); type != null; type = type.getSuperclass()) {
      if (type.getName().startsWith(FLUTTER_ACTIVITIES)) {
        return true;
      }
    }
    return false;
  }

  private static final class OverlayWindow {
    final View decorView;
    final ViewTreeObserver.OnWindowFocusChangeListener focusListener;

    OverlayWindow(View decorView, ViewTreeObserver.OnWindowFocusChangeListener focusListener) {
      this.decorView = decorView;
      this.focusListener = focusListener;
    }
  }
}
