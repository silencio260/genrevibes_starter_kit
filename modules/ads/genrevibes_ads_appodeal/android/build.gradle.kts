group = "com.genrevibes.ads_appodeal"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.0"

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.12.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

if (agpMajor < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

android {
    namespace = "com.genrevibes.ads_appodeal"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 21
    }
}

dependencies {
    // Appodeal's Firebase service adapter. It sends every Appodeal impression's
    // revenue to Firebase as `ad_impression` (once Firebase Tracking is on in
    // the app's Appodeal dashboard), so apps no longer declare it themselves.
    // Matches the native set published with stack_appodeal_flutter 4.3.1;
    // upgrade the two together. FirebaseAnalyticsSink skips the app's own
    // Appodeal copy by default to avoid counting it twice.
    implementation("com.appodeal.ads.sdk.adapters:firebase:23.2.0.0")
}
