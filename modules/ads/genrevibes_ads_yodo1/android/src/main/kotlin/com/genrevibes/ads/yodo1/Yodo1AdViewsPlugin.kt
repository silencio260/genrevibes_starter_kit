package com.genrevibes.ads.yodo1

import android.content.Context
import android.app.Activity
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
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
    private val views = mutableSetOf<InlinePlatformView>()
    private val preloads = InlineAdPreloads()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = true
        val messenger = binding.binaryMessenger
        control = MethodChannel(messenger, "genrevibes.ads.yodo1/control").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "clearPreloads") {
                    preloads.clear()
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method == "preloadInline") {
                    val host = activity
                    val params = call.arguments as? Map<*, *>
                    val placement = params?.get("placementId") as? String
                    val format = params?.get("format") as? String
                    if (host == null || initializedAppKey == null || placement.isNullOrBlank() ||
                        (format != "native" && format != "banner")) {
                        result.success(false)
                    } else {
                        @Suppress("UNCHECKED_CAST")
                        val arguments = params as Map<String, Any?>
                        preloads.load(arguments, result) {
                            createView(host, arguments, format == "native")
                        }
                    }
                    return@setMethodCallHandler
                }
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
            Yodo1AdViewFactory(messenger, native = false, preloads = preloads, createView = ::createView),
        )
        binding.platformViewRegistry.registerViewFactory(
            NATIVE_VIEW_TYPE,
            Yodo1AdViewFactory(messenger, native = true, preloads = preloads, createView = ::createView),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        attached = false
        control?.setMethodCallHandler(null)
        control = null
        preloads.clear()
        views.toList().forEach { it.dispose() }
        views.clear()
    }

    private fun createView(context: Context, params: Map<String, Any?>, native: Boolean): InlinePlatformView {
        val view = if (native) Yodo1NativePlatformView(context, params) { views.remove(it) }
            else Yodo1BannerPlatformView(context, params) { views.remove(it) }
        views.add(view)
        return view
    }

    companion object {
        private var initializedAppKey: String? = null
        const val BANNER_VIEW_TYPE = "genrevibes.ads.yodo1/banner"
        const val NATIVE_VIEW_TYPE = "genrevibes.ads.yodo1/native"
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { preloads.clear(); activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { preloads.clear(); activity = null }
}

/** Creates one ad view per Flutter widget instance. */
internal class Yodo1AdViewFactory(
    private val messenger: BinaryMessenger,
    private val native: Boolean,
    private val preloads: InlineAdPreloads,
    private val createView: (Context, Map<String, Any?>, Boolean) -> InlinePlatformView,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val params = args as? Map<String, Any?> ?: emptyMap()
        val channel = MethodChannel(messenger, "genrevibes.ads.yodo1/view_$viewId")
        val view = preloads.take(params + ("format" to if (native) "native" else "banner"))
            ?: createView(context, params, native)
        view.attach(channel)
        return view
    }
}

/** Detached views only: no hidden window and no app impression event on preload. */
internal class InlineAdPreloads {
    private data class Entry(val view: InlinePlatformView, val waiters: MutableList<MethodChannel.Result>)
    private val entries = linkedMapOf<String, Entry>()
    private val handler = Handler(Looper.getMainLooper())
    private fun key(params: Map<String, Any?>) = listOf(
        params["format"], params["placementId"], params["size"], params["backgroundColor"],
        params["widthPx"], params["heightPx"],
    ).joinToString("|")

    fun load(params: Map<String, Any?>, result: MethodChannel.Result, create: () -> InlinePlatformView) {
        val key = key(params)
        entries[key]?.let {
            if (it.view.loaded) result.success(true) else it.waiters.add(result)
            return
        }
        // Keep one creative per placement, with a small, bounded memory budget.
        if (entries.size >= 6) remove(entries.keys.first())
        val view = create()
        val entry = Entry(view, mutableListOf(result))
        entries[key] = entry
        view.onPreloadResult = { ready ->
            if (entries[key] === entry) {
                entry.waiters.toList().forEach { it.success(ready) }
                entry.waiters.clear()
                if (!ready) remove(key)
            }
        }
        handler.postAtTime({
            if (entries[key] === entry && !view.loaded) remove(key)
        }, entry, SystemClock.uptimeMillis() + 30_000)
        handler.postAtTime({ if (entries[key] === entry) remove(key) }, entry,
            SystemClock.uptimeMillis() + 120_000)
        Log.d(TAG, "preload: requesting $key")
        view.start()
    }

