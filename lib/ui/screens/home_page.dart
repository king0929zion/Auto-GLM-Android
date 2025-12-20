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
import '../../l10n/app_strings.dart';
import '../../config/app_config.dart';

/// 主页面 - 极简聊天界面
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
  
  final List<_ChatMessage> _messages = [];
  bool _isInitialized = false;
  String? _errorMessage;
  String? _currentSessionId;
  String _language = AppConfig.defaultLanguage;
  
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
    if (mounted) setState(() {});
  }

  void _onStepCompleted(StepResult result) {
    setState(() {
      _messages.add(_ChatMessage(
        isUser: false,
        thinking: result.thinking,
        action: result.action?.actionName,
        message: result.message,
        isSuccess: result.success,
      ));
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
      barrierColor: AppTheme.black.withOpacity(0.5),
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
      barrierColor: AppTheme.black.withOpacity(0.5),
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
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  /// 极简头部
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space16,
        vertical: AppTheme.space12,
      ),
      child: Row(
        children: [
          // 模型选择器
          GestureDetector(
            onTap: () => _showModelSelector(),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.space12,
                vertical: AppTheme.space8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
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
                    size: 16,
                    color: AppTheme.grey500,
                  ),
                ],
              ),
            ),
          ),
          
          const Spacer(),
          
          // 操作按钮组
          _HeaderButton(
            icon: Icons.history_rounded,
            onTap: _showHistorySheet,
          ),
          const SizedBox(width: AppTheme.space8),
          _HeaderButton(
            icon: Icons.add_rounded,
            onTap: _startNewConversation,
          ),
          const SizedBox(width: AppTheme.space8),
          _HeaderButton(
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
    if (_messages.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space20,
        vertical: AppTheme.space16,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
    );
  }

  /// 空状态 - 极简引导
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 极简图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: AppTheme.grey400,
              ),
            ),
            const SizedBox(height: AppTheme.space32),
            
            Text(
              _getStr('helpPrompt'),
              style: const TextStyle(
                fontSize: AppTheme.fontSize20,
                fontWeight: FontWeight.w600,
                color: AppTheme.grey900,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space12),
            
            Text(
              _getStr('tryAsk'),
              style: const TextStyle(
                fontSize: AppTheme.fontSize14,
                color: AppTheme.grey500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 消息气泡
  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.isUser) {
      return _UserBubble(message: msg.message ?? '');
    }
    return _AssistantBubble(
      message: msg.message,
      thinking: msg.thinking,
      action: msg.action,
      isSuccess: msg.isSuccess,
      thinkingLabel: _getStr('thinking'),
    );
  }

  /// 极简输入栏
  Widget _buildInputBar() {
    final isRunning = _agent.isRunning;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space16,
        AppTheme.space8,
        AppTheme.space16,
        AppTheme.space16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.grey50,
          borderRadius: BorderRadius.circular(AppTheme.radius24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _taskController,
                focusNode: _focusNode,
                enabled: _isInitialized && !isRunning,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _startTask(),
                style: const TextStyle(
                  fontSize: AppTheme.fontSize15,
                  color: AppTheme.grey900,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: isRunning ? _getStr('working') : _getStr('askHint'),
                  hintStyle: const TextStyle(
                    color: AppTheme.grey400,
                    fontSize: AppTheme.fontSize15,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space20,
                    vertical: AppTheme.space14,
                  ),
                ),
                cursorColor: AppTheme.grey900,
              ),
            ),
            
            // 发送按钮
            Padding(
              padding: const EdgeInsets.all(AppTheme.space6),
              child: GestureDetector(
                onTap: isRunning ? _stopTask : _startTask,
                child: AnimatedContainer(
                  duration: AppTheme.durationFast,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isRunning ? AppTheme.grey200 : AppTheme.black,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRunning ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                    color: isRunning ? AppTheme.grey600 : AppTheme.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
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
          // TODO: Load session
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
      barrierColor: AppTheme.black.withOpacity(0.5),
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
    
    setState(() {
      _messages.add(_ChatMessage(isUser: true, message: task));
    });
    
    await _saveMessageToHistory(MessageItem(
      id: const Uuid().v4(),
      isUser: true,
      content: task,
      timestamp: DateTime.now(),
    ));

    _taskController.clear();
    _focusNode.unfocus();
    _scrollToBottom();
    
    try {
      await _agent.run(task);
    } catch (e) {
      final errorMsg = 'Error: $e';
      setState(() {
        _messages.add(_ChatMessage(
          isUser: false,
          message: errorMsg,
          isSuccess: false,
        ));
      });
      
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
      barrierColor: AppTheme.black.withOpacity(0.5),
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
      _messages.add(_ChatMessage(
        isUser: false,
        message: _getStr('taskStopped'),
        isSuccess: false,
      ));
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
    
    setState(() {
      _messages.clear();
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
// 组件
// ============================================

/// 头部按钮
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.grey50,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppTheme.grey700),
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
          // Header
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
          
          // List
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

// ============================================
// 数据类
// ============================================

class _ChatMessage {
  final bool isUser;
  final String? message;
  final String? thinking;
  final String? action;
  final bool? isSuccess;

  _ChatMessage({
    required this.isUser,
    this.message,
    this.thinking,
    this.action,
    this.isSuccess,
  });
}
