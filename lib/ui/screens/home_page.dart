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

  /// 检查并确保必需权限 - 简化版弹窗
  Future<bool> _ensureRequiredPermissions() async {
    final accessibilityEnabled = await _deviceController.isAccessibilityEnabled();
    if (accessibilityEnabled) return true;
    if (!mounted) return false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.accessibility_new, color: AppTheme.error),
            const SizedBox(width: 12),
            const Expanded(child: Text('需要无障碍权限')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '无障碍服务未启用',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AutoGLM 需要无障碍权限来：',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              '• 读取屏幕内容\n'
              '• 模拟点击和滑动\n'
              '• 输入文字',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('打开无障碍设置'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () async {
                await _deviceController.openAccessibilitySettings();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('AutoGLM', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.history),
          tooltip: '历史记录',
          onPressed: _showHistoryDrawer,
        ),
        actions: [
          // 新建对话按钮
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: '新建对话',
            onPressed: _startNewConversation,
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              // Reload agent with new settings
              _agent.removeListener(_onAgentChanged);
              _agent.dispose();
              _initializeAgent();
            },
          ),
        ],
      ),
      body: _errorMessage != null ? _buildErrorView() : _buildBody(),
    );
  }
  
  /// 新建对话
  void _startNewConversation() {
    if (_agent.isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请等待当前任务完成')),
      );
      return;
    }
    
    // 重置 Agent 上下文，清除历史截图和对话记录
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
  
  /// 显示历史记录抽屉
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
  
  /// 构建历史记录面板
  Widget _buildHistorySheet() {
    final history = SettingsRepository.instance.taskHistory;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              const Icon(Icons.history, color: AppTheme.accentOrange),
              const SizedBox(width: 8),
              const Text(
                '历史记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
          const Divider(),
          
          // 历史列表
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
                        leading: const Icon(Icons.chat_bubble_outline, size: 20),
                        title: Text(
                          task,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            '描述您想要执行的任务',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
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

  Widget _buildMessageItem(_ChatMessage msg) {
    if (msg.isUser) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 48),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg.message ?? '', style: const TextStyle(fontSize: 15)),
      );
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 48),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warmBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (msg.thinking != null && msg.thinking!.isNotEmpty) ...[
            Text(
              msg.thinking!,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
          ],
          if (msg.action != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: msg.isSuccess == true 
                  ? AppTheme.success.withOpacity(0.1)
                  : AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                msg.action!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: msg.isSuccess == true ? AppTheme.success : AppTheme.error,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (msg.message != null)
            Text(msg.message!, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final isRunning = _agent.isRunning;
    
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taskController,
                focusNode: _focusNode,
                enabled: _isInitialized && !isRunning,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _startTask(),
                decoration: InputDecoration(
                  hintText: isRunning ? '任务执行中...' : '输入您的任务...',
                  filled: true,
                  fillColor: AppTheme.surfaceWhite,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 发送/停止按钮 - 任务执行中变为停止按钮
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isRunning ? AppTheme.error : AppTheme.accentOrange,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: isRunning ? _stopTask : _startTask,
                tooltip: isRunning ? '停止任务' : '发送',
                icon: isRunning
                  ? const Icon(Icons.stop, color: Colors.white, size: 22)
                  : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
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
