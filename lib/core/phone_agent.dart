import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/models.dart';
import '../config/i18n.dart';
import '../services/model/model_client.dart';
import '../services/device/device_controller.dart';
import '../services/device/action_handler.dart';

/// PhoneAgent configuration
class AgentConfig {
  final int maxSteps;
  final String lang;
  final String? systemPrompt;
  final bool verbose;

  const AgentConfig({
    this.maxSteps = 100,
    this.lang = 'cn',
    this.systemPrompt,
    this.verbose = true,
  });
  
  String get effectiveSystemPrompt {
    return systemPrompt ?? I18n.getSystemPrompt(lang);
  }
  
  Map<String, String> get messages => I18n.getMessages(lang);
}

/// PhoneAgent - AI-driven phone automation agent
class PhoneAgent extends ChangeNotifier {
  final ModelConfig modelConfig;
  final AgentConfig agentConfig;
  
  late final ModelClient _modelClient;
  late final DeviceController _deviceController;
  late final ActionHandler _actionHandler;
  
  final List<Map<String, dynamic>> _context = [];
  int _stepCount = 0;
  TaskInfo? _currentTask;
  ScreenshotData? _latestScreenshot;
  bool _isRunning = false;
  bool _shouldPause = false;
  
  Future<bool> Function(String message)? onConfirmationRequired;
  Future<void> Function(String message)? onTakeoverRequired;
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

  TaskInfo? get currentTask => _currentTask;
  int get stepCount => _stepCount;
  List<Map<String, dynamic>> get context => List.unmodifiable(_context);
  bool get isRunning => _isRunning;
  ScreenshotData? get latestScreenshot => _latestScreenshot;

  Future<void> initialize() async {
    await _deviceController.initialize();
  }

  Future<String> run(String task) async {
    if (_isRunning) {
      return 'Agent is already running';
    }
    
    _isRunning = true;
    _shouldPause = false;
    _context.clear();
    _stepCount = 0;
    
    _currentTask = TaskInfo.create(
      task: task,
      maxSteps: agentConfig.maxSteps,
    ).copyWith(
      status: TaskStatus.running,
      startTime: DateTime.now(),
    );
    notifyListeners();
    
    try {
      var result = await _executeStep(userPrompt: task, isFirst: true);
      
      if (result.finished) {
        _finishTask(true, result.message);
        return result.message ?? 'Task completed';
      }
      
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

  Future<StepResult> step({String? task}) async {
    final isFirst = _context.isEmpty;
    if (isFirst && task == null) {
      throw ArgumentError('Task is required for the first step');
    }
    return await _executeStep(userPrompt: task, isFirst: isFirst);
  }

  void pause() {
    _shouldPause = true;
  }

  void reset() {
    _context.clear();
    _stepCount = 0;
    _currentTask = null;
    _isRunning = false;
    _shouldPause = false;
    notifyListeners();
  }

  Future<StepResult> _executeStep({String? userPrompt, required bool isFirst}) async {
    final stopwatch = Stopwatch()..start();
    _stepCount++;
    
    _currentTask = _currentTask?.copyWith(
      currentStep: _stepCount,
      status: TaskStatus.running,
    );
    notifyListeners();
    
    final screenshot = await _deviceController.getScreenshot();
    _latestScreenshot = screenshot;
    final currentApp = await _deviceController.getCurrentApp();
    
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
      debugPrint('Thinking: ${response.thinking}');
      debugPrint('Action: ${action.toJsonString()}');
    }
    
    if (_context.isNotEmpty) {
      _context[_context.length - 1] = 
        MessageBuilder.removeImagesFromMessage(_context.last);
    }
    
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
    
    _context.add(
      MessageBuilder.createAssistantMessage(
        '<think>${response.thinking}</think><answer>${response.action}</answer>',
      ),
    );
    
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
    
    _currentTask = _currentTask?.copyWith(
      history: [...?_currentTask?.history, result],
    );
    notifyListeners();
    
    onStepCompleted?.call(result);
    return result;
  }

  void _finishTask(bool success, String? message) {
    _currentTask = _currentTask?.copyWith(
      status: success ? TaskStatus.completed : TaskStatus.failed,
      endTime: DateTime.now(),
      resultMessage: message,
    );
    _isRunning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _modelClient.dispose();
    _deviceController.dispose();
    super.dispose();
  }
}
