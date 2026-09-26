import 'dart:io' show Platform;

/// Real OS check. `defaultTargetPlatform` is wrong for this purpose because
/// `flutter_test` reports Android even while tests run on a Linux VM, which
/// would send widget tests down the Android audio path with no plugin attached.
bool get platformHasNativeAudio => Platform.isAndroid;
