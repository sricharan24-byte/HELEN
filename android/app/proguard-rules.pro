# BUS-P2-02: R8 keep rules for the BusBuddy release build.
# Only evidence-based keeps live here. The Flutter Gradle plugin already
# supplies default rules for the Flutter engine and generated plugin
# registrant (see Flutter's flutter_embedding_release proguard artifacts);
# these rules cover the plugin-generated glue that is looked up reflectively
# and the JSON-backed settings store whose names are read dynamically.

# Flutter engine JNI bridge (FlutterJNI natives bind by class name).
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }

# GeneratedPluginRegistrant is referenced reflectively by the embedding.
-keep public class com.busbuddy.app.MainActivity { *; }

# shared_preferences_android is invoked through platform channels by
# generated handler names; keep its entry points.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# BUS-P2-02: Flutter embedding optionally references Play Store split /
# deferred-component APIs that are not on BusBuddy's dependency graph
# (no Play Core dependency, no dynamic feature modules). R8 requires
# -dontwarn for these optional link-time references; they are never
# executed at runtime in this packaging. Source: AGP-generated
# missing_rules.txt from minifyReleaseWithR8 on 2026-09-20.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
