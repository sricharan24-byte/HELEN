import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalJsonStore {
  LocalJsonStore(this._preferences, {String? namespace}) : _namespace = namespace;

  final SharedPreferences? _preferences;
  final String? _namespace;
  static Future<void> _pending = Future<void>.value();
  Object? lastError;

  static Future<LocalJsonStore> open() async {
    try {
      return LocalJsonStore(await SharedPreferences.getInstance());
    } catch (error) {
      return LocalJsonStore(null)..lastError = error;
    }
  }

  /// Opens a store isolated to [namespace]: all keys are prefixed so tests
  /// and feature sandboxes never collide with the default shared store.
  static Future<LocalJsonStore> openScoped({required String namespace}) async {
    try {
      return LocalJsonStore(
        await SharedPreferences.getInstance(),
        namespace: namespace,
      );
    } catch (error) {
      return LocalJsonStore(null, namespace: namespace)..lastError = error;
    }
  }

  String _qualified(String key) =>
      _namespace == null ? key : '${_namespace}:$key';

  Future<void> flush() => _pending;

  ({bool absent, Object? value}) read(String key) {
    try {
      final preferences = _preferences;
      if (preferences == null) return (absent: false, value: null);
      final qualifiedKey = _qualified(key);
      if (!preferences.containsKey(qualifiedKey)) {
        return (absent: true, value: null);
      }
      final raw = preferences.get(qualifiedKey);
      if (raw is! String) throw const FormatException('Expected JSON string');
      return (absent: false, value: jsonDecode(raw));
    } catch (error) {
      lastError = error;
      return (absent: false, value: null);
    }
  }

  Future<bool> write(String key, Object value) {
    final String snapshot;
    try {
      snapshot = jsonEncode(value);
    } catch (error) {
      lastError = error;
      return Future<bool>.value(false);
    }
    final result = _pending.then((_) async {
      try {
        final preferences = _preferences;
        if (preferences == null) throw StateError('Storage unavailable');
        if (!await preferences.setString(_qualified(key), snapshot)) {
          throw StateError('Storage write failed');
        }
        lastError = null;
        return true;
      } catch (error) {
        lastError = error;
        return false;
      }
    });
    _pending = result.then((_) {});
    return result;
  }
}
