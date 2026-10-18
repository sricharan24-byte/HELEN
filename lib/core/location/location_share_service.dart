import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum LocationShareStatus {
  chooserOpened,
  permissionDenied,
  permanentlyDenied,
  locationDisabled,
  timeout,
  unavailable,
  unsupported,
  cancelled,
}

class LocationShareResult {
  const LocationShareResult(this.status);

  final LocationShareStatus status;
}

enum DialerStatus { opened, invalidNumber, unavailable, unsupported }

class DialerResult {
  const DialerResult(this.status);

  final DialerStatus status;
}

/// One-time foreground location sharing through Android's native chooser.
class LocationShareService {
  LocationShareService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('busbuddy/location_share');

  final MethodChannel _channel;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<LocationShareResult> shareCurrentLocation({
    required String message,
    required String chooserTitle,
  }) async {
    if (!_isAndroid) {
      return const LocationShareResult(LocationShareStatus.unsupported);
    }

    try {
      final location = await _channel.invokeMapMethod<String, dynamic>(
        'getCurrentLocation',
      );
      final status = location?['status'];
      if (status != 'success') {
        return LocationShareResult(
          _locationStatus(status, location?['permanentlyDenied'] == true),
        );
      }

      final latitude = _coordinate(location?['latitude'], maxAbsoluteValue: 90);
      final longitude = _coordinate(
        location?['longitude'],
        maxAbsoluteValue: 180,
      );
      if (latitude == null || longitude == null) {
        return const LocationShareResult(LocationShareStatus.unavailable);
      }
      final mapUrl = 'https://maps.google.com/?q=$latitude,$longitude';
      final share = await _channel
          .invokeMapMethod<String, dynamic>('shareText', {
            'text': '$message\nLocation snapshot: $mapUrl',
            'chooserTitle': chooserTitle,
          });
      return LocationShareResult(
        share?['status'] == 'chooser_opened'
            ? LocationShareStatus.chooserOpened
            : LocationShareStatus.unavailable,
      );
    } on MissingPluginException {
      return const LocationShareResult(LocationShareStatus.unsupported);
    } on PlatformException {
      return const LocationShareResult(LocationShareStatus.unavailable);
    }
  }

  Future<DialerResult> openDialer(String phoneNumber) async {
    if (!_isAndroid) return const DialerResult(DialerStatus.unsupported);
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'openDialer',
        {'phoneNumber': phoneNumber},
      );
      return DialerResult(switch (result?['status']) {
        'dialer_opened' => DialerStatus.opened,
        'invalid_number' => DialerStatus.invalidNumber,
        _ => DialerStatus.unavailable,
      });
    } on MissingPluginException {
      return const DialerResult(DialerStatus.unsupported);
    } on PlatformException {
      return const DialerResult(DialerStatus.unavailable);
    }
  }

  Future<void> cancelCurrentLocation() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('cancelLocation');
    } on MissingPluginException {
      // The Android channel may not be attached during app teardown.
    } on PlatformException {
      // Cancellation is best effort; the native timeout remains bounded.
    }
  }

  static String? _coordinate(
    Object? value, {
    required double maxAbsoluteValue,
  }) {
    final number = switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
    if (number == null || !number.isFinite || number.abs() > maxAbsoluteValue) {
      return null;
    }
    return number.toStringAsFixed(6);
  }

  static LocationShareStatus _locationStatus(
    Object? status,
    bool permanentlyDenied,
  ) => switch (status) {
    'permission_denied' =>
      permanentlyDenied
          ? LocationShareStatus.permanentlyDenied
          : LocationShareStatus.permissionDenied,
    'location_disabled' => LocationShareStatus.locationDisabled,
    'timeout' => LocationShareStatus.timeout,
    'unsupported' => LocationShareStatus.unsupported,
    'cancelled' => LocationShareStatus.cancelled,
    _ => LocationShareStatus.unavailable,
  };
}
