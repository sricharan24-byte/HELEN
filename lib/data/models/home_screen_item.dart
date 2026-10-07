import 'package:flutter/material.dart';

/// Represents a configurable component/card displayed on the BusBuddy home screen.
class HomeScreenItem {
  const HomeScreenItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.isVisible = true,
    this.customIcon,
    this.customColor,
  });

  /// Unique identifier for the home screen component.
  final String id;

  /// User-visible card heading.
  final String title;

  /// Descriptive subtitle or purpose explanation.
  final String subtitle;

  /// Whether this card is rendered on the home screen.
  final bool isVisible;

  /// Optional custom icon override.
  final IconData? customIcon;

  /// Optional custom color override.
  final Color? customColor;

  /// Standard component IDs in the BusBuddy system.
  static const String idRouteSearch = 'route_search';
  static const String idMyTickets = 'my_tickets';
  static const String idVoiceAssistant = 'voice_assistant';
  static const String idAlerts = 'alerts';
  static const String idSafety = 'safety';
  static const String idSettings = 'settings';

  /// Primary icon for the component.
  IconData get icon {
    if (customIcon != null) return customIcon!;
    switch (id) {
      case idRouteSearch:
        return Icons.directions_bus;
      case idMyTickets:
        return Icons.confirmation_number_outlined;
      case idVoiceAssistant:
        return Icons.auto_awesome;
      case idAlerts:
        return Icons.notifications_outlined;
      case idSafety:
        return Icons.health_and_safety_outlined;
      case idSettings:
        return Icons.settings;
      default:
        return Icons.widgets_outlined;
    }
  }

  /// Visual theme accent color for the component card border and icon bubble.
  /// All cards use a single neutral accent; red is reserved for Emergency SOS.
  Color get color {
    if (customColor != null) return customColor!;
    switch (id) {
      case idSafety:
        return const Color(0xFFE11D48); // Rose — reserved for Emergency SOS
      default:
        return const Color(0xFF007AFF); // Single accent for all other cards
    }
  }

  /// Returns a copy with specified fields updated.
  HomeScreenItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    bool? isVisible,
    IconData? customIcon,
    Color? customColor,
  }) {
    return HomeScreenItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isVisible: isVisible ?? this.isVisible,
      customIcon: customIcon ?? this.customIcon,
      customColor: customColor ?? this.customColor,
    );
  }

  /// Serializes to a JSON-compatible map for persistent storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'isVisible': isVisible,
  };

  /// Constructs an item from JSON, falling back to default metadata if titles are missing.
  factory HomeScreenItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] as String? ?? idRouteSearch;
    final defaultItem = defaultItemsMap[rawId];

    return HomeScreenItem(
      id: rawId,
      title: json['title'] as String? ?? defaultItem?.title ?? 'Feature',
      subtitle: json['subtitle'] as String? ?? defaultItem?.subtitle ?? '',
      isVisible: json['isVisible'] as bool? ?? true,
    );
  }

  /// Default ordered list of home screen components matching the accessible master UI design.
  static List<HomeScreenItem> get defaultItems => [
    const HomeScreenItem(
      id: idRouteSearch,
      title: 'Find a Place',
      subtitle: 'Search destination, find buses and book tickets',
      isVisible: true,
    ),
    const HomeScreenItem(
      id: idSafety,
      title: 'Emergency SOS',
      subtitle: 'Share location with trusted contacts',
      isVisible: true,
    ),
    const HomeScreenItem(
      id: idMyTickets,
      title: 'My Tickets',
      subtitle: 'View current and previous tickets',
      isVisible: true,
    ),
    const HomeScreenItem(
      id: idVoiceAssistant,
      title: 'Ask BusBuddy',
      subtitle: 'Gemini Live Voice Mode',
      isVisible: true,
    ),
    const HomeScreenItem(
      id: idSettings,
      title: 'Settings',
      subtitle: 'Customize your experience',
      isVisible: true,
    ),
  ];

  /// Map lookup for default items by ID.
  static Map<String, HomeScreenItem> get defaultItemsMap => {
    for (final item in defaultItems) item.id: item,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HomeScreenItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          subtitle == other.subtitle &&
          isVisible == other.isVisible;

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ subtitle.hashCode ^ isVisible.hashCode;

  @override
  String toString() =>
      'HomeScreenItem(id: $id, title: $title, isVisible: $isVisible)';
}
