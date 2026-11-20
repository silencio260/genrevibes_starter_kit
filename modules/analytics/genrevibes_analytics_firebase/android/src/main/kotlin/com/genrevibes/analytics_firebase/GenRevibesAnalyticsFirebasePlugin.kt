package com.genrevibes.analytics_firebase

import android.content.Context
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Tells the Firebase sink whether it runs on one of Google's test phones. */
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
        when {
            call.method != "isGoogleTestDevice" -> result.notImplemented()
            context == null -> result.success(false)
            else -> result.success(isFirebaseTestLab(context))
        }
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
    }
}
