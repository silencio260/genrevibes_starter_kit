package com.genrevibes.device_identity_platform

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.ads.identifier.AdvertisingIdClient
import com.google.android.gms.appset.AppSet
import com.google.android.gms.appset.AppSetIdInfo
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Reads identifiers only Android's own APIs expose. */
class GenRevibesDeviceIdentityPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
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
        if (context == null) {
            result.error(UNAVAILABLE, "Plugin is detached from the engine.", null)
            return
        }
        when (call.method) {
            "appSetId" -> readAppSetId(context, result)
            "firstInstallTime" -> readFirstInstallTime(context, result)
            "advertisingId" -> readAdvertisingId(context, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Google's advertising ID, so a developer can register the phone as an ad
     * network test device. Play services answers over a blocking call, so it
     * is read off the main thread. The ID is all zeros once the user deletes
     * it.
     */
    private fun readAdvertisingId(context: Context, result: MethodChannel.Result) {
        val main = Handler(Looper.getMainLooper())
        Thread {
            try {
                val info = AdvertisingIdClient.getAdvertisingIdInfo(context)
                val payload = mapOf(
                    "id" to info.id,
                    "limitAdTracking" to info.isLimitAdTrackingEnabled,
                )
                main.post { result.success(payload) }
            } catch (error: Exception) {
                main.post { result.error(UNAVAILABLE, error.message, null) }
            }
        }.start()
    }

    /**
     * Google's app set ID. Developer-scoped for Play installs, so one value
     * covers every app from the same Play developer account on this device.
     * Fetched on every call, as Google's documentation requires.
     */
    private fun readAppSetId(context: Context, result: MethodChannel.Result) {
        try {
            AppSet.getClient(context).appSetIdInfo
                .addOnSuccessListener { info ->
                    result.success(
                        mapOf("id" to info.id, "scope" to scopeName(info.scope)),
                    )
                }
                .addOnFailureListener { error ->
                    result.error(UNAVAILABLE, error.message, null)
                }
        } catch (error: Exception) {
            result.error(UNAVAILABLE, error.message, null)
        }
    }

    /** Changes on every reinstall; it is not app data, so no backup restores it. */
    private fun readFirstInstallTime(context: Context, result: MethodChannel.Result) {
        try {
            @Suppress("DEPRECATION")
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            result.success(info.firstInstallTime)
        } catch (error: Exception) {
            result.error(UNAVAILABLE, error.message, null)
        }
    }

    private fun scopeName(scope: Int): String = when (scope) {
        AppSetIdInfo.SCOPE_DEVELOPER -> "developer"
        AppSetIdInfo.SCOPE_APP -> "app"
        else -> "unknown"
    }

    private companion object {
        const val CHANNEL = "com.genrevibes/device_identity"
        const val UNAVAILABLE = "unavailable"
    }
}
