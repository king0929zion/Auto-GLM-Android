import 'package:flutter/material.dart';
import '../../core/phone_agent.dart';
import '../../data/models/models.dart';
import '../../config/settings_repository.dart';
import '../../services/device/device_controller.dart';
import '../theme/app_theme.dart';

/// 主页面 - 简洁的任务执行界面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late PhoneAgent _agent;
  final DeviceController _deviceController = DeviceController();
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final List<_ChatMessage> _messages = [];
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  Future<void> _initializeAgent() async {
    final settings = SettingsRepository.instance;
    final modelConfig = settings.getModelConfig();
    final agentConfig = AgentConfig(
      maxSteps: settings.maxSteps,
      lang: settings.language,
      verbose: true,
    );
    
    // Debug print configuration
    debugPrint('=== Model Config ===');
    debugPrint('Base URL: ${modelConfig.baseUrl}');
    debugPrint('API Key: ${modelConfig.apiKey.substring(0, modelConfig.apiKey.length > 10 ? 10 : modelConfig.apiKey.length)}...');
    debugPrint('Model: ${modelConfig.modelName}');
    
    _agent = PhoneAgent(
      modelConfig: modelConfig,
      agentConfig: agentConfig,
    );
    
    _agent.onConfirmationRequired = _showConfirmationDialog;
    _agent.onTakeoverRequired = _showTakeoverDialog;
    _agent.onStepCompleted = _onStepCompleted;
    
    try {
      await _agent.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Initialization failed: $e');
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
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<bool> _showConfirmationDialog(String message) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('确认操作'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showTakeoverDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('需要手动操作'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Default background is sufficient (AppTheme.scaffoldBackgroundColor)
      appBar: AppBar(
        title: const Text('AutoZi', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: AppTheme.scaffoldWhite,
        surfaceTintColor: Colors.transparent, // Prevent tint on scroll
        leading: IconButton(
          icon: const Icon(Icons.history_outlined),
          tooltip: '历史记录',
          onPressed: _showHistoryDrawer,
          style: IconButton.styleFrom(
            foregroundColor: AppTheme.primaryBlack,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新建对话',
            onPressed: _startNewConversation,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _agent.removeListener(_onAgentChanged);
              _agent.dispose();
              _initializeAgent();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _errorMessage != null ? _buildErrorView() : _buildBody(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.grey200, width: 1),
            ),
            child: const Icon(Icons.auto_awesome_outlined, size: 48, color: AppTheme.grey400),
          ),
          const SizedBox(height: 24),
          const Text(
            '有什么可以帮您？',
            style: TextStyle(
              color: AppTheme.primaryBlack, 
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '尝试输入 "帮我查看今天的待办事项"',
            style: TextStyle(color: AppTheme.textHint, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24, left: 60),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlack,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Text(
            msg.message ?? '', 
            style: const TextStyle(
              fontSize: 15, 
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 40),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppTheme.grey200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.thinking != null && msg.thinking!.isNotEmpty) ...[
              Row(
                children: [
                  // Spinning icon or static brain?
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.grey50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, size: 12, color: AppTheme.primaryBlack),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Thinking Process',
                    style: TextStyle(
                      color: AppTheme.textSecondary, 
                      fontSize: 12, 
                      fontWeight: FontWeight.w600
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                msg.thinking!,
                style: const TextStyle(
                  color: AppTheme.textSecondary, 
                  fontSize: 14, 
                  height: 1.6,
                  fontFamily: 'monospace', // Code-like feel for thinking
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, thickness: 1, color: AppTheme.grey100),
              ),
            ],
            
            if (msg.action != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.grey50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.grey200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      msg.isSuccess == true ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: msg.isSuccess == true ? AppTheme.primaryBlack : AppTheme.error,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        msg.action!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryBlack,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (msg.message != null)
              Text(
                msg.message!, 
                style: const TextStyle(
                  fontSize: 15, 
                  color: AppTheme.primaryBlack,
                  height: 1.6,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final isRunning = _agent.isRunning;
    
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppTheme.grey200),
          // No shadow for flat design
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taskController,
                focusNode: _focusNode,
                enabled: _isInitialized && !isRunning,
                maxLines: null, // Allow multi-line expand
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _startTask(),
                decoration: InputDecoration(
                  hintText: isRunning ? 'AutoZi is working...' : 'Ask AutoZi anything...',
                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 15),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16, color: AppTheme.primaryBlack),
                cursorColor: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(width: 4),
            // Send Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: isRunning ? AppTheme.grey200 : AppTheme.primaryBlack,
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: isRunning ? _stopTask : _startTask,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    isRunning ? Icons.stop : Icons.arrow_upward,
                    color: isRunning ? AppTheme.primaryBlack : Colors.white,
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

  /// 检查并确保必需权限 - 极简弹窗
  Future<bool> _ensureRequiredPermissions() async {
    final accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
    if (accessibilityEnabled) return true;
    if (!mounted) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceWhite,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.grey200)
        ),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.grey200),
              ),
              child: const Icon(
                Icons.accessibility_new_outlined,
                size: 32,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '权限未就绪',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '请前往系统设置开启无障碍服务\n"AutoZi" 才能为您操作手机',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _deviceController.openAccessibilitySettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlack,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26), // Full rounded
                  ),
                ),
                child: const Text('去开启', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: AppTheme.textHint)),
            ),
          ],
        ),
      ),
    );

    return false;
  }

  void _startTask() async {
    final task = _taskController.text.trim();
    if (task.isEmpty) return;

    if (_agent.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请等待当前任务完成')),
      );
      return;
    }

    final permissionsOk = await _ensureRequiredPermissions();
    if (!permissionsOk) return;
    
    await SettingsRepository.instance.addTaskToHistory(task);
    
    setState(() {
      _messages.add(_ChatMessage(isUser: true, message: task));
    });
    _taskController.clear();
    _focusNode.unfocus();
    _scrollToBottom();
    
    try {
      await _agent.run(task);
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          isUser: false,
          message: 'Error: $e',
          isSuccess: false,
        ));
      });
    }
  }

  @override
  void dispose() {
    _agent.removeListener(_onAgentChanged);
    _agent.dispose();
    _taskController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _stopTask() async {
    if (!_agent.isRunning) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('停止任务'),
        content: const Text('确定要停止当前任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('停止'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    _agent.stop('用户停止');
    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage(
        isUser: false,
        message: '已停止当前任务',
        isSuccess: false,
      ));
    });
    _scrollToBottom();
  }

  void _startNewConversation() {
    if (_agent.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请等待当前任务完成')),
      );
      return;
    }
    
    _agent.reset();
    
    setState(() {
      _messages.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已开始新对话'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _showHistoryDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildHistorySheet(),
    );
  }
  
  Widget _buildHistorySheet() {
    final history = SettingsRepository.instance.taskHistory;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: AppTheme.primaryBlack),
              const SizedBox(width: 8),
              const Text(
                '历史记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const Spacer(),
              if (history.isNotEmpty)
                TextButton(
                  onPressed: () {
                    SettingsRepository.instance.clearTaskHistory();
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('清除', style: TextStyle(color: AppTheme.error)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Text(
                      '暂无历史记录',
                      style: TextStyle(color: AppTheme.textHint),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final task = history[history.length - 1 - index];
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, size: 20, color: AppTheme.textSecondary),
                        title: Text(
                          task,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textPrimary),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.grey300),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          Navigator.pop(context);
                          _taskController.text = task;
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _initializeAgent();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Chat messages area
        Expanded(
          child: _messages.isEmpty ? _buildEmptyState() : _buildMessagesList(),
        ),
        
        // Input area
        _buildInputArea(),
      ],
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
    );
  }
}

class _ChatMessage {
  final bool isUser;
  final String? thinking;
  final String? action;
  final String? message;
  final bool? isSuccess;

  _ChatMessage({
    required this.isUser,
    this.thinking,
    this.action,
    this.message,
    this.isSuccess,
  });
}
