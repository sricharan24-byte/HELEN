import 'dart:async';
import 'package:flutter/material.dart';

import '../../data/datasources/local_json_store.dart';
import '../../data/models/home_screen_item.dart';
import '../../domain/ticketing/entities/ticket.dart';

/// Global application settings and accessibility controller.
class AppSettingsController extends ChangeNotifier {
  static final AppSettingsController instance = AppSettingsController._();
  AppSettingsController._();
  factory AppSettingsController() => instance;
  AppSettingsController.local();

  static const storageKey = 'busbuddy.settings.v1';
  LocalJsonStore? _store;

  Future<void> hydrate(LocalJsonStore store) async {
    await store.flush();
    _store = store;
    final stored = store.read(storageKey);
    final value = stored.value;
    if (value is Map<String, dynamic>) {
      String choice(String key, String fallback, List<String> choices) {
        final candidate = value[key];
        return candidate is String && choices.contains(candidate)
            ? candidate
            : fallback;
      }

      bool flag(String key, bool fallback) =>
          value[key] is bool ? value[key] as bool : fallback;

      textSize = choice('textSize', textSize, [
        'Small',
        'Medium',
        'Large',
        'Extra Large',
      ]);
      highContrast = choice('highContrast', highContrast, ['On', 'Off']);
      hapticFeedback = flag('hapticFeedback', hapticFeedback);
      adaptiveUi = flag('adaptiveUi', adaptiveUi);
      startingScreen = choice('startingScreen', startingScreen, [
        'Home',
        'Live Tracking',
        'My Tickets',
        'Alerts',
      ]);
      preferredLanguage = choice('preferredLanguage', preferredLanguage, [
        'English',
        'Tamil',
        'Hindi',
        'Telugu',
      ]);
      voiceSpeed = choice('voiceSpeed', voiceSpeed, ['Slow', 'Normal', 'Fast']);
      wakePhrase = flag('wakePhrase', wakePhrase);
      voiceConfirmations = flag('voiceConfirmations', voiceConfirmations);
      final model = value['geminiModel'];
      if (model is String && model.trim().isNotEmpty) {
        geminiModel = model.trim();
      }
      geminiVoice = choice('geminiVoice', geminiVoice, [
        'Aoede',
        'Kore',
        'Charon',
        'Puck',
        'Fenrir',
      ]);

      final savedRaw = value['savedPlaceStopIds'];
      if (savedRaw is List) {
        final loaded = savedRaw
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (loaded.isNotEmpty) {
          savedPlaceStopIds = loaded;
        }
      }

      // Booking profile: every field validates independently, so a corrupt
      // payload can never break hydration — invalid values just keep defaults.
      final nameRaw = value['preferredPassengerName'];
      if (nameRaw is String) {
        preferredPassengerName = nameRaw.trim();
      }
      final typeRaw = value['defaultPassengerType'];
      if (typeRaw is String) {
        for (final t in PassengerType.values) {
          if (t.name == typeRaw) defaultPassengerType = t;
        }
      }
      useBookingPersonalization = flag(
        'useBookingPersonalization',
        useBookingPersonalization,
      );

      final layoutRaw = value['homeScreenLayout'];
      if (layoutRaw is List) {
        final loaded = <HomeScreenItem>[];
        final seenIds = <String>{};
        for (final item in layoutRaw) {
          if (item is Map<String, dynamic>) {
            final parsed = HomeScreenItem.fromJson(item);
            // Skip items that no longer exist in the default layout
            // (e.g. removed options like 'my_journey' or 'live_tracking').
            if (!HomeScreenItem.defaultItemsMap.containsKey(parsed.id)) {
              continue;
            }
            loaded.add(parsed);
            seenIds.add(parsed.id);
          } else if (item is Map) {
            final parsed = HomeScreenItem.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (!HomeScreenItem.defaultItemsMap.containsKey(parsed.id)) {
              continue;
            }
            loaded.add(parsed);
            seenIds.add(parsed.id);
          }
        }
        for (final def in HomeScreenItem.defaultItems) {
          if (!seenIds.contains(def.id)) {
            loaded.add(def);
          }
        }
        if (loaded.isNotEmpty) {
          homeScreenItems = loaded;
        }
      }
    }
    if (stored.absent) await store.write(storageKey, _snapshot());
    super.notifyListeners();
  }

