package com.genrevibes.ads.yodo1

import android.content.Context
import android.app.Activity
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import com.yodo1.mas.ad.Yodo1MasAdValue
import com.yodo1.mas.Yodo1Mas
import com.yodo1.mas.Yodo1MasSdkConfiguration
import com.yodo1.mas.helper.model.Yodo1MasAdBuildConfig
import com.yodo1.mas.banner.Yodo1MasBannerAdListener
import com.yodo1.mas.banner.Yodo1MasBannerAdRevenueListener
import com.yodo1.mas.banner.Yodo1MasBannerAdSize
import com.yodo1.mas.banner.Yodo1MasBannerAdView
import com.yodo1.mas.error.Yodo1MasError
import com.yodo1.mas.nativeads.Yodo1MasNativeAdListener
import com.yodo1.mas.nativeads.Yodo1MasNativeAdRevenueListener
import com.yodo1.mas.nativeads.Yodo1MasNativeAdView
import com.yodo1.mas.nativeads.Yodo1MasNativeAdViewBuilder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Logcat tag for every ad view in this file. */
private const val TAG = "Yodo1AdViews"

/**
 * Bridges Yodo1 MAS banner and native ads into Flutter as platform views.
 *
 * The official `yodo1_mas_flutter_plugin` documents both formats but its
 * Android and iOS implementations handle only rewarded, interstitial and
 * app-open: banner and native requests fall through a `default` branch and are
 * silently dropped, and it registers no platform view at all. Both MAS views
 * are ordinary Android views, so this plugin embeds them directly, which also
 * gives the app what the ad-type API could not: a view it positions itself, a
 * real `destroy()`, and the impression revenue callback.
 *
 * Full-screen formats keep going through the official plugin. This one adds
 * only what that plugin is missing.
 */
class Yodo1AdViewsPlugin : FlutterPlugin, ActivityAware {
    private var activity: Activity? = null
    private var control: MethodChannel? = null
    private var attached = false
    private var banners: Yodo1AdViewFactory? = null
    private val nativeViews = mutableListOf<Yodo1NativePlatformView>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = true
        val messenger = binding.binaryMessenger
        control = MethodChannel(messenger, "genrevibes.ads.yodo1/control").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method != "initialize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val key = call.argument<String>("appKey")
                val host = activity
                if (key.isNullOrBlank() || host == null) {
                    result.error("init_unavailable", "Activity or app key missing", null)
                    return@setMethodCallHandler
                }
                // MAS is process-scoped; a fresh Dart engine must not wait for
                // a second init callback from an already initialized SDK.
                if (initializedAppKey == key) {
                    result.success(true)
                    return@setMethodCallHandler
                }
                if (initializedAppKey != null) {
                    result.error("app_key_changed", "MAS already initialized with another key", null)
                    return@setMethodCallHandler
                }
                val sdk = Yodo1Mas.getInstance()
                sdk.setGDPR(call.argument<Boolean>("gdpr") ?: false)
                sdk.setCOPPA(call.argument<Boolean>("coppa") ?: false)
                sdk.setCCPA(call.argument<Boolean>("ccpa") ?: false)
                sdk.setAdBuildConfig(Yodo1MasAdBuildConfig.Builder()
                    .enableUserPrivacyDialog(call.argument<Boolean>("privacy") ?: true).build())
                var replied = false
                fun complete(success: Boolean) {
                    if (success) initializedAppKey = key
                    if (replied) return
                    replied = true
                    if (attached) result.success(success)
                }
                try {
                    sdk.initMas(host, key, object : Yodo1Mas.InitListener {
                        override fun onMasInitSuccessful() = complete(true)
                        override fun onMasInitSuccessful(config: Yodo1MasSdkConfiguration) = complete(true)
                        override fun onMasInitFailed(error: Yodo1MasError) {
                            Log.w(TAG, "MAS initialization failed: ${error.code} ${error.message}")
                            complete(false)
                        }
                    })
                } catch (error: Exception) {
                    if (!replied && attached) result.error("init_exception", error.message, null)
                    replied = true
                }
            }
        }
        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW_TYPE,
            Yodo1AdViewFactory(messenger, native = false).also { banners = it },
        )
        binding.platformViewRegistry.registerViewFactory(
            NATIVE_VIEW_TYPE,
            Yodo1AdViewFactory(messenger, native = true, nativeViews = nativeViews),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        control?.setMethodCallHandler(null)
        control = null
        nativeViews.toList().forEach { it.dispose() }
        nativeViews.clear()
        banners = null
    }

    companion object {
        private var initializedAppKey: String? = null
        const val BANNER_VIEW_TYPE = "genrevibes.ads.yodo1/banner"
        const val NATIVE_VIEW_TYPE = "genrevibes.ads.yodo1/native"
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
}

