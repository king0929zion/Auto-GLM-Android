import 'package:json_annotation/json_annotation.dart';

part 'chat_history.g.dart';

@JsonSerializable()
class ConversationSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;
  final List<MessageItem> messages;

  ConversationSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.messages,
  });

  factory ConversationSession.fromJson(Map<String, dynamic> json) =>
      _$ConversationSessionFromJson(json);
  Map<String, dynamic> toJson() => _$ConversationSessionToJson(this);

  ConversationSession copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
    List<MessageItem>? messages,
  }) {
    return ConversationSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      messages: messages ?? this.messages,
    );
  }
}

@JsonSerializable()
class MessageItem {
  final String id;
  final bool isUser;
  final String? content;      // Text message or Action description
  final String? thinking;     // Thinking process
  final String? actionType;   // e.g., 'click', 'input'
  final bool? isSuccess;      // For action result
  final DateTime timestamp;

  MessageItem({
    required this.id,
    required this.isUser,
    this.content,
    this.thinking,
    this.actionType,
    this.isSuccess,
    required this.timestamp,
  });

  factory MessageItem.fromJson(Map<String, dynamic> json) =>
      _$MessageItemFromJson(json);
  Map<String, dynamic> toJson() => _$MessageItemToJson(this);
}
