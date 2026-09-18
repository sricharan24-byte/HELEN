import 'package:flutter/material.dart';

import '../../data/datasources/local_json_store.dart';
import '../../data/models/home_screen_item.dart';

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

      textSize = choice('textSize', textSize, ['Small', 'Medium', 'Large', 'Extra Large']);
      highContrast = choice('highContrast', highContrast, ['On', 'Off']);
      hapticFeedback = flag('hapticFeedback', hapticFeedback);
      simplifiedNav = flag('simplifiedNav', simplifiedNav);
      screenReaderHints = flag('screenReaderHints', screenReaderHints);
      adaptiveUi = flag('adaptiveUi', adaptiveUi);
      startingScreen = choice('startingScreen', startingScreen, ['Home', 'Live Tracking', 'My Tickets', 'Alerts']);
      preferredLanguage = choice('preferredLanguage', preferredLanguage, ['English', 'Tamil', 'Hindi', 'Telugu']);
      voiceSpeed = choice('voiceSpeed', voiceSpeed, ['Slow', 'Normal', 'Fast']);
      wakePhrase = flag('wakePhrase', wakePhrase);
      voiceConfirmations = flag('voiceConfirmations', voiceConfirmations);
      useGemini = flag('useGemini', useGemini);
      floatingAssistantEnabled = flag('floatingAssistantEnabled', floatingAssistantEnabled);
      final model = value['geminiModel'];
      if (model is String && model.trim().isNotEmpty) geminiModel = model.trim();
      geminiVoice = choice('geminiVoice', geminiVoice, ['Aoede', 'Kore', 'Charon', 'Puck', 'Fenrir']);

      final layoutRaw = value['homeScreenLayout'];
      if (layoutRaw is List) {
        final loaded = <HomeScreenItem>[];
        final seenIds = <String>{};
        for (final item in layoutRaw) {
          if (item is Map<String, dynamic>) {
            final parsed = HomeScreenItem.fromJson(item);
            loaded.add(parsed);
            seenIds.add(parsed.id);
          } else if (item is Map) {
            final parsed = HomeScreenItem.fromJson(Map<String, dynamic>.from(item));
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
    'simplifiedNav': simplifiedNav,
    'screenReaderHints': screenReaderHints,
    'adaptiveUi': adaptiveUi,
    'startingScreen': startingScreen,
    'preferredLanguage': preferredLanguage,
    'voiceSpeed': voiceSpeed,
    'wakePhrase': wakePhrase,
    'voiceConfirmations': voiceConfirmations,
    'useGemini': useGemini,
    'floatingAssistantEnabled': floatingAssistantEnabled,
    'geminiModel': geminiModel,
    'geminiVoice': geminiVoice,
    'homeScreenLayout': homeScreenItems.map((e) => e.toJson()).toList(),
  };

  @override
  void notifyListeners() {
    _store?.write(storageKey, _snapshot());
    super.notifyListeners();
  }

  String textSize = 'Large';
  String highContrast = 'On';
  bool hapticFeedback = true;
  bool simplifiedNav = true;
  bool screenReaderHints = true;

  bool adaptiveUi = true;
  String startingScreen = 'Home';

  String preferredLanguage = 'English';
  String voiceSpeed = 'Normal';
  bool wakePhrase = true;
  bool voiceConfirmations = true;
  bool useGemini = true;
  bool floatingAssistantEnabled = true;
  String geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  String geminiModel = const String.fromEnvironment('GEMINI_MODEL', defaultValue: 'models/gemini-3.8-live');
  String geminiVoice = const String.fromEnvironment('GEMINI_VOICE', defaultValue: 'Aoede');
  List<HomeScreenItem> homeScreenItems = List.from(HomeScreenItem.defaultItems);

  double get textScaleFactor {
    switch (textSize) {
      case 'Small':
        return 0.85;
      case 'Medium':
        return 1.0;
      case 'Large':
        return 1.15;
      case 'Extra Large':
        return 1.30;
      default:
        return 1.15;
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

  void updateSimplifiedNav(bool val) {
    simplifiedNav = val;
    notifyListeners();
  }

  void updateScreenReaderHints(bool val) {
    screenReaderHints = val;
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

  void updateUseGemini(bool val) {
    useGemini = val;
    notifyListeners();
  }

  void updateFloatingAssistantEnabled(bool val) {
    floatingAssistantEnabled = val;
    notifyListeners();
  }

  void updateGeminiApiKey(String key) {
    geminiApiKey = key.trim();
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
      homeScreenItems[index] = homeScreenItems[index].copyWith(isVisible: isVisible);
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
    simplifiedNav = true;
    screenReaderHints = true;
    adaptiveUi = true;
    startingScreen = 'Home';
    preferredLanguage = 'English';
    voiceSpeed = 'Normal';
    wakePhrase = true;
    voiceConfirmations = true;
    useGemini = true;
    floatingAssistantEnabled = true;
    geminiApiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    geminiModel = const String.fromEnvironment('GEMINI_MODEL', defaultValue: 'models/gemini-3.8-live');
    geminiVoice = const String.fromEnvironment('GEMINI_VOICE', defaultValue: 'Aoede');
    homeScreenItems = List.from(HomeScreenItem.defaultItems);
    notifyListeners();
  }
}
