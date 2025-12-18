// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_history.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationSession _$ConversationSessionFromJson(Map<String, dynamic> json) =>
    ConversationSession(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
      messages: (json['messages'] as List<dynamic>)
          .map((e) => MessageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ConversationSessionToJson(
        ConversationSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastUpdatedAt': instance.lastUpdatedAt.toIso8601String(),
      'messages': instance.messages,
    };

MessageItem _$MessageItemFromJson(Map<String, dynamic> json) => MessageItem(
      id: json['id'] as String,
      isUser: json['isUser'] as bool,
      content: json['content'] as String?,
      thinking: json['thinking'] as String?,
      actionType: json['actionType'] as String?,
      isSuccess: json['isSuccess'] as bool?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$MessageItemToJson(MessageItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'isUser': instance.isUser,
      'content': instance.content,
      'thinking': instance.thinking,
      'actionType': instance.actionType,
      'isSuccess': instance.isSuccess,
      'timestamp': instance.timestamp.toIso8601String(),
    };
