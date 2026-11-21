package com.genrevibes.ads_appodeal

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * No channel: this plugin exists so its Gradle module brings Appodeal's
 * Firebase revenue adapter into every app that uses genrevibes_ads_appodeal.
 */
class GenRevibesAppodealPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
}