/** Creates one ad view per Flutter widget instance. */
internal class Yodo1AdViewFactory(
    private val messenger: BinaryMessenger,
    private val native: Boolean,
    private val nativeViews: MutableList<Yodo1NativePlatformView>? = null,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        val channel = MethodChannel(messenger, "genrevibes.ads.yodo1/view_$viewId")
        return if (native) {
            Yodo1NativePlatformView(context, params, channel, viewId) { view ->
                nativeViews?.remove(view)
            }.also { nativeViews?.add(it) }
        } else {
            Yodo1BannerPlatformView(context, params, channel, viewId)
        }
    }
}

/** Reports one ad view's lifecycle to its Dart widget. */
internal class AdViewEvents(
    private val channel: MethodChannel,
    private val label: String = "banner",
) {
    private var disposed = false

    fun dispose() { disposed = true }

    fun loaded() {
        if (disposed) return
        Log.d(TAG, "$label: Ad view loaded")
        channel.invokeMethod("loaded", null)
    }

    fun failed(error: Yodo1MasError?) {
        if (disposed) return
        Log.w(TAG, "$label: Ad view failed: code=${error?.code} ${error?.message}")
        channel.invokeMethod("failed", "code=${error?.code} ${error?.message}")
    }


    fun clicked() { if (!disposed) channel.invokeMethod("clicked", null) }

    fun paid(value: Yodo1MasAdValue?) {
        if (disposed || value == null) return
        // Only the fields every network reports; anything richer differs per
        // adapter and would be wrong more often than useful.
        channel.invokeMethod(
            "paid",
            mapOf(
                "value" to value.revenue,
                "currency" to value.currency,
                "network" to value.networkName,
                "precision" to value.revenuePrecision,
            ),
        )
    }
}

