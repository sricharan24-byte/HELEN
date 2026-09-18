import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:busbuddy/core/settings/app_settings_controller.dart';
import 'package:busbuddy/data/models/home_screen_item.dart';
import 'package:busbuddy/data/models/transport_models.dart';
import 'package:busbuddy/data/models/ticket_model.dart';
import 'package:busbuddy/data/repositories/emergency_contact_repository.dart';
import 'package:busbuddy/data/repositories/ticket_repository.dart';
import 'package:busbuddy/data/datasources/local_json_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LocalJsonStore', () {
    test('read absent key reports absent', () async {
      final store = await LocalJsonStore.open();
      final result = store.read('missing');
      expect(result.absent, isTrue);
      expect(result.value, isNull);
    });
  });

  group('AppSettingsController persistence', () {
    test('fresh instance seeds defaults and writes them to storage', () async {
      final controller = AppSettingsController.local();
      final store = await LocalJsonStore.open();
      await controller.hydrate(store);
      expect(controller.textSize, 'Large');
      final result = store.read(AppSettingsController.storageKey);
      expect(result.absent, isFalse);
      expect(result.value, isMap);
    });

    test('stored payload overrides defaults, API key excluded', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.busbuddy.settings.v1': jsonEncode({
          'textSize': 'Medium',
          'geminiModel': 'custom-model',
          'geminiApiKey': 'leak-attempt',
        }),
      });
      final controller = AppSettingsController.local();
      final store = await LocalJsonStore.open();
      await controller.hydrate(store);
      expect(controller.textSize, 'Medium');
      expect(controller.geminiModel, 'custom-model');
      expect(controller.geminiApiKey, '');
    });

    test('corrupt payload falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.busbuddy.settings.v1': 'not json',
      });
      final controller = AppSettingsController.local();
      final store = await LocalJsonStore.open();
      await controller.hydrate(store);
      expect(controller.textSize, 'Large');
      expect(store.lastError, isNotNull);
    });

    test('api key excluded from persisted snapshot', () async {
      final controller = AppSettingsController.local();
      final store = await LocalJsonStore.open();
      await controller.hydrate(store);
      controller.updateGeminiApiKey('secret');
      await store.flush();
      final result = store.read(AppSettingsController.storageKey);
      final json = result.value as Map;
      expect(json.containsKey('geminiApiKey'), isFalse);
      expect(controller.geminiApiKey, 'secret');
    });

    test('resetToDefaults persists reset values', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.busbuddy.settings.v1': jsonEncode({'textSize': 'Small'}),
      });
      final controller = AppSettingsController.local();
      final store = await LocalJsonStore.open();
      await controller.hydrate(store);
      controller.resetToDefaults();
      await store.flush();
      final result = store.read(AppSettingsController.storageKey);
      final json = result.value as Map;
      expect(json['textSize'], 'Large');
      expect(controller.textSize, 'Large');
    });

    test('homeScreenLayout persists customized order and visibility', () async {
      final controller = AppSettingsController.local();
      final store = await LocalJsonStore.open();
      await controller.hydrate(store);

      controller.toggleHomeScreenItemVisibility(HomeScreenItem.idRouteSearch, false);
      controller.moveHomeScreenItemDown(HomeScreenItem.idRouteSearch);
      await store.flush();

      final reloadedController = AppSettingsController.local();
      await reloadedController.hydrate(store);

      final reloadedItems = reloadedController.homeScreenItems;
      final reloadedSearch = reloadedItems.firstWhere((e) => e.id == HomeScreenItem.idRouteSearch);
      expect(reloadedSearch.isVisible, false);
      expect(reloadedItems[1].id, HomeScreenItem.idRouteSearch);
    });
  });

  group('LocalTicketRepository persistence', () {
    test('fresh instance seeds demo tickets and persists them', () async {
      final repository = LocalTicketRepository();
      final store = await LocalJsonStore.open();
      await repository.hydrate(store);
      expect(repository.allTickets, isNotEmpty);
      final result = store.read(LocalTicketRepository.storageKey);
      expect(result.absent, isFalse);
      expect(result.value, isList);
    });

    test('explicit empty list preserved, demo seed suppressed', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.busbuddy.tickets.v1': jsonEncode(<Object>[]),
      });
      final repository = LocalTicketRepository();
      final store = await LocalJsonStore.open();
      await repository.hydrate(store);
      expect(repository.allTickets, isEmpty);
    });

    test('booked ticket survives reload on fresh repository', () async {
      final repository = LocalTicketRepository();
      final store = await LocalJsonStore.open();
      await repository.hydrate(store);
      repository.addTicket(Ticket(
        id: 'TKT-777',
        routeId: 'vit-to-katpadi',
        routeName: 'VIT Main Gate → Katpadi',
        origin: const Stop(id: 'vit-main-gate', name: 'VIT Main Gate', area: 'VIT University'),
        destination: const Stop(id: 'katpadi-railway-station', name: 'Katpadi', area: 'Katpadi'),
        busId: 'Bus 18B',
        passengerName: 'Pavan K',
        passengerType: PassengerType.general,
        fareAmount: 25.0,
        paymentMethod: PaymentMethod.upi,
        issuedAt: DateTime.now(),
        validUntil: DateTime.now().add(const Duration(hours: 4)),
        qrCodeData: 'BUSBUDDY::TKT-777',
      ));
      await store.flush();

      final reloaded = LocalTicketRepository();
      await reloaded.hydrate(await LocalJsonStore.open());
      expect(reloaded.allTickets.map((t) => t.id), contains('TKT-777'));
    });

    test('malformed entries skipped, valid ones kept', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.busbuddy.tickets.v1': jsonEncode([
          {'id': 'BB1', 'routeId': 'r1'},
          {'bogus': true},
        ]),
      });
      final repository = LocalTicketRepository();
      final store = await LocalJsonStore.open();
      await repository.hydrate(store);
      expect(repository.allTickets, isEmpty);
    });
  });

  group('EmergencyContactRepository persistence', () {
    test('fresh instance seeds demo contacts and persists them', () async {
      final repository = EmergencyContactRepository();
      final store = await LocalJsonStore.open();
      await repository.hydrate(store);
      expect(repository.contacts.length, 2);
      final result = store.read(EmergencyContactRepository.storageKey);
      expect(result.absent, isFalse);
      expect(result.value, isList);
    });

    test('added contact survives reload, empty list preserved', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.busbuddy.emergencyContacts.v1': jsonEncode(<Object>[]),
      });
      final repository = EmergencyContactRepository();
      final store = await LocalJsonStore.open();
      await repository.hydrate(store);
      expect(repository.contacts, isEmpty);
      repository.addContact({'name': 'Amma', 'phone': '+91 90000 00000', 'relation': 'Family'});
      await store.flush();

      final reloaded = EmergencyContactRepository();
      await reloaded.hydrate(await LocalJsonStore.open());
      expect(reloaded.contacts.first['name'], 'Amma');
    });

    test('malformed payload discarded, defaults kept', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.busbuddy.emergencyContacts.v1': 'garbage',
      });
      final repository = EmergencyContactRepository();
      final store = await LocalJsonStore.open();
      await repository.hydrate(store);
      expect(repository.contacts.length, 2);
      expect(store.lastError, isNotNull);
    });
  });
}
