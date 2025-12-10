import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/models.dart';
import '../config/i18n.dart';
import '../services/model/model_client.dart';
import '../services/device/device_controller.dart';
import '../services/device/action_handler.dart';

/// PhoneAgent 配置
class AgentConfig {
  /// 最大步骤数
  final int maxSteps;
  
  /// 语言
  final String lang;
  
  /// 系统提示词
  final String? systemPrompt;
  
  /// 是否详细输出
  final bool verbose;

  const AgentConfig({
    this.maxSteps = 100,
    this.lang = 'cn',
    this.systemPrompt,
    this.verbose = true,
  });
  
  /// 获取有效的系统提示词
  String get effectiveSystemPrompt {
    return systemPrompt ?? I18n.getSystemPrompt(lang);
  }
  
  /// 获取UI消息
  Map<String, String> get messages => I18n.getMessages(lang);
}


/// PhoneAgent - AI驱动的手机自动化代理
class PhoneAgent extends ChangeNotifier {
  /// 模型配置
  final ModelConfig modelConfig;
  
  /// Agent配置
  final AgentConfig agentConfig;
  
  /// 模型客户端
  late final ModelClient _modelClient;
  
  /// 设备控制器
  late final DeviceController _deviceController;
  
  /// 动作处理器
  late final ActionHandler _actionHandler;
  
  /// 对话上下文
  final List<Map<String, dynamic>> _context = [];
  
  /// 当前步骤数
  int _stepCount = 0;
  
  /// 当前任务
  TaskInfo? _currentTask;
  
  /// 最新截图
  ScreenshotData? _latestScreenshot;
  
  /// 是否正在运行
  bool _isRunning = false;
  
  /// 是否需要暂停
  bool _shouldPause = false;
  
  /// 敏感操作确认回调
  Future<bool> Function(String message)? onConfirmationRequired;
  
  /// 接管请求回调
  Future<void> Function(String message)? onTakeoverRequired;
  
  /// 步骤完成回调
  void Function(StepResult result)? onStepCompleted;

  PhoneAgent({
    ModelConfig? modelConfig,
    AgentConfig? agentConfig,
  }) : modelConfig = modelConfig ?? const ModelConfig(),
       agentConfig = agentConfig ?? const AgentConfig() {
    _modelClient = ModelClient(config: this.modelConfig);
    _deviceController = DeviceController();
    _actionHandler = ActionHandler(
      deviceController: _deviceController,
      confirmationCallback: (msg) async {
        if (onConfirmationRequired != null) {
          return await onConfirmationRequired!(msg);
        }
        return true;
      },
      takeoverCallback: (msg) async {
        if (onTakeoverRequired != null) {
          await onTakeoverRequired!(msg);
        }
      },
    );
  }

  /// 获取当前任务
  TaskInfo? get currentTask => _currentTask;
  
  /// 获取当前步骤数
  int get stepCount => _stepCount;
  
  /// 获取对话上下文
  List<Map<String, dynamic>> get context => List.unmodifiable(_context);
  
  /// 是否正在运行
  bool get isRunning => _isRunning;
  
  /// 获取最新截图
  ScreenshotData? get latestScreenshot => _latestScreenshot;

  /// 初始化Agent
  Future<void> initialize() async {
    await _deviceController.initialize();
  }

  /// 执行任务
  Future<String> run(String task) async {
    if (_isRunning) {
      return 'Agent is already running';
    }
    
    _isRunning = true;
    _shouldPause = false;
    _context.clear();
    _stepCount = 0;
    
    // 创建任务
    _currentTask = TaskInfo.create(
      task: task,
      maxSteps: agentConfig.maxSteps,
    ).copyWith(
      status: TaskStatus.running,
      startTime: DateTime.now(),
    );
    notifyListeners();
    
    try {
      // 第一步
      var result = await _executeStep(userPrompt: task, isFirst: true);
      
      if (result.finished) {
        _finishTask(true, result.message);
        return result.message ?? 'Task completed';
      }
      
      // 继续执行直到完成或达到最大步骤
      while (_stepCount < agentConfig.maxSteps && !_shouldPause) {
        result = await _executeStep(userPrompt: null, isFirst: false);
        
        if (result.finished) {
          _finishTask(true, result.message);
          return result.message ?? 'Task completed';
        }
      }
      
      if (_shouldPause) {
        _currentTask = _currentTask?.copyWith(status: TaskStatus.paused);
        notifyListeners();
        return 'Task paused';
      }
      
      _finishTask(false, 'Max steps reached');
      return 'Max steps reached';
      
    } catch (e) {
      _finishTask(false, 'Error: $e');
      rethrow;
    } finally {
      _isRunning = false;
      notifyListeners();
    }
  }