  Map<String, Object> _snapshot() => {
    'textSize': textSize,
    'highContrast': highContrast,
    'hapticFeedback': hapticFeedback,
    'adaptiveUi': adaptiveUi,
    'startingScreen': startingScreen,
    'preferredLanguage': preferredLanguage,
    'voiceSpeed': voiceSpeed,
    'wakePhrase': wakePhrase,
    'voiceConfirmations': voiceConfirmations,
    'geminiModel': geminiModel,
    'geminiVoice': geminiVoice,
    'savedPlaceStopIds': savedPlaceStopIds.toList(),
    'homeScreenLayout': homeScreenItems.map((e) => e.toJson()).toList(),
    'preferredPassengerName': preferredPassengerName,
    if (defaultPassengerType case final t?) 'defaultPassengerType': t.name,
    'useBookingPersonalization': useBookingPersonalization,
  };

  @override
  void notifyListeners() {
    unawaited(_store?.write(storageKey, _snapshot()));
    super.notifyListeners();
  }

  String textSize = 'Large';
  String highContrast = 'On';
  bool get isHighContrast => highContrast == 'On';
  bool hapticFeedback = true;

  bool adaptiveUi = true;
  String startingScreen = 'Home';

  String preferredLanguage = 'English';
  String voiceSpeed = 'Normal';
  bool wakePhrase = true;
  bool voiceConfirmations = true;
  String geminiApiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  String geminiModel = const String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'models/gemini-3.8-live',
  );
  String geminiVoice = const String.fromEnvironment(
    'GEMINI_VOICE',
    defaultValue: 'Aoede',
  );

  /// User-saved place stops, as transport stop IDs. Seeded with the corridor's
  /// everyday places so the booking and route-search pickers offer one-tap
  /// destinations from the first run; the passenger can star/unstar any stop
  /// to add or remove entries. Rendered by name (resolved from the transport
  /// data source), never persisted as display text.
  List<String> savedPlaceStopIds = [
    'vit-main-gate',
    'katpadi-railway-station',
    'green-circle',
    'katpadi-bus-stand',
  ];

  /// Optional name the passenger wants the assistant to address them by.
  /// Never copied into a ticket's passenger field — the checkout passenger
  /// name is always an explicit choice.
  String preferredPassengerName = '';

  /// Optional default passenger type the passenger explicitly saved. Only
  /// ever prefills an unset booking slot, marked as a profile default so it
  /// can be disclosed and corrected.
  PassengerType? defaultPassengerType;

  /// Opt-in gate for booking personalization (off by default). When false,
  /// no profile, accessibility-setting, saved-place, or recent-history data
  /// may reach Gemini — only the current booking draft facts.
  bool useBookingPersonalization = false;

  /// True when [stopId] is in the passenger's saved places.
  bool isPlaceSaved(String stopId) => savedPlaceStopIds.contains(stopId);

  /// Stars ([save]=true) or unstars a stop. Unknown IDs are ignored so a
  /// stale entry can never break the pickers.
  void toggleSavedPlace(String stopId, {required bool save}) {
    final id = stopId.trim();
    if (id.isEmpty) return;
    final updated = savedPlaceStopIds.toList();
    if (save) {
      if (!updated.contains(id)) updated.add(id);
    } else {
      updated.remove(id);
    }
    savedPlaceStopIds = updated;
    notifyListeners();
  }

  List<HomeScreenItem> homeScreenItems = List.from(HomeScreenItem.defaultItems);

  /// In-app text enlargement multiplier.
  /// Strictly guaranteed never to return < 1.0, preserving platform TextScaler.
  double get inAppEnlargementMultiplier => textScaleFactor;

  double get textScaleFactor {
    switch (textSize) {
      case 'Small':
        // Astra BUS-P0-03: Never downscale below platform accessibility font size.
        return 1.0;
      case 'Medium':
        return 1.0;
      case 'Large':
        return 1.15;
      case 'Extra Large':
        return 1.30;
      case 'Huge (160%)':
      case 'Huge':
        return 1.60;
      case 'Maximum (200%)':
      case 'Maximum':
        return 2.00;
      default:
        return 1.0;
    }
  }

  double get speechRate {
    switch (voiceSpeed) {
      case 'Slow':
        return 0.8;
      case 'Fast':
        return 1.2;
      default:
        return 1.0;
    }
  }

  String get speechLanguageCode {
    switch (preferredLanguage) {
      case 'Tamil':
        return 'ta-IN';
      case 'Hindi':
        return 'hi-IN';
      case 'Telugu':
        return 'te-IN';
      default:
        return 'en-US';
    }
  }

  void updateTextSize(String size) {
    textSize = size;
    notifyListeners();
  }

  void toggleHighContrast() {
    highContrast = highContrast == 'On' ? 'Off' : 'On';
    notifyListeners();
  }

  void updateHapticFeedback(bool val) {
    hapticFeedback = val;
    notifyListeners();
  }

  void updateAdaptiveUi(bool val) {
    adaptiveUi = val;
    notifyListeners();
  }

  void updateStartingScreen(String screen) {
    startingScreen = screen;
    notifyListeners();
  }

  void updatePreferredLanguage(String lang) {
    preferredLanguage = lang;
    notifyListeners();
  }

  void updateVoiceSpeed(String speed) {
    voiceSpeed = speed;
    notifyListeners();
  }

  void updateWakePhrase(bool val) {
    wakePhrase = val;
    notifyListeners();
  }

  void updateVoiceConfirmations(bool val) {
    voiceConfirmations = val;
    notifyListeners();
  }

  void updateGeminiApiKey(String key) {
    geminiApiKey = key.trim();
    notifyListeners();
  }

  void updatePreferredPassengerName(String value) {
    preferredPassengerName = value.trim();
    notifyListeners();
  }

  void updateDefaultPassengerType(PassengerType? value) {
    defaultPassengerType = value;
    notifyListeners();
  }

  void updateBookingPersonalization(bool enabled) {
    useBookingPersonalization = enabled;
    notifyListeners();
  }

  void updateGeminiModel(String model) {
    geminiModel = model.trim();
    notifyListeners();
  }

  void updateGeminiVoice(String voice) {
    geminiVoice = voice.trim();
    notifyListeners();
  }

  void updateHomeScreenItems(List<HomeScreenItem> items) {
    homeScreenItems = List.from(items);
    notifyListeners();
  }

  void reorderHomeScreenItem(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= homeScreenItems.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > homeScreenItems.length) newIndex = homeScreenItems.length;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = homeScreenItems.removeAt(oldIndex);
    homeScreenItems.insert(newIndex, item);
    notifyListeners();
  }

  void toggleHomeScreenItemVisibility(String id, bool isVisible) {
    final index = homeScreenItems.indexWhere((e) => e.id == id);
    if (index != -1) {
      homeScreenItems[index] = homeScreenItems[index].copyWith(
        isVisible: isVisible,
      );
      notifyListeners();
    }
  }

  void moveHomeScreenItemUp(String id) {
    final index = homeScreenItems.indexWhere((e) => e.id == id);
    if (index > 0) {
      final item = homeScreenItems.removeAt(index);
      homeScreenItems.insert(index - 1, item);
      notifyListeners();
    }
  }

  void moveHomeScreenItemDown(String id) {
    final index = homeScreenItems.indexWhere((e) => e.id == id);
    if (index != -1 && index < homeScreenItems.length - 1) {
      final item = homeScreenItems.removeAt(index);
      homeScreenItems.insert(index + 1, item);
      notifyListeners();
    }
  }

  void resetHomeScreenLayout() {
    homeScreenItems = List.from(HomeScreenItem.defaultItems);
    notifyListeners();
  }

  void resetToDefaults() {
    textSize = 'Large';
    highContrast = 'On';
    hapticFeedback = true;
    adaptiveUi = true;
    startingScreen = 'Home';
    preferredLanguage = 'English';
    voiceSpeed = 'Normal';
    wakePhrase = true;
    voiceConfirmations = true;
    geminiApiKey = const String.fromEnvironment(
      'GEMINI_API_KEY',
      defaultValue: '',
    );
    geminiModel = const String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: 'models/gemini-3.8-live',
    );
    geminiVoice = const String.fromEnvironment(
      'GEMINI_VOICE',
      defaultValue: 'Aoede',
    );
    savedPlaceStopIds = [
      'vit-main-gate',
      'katpadi-railway-station',
      'green-circle',
      'katpadi-bus-stand',
    ];
    preferredPassengerName = '';
    defaultPassengerType = null;
    useBookingPersonalization = false;
    homeScreenItems = List.from(HomeScreenItem.defaultItems);
    notifyListeners();
  }
}
