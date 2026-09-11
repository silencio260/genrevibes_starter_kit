package com.genrevibes.consent_appodeal

import android.app.Activity
import android.content.Context
import android.content.pm.ApplicationInfo
import com.google.android.ump.ConsentDebugSettings
import com.google.android.ump.ConsentRequestParameters
import com.google.android.ump.FormError
import com.google.android.ump.UserMessagingPlatform
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Consent development tools the Appodeal Flutter plugin does not expose.
 *
 * Appodeal's consent manager is built on Google's User Messaging Platform but
 * never passes it debug settings, so a device outside a regulated region can
 * never see the form. The preview calls the platform directly with them, and
 * refuses in a build that is not debuggable: forcing a region in production
 * would show the form to users who should not see it.
 *
 * Reading the stored consent signals only reads storage, so it runs anywhere.
 */
class GenRevibesConsentAppodealPlugin :
    FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null
    private var activity: Activity? = null

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

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "previewConsentForm" -> previewConsentForm(call, result)
            "readConsentSignals" -> readConsentSignals(result)
            else -> result.notImplemented()
        }
    }

    /**
     * Every `IABTCF_` and `IABGPP_` value in the app's default shared
     * preferences. The IAB specifications put consent signals there, which is
     * where ad SDKs read them.
     */
    private fun readConsentSignals(result: MethodChannel.Result) {
        val context = context
        if (context == null) {
            result.error(UNAVAILABLE, "Plugin is detached from the engine.", null)
            return
        }
        try {
            val preferences = context.getSharedPreferences(
                "${context.packageName}_preferences",
                Context.MODE_PRIVATE,
            )
            val signals = preferences.all
                .filterKeys { it.startsWith("IABTCF_") || it.startsWith("IABGPP_") }
                .mapValues { (_, value) ->
                    when (value) {
                        is Int, is Long, is Boolean, is String, null -> value
                        else -> value.toString()
                    }
                }
            result.success(signals)
        } catch (error: Exception) {
            result.error(UNAVAILABLE, error.message, null)
        }
    }

    /**
     * Updates consent information with the requested region simulated, then
     * loads and shows the form. Answers when the form is dismissed.
     */
    private fun previewConsentForm(call: MethodCall, result: MethodChannel.Result) {
        val activity = activity
        if (activity == null) {
            result.error(UNAVAILABLE, "No activity is attached.", null)
            return
        }
        if ((activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) == 0) {
            result.error(DEBUG_ONLY, "The consent form preview runs only in debuggable builds.", null)
            return
        }

        val geography = when (call.argument<String>("geography")) {
            "europeanEconomicArea" -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_EEA
            "notRegulated" -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_OTHER
            else -> ConsentDebugSettings.DebugGeography.DEBUG_GEOGRAPHY_DISABLED
        }
        val debugSettings = ConsentDebugSettings.Builder(activity)
            .setDebugGeography(geography)
            // Applies the settings without this device's hashed ID, so no
            // device identifier is read.
            .setForceTesting(true)
        call.argument<List<String>>("testDeviceIds")?.forEach {
            debugSettings.addTestDeviceHashedId(it)
        }
        val parameters = ConsentRequestParameters.Builder()
            .setConsentDebugSettings(debugSettings.build())
            .build()

        val reply = Reply(result)
        try {
            UserMessagingPlatform.getConsentInformation(activity).requestConsentInfoUpdate(
                activity,
                parameters,
                {
                    UserMessagingPlatform.loadConsentForm(
                        activity,
                        { form ->
                            form.show(activity) { error ->
                                if (error == null) reply.success() else reply.error(FORM_ERROR, error)
                            }
                        },
                        { error -> reply.error(FORM_UNAVAILABLE, error) },
                    )
                },
                { error -> reply.error(UPDATE_FAILED, error) },
            )
        } catch (error: Exception) {
            reply.error(UNAVAILABLE, error.message)
        }
    }

    /** Answers a call exactly once, whichever callback arrives first. */
    private class Reply(private val result: MethodChannel.Result) {
        private var sent = false

        fun success() {
            if (sent) return
            sent = true
            result.success(null)
        }

        fun error(code: String, error: FormError) =
            error(code, "${error.message} (UMP code ${error.errorCode})")

        fun error(code: String, message: String?) {
            if (sent) return
            sent = true
            result.error(code, message, null)
        }
    }

    private companion object {
        const val CHANNEL = "com.genrevibes/consent_appodeal"
        const val UNAVAILABLE = "unavailable"
        const val DEBUG_ONLY = "debug_only"
        const val UPDATE_FAILED = "update_failed"
        const val FORM_UNAVAILABLE = "form_unavailable"
        const val FORM_ERROR = "form_error"
    }
}
