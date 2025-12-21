import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/phone_agent.dart';
import '../../data/models/models.dart';
import '../../data/models/chat_history.dart';
import '../../config/settings_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../services/device/device_controller.dart';
import '../../data/repositories/model_config_repository.dart';
import '../../data/models/model_provider.dart';
import '../../services/model/model_client.dart';
import '../theme/app_theme.dart';
import '../widgets/task_execution_card.dart';
import '../../l10n/app_strings.dart';
import '../../config/app_config.dart';

enum _ToolOption {
  none,
  agent,
  canvas,
  buildApp,
}

/// 主页面 - Gemini 风格聊天界面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late PhoneAgent _agent;
  final DeviceController _deviceController = DeviceController();
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ModelConfigRepository _modelRepo = ModelConfigRepository.instance;
  
  final List<_ChatItem> _chatItems = [];
  final List<Map<String, dynamic>> _chatContext = [];
  bool _isInitialized = false;
  String? _errorMessage;
  String? _currentSessionId;
  String _language = AppConfig.defaultLanguage;
  bool _isChatRunning = false;
  _ToolOption _selectedTool = _ToolOption.none;
  
  // 当前任务执行状态
  TaskExecution? _currentExecution;
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initModelConfig();
    _initializeAgent();
  }

  String _getStr(String key) => AppStrings.getString(key, _language);

  Future<void> _initializeAgent() async {
    final settings = SettingsRepository.instance;
    await settings.init();
    
    setState(() {
      _language = settings.language;
    });

    final agentConfig = AgentConfig(
      maxSteps: settings.maxSteps,
      lang: _language,
      verbose: true,
    );
    
    // 创建 PhoneAgent 实例
    _agent = PhoneAgent(agentConfig: agentConfig);
    
    _agent.onConfirmationRequired = _showConfirmationDialog;
    _agent.onTakeoverRequired = _showTakeoverDialog;
    _agent.onStepCompleted = _onStepCompleted;
    
    try {
      await _agent.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Initialization failed: $e');
    }
    
    _agent.addListener(_onAgentChanged);
  }

  void _onAgentChanged() {
    if (mounted) {
      setState(() {
        // 更新当前任务执行状态
        if (_currentExecution != null) {
          final status = _agent.currentTask?.status ?? _currentExecution!.status;
          _currentExecution = _currentExecution!.copyWith(
            status: status,
            endTime: status == TaskStatus.completed ||
                    status == TaskStatus.failed ||
                    status == TaskStatus.cancelled
                ? (_currentExecution!.endTime ?? DateTime.now())
                : null,
          );
          // 同步更新聊天项中的执行状态
          for (var i = 0; i < _chatItems.length; i++) {
            if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
              _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
            }
          }
        }
      });
    }
  }
  
  // 初始化模型配置
  Future<void> _initModelConfig() async {
    await _modelRepo.init();
    if (_modelRepo.activeModelId == null && _modelRepo.selectedModelIds.isNotEmpty) {
      await _modelRepo.setActiveModel(_modelRepo.selectedModelIds.first);
    }
    if (mounted) setState(() {});
  }
  
  // 重新加载模型列表（当从设置页返回时调用）
  Future<void> _reloadModels() async {
    await _modelRepo.init();
    if (mounted) setState(() {});
  }
  
  void _onStepCompleted(StepResult result) {
    final actionRecord = ActionRecord(
      id: const Uuid().v4(),
      actionType: result.action?.actionName ?? 'unknown',
      description: _getActionDescription(result),
      thinking: result.thinking,
      timestamp: DateTime.now(),
      isSuccess: result.success,
    );
    
    setState(() {
      if (_currentExecution != null) {
        // 添加动作到当前执行
        _currentExecution = _currentExecution!.copyWith(
          status: TaskStatus.running,
          actions: [..._currentExecution!.actions, actionRecord],
        );
        
        // 更新聊天项中的执行状态
        for (var i = 0; i < _chatItems.length; i++) {
          if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
            _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
          }
        }
      }
    });
    
    _scrollToBottom();
    
    if (_currentSessionId != null) {
      _saveMessageToHistory(MessageItem(
        id: const Uuid().v4(),
        isUser: false,
        thinking: result.thinking,
        content: result.message,
        actionType: result.action?.actionName,
        isSuccess: result.success,
        timestamp: DateTime.now(),
      ));
    }
  }

  String _getActionDescription(StepResult result) {
    final action = result.action;
    if (action == null) return result.message ?? '执行中...';
    
    final name = action.actionName;
    
    switch (name) {
      case 'Tap':
      case 'tap':
      case 'click':
        final element = action.element;
        return '点击 ${element != null ? "[${element[0]}, ${element[1]}]" : "元素"}';
      case 'Swipe':
      case 'swipe':
        return '滑动屏幕';
      case 'scroll':
        return '滚动列表';
      case 'Type':
      case 'type':
      case 'input':
        return '输入 "${action.text ?? "文本"}"';
      case 'Launch':
      case 'open_app':
      case 'launch':
        return '打开 ${action.app ?? "应用"}';
      case 'Back':
      case 'back':
        return '返回上一页';
      case 'Home':
      case 'home':
        return '返回主屏幕';
      case 'screenshot':
        return '截取屏幕';
      case 'Wait':
      case 'wait':
        return '等待 ${action.duration ?? ""}';
      default:
        return result.message ?? name;
    }
  }

  Future<void> _saveMessageToHistory(MessageItem message) async {
    if (_currentSessionId == null) return;
    final repo = HistoryRepository.instance;
    final session = repo.getSession(_currentSessionId!);
    if (session != null) {
      final updatedSession = session.copyWith(
        lastUpdatedAt: DateTime.now(),
        messages: [...session.messages, message],
      );
      await repo.saveSession(updatedSession);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppTheme.durationNormal,
          curve: AppTheme.curveDefault,
        );
      }
    });
  }

  Future<bool> _showConfirmationDialog(String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppTheme.black.withOpacity(0.6),
      builder: (context) => _MinimalDialog(
        title: _getStr('confirmAction'),
        content: message,
        confirmText: _getStr('confirm'),
        cancelText: _getStr('cancel'),
      ),
    );
    return result ?? false;
  }

  Future<void> _showTakeoverDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppTheme.black.withOpacity(0.6),
      builder: (context) => _MinimalDialog(
        title: _getStr('manualIntervention'),
        content: message,
        confirmText: _getStr('continue'),
        showCancel: false,
      ),
    );
  }

  String _getModelDisplayName() {
    final activeModel = _modelRepo.activeModel;
    if (activeModel != null) {
      return activeModel.displayName;
    }
    return _getStr('selectModel');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border(
                    top: BorderSide(color: AppTheme.grey150, width: 1),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: _errorMessage != null ? _buildErrorView() : _buildChatArea(),
                ),
              ),
            ),
            _buildGeminiInputBar(),
          ],
        ),
      ),
    );
  }

  /// 顶部导航栏 - 极简风格
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      child: Row(
        children: [
          // 历史记录按钮
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppTheme.grey700),
            onPressed: () {
              _focusNode.unfocus();
              Navigator.pushNamed(context, '/history');
            },
          ),
          
          // 中间标题 / 模型选择器
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _showModelSelector,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _getModelDisplayName(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppTheme.grey500,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.grey700),
            onPressed: _startNewConversation,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.grey700),
            onPressed: () {
              _focusNode.unfocus();
              Navigator.pushNamed(context, '/settings').then((_) => _reloadModels());
            },
          ),
        ],
      ),
    );
  }

  /// 聊天区域
  Widget _buildChatArea() {
    if (_chatItems.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        if (_buildAgentBanner() != null) _buildAgentBanner()!,
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.space20,
              vertical: AppTheme.space16,
            ),
            itemCount: _chatItems.length,
            itemBuilder: (context, index) => _buildChatItem(_chatItems[index]),
          ),
        ),
      ],
    );
  }

  Widget? _buildAgentBanner() {
    final exec = _currentExecution;
    if (exec == null) return null;
    final show = exec.status == TaskStatus.running ||
        exec.status == TaskStatus.paused ||
        exec.status == TaskStatus.waitingConfirmation ||
        exec.status == TaskStatus.waitingTakeover;
    if (!show) return null;

    final statusText = () {
      switch (exec.status) {
        case TaskStatus.running:
          return 'Agent 执行中';
        case TaskStatus.paused:
          return 'Agent 已暂停';
        case TaskStatus.waitingConfirmation:
          return '等待确认';
        case TaskStatus.waitingTakeover:
          return '需要接管';
        default:
          return '任务中';
      }
    }();

    final statusColor = () {
      switch (exec.status) {
        case TaskStatus.running:
          return AppTheme.success;
        case TaskStatus.paused:
          return AppTheme.warning;
        case TaskStatus.waitingConfirmation:
        case TaskStatus.waitingTakeover:
          return AppTheme.grey900;
        default:
          return AppTheme.grey700;
      }
    }();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.space20, 12, AppTheme.space20, 0),
      child: GestureDetector(
        onTap: () => _openVirtualScreenPreview(exec),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.grey50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.grey150),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exec.currentStep} 步 · ${exec.formattedDuration} · 点击查看虚拟屏幕',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.grey500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (exec.status == TaskStatus.running)
                IconButton(
                  onPressed: _pauseTask,
                  icon: const Icon(Icons.pause_rounded, size: 20),
                  color: AppTheme.grey700,
                  tooltip: '暂停',
                )
              else if (exec.status == TaskStatus.paused)
                IconButton(
                  onPressed: _resumeTask,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  color: AppTheme.grey700,
                  tooltip: '继续',
                ),
              IconButton(
                onPressed: _stopTask,
                icon: const Icon(Icons.stop_rounded, size: 20),
                color: AppTheme.error,
                tooltip: '停止',
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.grey400),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建聊天项
  Widget _buildChatItem(_ChatItem item) {
    if (item.isUser) {
      return _UserBubble(message: item.message ?? '');
    }
    
    // Agent 模式：显示任务执行卡片
    if (item.execution != null) {
      return TaskExecutionCard(
        execution: item.execution!,
        onTap: () => _openVirtualScreenPreview(item.execution!),
        onPause: () => _pauseTask(),
        onResume: () => _resumeTask(),
        onStop: () => _stopTask(),
      );
    }
    
    // Canvas 模式或普通消息：显示消息气泡
    return _AssistantBubble(
      message: item.message,
      thinking: item.thinking,
      action: item.action,
      isSuccess: item.isSuccess,
      thinkingLabel: _getStr('thinking'),
    );
  }

  /// 打开虚拟屏幕预览页面
  void _openVirtualScreenPreview(TaskExecution execution) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VirtualScreenPreviewPage(
          execution: execution,
          onPause: () => _pauseTask(),
          onResume: () => _resumeTask(),
          onStop: () => _stopTask(),
        ),
      ),
    );
  }

  /// 暂停任务
  void _pauseTask() {
    if (!_agent.isRunning) return;
    _agent.pause();
    if (!mounted) return;

    setState(() {
      if (_currentExecution != null) {
        _currentExecution = _currentExecution!.copyWith(
          status: TaskStatus.paused,
        );
        for (var i = 0; i < _chatItems.length; i++) {
          if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
            _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
          }
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_getStr('taskPaused'))),
    );
  }

  Future<void> _resumeTask() async {
    if (_agent.isRunning) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_getStr('taskResumed'))),
    );
    try {
      await _agent.resume();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  /// 获取时间问候语
  String _getGreeting() {
    final hour = DateTime.now().hour;
    final nickname = SettingsRepository.instance.getNickname() ?? 'there';
    
    if (hour < 12) {
      return 'Good morning, $nickname';
    } else if (hour < 18) {
      return 'Good afternoon, $nickname';
    } else {
      return 'Good evening, $nickname';
    }
  }

  /// 空状态 - 简洁欢迎
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getGreeting(),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w300,
                color: AppTheme.grey700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Gemini 风格输入栏 - 统一背景设计
  Widget _buildGeminiInputBar() {
    final agentRunning = _agent.isRunning;
    final chatRunning = _isChatRunning;
    final isBusy = agentRunning || chatRunning;
    final showStop = agentRunning;
    final hasText = _taskController.text.isNotEmpty;
    final isAgentToolSelected = _selectedTool == _ToolOption.agent;
    
    // 棕色主题色
    const accentColor = Color(0xFF8B7355);
    
    return Container(
      color: AppTheme.grey100,
      child: SafeArea(
        top: false,
        child: Container(
          color: AppTheme.grey100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 输入区域 - 统一背景色（保持旧样式）
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _taskController,
                  focusNode: _focusNode,
                  enabled: _isInitialized && !isBusy,
                  maxLines: 5,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.grey900,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: isBusy ? _getStr('working') : 'Ask AutoZi',
                    hintStyle: const TextStyle(
                      color: AppTheme.grey400,
                      fontSize: 16,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  cursorColor: AppTheme.accent,
                ),
              ),

              // 工具栏：左侧图片/工具，右侧发送/停止
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Row(
                  children: [
                    _InputIconButton(
                      icon: Icons.add_photo_alternate_outlined,
                      onTap: isBusy ? null : _showImageMenu,
                      isActive: false,
                    ),
                    const SizedBox(width: 8),
                    _InputIconButton(
                      icon: Icons.handyman_outlined,
                      onTap: isBusy ? null : _showToolSelector,
                      isActive: isAgentToolSelected,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: showStop
                          ? _stopTask
                          : (hasText && !isBusy ? _startTask : null),
                      child: AnimatedContainer(
                        duration: AppTheme.durationFast,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: showStop
                              ? Colors.red.withOpacity(0.15)
                              : hasText && !isBusy
                                  ? accentColor
                                  : AppTheme.grey200,
                          shape: BoxShape.circle,
                        ),
                        child: showStop
                            ? const Icon(
                                Icons.stop_rounded,
                                color: Colors.red,
                                size: 20,
                              )
                            : isBusy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.grey500,
                                    ),
                                  )
                                : CustomPaint(
                                    size: const Size(40, 40),
                                    painter: _LeafIconPainter(
                                      color: hasText ? AppTheme.white : AppTheme.grey400,
                                    ),
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 错误视图
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.grey600,
                fontSize: AppTheme.fontSize14,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            TextButton.icon(
              onPressed: _initializeAgent,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_getStr('retry')),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.grey900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature 功能暂未开放')),
    );
  }

  void _showImageMenu() {
    if (_agent.isRunning || _isChatRunning) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '添加图片',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey900,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('上传图片'),
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoon('上传图片');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('拍照'),
                  onTap: () {
                    Navigator.pop(context);
                    _showComingSoon('拍照');
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToolSelector() {
    if (_agent.isRunning || _isChatRunning) return;
    final tools = [
      _ToolOption.none,
      _ToolOption.agent,
      _ToolOption.canvas,
      _ToolOption.buildApp,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.grey200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '选择工具',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey900,
                    ),
                  ),
                ),
                ...tools.map((tool) {
                  final supported = tool == _ToolOption.none || tool == _ToolOption.agent;
                  final selected = tool == _selectedTool;
                  return ListTile(
                    leading: Icon(_toolIcon(tool)),
                    title: Text(_toolLabel(tool)),
                    subtitle: supported ? null : const Text('即将开放'),
                    trailing: selected
                        ? const Icon(Icons.check_rounded, color: AppTheme.grey900)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      if (!supported) {
                        _showComingSoon(_toolLabel(tool));
                        return;
                      }
                      setState(() {
                        _selectedTool = tool;
                      });
                    },
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _toolLabel(_ToolOption tool) {
    switch (tool) {
      case _ToolOption.none:
        return '不使用工具';
      case _ToolOption.agent:
        return 'Agent';
      case _ToolOption.canvas:
        return 'Canvas';
      case _ToolOption.buildApp:
        return 'Build App';
    }
  }

  IconData _toolIcon(_ToolOption tool) {
    switch (tool) {
      case _ToolOption.none:
        return Icons.chat_bubble_outline;
      case _ToolOption.agent:
        return Icons.auto_awesome_outlined;
      case _ToolOption.canvas:
        return Icons.brush_outlined;
      case _ToolOption.buildApp:
        return Icons.auto_fix_high_outlined;
    }
  }

  Future<String> _buildAgentInstruction(String task) async {
    const systemPrompt =
        '你是任务转写器，请把用户需求整理成一句清晰、可执行的手机操作任务，'
        '给 AutoGLM 执行。仅输出任务描述，不要解释。';
    final messages = [
      MessageBuilder.createSystemMessage(systemPrompt),
      {'role': 'user', 'content': task},
    ];
    final response = await ModelClient().request(messages);
    return response.rawContent.trim();
  }

  Future<String> _summarizeAgentResult({
    required String task,
    required String agentInstruction,
    required String agentResult,
    TaskStatus? status,
  }) async {
    const systemPrompt =
        '你是主对话助手，请根据 AutoGLM 的执行结果向用户反馈。'
        '要求：简洁、明确说明是否完成、关键结果或失败原因。';
    final statusText = _formatTaskStatus(status);
    final errorMessage = _currentExecution?.errorMessage;
    final content = [
      '用户任务：$task',
      'AutoGLM 指令：$agentInstruction',
      '执行状态：$statusText',
      if (errorMessage != null && errorMessage.isNotEmpty) '错误信息：$errorMessage',
      '执行结果：$agentResult',
    ].join('\n');

    final messages = [
      MessageBuilder.createSystemMessage(systemPrompt),
      {'role': 'user', 'content': content},
    ];
    final response = await ModelClient().request(messages);
    return response.rawContent.trim();
  }

  String _formatTaskStatus(TaskStatus? status) {
    switch (status) {
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '执行失败';
      case TaskStatus.cancelled:
        return '已取消';
      case TaskStatus.paused:
        return '已暂停';
      case TaskStatus.running:
        return '执行中';
      case TaskStatus.waitingConfirmation:
        return '等待确认';
      case TaskStatus.waitingTakeover:
        return '需要接管';
      case TaskStatus.pending:
      case TaskStatus.idle:
      default:
        return '准备中';
    }
  }

  void _showModelSelector() {
    if (_agent.isRunning || _isChatRunning) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModelSelectorSheet(
        title: _getStr('modelConfig'),
        models: _modelRepo.selectedModels,
        activeModelId: _modelRepo.activeModelId,
        emptyHint: _getStr('noModelSelected'),
        manageLabel: _getStr('configure'),
        onManage: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/provider-config');
        },
        onSelect: (model) async {
          Navigator.pop(context);
          if (model.modelId.toLowerCase().contains('autoglm')) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('不建议将 AutoGLM 作为主对话模型，请在 AutoGLM 配置页单独配置')),
            );
            return;
          }
          await _modelRepo.setActiveModel(model.id);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<bool> _ensureRequiredPermissions() async {
    final accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
    if (accessibilityEnabled) return true;
    if (!mounted) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppTheme.black.withOpacity(0.6),
      builder: (context) => _PermissionDialog(
        title: _getStr('permissionNotReady'),
        description: _getStr('permissionGuide'),
        buttonLabel: _getStr('goToEnable'),
        cancelLabel: _getStr('cancel'),
        onEnable: () async {
          Navigator.pop(context);
          await _deviceController.openAccessibilitySettings();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );

    return false;
  }

  void _startTask() async {
    final task = _taskController.text.trim();
    if (task.isEmpty) return;

    if (_agent.isRunning || _isChatRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getStr('waitCurrentTask'))),
      );
      return;
    }

    if (_selectedTool != _ToolOption.none && _selectedTool != _ToolOption.agent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该工具暂未支持')),
      );
      return;
    }

    if (_modelRepo.activeModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getStr('noModelSelected'))),
      );
      return;
    }

    final useAgentTool = _selectedTool == _ToolOption.agent;

    if (useAgentTool) {
      if (!_modelRepo.autoglmConfig.isConfigured) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_getStr('agentNotConfigured'))),
        );
        return;
      }

      final permissionsOk = await _ensureRequiredPermissions();
      if (!permissionsOk) return;
    }
    
    if (_currentSessionId == null) {
      _currentSessionId = const Uuid().v4();
      final newSession = ConversationSession(
        id: _currentSessionId!,
        title: task,
        createdAt: DateTime.now(),
        lastUpdatedAt: DateTime.now(),
        messages: [],
      );
      await HistoryRepository.instance.saveSession(newSession);
    }
    
    // 添加用户消息
    setState(() {
      _chatItems.add(_ChatItem(isUser: true, message: task));
    });
    
    await _saveMessageToHistory(MessageItem(
      id: const Uuid().v4(),
      isUser: true,
      content: task,
      timestamp: DateTime.now(),
    ));

    _chatContext.add({'role': 'user', 'content': task});

    _taskController.clear();
    _focusNode.unfocus();
    
    // Agent 工具：创建任务执行卡片
    if (useAgentTool) {
      final executionId = const Uuid().v4();
      _currentExecution = TaskExecution(
        taskId: executionId,
        taskDescription: task,
        status: TaskStatus.running,
        actions: [],
        startTime: DateTime.now(),
      );
      
      setState(() {
        _chatItems.add(_ChatItem(
          isUser: false,
          execution: _currentExecution,
        ));
      });
    }
    
    _scrollToBottom();
    
    if (useAgentTool) {
      final placeholderIndex = _chatItems.length;
      setState(() {
        _chatItems.add(_ChatItem(isUser: false, message: _getStr('thinking')));
        _isChatRunning = true;
      });
      _scrollToBottom();

      try {
        final agentInstruction = await _buildAgentInstruction(task);
        final normalizedInstruction =
            agentInstruction.trim().isEmpty ? task : agentInstruction.trim();
        final agentResult = await _agent.run(normalizedInstruction);
        final taskStatus = _agent.currentTask?.status;
        if (_currentExecution != null && taskStatus != null) {
          setState(() {
            _currentExecution = _currentExecution!.copyWith(
              status: taskStatus,
              endTime: taskStatus == TaskStatus.completed ||
                      taskStatus == TaskStatus.failed ||
                      taskStatus == TaskStatus.cancelled
                  ? DateTime.now()
                  : null,
            );
            for (var i = 0; i < _chatItems.length; i++) {
              if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
                _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
              }
            }
          });
        }
        final finalReply = await _summarizeAgentResult(
          task: task,
          agentInstruction: normalizedInstruction,
          agentResult: agentResult,
          status: _agent.currentTask?.status,
        );

        setState(() {
          _chatItems[placeholderIndex] = _ChatItem(
            isUser: false,
            message: finalReply,
            isSuccess: _agent.currentTask?.status == TaskStatus.completed,
          );
        });
        _scrollToBottom();

        _chatContext.add({'role': 'assistant', 'content': finalReply});
        await _saveMessageToHistory(MessageItem(
          id: const Uuid().v4(),
          isUser: false,
          content: finalReply,
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        final errorMsg = 'Error: $e';
        if (_currentExecution != null) {
          setState(() {
            _currentExecution = _currentExecution!.copyWith(
              status: TaskStatus.failed,
              errorMessage: errorMsg,
              endTime: DateTime.now(),
            );
            for (var i = 0; i < _chatItems.length; i++) {
              if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
                _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
              }
            }
          });
        }
        setState(() {
          _chatItems[placeholderIndex] = _ChatItem(
            isUser: false,
            message: errorMsg,
            isSuccess: false,
          );
        });
        await _saveMessageToHistory(MessageItem(
          id: const Uuid().v4(),
          isUser: false,
          content: errorMsg,
          isSuccess: false,
          timestamp: DateTime.now(),
        ));
      } finally {
        if (mounted) {
          setState(() {
            _isChatRunning = false;
          });
        } else {
          _isChatRunning = false;
        }
      }
    } else {
      final placeholderIndex = _chatItems.length;
      setState(() {
        _chatItems.add(_ChatItem(isUser: false, message: _getStr('thinking')));
        _isChatRunning = true;
      });
      _scrollToBottom();

      try {
        final response = await ModelClient().request(_chatContext);
        final reply = response.rawContent.trim();
        _chatContext.add({'role': 'assistant', 'content': reply});

        setState(() {
          _chatItems[placeholderIndex] = _ChatItem(
            isUser: false,
            message: reply,
          );
        });
        _scrollToBottom();

        await _saveMessageToHistory(MessageItem(
          id: const Uuid().v4(),
          isUser: false,
          content: reply,
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        final errorMsg = 'Error: $e';
        setState(() {
          _chatItems[placeholderIndex] = _ChatItem(
            isUser: false,
            message: errorMsg,
            isSuccess: false,
          );
        });
        await _saveMessageToHistory(MessageItem(
          id: const Uuid().v4(),
          isUser: false,
          content: errorMsg,
          isSuccess: false,
          timestamp: DateTime.now(),
        ));
      } finally {
        if (mounted) {
          setState(() {
            _isChatRunning = false;
          });
        } else {
          _isChatRunning = false;
        }
      }
    }
  }

  Future<void> _stopTask() async {
    if (!_agent.isRunning) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppTheme.black.withOpacity(0.6),
      builder: (context) => _MinimalDialog(
        title: _getStr('stopTask'),
        content: _getStr('confirmStop'),
        confirmText: _getStr('stopTask'),
        cancelText: _getStr('cancel'),
        isDestructive: true,
      ),
    );

    if (confirmed != true) return;

    _agent.stop(_getStr('taskStopped'));
    if (!mounted) return;

    setState(() {
      if (_currentExecution != null) {
        _currentExecution = _currentExecution!.copyWith(
          status: TaskStatus.cancelled,
          errorMessage: _getStr('taskStopped'),
          endTime: DateTime.now(),
        );
        // 更新聊天项
        for (var i = 0; i < _chatItems.length; i++) {
          if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
            _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
          }
        }
      }
    });
    _scrollToBottom();
  }

  void _startNewConversation() {
    if (_agent.isRunning || _isChatRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getStr('waitCurrentTask'))),
      );
      return;
    }
    
    _agent.reset();
    _currentSessionId = null;
    _currentExecution = null;
    _chatContext.clear();
    _isChatRunning = false;
    
    setState(() {
      _chatItems.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getStr('newChatStarted')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _agent.removeListener(_onAgentChanged);
    _agent.dispose();
    _taskController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

// ============================================
// 数据类
// ============================================

/// 聊天项 - 可以是用户消息、AI消息或任务执行卡片
class _ChatItem {
  final bool isUser;
  final String? message;
  final String? thinking;
  final String? action;
  final bool? isSuccess;
  final TaskExecution? execution;

  _ChatItem({
    required this.isUser,
    this.message,
    this.thinking,
    this.action,
    this.isSuccess,
    this.execution,
  });

  _ChatItem copyWith({
    bool? isUser,
    String? message,
    String? thinking,
    String? action,
    bool? isSuccess,
    TaskExecution? execution,
  }) {
    return _ChatItem(
      isUser: isUser ?? this.isUser,
      message: message ?? this.message,
      thinking: thinking ?? this.thinking,
      action: action ?? this.action,
      isSuccess: isSuccess ?? this.isSuccess,
      execution: execution ?? this.execution,
    );
  }
}

// ============================================
// 组件
// ============================================

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;

  const _InputIconButton({
    required this.icon,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final backgroundColor = isActive
        ? AppTheme.grey900
        : enabled
            ? AppTheme.grey200
            : AppTheme.grey150;
    final iconColor = isActive
        ? AppTheme.white
        : enabled
            ? AppTheme.grey600
            : AppTheme.grey400;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

/// 用户消息气泡
class _UserBubble extends StatelessWidget {
  final String message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppTheme.space16,
          left: AppTheme.space48,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: AppTheme.black,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        child: Text(
          message,
          style: const TextStyle(
            fontSize: AppTheme.fontSize15,
            color: AppTheme.white,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// 助手消息气泡
class _AssistantBubble extends StatelessWidget {
  final String? message;
  final String? thinking;
  final String? action;
  final bool? isSuccess;
  final String thinkingLabel;

  const _AssistantBubble({
    this.message,
    this.thinking,
    this.action,
    this.isSuccess,
    required this.thinkingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppTheme.space16,
          right: AppTheme.space24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 思考过程
            if (thinking != null && thinking!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.space12),
                decoration: BoxDecoration(
                  color: AppTheme.grey50,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          size: 14,
                          color: AppTheme.grey500,
                        ),
                        const SizedBox(width: AppTheme.space6),
                        Text(
                          thinkingLabel,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSize11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.grey500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Text(
                      thinking!,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSize13,
                        color: AppTheme.grey600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space8),
            ],
            
            // 动作标签
            if (action != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space10,
                  vertical: AppTheme.space6,
                ),
                decoration: BoxDecoration(
                  color: isSuccess == true 
                      ? AppTheme.grey900 
                      : AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSuccess == true 
                          ? Icons.check_rounded 
                          : Icons.close_rounded,
                      size: 14,
                      color: isSuccess == true 
                          ? AppTheme.white 
                          : AppTheme.error,
                    ),
                    const SizedBox(width: AppTheme.space6),
                    Text(
                      action!,
                      style: TextStyle(
                        fontSize: AppTheme.fontSize12,
                        fontWeight: FontWeight.w600,
                        color: isSuccess == true 
                            ? AppTheme.white 
                            : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space8),
            ],
            
            // 消息内容
            if (message != null && (action == null || message != action))
              Text(
                message!,
                style: const TextStyle(
                  fontSize: AppTheme.fontSize15,
                  color: AppTheme.grey900,
                  height: 1.6,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 极简对话框
class _MinimalDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String? cancelText;
  final bool showCancel;
  final bool isDestructive;

  const _MinimalDialog({
    required this.title,
    required this.content,
    required this.confirmText,
    this.cancelText,
    this.showCancel = true,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.fontSize18,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSize14,
                color: AppTheme.grey600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            Row(
              children: [
                if (showCancel) ...[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        cancelText ?? 'Cancel',
                        style: const TextStyle(color: AppTheme.grey600),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDestructive 
                          ? AppTheme.error 
                          : AppTheme.black,
                      minimumSize: const Size(0, 44),
                    ),
                    child: Text(confirmText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 权限对话框
class _PermissionDialog extends StatelessWidget {
  final String title;
  final String description;
  final String buttonLabel;
  final String cancelLabel;
  final VoidCallback onEnable;
  final VoidCallback onCancel;

  const _PermissionDialog({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.cancelLabel,
    required this.onEnable,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.accessibility_new_rounded,
                size: 28,
                color: AppTheme.grey700,
              ),
            ),
            const SizedBox(height: AppTheme.space20),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.fontSize18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.fontSize14,
                color: AppTheme.grey600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.space24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onEnable,
                child: Text(buttonLabel),
              ),
            ),
            const SizedBox(height: AppTheme.space12),
            TextButton(
              onPressed: onCancel,
              child: Text(
                cancelLabel,
                style: const TextStyle(color: AppTheme.grey500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 模型选择器
class _ModelSelectorSheet extends StatelessWidget {
  final String title;
  final List<Model> models;
  final String? activeModelId;
  final String emptyHint;
  final String manageLabel;
  final VoidCallback onManage;
  final ValueChanged<Model> onSelect;

  const _ModelSelectorSheet({
    required this.title,
    required this.models,
    required this.activeModelId,
    required this.emptyHint,
    required this.manageLabel,
    required this.onManage,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTheme.space24),
            Text(
              title,
              style: const TextStyle(
                fontSize: AppTheme.fontSize16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.space16),
            if (models.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space24,
                  vertical: AppTheme.space12,
                ),
                child: Text(
                  emptyHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSize14,
                    color: AppTheme.grey500,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space8),
              TextButton(
                onPressed: onManage,
                child: Text(manageLabel),
              ),
            ] else ...[
              ...models.map((model) => _ModelOption(
                    label: model.displayName,
                    isSelected: model.id == activeModelId,
                    onTap: () => onSelect(model),
                  )),
              const SizedBox(height: AppTheme.space16),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModelOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space24,
          vertical: AppTheme.space14,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: isSelected ? AppTheme.black : AppTheme.grey300,
            ),
            const SizedBox(width: AppTheme.space12),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSize15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: AppTheme.grey900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 树叶图标绘制器 - 圆形内的树叶设计
class _LeafIconPainter extends CustomPainter {
  final Color color;
  
  _LeafIconPainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final center = Offset(size.width / 2, size.height / 2);
    final leafSize = size.width * 0.28;
    
    // 绘制树叶形状 - 使用贝塞尔曲线
    final path = Path();
    
    // 树叶主体
    path.moveTo(center.dx, center.dy - leafSize);
    path.quadraticBezierTo(
      center.dx + leafSize * 1.2, center.dy - leafSize * 0.3,
      center.dx + leafSize * 0.3, center.dy + leafSize * 0.8,
    );
    path.quadraticBezierTo(
      center.dx, center.dy + leafSize * 0.5,
      center.dx - leafSize * 0.3, center.dy + leafSize * 0.8,
    );
    path.quadraticBezierTo(
      center.dx - leafSize * 1.2, center.dy - leafSize * 0.3,
      center.dx, center.dy - leafSize,
    );
    path.close();
    
    canvas.drawPath(path, paint);
    
    // 中间叶脉
    final veinPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawLine(
      Offset(center.dx, center.dy - leafSize * 0.8),
      Offset(center.dx, center.dy + leafSize * 0.6),
      veinPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant _LeafIconPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
