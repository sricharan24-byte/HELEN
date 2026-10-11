import '../../core/settings/app_settings_controller.dart';
import '../../data/repositories/transport_repository.dart';
import '../tickets/ticket_controller.dart';

/// The minimal, immutable snapshot Gemini Live may receive while helping the
/// passenger with a booking. Built only when the assistant requests it (the
/// read-only `get_booking_context` tool), never embedded in the general
/// system instruction, and scoped to the current booking attempt.
///
/// Privacy contract (spec §"Context sent to Gemini"): when personalization is
/// opted out, the context carries nothing but the current draft facts. When
/// opted in, only the allowlisted profile, communication, saved-place, and
/// recent-trip fields are emitted — never API keys, ticket identifiers, QR
/// payloads, fares, payment data beyond the selected method name, timestamps,
/// contacts, or precise locations, and never seeded demo tickets.
class BookingContext {
  const BookingContext._(Map<String, Object?> data) : _data = data;

  final Map<String, Object?> _data;

  /// JSON-safe, allowlisted view of this context. Unmodifiable shallowly; the
  /// builder guarantees every nested value is a fresh primitive/map/list.
  Map<String, Object?> toJson() => Map<String, Object?>.unmodifiable(_data);
}

/// Builds [BookingContext] from local state. Every section is created fresh
/// and filtered against a strict allowlist before serialization, so no
/// settings object, ticket object, or private identifier can escape.
class BookingContextBuilder {
  const BookingContextBuilder._();

  static const int _maxRecentTrips = 3;

  static BookingContext build({
    required AppSettingsController settings,
    required TransportRepository repository,
    required TicketController ticketController,
    required Map<String, Object?> bookingDraft,
  }) {
    final json = <String, Object?>{
      // The current draft is the one section that is always present: the
      // assistant needs the slot values and their provenance to continue the
      // booking even when personalization is off.
      'draft': _draftJson(bookingDraft),
    };

    if (settings.useBookingPersonalization) {
      final profile = _profileJson(settings);
      if (profile != null) json['profile'] = profile;
      json['communication'] = _communicationJson(settings);
      final savedPlaces = _savedPlacesJson(settings, repository);
      if (savedPlaces != null) json['savedPlaces'] = savedPlaces;
      final recentTrips = _recentTripsJson(ticketController);
      if (recentTrips != null) json['recentTrips'] = recentTrips;
    }

    return BookingContext._(Map<String, Object?>.unmodifiable(json));
  }

  /// Copies only the six booking slots, and only their `value` and `source`
  /// primitives. Anything else on a slot (credentials, notes, malformed
  /// entries) is dropped here before the context can leave the app.
  static Map<String, Object?> _draftJson(Map<String, Object?> bookingDraft) {
    final rawSlots = bookingDraft['slots'];
    final slots = <String, Object?>{};
    if (rawSlots is Map) {
      rawSlots.forEach((key, rawSlot) {
        if (key is! String || rawSlot is! Map) return;
        final value = rawSlot['value'];
        final source = rawSlot['source'];
        if (!_isJsonPrimitive(value) || !_isJsonPrimitive(source)) return;
        slots[key] = {'value': value, 'source': source};
      });
    }
    return {'slots': slots};
  }

  static bool _isJsonPrimitive(Object? v) =>
      v == null || v is String || v is num || v is bool;

  static Map<String, Object?>? _profileJson(AppSettingsController settings) {
    final name = settings.preferredPassengerName.trim();
    final type = settings.defaultPassengerType;
    if (name.isEmpty && type == null) return null;
    return {
      if (name.isNotEmpty) 'preferredName': name,
      if (type != null) 'defaultPassengerType': type.name,
    };
  }

  /// Accessibility-relevant presentation settings only — never interpreted
  /// as diagnoses, and never sent when personalization is off.
  static Map<String, Object?> _communicationJson(
    AppSettingsController settings,
  ) {
    return {
      'preferredLanguage': settings.preferredLanguage,
      'voiceSpeed': settings.voiceSpeed,
      'voiceConfirmations': settings.voiceConfirmations,
      'textSize': settings.textSize,
      'highContrast': settings.highContrast,
    };
  }

  /// Saved stop IDs resolved to display names; unknown/stale IDs are skipped
  /// so nothing can name a place that no longer exists.
  static List<Map<String, Object?>>? _savedPlacesJson(
    AppSettingsController settings,
    TransportRepository repository,
  ) {
    final places = <Map<String, Object?>>[];
    for (final stopId in settings.savedPlaceStopIds) {
      final stop = repository.getStop(stopId);
      if (stop == null) continue;
      places.add({'name': stop.name});
    }
    return places.isEmpty ? null : places;
  }

  /// At most three most recent non-demo trips, newest-first repository order,
  /// each reduced to origin, destination, bus, and passenger type. Seeded
  /// demo tickets are never surfaced as personal history.
  static List<Map<String, Object?>>? _recentTripsJson(
    TicketController ticketController,
  ) {
    final trips = <Map<String, Object?>>[];
    for (final t in ticketController.tickets) {
      if (t.isDemo) continue;
      trips.add({
        'origin': t.origin.name,
        'destination': t.destination.name,
        'bus': t.busId,
        'passengerType': t.passengerType.name,
      });
      if (trips.length == _maxRecentTrips) break;
    }
    return trips.isEmpty ? null : trips;
  }
}
