plugins {
    id("com.android.application")
    // Required: AGP 8.x has no built-in Kotlin, so the `kotlin { }` block below
    // and MainActivity.kt need KGP applied explicitly.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.busbuddy.app"
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

    signingConfigs {
        create("release") {
            val keystoreFile = project.findProperty("RELEASE_STORE_FILE")?.toString()
                ?: System.getenv("RELEASE_STORE_FILE")
            if (keystoreFile != null && file(keystoreFile).exists()) {
                storeFile = file(keystoreFile)
                storePassword = project.findProperty("RELEASE_STORE_PASSWORD")?.toString()
                    ?: System.getenv("RELEASE_STORE_PASSWORD") ?: ""
                keyAlias = project.findProperty("RELEASE_KEY_ALIAS")?.toString()
                    ?: System.getenv("RELEASE_KEY_ALIAS") ?: ""
                keyPassword = project.findProperty("RELEASE_KEY_PASSWORD")?.toString()
                    ?: System.getenv("RELEASE_KEY_PASSWORD") ?: ""
            }
        }
    }

    defaultConfig {
        applicationId = "com.busbuddy.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.findByName("release")
            signingConfig = if (releaseSigning?.storeFile != null) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
            // BUS-P2-02: R8 code shrinking + resource shrinking for release.
            // Keep rules live in android/app/proguard-rules.pro and are
            // limited to evidence-based keeps (Flutter embedding + plugins);
            // release smoke tests must re-verify reflection/plugin features.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
