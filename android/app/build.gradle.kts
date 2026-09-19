plugins {
    id("com.android.application")
    // Required: AGP 8.x has no built-in Kotlin, so the `kotlin { }` block below
    // and MainActivity.kt need KGP applied explicitly.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.busbuddy"
    compileSdk = flutter.compileSdkVersion
    // Pinned to the only build-tools installed locally, so AGP never tries to
    // auto-download another version (which re-triggers the license check).
    buildToolsVersion = "36.0.0"
    // Must be set explicitly. Leaving it unset does NOT skip the NDK: Flutter's
    // FlutterPluginUtils computes max(app, plugins) ndkVersion and, with no app
    // value, falls through to AGP 8.11.1's own default (27.0.12077973) — which
    // is the package the license check was failing on.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.busbuddy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
