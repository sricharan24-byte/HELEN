import 'package:flutter/foundation.dart';

import '../datasources/local_json_store.dart';

class EmergencyContactRepository extends ChangeNotifier {
  EmergencyContactRepository();

  static final instance = EmergencyContactRepository();
  static const storageKey = 'busbuddy.emergencyContacts.v1';
  LocalJsonStore? _store;
  final List<Map<String, String>> _contacts = [
    {'name': 'Parent / Guardian', 'phone': '+91 98765 43210', 'relation': 'Family'},
    {'name': 'Campus Security', 'phone': '+91 416 220 2000', 'relation': 'VIT Security'},
  ];

  List<Map<String, String>> get contacts => List.unmodifiable(
    _contacts.map((contact) => Map<String, String>.unmodifiable(contact)),
  );

  static bool _valid(Object? value) =>
      value is Map &&
      ['name', 'phone', 'relation'].every(
        (key) => value[key] is String && (value[key] as String).trim().isNotEmpty,
      );

  Future<void> hydrate(LocalJsonStore store) async {
    await store.flush();
    _store = store;
    final stored = store.read(storageKey);
    if (stored.absent) {
      await store.write(storageKey, _contacts);
    } else {
      final value = stored.value;
      if (value is List) {
        final parsed = <Map<String, String>>[
          for (final item in value)
            if (_valid(item))
              {
                for (final key in ['name', 'phone', 'relation'])
                  key: (item as Map)[key] as String,
              },
        ];
        _contacts
          ..clear()
          ..addAll(parsed);
      }
    }
    notifyListeners();
  }

  void addContact(Map<String, String> contact) {
    if (!_valid(contact)) return;
    _contacts.add({
      for (final key in ['name', 'phone', 'relation']) key: contact[key]!.trim(),
    });
    _persist();
  }

  void removeContact(int index) {
    _contacts.removeAt(index);
    _persist();
  }

  void _persist() {
    _store?.write(storageKey, _contacts);
    notifyListeners();
  }
}