    fun take(params: Map<String, Any?>): InlinePlatformView? {
        val key = key(params)
        val entry = entries.remove(key) ?: return null
        handler.removeCallbacksAndMessages(entry)
        entry.view.onPreloadResult = null
        entry.waiters.forEach { it.success(entry.view.loaded) }
        // Transfer even an in-flight request; the destination must not reload it.
        Log.d(TAG, "preload: consumed $key ready=${entry.view.loaded}")
        return entry.view
    }

    private fun remove(key: String) {
        val entry = entries.remove(key) ?: return
        handler.removeCallbacksAndMessages(entry)
        entry.view.onPreloadResult = null
        entry.waiters.forEach { it.success(false) }
        entry.view.dispose()
    }

    fun clear() {
        entries.keys.toList().forEach(::remove)
        handler.removeCallbacksAndMessages(null)
    }
}

/** A single request whose ownership transfers from the cache to one widget. */
internal abstract class InlinePlatformView(private val onDisposed: (InlinePlatformView) -> Unit) : PlatformView {
    protected var channel: MethodChannel? = null
    protected var destroyed = false
    private var started = false
    private var failureMessage: String? = null
    var loaded = false
        private set
    var onPreloadResult: ((Boolean) -> Unit)? = null
    private var listening = false
    protected val events = AdViewEvents(channel = { if (listening) channel else null })

    fun attach(channel: MethodChannel) {
        this.channel = channel
        channel.setMethodCallHandler { call, result ->
            if (call.method != "load") result.notImplemented()
            else if (destroyed) result.error("disposed", "Ad view already disposed", null)
            else {
                // Dart installs its event listener before invoking load.
                listening = true
                val failure = failureMessage
                if (failure != null) channel.invokeMethod("failed", failure)
                else if (loaded) renderLoaded() else start()
                result.success(null)
            }
        }
    }

    fun start() {
        if (started || destroyed) return
        started = true
        try { requestAd() } catch (error: Exception) { failed(error.message ?: "load_exception") }
    }

    protected fun didLoad() {
        if (destroyed) return
        loaded = true
        onPreloadResult?.invoke(true)
        if (listening) renderLoaded()
    }

    protected fun failed(message: String) {
        if (destroyed) return
        failureMessage = message
        Log.w(TAG, "inline load failed: $message")
        if (listening) channel?.invokeMethod("failed", message)
        onPreloadResult?.invoke(false)
    }

    protected abstract fun requestAd()
    protected abstract fun renderLoaded()
    protected abstract fun destroyAd()

    override fun dispose() {
        if (destroyed) return
        destroyed = true
        onPreloadResult = null
        events.dispose()
        channel?.setMethodCallHandler(null)
        channel = null
        destroyAd()
        onDisposed(this)
    }
}

