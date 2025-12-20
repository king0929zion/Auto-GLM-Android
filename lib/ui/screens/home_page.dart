import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/phone_agent.dart';
import '../../data/models/models.dart';
import '../../data/models/chat_history.dart';
import '../../config/settings_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/task_execution_card.dart';
import '../../l10n/app_strings.dart';
import '../../config/app_config.dart';

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
  
  final List<_ChatItem> _chatItems = [];
  bool _isInitialized = false;
  String? _errorMessage;
  String? _currentSessionId;
  String _language = AppConfig.defaultLanguage;
  
  // 当前选择的能力模式
  String _selectedMode = 'agent'; // agent, canvas
  
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
    _initializeAgent();
  }

  String _getStr(String key) => AppStrings.getString(key, _language);

  Future<void> _initializeAgent() async {
    final settings = SettingsRepository.instance;
    await settings.init();
    
    setState(() {
      _language = settings.language;
    });

    final modelConfig = settings.getModelConfig();
    final agentConfig = AgentConfig(
      maxSteps: settings.maxSteps,
      lang: _language,
      verbose: true,
    );
    
    _agent = PhoneAgent(
      modelConfig: modelConfig,
      agentConfig: agentConfig,
    );
    
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
          _currentExecution = _currentExecution!.copyWith(
            status: _agent.isRunning ? TaskStatus.running : TaskStatus.completed,
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
    final provider = SettingsRepository.instance.selectedProvider;
    if (provider == 'doubao') return _getStr('modelDoubao');
    return _getStr('modelAutoGLM');
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
              child: _errorMessage != null 
                  ? _buildErrorView() 
                  : _buildChatArea(),
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
          // 模型选择器 - 使用下拉菜单
          PopupMenuButton<String>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: AppTheme.white,
            elevation: 8,
            enabled: !_agent.isRunning,
            onSelected: (provider) async {
              await SettingsRepository.instance.setSelectedProvider(provider);
              _initializeAgent();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'autoglm',
                child: Row(
                  children: [
                    Icon(
                      SettingsRepository.instance.selectedProvider == 'autoglm'
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: SettingsRepository.instance.selectedProvider == 'autoglm'
                          ? AppTheme.grey900
                          : AppTheme.grey400,
                    ),
                    const SizedBox(width: 10),
                    Text(_getStr('modelAutoGLM')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'doubao',
                child: Row(
                  children: [
                    Icon(
                      SettingsRepository.instance.selectedProvider == 'doubao'
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      size: 18,
                      color: SettingsRepository.instance.selectedProvider == 'doubao'
                          ? AppTheme.grey900
                          : AppTheme.grey400,
                    ),
                    const SizedBox(width: 10),
                    Text(_getStr('modelDoubao')),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space12,
                vertical: AppTheme.space8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getModelDisplayName(),
                    style: const TextStyle(
                      fontSize: AppTheme.fontSize13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grey900,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppTheme.grey500,
                  ),
                ],
              ),
            ),
          ),
          
          const Spacer(),
          
          // 操作按钮组
          _HeaderIconButton(
            icon: Icons.history_rounded,
            onTap: _showHistorySheet,
          ),
          const SizedBox(width: AppTheme.space8),
          _HeaderIconButton(
            icon: Icons.add_rounded,
            onTap: _startNewConversation,
          ),
          const SizedBox(width: AppTheme.space8),
          _HeaderIconButton(
            icon: Icons.settings_rounded,
            onTap: () async {
              await Navigator.pushNamed(context, '/settings');
              _agent.removeListener(_onAgentChanged);
              _agent.dispose();
              _initializeAgent();
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
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space20,
        vertical: AppTheme.space16,
      ),
      itemCount: _chatItems.length,
      itemBuilder: (context, index) => _buildChatItem(_chatItems[index]),
    );
  }

  /// 构建聊天项
  Widget _buildChatItem(_ChatItem item) {
    if (item.isUser) {
      return _UserBubble(message: item.message ?? '');
    }
    
    // Agent 模式：显示任务执行卡片
    if (_selectedMode == 'agent' && item.execution != null) {
      return TaskExecutionCard(
        execution: item.execution!,
        onTap: () => _openVirtualScreenPreview(item.execution!),
        onPause: () => _pauseTask(),
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
          onStop: () => _stopTask(),
        ),
      ),
    );
  }

  /// 暂停任务
  void _pauseTask() {
    // TODO: 实现暂停逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暂停功能开发中...')),
    );
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
    final isRunning = _agent.isRunning;
    final hasText = _taskController.text.isNotEmpty;
    final isAgentMode = _selectedMode == 'agent';
    
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
              // 输入区域 - 更高
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _taskController,
                  focusNode: _focusNode,
                  enabled: _isInitialized && !isRunning,
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
                    hintText: isRunning 
                        ? _getStr('working') 
                        : 'Ask AutoZi',
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
                  cursorColor: accentColor,
                ),
              ),
              
              // 工具栏
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Row(
                  children: [
                    // 添加按钮 - 上传图片/拍照/文档
                    _InputToolButton(
                      icon: Icons.add,
                      onTap: _showAttachmentMenu,
                    ),
                    const SizedBox(width: 4),
                    
                    // 功能模块选择器
                    _InputToolButton(
                      icon: Icons.dashboard_customize_outlined,
                      onTap: _showModeSelector,
                    ),
                    
                    const Spacer(),
                    
                    // Agent 开关按钮
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMode = isAgentMode ? 'chat' : 'agent';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isAgentMode ? accentColor.withOpacity(0.15) : AppTheme.grey200,
                          borderRadius: BorderRadius.circular(20),
                          border: isAgentMode ? Border.all(
                            color: accentColor.withOpacity(0.3),
                            width: 1,
                          ) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAgentMode ? Icons.auto_awesome : Icons.chat_bubble_outline,
                              size: 16,
                              color: isAgentMode ? accentColor : AppTheme.grey500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAgentMode ? 'Agent' : 'Chat',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isAgentMode ? accentColor : AppTheme.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 发送按钮 - 棕色主题
                    GestureDetector(
                      onTap: isRunning ? _stopTask : (hasText ? _startTask : null),
                      child: AnimatedContainer(
                        duration: AppTheme.durationFast,
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isRunning 
                              ? Colors.red.withOpacity(0.15)
                              : hasText 
                                  ? accentColor
                                  : AppTheme.grey200,
                          shape: BoxShape.circle,
                        ),
                        child: isRunning
                            ? const Icon(
                                Icons.stop_rounded,
                                color: Colors.red,
                                size: 20,
                              )
                            : CustomPaint(
                                size: const Size(40, 40),
                                painter: _LeafIconPainter(
                                  color: hasText 
                                      ? AppTheme.white 
                                      : AppTheme.grey400,
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

  /// 显示附件菜单
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: Colors.blue),
                ),
                title: const Text('从相册选择'),
                subtitle: const Text('选择图片或视频'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现相册选择
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Colors.green),
                ),
                title: const Text('拍照'),
                subtitle: const Text('拍摄新照片'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现拍照
                },
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.folder_outlined, color: Colors.orange),
                ),
                title: const Text('选择文档'),
                subtitle: const Text('PDF、Word、Excel 等'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 实现文档选择
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示模式选择器
  void _showModeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动指示条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              
              // Agent 模式
              _ModeOptionTile(
                icon: Icons.smart_toy_outlined,
                title: 'Agent',
                subtitle: _language == 'cn' ? '智能代理模式，自动执行手机操作' : 'AI agent for phone automation',
                isSelected: _selectedMode == 'agent',
                onTap: () {
                  setState(() => _selectedMode = 'agent');
                  Navigator.pop(context);
                },
              ),
              
              // Canvas 模式
              _ModeOptionTile(
                icon: Icons.dashboard_customize_outlined,
                title: 'Canvas',
                subtitle: _language == 'cn' ? '画布模式，实时编辑和协作' : 'Real-time editing and collaboration',
                isSelected: _selectedMode == 'canvas',
                onTap: () {
                  setState(() => _selectedMode = 'canvas');
                  Navigator.pop(context);
                },
              ),
              
              const SizedBox(height: 16),
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

  void _showModelSelector() {
    if (_agent.isRunning) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModelSelectorSheet(
        title: _getStr('modelConfig'),
        currentProvider: SettingsRepository.instance.selectedProvider,
        autoglmLabel: _getStr('modelAutoGLM'),
        doubaoLabel: _getStr('modelDoubao'),
        onSelect: (provider) async {
          Navigator.pop(context);
          await SettingsRepository.instance.setSelectedProvider(provider);
          _initializeAgent();
        },
      ),
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _HistorySheet(
        sessions: HistoryRepository.instance.getSessions(),
        historyLabel: _getStr('history'),
        clearLabel: _getStr('clearHistory'),
        emptyLabel: _getStr('noHistory'),
        onClear: () async {
          await HistoryRepository.instance.clearAll();
          Navigator.pop(context);
          setState(() {});
        },
        onSelect: (session) {
          Navigator.pop(context);
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

    if (_agent.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getStr('waitCurrentTask'))),
      );
      return;
    }

    final permissionsOk = await _ensureRequiredPermissions();
    if (!permissionsOk) return;
    
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

    _taskController.clear();
    _focusNode.unfocus();
    
    // Agent 模式：创建任务执行卡片
    if (_selectedMode == 'agent') {
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
    
    try {
      await _agent.run(task);
      
      // 任务完成
      if (_currentExecution != null) {
        setState(() {
          _currentExecution = _currentExecution!.copyWith(
            status: TaskStatus.completed,
            endTime: DateTime.now(),
          );
          // 更新聊天项
          for (var i = 0; i < _chatItems.length; i++) {
            if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
              _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
            }
          }
        });
      }
    } catch (e) {
      final errorMsg = 'Error: $e';
      
      if (_currentExecution != null) {
        setState(() {
          _currentExecution = _currentExecution!.copyWith(
            status: TaskStatus.failed,
            errorMessage: errorMsg,
            endTime: DateTime.now(),
          );
          // 更新聊天项
          for (var i = 0; i < _chatItems.length; i++) {
            if (_chatItems[i].execution?.taskId == _currentExecution!.taskId) {
              _chatItems[i] = _chatItems[i].copyWith(execution: _currentExecution);
            }
          }
        });
      } else {
        setState(() {
          _chatItems.add(_ChatItem(
            isUser: false,
            message: errorMsg,
            isSuccess: false,
          ));
        });
      }
      
      await _saveMessageToHistory(MessageItem(
        id: const Uuid().v4(),
        isUser: false,
        content: errorMsg,
        isSuccess: false,
        timestamp: DateTime.now(),
      ));
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

    _agent.stop(_getStr('userStopped'));
    if (!mounted) return;

    setState(() {
      if (_currentExecution != null) {
        _currentExecution = _currentExecution!.copyWith(
          status: TaskStatus.failed,
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
    if (_agent.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getStr('waitCurrentTask'))),
      );
      return;
    }
    
    _agent.reset();
    _currentSessionId = null;
    _currentExecution = null;
    
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

/// 头部图标按钮
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppTheme.grey700),
      ),
    );
  }
}

