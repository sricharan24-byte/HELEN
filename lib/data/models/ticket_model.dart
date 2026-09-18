import 'package:flutter/foundation.dart';
import 'transport_models.dart';

enum TicketStatus { active, used, expired }

enum PassengerType { general, student, senior }

enum PaymentMethod { upi, card, netBanking, wallet }

@immutable
class Ticket {
  const Ticket({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.busId,
    required this.passengerName,
    required this.passengerType,
    required this.fareAmount,
    required this.paymentMethod,
    required this.issuedAt,
    required this.validUntil,
    this.status = TicketStatus.active,
    required this.qrCodeData,
  });

  final String id;
  final String routeId;
  final String routeName;
  final Stop origin;
  final Stop destination;
  final String busId;
  final String passengerName;
  final PassengerType passengerType;
  final double fareAmount;
  final PaymentMethod paymentMethod;
  final DateTime issuedAt;
  final DateTime validUntil;
  final TicketStatus status;
  final String qrCodeData;

  bool get isActive => status == TicketStatus.active && DateTime.now().isBefore(validUntil);

  Map<String, Object?> toJson() {
    Map<String, Object?> stopJson(Stop stop) => {
      'id': stop.id,
      'name': stop.name,
      'area': stop.area,
      'latitude': stop.latitude,
      'longitude': stop.longitude,
    };

    return {
      'id': id,
      'routeId': routeId,
      'routeName': routeName,
      'origin': stopJson(origin),
      'destination': stopJson(destination),
      'busId': busId,
      'passengerName': passengerName,
      'passengerType': passengerType.name,
      'fareAmount': fareAmount,
      'paymentMethod': paymentMethod.name,
      'issuedAt': issuedAt.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'status': status.name,
      'qrCodeData': qrCodeData,
    };
  }

  factory Ticket.fromJson(Map<String, dynamic> json) {
    String text(Map<String, dynamic> data, String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid $key');
      }
      return value;
    }

    double? coordinate(Object? value, double maximum) {
      if (value == null) return null;
      if (value is! num || !value.isFinite || value.abs() > maximum) {
        throw const FormatException('Invalid coordinate');
      }
      return value.toDouble();
    }

    Stop stop(Object? value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid stop');
      }
      return Stop(
        id: text(value, 'id'),
        name: text(value, 'name'),
        area: text(value, 'area'),
        latitude: coordinate(value['latitude'], 90),
        longitude: coordinate(value['longitude'], 180),
      );
    }

    T enumValue<T extends Enum>(String key, List<T> values) {
      final name = text(json, key);
      for (final value in values) {
        if (value.name == name) return value;
      }
      throw FormatException('Invalid $key');
    }

    DateTime date(String key) {
      final value = text(json, key);
      final parsed = DateTime.tryParse(value);
      if (parsed == null || parsed.toIso8601String() != value) {
        throw FormatException('Invalid $key');
      }
      return parsed;
    }

    final fare = json['fareAmount'];
    if (fare is! num || !fare.isFinite || fare < 0) {
      throw const FormatException('Invalid fare');
    }
    final issuedAt = date('issuedAt');
    final validUntil = date('validUntil');
    if (validUntil.isBefore(issuedAt)) {
      throw const FormatException('Invalid validity period');
    }
    return Ticket(
      id: text(json, 'id'),
      routeId: text(json, 'routeId'),
      routeName: text(json, 'routeName'),
      origin: stop(json['origin']),
      destination: stop(json['destination']),
      busId: text(json, 'busId'),
      passengerName: text(json, 'passengerName'),
      passengerType: enumValue('passengerType', PassengerType.values),
      fareAmount: fare.toDouble(),
      paymentMethod: enumValue('paymentMethod', PaymentMethod.values),
      issuedAt: issuedAt,
      validUntil: validUntil,
      status: enumValue('status', TicketStatus.values),
      qrCodeData: text(json, 'qrCodeData'),
    );
  }

  Ticket copyWith({
    String? id,
    String? routeId,
    String? routeName,
    Stop? origin,
    Stop? destination,
    String? busId,
    String? passengerName,
    PassengerType? passengerType,
    double? fareAmount,
    PaymentMethod? paymentMethod,
    DateTime? issuedAt,
    DateTime? validUntil,
    TicketStatus? status,
    String? qrCodeData,
  }) {
    return Ticket(
      id: id ?? this.id,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      busId: busId ?? this.busId,
      passengerName: passengerName ?? this.passengerName,
      passengerType: passengerType ?? this.passengerType,
      fareAmount: fareAmount ?? this.fareAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      issuedAt: issuedAt ?? this.issuedAt,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      qrCodeData: qrCodeData ?? this.qrCodeData,
    );
  }
}
