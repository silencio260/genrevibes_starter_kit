package com.genrevibes.system_ui;

import android.app.Activity;
import android.os.Build;
import android.view.View;
import android.view.ViewTreeObserver;
import android.view.Window;
import android.view.WindowInsets;
import android.view.WindowInsetsController;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Shows and hides the system navigation bar: the back, home and recents
 * buttons, or the gesture handle. The status bar is left alone.
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
 */
public final class GenRevibesSystemUiPlugin
    implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
  private static final String CHANNEL = "com.genrevibes/system_ui";

  private MethodChannel channel;
  private Activity activity;
  private View observedDecorView;

  /** Null until Dart asks for a state: nothing is changed before then. */
  private Boolean requestedVisible;

  private final ViewTreeObserver.OnWindowFocusChangeListener focusListener =
      hasFocus -> {
        if (hasFocus) {
          applyAfterCurrentWork();
        }
      };

  @Override
  public void onAttachedToEngine(FlutterPluginBinding binding) {
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
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
    if (!"setNavigationBarVisible".equals(call.method)) {
      result.notImplemented();
      return;
    }
    Boolean visible = call.argument("visible");
    if (visible == null) {
      result.error("invalid_argument", "visible is required.", null);
      return;
    }
    requestedVisible = visible;
    // Without an activity the state is kept and applied when one attaches.
    apply();
    result.success(null);
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
}