/// 模式选项
class _ModeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 22,
                color: Colors.white,
              ),
          ],
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
  final String currentProvider;
  final String autoglmLabel;
  final String doubaoLabel;
  final Function(String) onSelect;

  const _ModelSelectorSheet({
    required this.title,
    required this.currentProvider,
    required this.autoglmLabel,
    required this.doubaoLabel,
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
            _ModelOption(
              label: autoglmLabel,
              isSelected: currentProvider == 'autoglm',
              onTap: () => onSelect('autoglm'),
            ),
            _ModelOption(
              label: doubaoLabel,
              isSelected: currentProvider == 'doubao',
              onTap: () => onSelect('doubao'),
            ),
            const SizedBox(height: AppTheme.space16),
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

/// 历史记录
class _HistorySheet extends StatelessWidget {
  final List sessions;
  final String historyLabel;
  final String clearLabel;
  final String emptyLabel;
  final VoidCallback onClear;
  final Function(dynamic) onSelect;

  const _HistorySheet({
    required this.sessions,
    required this.historyLabel,
    required this.clearLabel,
    required this.emptyLabel,
    required this.onClear,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radius20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.space20),
            child: Row(
              children: [
                Text(
                  historyLabel,
                  style: const TextStyle(
                    fontSize: AppTheme.fontSize18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (sessions.isNotEmpty)
                  TextButton(
                    onPressed: onClear,
                    child: Text(
                      clearLabel,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: AppTheme.fontSize13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      emptyLabel,
                      style: const TextStyle(color: AppTheme.grey400),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final date = session.lastUpdatedAt;
                      final dateStr = '${date.month}/${date.day}';
                      
                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.grey50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 16,
                            color: AppTheme.grey500,
                          ),
                        ),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSize14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: AppTheme.fontSize12,
                            color: AppTheme.grey400,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppTheme.grey300,
                        ),
                        onTap: () => onSelect(session),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 输入栏工具按钮
class _InputToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  
  const _InputToolButton({
    required this.icon,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.grey200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: AppTheme.grey600,
        ),
      ),
    );
  }
}

/// 模式指示标签
class _ModeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  
  const _ModeChip({
    required this.label,
    required this.isActive,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.grey200 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? AppTheme.grey800 : AppTheme.grey500,
          ),
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