/** A MAS banner, sized by the Dart widget and destroyed with it. */
internal class Yodo1BannerPlatformView(
    context: Context,
    params: Map<String, Any?>,
    private val channel: MethodChannel,
    viewId: Int,
) : PlatformView {

    private val label = "banner placement=${params["placementId"]} view=$viewId"
    private val events = AdViewEvents(channel, label)
    private val banner = Yodo1MasBannerAdView(context)
    private var destroyed = false
    private var started = false

    init {
        banner.setAdSize(sizeFrom(params["size"] as? String))
        (params["placementId"] as? String)?.let(banner::setAdPlacement)
        banner.setAdListener(object : Yodo1MasBannerAdListener {
            override fun onBannerAdLoaded(view: Yodo1MasBannerAdView?) {
                banner.post {
                    if (destroyed) return@post
                    banner.requestLayout()
                    if (banner.width > 0 && banner.height > 0) {
                        banner.measure(
                            View.MeasureSpec.makeMeasureSpec(banner.width, View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(banner.height, View.MeasureSpec.EXACTLY),
                        )
                        banner.layout(banner.left, banner.top, banner.right, banner.bottom)
                    }
                    banner.invalidate()
                    Log.d(TAG, "$label: layout ${banner.width}x${banner.height}, attached=${banner.isAttachedToWindow}")
                    events.loaded()
                }
            }

            override fun onBannerAdFailedToLoad(
                view: Yodo1MasBannerAdView?,
                error: Yodo1MasError,
            ) = events.failed(error)

            override fun onBannerAdOpened(view: Yodo1MasBannerAdView?) = events.clicked()

            override fun onBannerAdFailedToOpen(
                view: Yodo1MasBannerAdView?,
                error: Yodo1MasError,
            ) = events.failed(error)

            override fun onBannerAdClosed(view: Yodo1MasBannerAdView?) {}
        })
        banner.setAdRevenueListener(
            Yodo1MasBannerAdRevenueListener { _, value -> events.paid(value) },
        )
        channel.setMethodCallHandler { call, result ->
            if (call.method != "load") {
                result.notImplemented()
            } else if (destroyed) {
                result.error("disposed", "Banner view already disposed", null)
            } else {
                try {
                    if (!started) {
                        started = true
                        Log.d(TAG, "$label: requesting creative")
                        banner.loadAd()
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("banner_load", error.message, null)
                }
            }
        }
    }

    override fun getView(): View = banner

    override fun dispose() {
        if (destroyed) return
        destroyed = true
        events.dispose()
        channel.setMethodCallHandler(null)
        banner.destroy()
    }

    private fun sizeFrom(name: String?): Yodo1MasBannerAdSize = when (name) {
        "large" -> Yodo1MasBannerAdSize.LargeBanner
        "mediumRectangle" -> Yodo1MasBannerAdSize.IABMediumRectangle
        "smart" -> Yodo1MasBannerAdSize.SmartBanner
        "adaptive" -> Yodo1MasBannerAdSize.AdaptiveBanner
        else -> Yodo1MasBannerAdSize.Banner
    }
}

/**
 * A MAS native ad rendered into this package's layout.
 *
 * MAS fills a layout the host supplies and needs to be told which view is the
 * headline, the media area and so on, so the layout and the id mapping ship
 * together here rather than being each app's problem.
 */
internal class Yodo1NativePlatformView(
    context: Context,
    params: Map<String, Any?>,
    private val channel: MethodChannel,
    viewId: Int,
    private val onDisposed: (Yodo1NativePlatformView) -> Unit,
) : PlatformView {

    private val label = "native placement=${params["placementId"]} view=$viewId"
    private val events = AdViewEvents(channel, label)
    private val native = Yodo1MasNativeAdView(context)
    private var destroyed = false
    private var started = false

    init {
        native.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
        )
        native.setLayoutId(R.layout.genrevibes_yodo1_native_ad, builder())
        (params["placementId"] as? String)?.let(native::setAdPlacement)
        (params["backgroundColor"] as? String)?.let(native::setAdBackgroundColor)
        native.setAdListener(object : Yodo1MasNativeAdListener {
            override fun onNativeAdLoaded(view: Yodo1MasNativeAdView?) {
                if (destroyed) return
                // The SDK inserts children asynchronously. Ask the platform-view
                // host to lay them out after that insertion, not just at creation.
                native.post {
                    if (destroyed) return@post
                    native.requestLayout()
                    if (native.width > 0 && native.height > 0) {
                        native.measure(
                            View.MeasureSpec.makeMeasureSpec(native.width, View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(native.height, View.MeasureSpec.EXACTLY),
                        )
                        native.layout(native.left, native.top, native.right, native.bottom)
                    }
                    native.invalidate()
                    Log.d(TAG, "$label: layout ${native.width}x${native.height}, children=${native.childCount}, attached=${native.isAttachedToWindow}")
                    verifyContent(0)
                }
            }

            override fun onNativeAdFailedToLoad(
                view: Yodo1MasNativeAdView?,
                error: Yodo1MasError,
            ) = events.failed(error)
        })
        native.setAdRevenueListener(
            // Spelled "onNativedAdPayRevenue" in the SDK; SAM conversion keeps
            // that typo out of this file.
            Yodo1MasNativeAdRevenueListener { _, value -> events.paid(value) },
        )
        channel.setMethodCallHandler { call, result ->
            if (call.method != "load") {
                result.notImplemented()
            } else if (destroyed) {
                result.error("disposed", "Native view already disposed", null)
            } else {
                try {
                    if (!started) {
                        started = true
                        Log.d(TAG, "$label: requesting creative")
                        native.loadAd()
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("native_load", error.message, null)
                }
            }
        }
    }

    override fun getView(): View = native

    // A load callback alone is not enough: some adapters report it before
    // adding their asset views. Do not report an empty container as ready.
    private fun hasText(view: View): Boolean {
        if (view is TextView && !view.text.isNullOrBlank()) return true
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                if (hasText(view.getChildAt(index))) return true
            }
        }
        return false
    }

    private fun verifyContent(check: Int) {
        if (destroyed) return
        if (native.width > 0 && native.height > 0 && hasText(native)) {
            events.loaded()
        } else if (check < 20) {
            native.postDelayed({ verifyContent(check + 1) }, 500)
        } else {
            Log.w(TAG, "$label: loaded callback without text assets or usable layout")
            channel.invokeMethod("failed", "native_content_missing_after_load")
        }
    }

    override fun dispose() {
        if (destroyed) return
        destroyed = true
        events.dispose()
        channel.setMethodCallHandler(null)
        native.destroy()
        onDisposed(this)
    }

    private fun builder(): Yodo1MasNativeAdViewBuilder =
        Yodo1MasNativeAdViewBuilder()
            .setIconImageViewId(R.id.genrevibes_yodo1_native_icon)
            .setTitleTextViewId(R.id.genrevibes_yodo1_native_title)
            .setAdvertiserTextViewId(R.id.genrevibes_yodo1_native_advertiser)
            .setBodyTextViewId(R.id.genrevibes_yodo1_native_body)
            .setMediaContentViewGroupId(R.id.genrevibes_yodo1_native_media)
            .setOptionsContentViewGroupId(R.id.genrevibes_yodo1_native_options)
            .setCallToActionButtonId(R.id.genrevibes_yodo1_native_cta)
}
