group = "com.genrevibes.ads_appodeal_native"
version = "1.0-SNAPSHOT"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.12.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://artifactory.appodeal.com/appodeal") }
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.genrevibes.ads_appodeal_native"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }
}

dependencies {
    // Compile against the Appodeal SDK only. At runtime the app already has the
    // one stack_appodeal_flutter ships, so this never pins a second version.
    compileOnly("com.appodeal.ads.sdk:core:4.2.0")
}
