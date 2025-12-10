import 'action_data.dart';

/// 任务执行状态
enum TaskStatus {
  idle,        // 空闲
  running,     // 运行中
  paused,      // 暂停
  completed,   // 完成
  failed,      // 失败
  cancelled,   // 取消
  waitingConfirmation, // 等待用户确认
  waitingTakeover,     // 等待用户接管
}

/// 步骤执行结果
class StepResult {
  /// 是否成功
  final bool success;
  
  /// 是否已完成任务
  final bool finished;
  
  /// 执行的动作
  final ActionData? action;
  
  /// AI思考过程
  final String thinking;
  
  /// 结果消息
  final String? message;
  
  /// 执行耗时（毫秒）
  final int? durationMs;

  const StepResult({
    required this.success,
    required this.finished,
    this.action,
    required this.thinking,
    this.message,
    this.durationMs,
  });
  
  @override
  String toString() {
    return 'StepResult(success: $success, finished: $finished, action: $action)';
  }
}

/// 任务信息
class TaskInfo {
  /// 任务ID
  final String id;
  
  /// 任务描述
  final String task;
  
  /// 任务状态
  final TaskStatus status;
  
  /// 当前步骤
  final int currentStep;
  
  /// 最大步骤
  final int maxSteps;
  
  /// 开始时间
  final DateTime? startTime;
  
  /// 结束时间
  final DateTime? endTime;
  
  /// 步骤历史
  final List<StepResult> history;
  
  /// 结果消息
  final String? resultMessage;

  const TaskInfo({
    required this.id,
    required this.task,
    required this.status,
    this.currentStep = 0,
    this.maxSteps = 100,
    this.startTime,
    this.endTime,
    this.history = const [],
    this.resultMessage,
  });
  
  /// 创建新任务
  factory TaskInfo.create({
    required String task,
    int maxSteps = 100,
  }) {
    return TaskInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      task: task,
      status: TaskStatus.idle,
      maxSteps: maxSteps,
    );
  }
  
  /// 复制并修改
  TaskInfo copyWith({
    String? id,
    String? task,
    TaskStatus? status,
    int? currentStep,
    int? maxSteps,
    DateTime? startTime,
    DateTime? endTime,
    List<StepResult>? history,
    String? resultMessage,
  }) {
    return TaskInfo(
      id: id ?? this.id,
      task: task ?? this.task,
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      maxSteps: maxSteps ?? this.maxSteps,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      history: history ?? this.history,
      resultMessage: resultMessage ?? this.resultMessage,
    );
  }
  
  /// 是否正在运行
  bool get isRunning => status == TaskStatus.running;
  
  /// 是否已结束
  bool get isFinished => 
    status == TaskStatus.completed || 
    status == TaskStatus.failed || 
    status == TaskStatus.cancelled;
    
  /// 获取进度（0-1）
  double get progress {
    if (maxSteps == 0) return 0;
    return currentStep / maxSteps;
  }
  
  /// 获取执行时长
  Duration? get duration {
    if (startTime == null) return null;
    final end = endTime ?? DateTime.now();
    return end.difference(startTime!);
  }
}
