import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_info.dart';

/// 任务历史记录
class TaskHistory {
  final String id;
  final String taskDescription;
  final TaskStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int stepCount;
  final List<TaskHistoryStep> steps;
  final String? errorMessage;
  
  TaskHistory({
    required this.id,
    required this.taskDescription,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.stepCount,
    this.steps = const [],
    this.errorMessage,
  });
  
  /// 执行时长
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
  
  /// 格式化时长
  String get formattedDuration {
    final d = duration;
    if (d.inMinutes > 0) {
      return '${d.inMinutes}分${d.inSeconds % 60}秒';
    }
    return '${d.inSeconds}秒';
  }
  
  /// 格式化日期
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(startTime);
    
    if (diff.inDays == 0) {
      return '今天 ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${startTime.month}/${startTime.day}';
    }
  }
  
  /// 是否成功
  bool get isSuccess => status == TaskStatus.completed;
  
  /// 转为JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskDescription': taskDescription,
    'status': status.name,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'stepCount': stepCount,
    'steps': steps.map((s) => s.toJson()).toList(),
    'errorMessage': errorMessage,
  };
  
  /// 从JSON创建
  factory TaskHistory.fromJson(Map<String, dynamic> json) {
    return TaskHistory(
      id: json['id'] as String,
      taskDescription: json['taskDescription'] as String,
      status: TaskStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TaskStatus.completed,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime'] as String) 
          : null,
      stepCount: json['stepCount'] as int,
      steps: (json['steps'] as List<dynamic>?)
          ?.map((s) => TaskHistoryStep.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

/// 任务历史步骤
class TaskHistoryStep {
  final String actionType;
  final String description;
  final String? thinking;
  final DateTime timestamp;
  final bool isSuccess;
  
  TaskHistoryStep({
    required this.actionType,
    required this.description,
    this.thinking,
    required this.timestamp,
    required this.isSuccess,
  });
  
  Map<String, dynamic> toJson() => {
    'actionType': actionType,
    'description': description,
    'thinking': thinking,
    'timestamp': timestamp.toIso8601String(),
    'isSuccess': isSuccess,
  };
  
  factory TaskHistoryStep.fromJson(Map<String, dynamic> json) {
    return TaskHistoryStep(
      actionType: json['actionType'] as String,
      description: json['description'] as String,
      thinking: json['thinking'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSuccess: json['isSuccess'] as bool,
    );
  }
}

/// 任务历史仓库
class TaskHistoryRepository {
  static const String _storageKey = 'task_history';
  static const int _maxHistoryCount = 50;
  
  static TaskHistoryRepository? _instance;
  static TaskHistoryRepository get instance {
    _instance ??= TaskHistoryRepository._();
    return _instance!;
  }
  
  TaskHistoryRepository._();
  
  List<TaskHistory> _histories = [];
  bool _initialized = false;
  
  /// 初始化
  Future<void> init() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    
    if (jsonStr != null) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _histories = list
            .map((item) => TaskHistory.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
        _histories = [];
      }
    }
    
    _initialized = true;
  }
  
  /// 获取所有历史
  List<TaskHistory> getAll() => List.unmodifiable(_histories);
  
  /// 获取最近N条
  List<TaskHistory> getRecent(int count) {
    final sorted = List<TaskHistory>.from(_histories)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.take(count).toList();
  }
  
  /// 按状态筛选
  List<TaskHistory> getByStatus(TaskStatus status) {
    return _histories.where((h) => h.status == status).toList();
  }
  
  /// 添加历史
  Future<void> add(TaskHistory history) async {
    _histories.insert(0, history);
    
    // 限制最大数量
    if (_histories.length > _maxHistoryCount) {
      _histories = _histories.take(_maxHistoryCount).toList();
    }
    
    await _save();
  }
  
  /// 删除历史
  Future<void> delete(String id) async {
    _histories.removeWhere((h) => h.id == id);
    await _save();
  }
  
  /// 清空历史
  Future<void> clear() async {
    _histories.clear();
    await _save();
  }
  
  /// 保存到存储
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_histories.map((h) => h.toJson()).toList());
    await prefs.setString(_storageKey, jsonStr);
  }
  
  /// 从TaskInfo创建历史记录
  TaskHistory createFromTaskInfo(TaskInfo info, List<StepResult> steps) {
    return TaskHistory(
      id: info.id,
      taskDescription: info.task,
      status: info.status,
      startTime: info.startTime ?? DateTime.now(),
      endTime: info.endTime,
      stepCount: steps.length,
      steps: steps.map((s) => TaskHistoryStep(
        actionType: s.action?.actionName ?? 'unknown',
        description: s.message ?? s.action?.actionName ?? '',
        thinking: s.thinking,
        timestamp: DateTime.now(),
        isSuccess: s.success,
      )).toList(),
      errorMessage: info.resultMessage,
    );
  }
}
