import 'package:flutter/foundation.dart';

/// Represents a message in the floating BusBuddy AI assistant chat.
@immutable
class FloatingChatMessage {
  const FloatingChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actionType,
    this.actionLabel,
    this.actionData,
    this.isStreaming = false,
  });

  final String id;
  final String sender; // 'user', 'ai', 'system'
  final String text;
  final DateTime timestamp;
  final String? actionType;
  final String? actionLabel;
  final Map<String, dynamic>? actionData;
  final bool isStreaming;

  bool get isUser => sender == 'user';
  bool get isAi => sender == 'ai';
  bool get isSystem => sender == 'system';

  FloatingChatMessage copyWith({
    String? id,
    String? sender,
    String? text,
    DateTime? timestamp,
    String? actionType,
    String? actionLabel,
    Map<String, dynamic>? actionData,
    bool? isStreaming,
  }) {
    return FloatingChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      actionType: actionType ?? this.actionType,
      actionLabel: actionLabel ?? this.actionLabel,
      actionData: actionData ?? this.actionData,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
