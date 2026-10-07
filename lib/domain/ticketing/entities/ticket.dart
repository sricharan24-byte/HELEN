import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../transit/entities/stop.dart';
import '../../core/failure.dart';
import '../../core/result.dart';
import 'fare.dart';

enum TicketStatus {
  quoted,
  paymentPending,
  issued,
  active,
  used,
  expired,
  cancelled,
  refunded,
}

enum PassengerType { general, student, senior }

enum PaymentMethod { upi, card, netBanking, wallet }

/// Audit ledger record capturing state transition history.
@immutable
class TicketLedgerEntry {
  const TicketLedgerEntry({
    required this.status,
    required this.timestamp,
    this.reason = '',
    this.transactionId = '',
  });

  final TicketStatus status;
  final DateTime timestamp;
  final String reason;
  final String transactionId;

  Map<String, Object?> toJson() => {
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        'reason': reason,
        'transactionId': transactionId,
      };

  factory TicketLedgerEntry.fromJson(Map<String, dynamic> json) {
    return TicketLedgerEntry(
      status: TicketStatus.values.byName(json['status'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      reason: json['reason'] as String? ?? '',
      transactionId: json['transactionId'] as String? ?? '',
    );
  }

  @override
  String toString() =>
      'TicketLedgerEntry(${status.name}, $timestamp, reason: $reason, txId: $transactionId)';
}

/// Pure-Dart Ticket domain entity.
/// Sole authority on ticket state transitions and fare integrity per BUS-P0-01 and BUS-P0-02.
@immutable
class Ticket {
  Ticket({
    required this.id,
    required this.routeId,
    required this.routeName,
    required this.origin,
    required this.destination,
    required this.busId,
    required this.passengerName,
    required this.passengerType,
    required this.fareQuote,
    required this.paymentMethod,
    required this.issuedAt,
    required this.validUntil,
    this.status = TicketStatus.active,
    required this.qrCodeData,
    this.seatNumber,
    String? idempotencyKey,
    List<TicketLedgerEntry>? ledger,
    this.isDemo = true,
  })  : idempotencyKey = idempotencyKey ?? _generateSecureIdempotencyKey(id),
        ledger = ledger != null
            ? List.unmodifiable(ledger)
            : List.unmodifiable([
                TicketLedgerEntry(
                  status: status,
                  timestamp: issuedAt,
                  reason: 'Initial state: ${status.name}',
                  transactionId: idempotencyKey ?? id,
                ),
              ]);

  final String id;
  final String routeId;
  final String routeName;
  final Stop origin;
  final Stop destination;
  final String busId;
  final String passengerName;
  final PassengerType passengerType;
  final FareQuote fareQuote;
  final PaymentMethod paymentMethod;
  final DateTime issuedAt;
  final DateTime validUntil;
  final TicketStatus status;
  final String qrCodeData;
  final String? seatNumber;
  final String idempotencyKey;
  final List<TicketLedgerEntry> ledger;
  final bool isDemo;

  /// Display seat assignment (e.g. '14A' or allocated).
  String get seatAllocation {
    if (seatNumber != null && seatNumber!.trim().isNotEmpty) {
      return seatNumber!.trim();
    }
    final number = (id.hashCode.abs() % 28) + 1;
    final column = ['A', 'B', 'C', 'D'][id.hashCode.abs() % 4];
    return '$number$column';
  }

  /// Seat type description (e.g. Window / Aisle, Lower Deck).
  String get seatType {
    final seat = seatAllocation;
    final lastChar = seat.isNotEmpty ? seat[seat.length - 1].toUpperCase() : 'A';
    final isWindow = lastChar == 'A' || lastChar == 'D';
    return isWindow ? 'Window Seat • Lower Deck' : 'Aisle Seat • Lower Deck';
  }

  /// Presentation getter for integer paise.
  int get farePaise => fareQuote.finalPaise;

  /// Presentation helper in double rupees for display-only formatting.
  double get fareAmount => fareQuote.finalPaise / 100.0;

  bool get isActive =>
      status == TicketStatus.active && DateTime.now().isBefore(validUntil);

  bool get isTerminal =>
      status == TicketStatus.used ||
      status == TicketStatus.expired ||
      status == TicketStatus.cancelled ||
      status == TicketStatus.refunded;

  /// Checks if a transition from current status to [newStatus] is allowed per Astra Table 2.1.
  bool canTransitionTo(TicketStatus newStatus) {
    if (status == newStatus) return false; // Prevent duplicate transition callbacks
    if (isTerminal) return false; // Terminal states are immutable

    return switch (status) {
      TicketStatus.quoted =>
        newStatus == TicketStatus.paymentPending || newStatus == TicketStatus.cancelled,
      TicketStatus.paymentPending =>
        newStatus == TicketStatus.issued || newStatus == TicketStatus.cancelled,
      TicketStatus.issued =>
        newStatus == TicketStatus.active ||
        newStatus == TicketStatus.cancelled ||
        newStatus == TicketStatus.refunded,
      TicketStatus.active =>
        newStatus == TicketStatus.used ||
        newStatus == TicketStatus.expired ||
        newStatus == TicketStatus.cancelled ||
        newStatus == TicketStatus.refunded,
      TicketStatus.used ||
      TicketStatus.expired ||
      TicketStatus.cancelled ||
      TicketStatus.refunded =>
        false,
    };
  }

  /// Transitions ticket to [newStatus] returning a [Result].
  /// Appends transition entry to the immutable [ledger].
  Result<Ticket, StateTransitionFailure> transitionTo(
    TicketStatus newStatus, {
    DateTime? timestamp,
    String? reason,
    String? transactionId,
  }) {
    if (!canTransitionTo(newStatus)) {
      return FailureResult(
        StateTransitionFailure(
          'Illegal ticket state transition from ${status.name} to ${newStatus.name} for ticket $id.',
        ),
      );
    }

    final effectiveTimestamp = timestamp ?? DateTime.now();
    final newLedger = [
      ...ledger,
      TicketLedgerEntry(
        status: newStatus,
        timestamp: effectiveTimestamp,
        reason: reason ?? 'Transitioned to ${newStatus.name}',
        transactionId: transactionId ?? idempotencyKey,
      ),
    ];

    return Success(
      _copyInternal(
        status: newStatus,
        ledger: newLedger,
      ),
    );
  }

  /// Throws [StateError] if transition fails, for backwards-compatibility with legacy test cases.
  Ticket transitionToOrThrow(
    TicketStatus newStatus, {
    DateTime? timestamp,
    String? reason,
    String? transactionId,
  }) {
    final result = transitionTo(
      newStatus,
      timestamp: timestamp,
      reason: reason,
      transactionId: transactionId,
    );
    return result.when(
      success: (ticket) => ticket,
      failure: (failure) => throw StateError(failure.message),
    );
  }

  Ticket _copyInternal({
    String? id,
    String? routeId,
    String? routeName,
    Stop? origin,
    Stop? destination,
    String? busId,
    String? passengerName,
    PassengerType? passengerType,
    FareQuote? fareQuote,
    PaymentMethod? paymentMethod,
    DateTime? issuedAt,
    DateTime? validUntil,
    TicketStatus? status,
    String? qrCodeData,
    String? seatNumber,
    String? idempotencyKey,
    List<TicketLedgerEntry>? ledger,
    bool? isDemo,
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
      fareQuote: fareQuote ?? this.fareQuote,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      issuedAt: issuedAt ?? this.issuedAt,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      seatNumber: seatNumber ?? this.seatNumber,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      ledger: ledger ?? this.ledger,
      isDemo: isDemo ?? this.isDemo,
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
    FareQuote? fareQuote,
    PaymentMethod? paymentMethod,
    DateTime? issuedAt,
    DateTime? validUntil,
    TicketStatus? status,
    String? qrCodeData,
    String? seatNumber,
    String? idempotencyKey,
    List<TicketLedgerEntry>? ledger,
    bool? isDemo,
  }) {
    return _copyInternal(
      id: id,
      routeId: routeId,
      routeName: routeName,
      origin: origin,
      destination: destination,
      busId: busId,
      passengerName: passengerName,
      passengerType: passengerType,
      fareQuote: fareQuote,
      paymentMethod: paymentMethod,
      issuedAt: issuedAt,
      validUntil: validUntil,
      status: status,
      qrCodeData: qrCodeData,
      seatNumber: seatNumber,
      idempotencyKey: idempotencyKey,
      ledger: ledger,
      isDemo: isDemo,
    );
  }

  /// Generates a cryptographically secure Ticket ID with date prefix.
  static String generateSecureTicketId([DateTime? date]) {
    final now = date ?? DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final secureBytes = List<int>.generate(4, (_) => Random.secure().nextInt(256));
    final hex = secureBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
    return 'BB-$y$m$d-$hex';
  }

  static String _generateSecureIdempotencyKey(String ticketId) {
    final secureBytes = List<int>.generate(8, (_) => Random.secure().nextInt(256));
    final hex = secureBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join();
    return 'IDEMP-$ticketId-$hex';
  }

  /// Builds standardized tamper-evident QR code payload with serialized ticket expiry.
  static String buildQrPayload({
    required String ticketId,
    required String originId,
    required String destinationId,
    required String busId,
    required int farePaise,
    required DateTime validUntil,
    bool isDemo = true,
  }) {
    final prefix = isDemo ? 'DEMO' : 'PROD';
    final expiryIso = validUntil.toIso8601String();
    return 'BUSBUDDY|V2|$prefix|$ticketId|$originId|$destinationId|$busId|$farePaise|$expiryIso';
  }

  /// Verifies QR code data against the ticket and clock expiry.
  static bool verifyQrPayload(String payload, Ticket ticket) {
    final parts = payload.split('|');
    if (parts.length < 9) return false;
    if (parts[0] != 'BUSBUDDY' || parts[1] != 'V2') return false;
    final ticketId = parts[3];
    final originId = parts[4];
    final destinationId = parts[5];
    final busId = parts[6];
    final farePaise = int.tryParse(parts[7]);
    final expiryIso = parts[8];

    if (ticketId != ticket.id ||
        originId != ticket.origin.id ||
        destinationId != ticket.destination.id ||
        busId != ticket.busId ||
        farePaise != ticket.farePaise ||
        expiryIso != ticket.validUntil.toIso8601String()) {
      return false;
    }

    final parsedExpiry = DateTime.tryParse(expiryIso);
    if (parsedExpiry == null || DateTime.now().isAfter(parsedExpiry)) {
      return false;
    }

    return true;
  }

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
      'farePaise': farePaise,
      'fareAmount': fareAmount,
      'fareQuote': fareQuote.toJson(),
      'paymentMethod': paymentMethod.name,
      'issuedAt': issuedAt.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'status': status.name,
      'qrCodeData': qrCodeData,
      'seatNumber': seatAllocation,
      'idempotencyKey': idempotencyKey,
      'ledger': ledger.map((e) => e.toJson()).toList(),
      'isDemo': isDemo,
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

    final passengerType = enumValue('passengerType', PassengerType.values);

    // Reject negative fare payloads regardless of which field is present,
    // keeping the integer-paise monetary invariant authoritative (BUS-P0-01).
    if ((json['farePaise'] is num && (json['farePaise'] as num) < 0) ||
        (json['fareAmount'] is num && (json['fareAmount'] as num) < 0)) {
      throw const FormatException('Invalid fare: negative amounts are rejected');
    }

    final FareQuote fareQuote;
    if (json['fareQuote'] is Map<String, dynamic>) {
      fareQuote = FareQuote.fromJson(json['fareQuote'] as Map<String, dynamic>);
    } else if (json['farePaise'] is num) {
      final paise = (json['farePaise'] as num).toInt();
      fareQuote = FareQuote.fromPaise(
        basePaise: paise,
        passengerType: passengerType,
        discountPercentage: 0,
      );
    } else if (json['fareAmount'] is num) {
      final paise = ((json['fareAmount'] as num) * 100).round();
      fareQuote = FareQuote.fromPaise(
        basePaise: paise,
        passengerType: passengerType,
        discountPercentage: 0,
      );
    } else {
      throw const FormatException('Invalid fare');
    }

    final issuedAt = date('issuedAt');
    final validUntil = date('validUntil');
    if (validUntil.isBefore(issuedAt)) {
      throw const FormatException('Invalid validity period');
    }

    final ledgerList = <TicketLedgerEntry>[];
    if (json['ledger'] is List) {
      for (final entry in json['ledger'] as List) {
        if (entry is Map<String, dynamic>) {
          ledgerList.add(TicketLedgerEntry.fromJson(entry));
        }
      }
    }

    return Ticket(
      id: text(json, 'id'),
      routeId: text(json, 'routeId'),
      routeName: text(json, 'routeName'),
      origin: stop(json['origin']),
      destination: stop(json['destination']),
      busId: text(json, 'busId'),
      passengerName: text(json, 'passengerName'),
      passengerType: passengerType,
      fareQuote: fareQuote,
      paymentMethod: enumValue('paymentMethod', PaymentMethod.values),
      issuedAt: issuedAt,
      validUntil: validUntil,
      status: enumValue('status', TicketStatus.values),
      qrCodeData: text(json, 'qrCodeData'),
      seatNumber: json['seatNumber'] as String?,
      idempotencyKey: json['idempotencyKey'] as String?,
      ledger: ledgerList.isNotEmpty ? ledgerList : null,
      isDemo: json['isDemo'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ticket &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          routeId == other.routeId &&
          busId == other.busId &&
          farePaise == other.farePaise &&
          status == other.status;

  @override
  int get hashCode => Object.hash(id, routeId, busId, farePaise, status);

  @override
  String toString() =>
      'Ticket($id, route: $routeName, bus: $busId, passenger: $passengerName, fare: ₹${(farePaise / 100).toStringAsFixed(0)}, status: ${status.name})';
}