/** Reports one ad view's lifecycle to its Dart widget. */
internal class AdViewEvents(
    private val channel: () -> MethodChannel?,
    private val label: String = "inline",
) {
    private var disposed = false

    fun dispose() { disposed = true }

    fun loaded() {
        if (disposed) return
        Log.d(TAG, "$label: Ad view loaded")
        channel()?.invokeMethod("loaded", null)
    }

    fun clicked() { if (!disposed) channel()?.invokeMethod("clicked", null) }

    fun paid(value: Yodo1MasAdValue?) {
        if (disposed || value == null) return
        // Only the fields every network reports; anything richer differs per
        // adapter and would be wrong more often than useful.
        channel()?.invokeMethod(
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
    onDisposed: (InlinePlatformView) -> Unit,
) : InlinePlatformView(onDisposed) {

    private val label = "banner placement=${params["placementId"]}"
    private val banner = Yodo1MasBannerAdView(context)

    init {
        banner.setBackgroundColor(Color.TRANSPARENT)
        banner.setAdSize(sizeFrom(params["size"] as? String))
        (params["placementId"] as? String)?.let(banner::setAdPlacement)
        banner.setAdListener(object : Yodo1MasBannerAdListener {
            override fun onBannerAdLoaded(view: Yodo1MasBannerAdView?) {
                didLoad()
            }

            override fun onBannerAdFailedToLoad(
                view: Yodo1MasBannerAdView?,
                error: Yodo1MasError,
            ) = failed("code=${error.code} ${error.message}")

            override fun onBannerAdOpened(view: Yodo1MasBannerAdView?) = events.clicked()

            override fun onBannerAdFailedToOpen(
                view: Yodo1MasBannerAdView?,
                error: Yodo1MasError,
            ) = failed("code=${error.code} ${error.message}")

            override fun onBannerAdClosed(view: Yodo1MasBannerAdView?) {}
        })
        banner.setAdRevenueListener(
            Yodo1MasBannerAdRevenueListener { _, value -> events.paid(value) },
        )
    }

    override fun getView(): View = banner

    override fun requestAd() { banner.loadAd() }
    override fun destroyAd() { banner.destroy() }

    override fun renderLoaded() {
        banner.post {
            if (destroyed) return@post
            banner.setBackgroundColor(Color.TRANSPARENT)
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
    onDisposed: (InlinePlatformView) -> Unit,
) : InlinePlatformView(onDisposed) {

    private val label = "native placement=${params["placementId"]}"
    private val native = Yodo1MasNativeAdView(context)
    private var verifying = false

    init {
        native.layoutParams = FrameLayout.LayoutParams(
            (params["widthPx"] as? Number)?.toInt() ?: FrameLayout.LayoutParams.MATCH_PARENT,
            (params["heightPx"] as? Number)?.toInt() ?: FrameLayout.LayoutParams.WRAP_CONTENT,
        )
        native.setLayoutId(R.layout.genrevibes_yodo1_native_ad, builder())
        (params["placementId"] as? String)?.let(native::setAdPlacement)
        (params["backgroundColor"] as? String)?.let(native::setAdBackgroundColor)
        native.setAdListener(object : Yodo1MasNativeAdListener {
            override fun onNativeAdLoaded(view: Yodo1MasNativeAdView?) {
                // SDK-ready is separate from destination layout readiness.
                didLoad()
            }

            override fun onNativeAdFailedToLoad(
                view: Yodo1MasNativeAdView?,
                error: Yodo1MasError,
            ) = failed("code=${error.code} ${error.message}")
        })
        native.setAdRevenueListener(
            // Spelled "onNativedAdPayRevenue" in the SDK; SAM conversion keeps
            // that typo out of this file.
            Yodo1MasNativeAdRevenueListener { _, value -> events.paid(value) },
        )
    }

    override fun getView(): View = native

    override fun requestAd() { native.loadAd() }
    override fun destroyAd() { native.destroy() }

    override fun renderLoaded() {
        if (verifying || destroyed) return
        verifying = true
        // Do not post layout checks while cached: an unattached view has no size.
        native.post {
            if (destroyed) return@post
            native.requestLayout()
            verifyContent(0)
        }
    }

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
        if (native.width > 0 && native.height > 0) {
            native.measure(
                View.MeasureSpec.makeMeasureSpec(native.width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(native.height, View.MeasureSpec.EXACTLY),
            )
            native.layout(native.left, native.top, native.right, native.bottom)
            native.invalidate()
        }
        if (native.width > 0 && native.height > 0 && hasText(native)) {
            verifying = false
            Log.d(TAG, "$label: rendered ${native.width}x${native.height}")
            events.loaded()
        } else if (check < 20) {
            native.postDelayed({ verifyContent(check + 1) }, 500)
        } else {
            Log.w(TAG, "$label: loaded callback without text assets or usable layout")
            verifying = false
            failed("native_content_missing_after_load")
        }
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
