import 'package:json_annotation/json_annotation.dart';

part 'task_record.g.dart';

@JsonSerializable()
class TaskRecord {
  final String id;
  final String prompt;
  final int startTime; // Timestamp milliseconds
  final int? endTime;
  final String status; // 'completed', 'failed', 'stopped'
  final List<String> logs; // Text logs of steps
  final String? errorMessage;
  
  TaskRecord({
    required this.id,
    required this.prompt,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.logs,
    this.errorMessage,
  });
  
  Duration get duration {
    final end = endTime ?? DateTime.now().millisecondsSinceEpoch;
    return Duration(milliseconds: end - startTime);
  }

  factory TaskRecord.fromJson(Map<String, dynamic> json) => _$TaskRecordFromJson(json);
  Map<String, dynamic> toJson() => _$TaskRecordToJson(json);
}
