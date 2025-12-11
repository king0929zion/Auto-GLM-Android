// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskRecord _$TaskRecordFromJson(Map<String, dynamic> json) => TaskRecord(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      startTime: (json['startTime'] as num).toInt(),
      endTime: (json['endTime'] as num?)?.toInt(),
      status: json['status'] as String,
      logs: (json['logs'] as List<dynamic>).map((e) => e as String).toList(),
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$TaskRecordToJson(TaskRecord instance) =>
    <String, dynamic>{
      'id': instance.id,
      'prompt': instance.prompt,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'status': instance.status,
      'logs': instance.logs,
      'errorMessage': instance.errorMessage,
    };
