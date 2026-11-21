package com.genrevibes.analytics_firebase

import android.content.Context
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Tells the Firebase sink whether it runs on one of Google's test phones, and
 * which ad SDKs' own Firebase revenue adapters are compiled into the app.
 */
class GenRevibesAnalyticsFirebasePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var context: Context? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val context = context
        when (call.method) {
            "isGoogleTestDevice" ->
                result.success(context != null && isFirebaseTestLab(context))
            "nativeRevenueAdapters" -> result.success(nativeRevenueAdapters())
            else -> result.notImplemented()
        }
    }

    /**
     * Ad platform -> whether its native Firebase revenue adapter is in the app.
     * Looked up by class name, so this plugin needs no ad SDK dependency. The
     * Appodeal service class keeps its name in release builds: Appodeal's
     * consumer rules keep every `Service` subclass.
     */
    private fun nativeRevenueAdapters(): Map<String, Boolean> =
        REVENUE_ADAPTERS.mapValues { (_, className) -> classExists(className) }

    private fun classExists(name: String): Boolean = try {
        Class.forName(name, false, javaClass.classLoader)
        true
    } catch (error: ClassNotFoundException) {
        false
    } catch (error: LinkageError) {
        false
    }

    /**
     * Firebase Test Lab sets this system setting on its devices. Play's
     * pre-launch report and review checks run on Test Lab, so these phones are
     * robots, not users.
     */
    private fun isFirebaseTestLab(context: Context): Boolean = try {
        Settings.System.getString(context.contentResolver, "firebase.test.lab") == "true"
    } catch (error: Exception) {
        false
    }

    private companion object {
        const val CHANNEL = "com.genrevibes/analytics_firebase"

        /** `ad_platform` value -> the class its Firebase revenue adapter adds. */
        val REVENUE_ADAPTERS = mapOf(
            "appodeal" to "com.appodeal.ads.services.firebase.FirebaseService",
        )
    }
}