  /// 执行单步
  Future<StepResult> step({String? task}) async {
    final isFirst = _context.isEmpty;
    
    if (isFirst && task == null) {
      throw ArgumentError('Task is required for the first step');
    }
    
    return await _executeStep(userPrompt: task, isFirst: isFirst);
  }

  /// 暂停任务
  void pause() {
    _shouldPause = true;
  }

  /// 重置Agent
  void reset() {
    _context.clear();
    _stepCount = 0;
    _currentTask = null;
    _isRunning = false;
    _shouldPause = false;
    notifyListeners();
  }

  /// 执行单步核心逻辑
  Future<StepResult> _executeStep({String? userPrompt, required bool isFirst}) async {
    final stopwatch = Stopwatch()..start();
    _stepCount++;
    
    // 更新任务状态
    _currentTask = _currentTask?.copyWith(
      currentStep: _stepCount,
      status: TaskStatus.running,
    );
    notifyListeners();
    
    // 捕获屏幕状态
    final screenshot = await _deviceController.getScreenshot();
    _latestScreenshot = screenshot;
    final currentApp = await _deviceController.getCurrentApp();
    
    // 构建消息
    if (isFirst) {
      _context.add(
        MessageBuilder.createSystemMessage(agentConfig.effectiveSystemPrompt),
      );
      
      final screenInfo = MessageBuilder.buildScreenInfo(currentApp);
      final textContent = '$userPrompt\n\n$screenInfo';
      
      _context.add(
        MessageBuilder.createUserMessage(
          text: textContent,
          imageBase64: screenshot.base64Data,
        ),
      );
    } else {
      final screenInfo = MessageBuilder.buildScreenInfo(currentApp);
      final textContent = '** Screen Info **\n\n$screenInfo';
      
      _context.add(
        MessageBuilder.createUserMessage(
          text: textContent,
          imageBase64: screenshot.base64Data,
        ),
      );
    }
    
    // 请求模型
    ModelResponse response;
    try {
      response = await _modelClient.request(_context);
    } catch (e) {
      stopwatch.stop();
      final result = StepResult(
        success: false,
        finished: true,
        action: null,
        thinking: '',
        message: 'Model error: $e',
        durationMs: stopwatch.elapsedMilliseconds,
      );
      onStepCompleted?.call(result);
      return result;
    }
    
    // 解析动作
    ActionData action;
    try {
      action = ActionData.parse(response.action);
    } catch (e) {
      action = ActionData(
        type: ActionType.finish,
        actionName: 'finish',
        message: response.action,
        metadata: 'finish',
      );
    }
    
    if (agentConfig.verbose) {
      debugPrint('='.padRight(50, '='));
      debugPrint('💭 Thinking:');
      debugPrint(response.thinking);
      debugPrint('-'.padRight(50, '-'));
      debugPrint('🎯 Action:');
      debugPrint(action.toJsonString());
      debugPrint('='.padRight(50, '='));
    }
    
    // 从上下文中移除图片以节省空间
    if (_context.isNotEmpty) {
      _context[_context.length - 1] = 
        MessageBuilder.removeImagesFromMessage(_context.last);
    }
    
    // 执行动作
    ActionResult actionResult;
    try {
      actionResult = await _actionHandler.execute(action);
    } catch (e) {
      actionResult = ActionResult(
        success: false,
        shouldFinish: false,
        message: 'Action failed: $e',
      );
    }
    
    // 添加助手响应到上下文
    _context.add(
      MessageBuilder.createAssistantMessage(
        '<think>${response.thinking}</think><answer>${response.action}</answer>',
      ),
    );
    
    // 检查是否完成
    final finished = action.isFinish || actionResult.shouldFinish;
    
    stopwatch.stop();
    
    final result = StepResult(
      success: actionResult.success,
      finished: finished,
      action: action,
      thinking: response.thinking,
      message: actionResult.message ?? action.message,
      durationMs: stopwatch.elapsedMilliseconds,
    );
    
    // 更新任务历史
    _currentTask = _currentTask?.copyWith(
      history: [...?_currentTask?.history, result],
    );
    notifyListeners();
    
    onStepCompleted?.call(result);
    
    return result;
  }

  /// 完成任务
  void _finishTask(bool success, String? message) {
    _currentTask = _currentTask?.copyWith(
      status: success ? TaskStatus.completed : TaskStatus.failed,
      endTime: DateTime.now(),
      resultMessage: message,
    );
    _isRunning = false;
    notifyListeners();
  }

  /// 释放资源
  @override
  void dispose() {
    _modelClient.dispose();
    _deviceController.dispose();
    super.dispose();
  }
}
