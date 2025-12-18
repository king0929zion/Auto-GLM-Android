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
  String? _currentSessionId;
  String _language = AppConfig.defaultLanguage;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  String _getStr(String key) => AppStrings.getString(key, _language);

  Future<void> _initializeAgent() async {
    final settings = SettingsRepository.instance;
    await settings.init(); // Ensure settings are loaded
    
    setState(() {
      _language = settings.language;
    });

    final modelConfig = settings.getModelConfig();
    final agentConfig = AgentConfig(
      maxSteps: settings.maxSteps,
      lang: _language,
      verbose: true,
    );
    
    // Debug print configuration
    debugPrint('=== Model Config ===');
    debugPrint('Provider: ${settings.selectedProvider}');
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
        title: Text(_getStr('confirmAction')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_getStr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_getStr('confirm')),
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
        title: Text(_getStr('manualIntervention')),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_getStr('continue')),
          ),
        ],
      ),
    );
  }

  String _getModelDisplayName() {
    final provider = SettingsRepository.instance.selectedProvider;
    if (provider == 'doubao') return _getStr('modelDoubao');
    return _getStr('modelAutoGLM');
  }

  void _showModelSelector() {
    if (_agent.isRunning) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                _getStr('modelConfig'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: AppTheme.primaryBlack),
              title: Text(_getStr('modelAutoGLM')),
              trailing: SettingsRepository.instance.selectedProvider == 'autoglm' 
                  ? const Icon(Icons.check_circle, color: AppTheme.primaryBlack) 
                  : null,
              onTap: () async {
                Navigator.pop(context);
                await SettingsRepository.instance.setSelectedProvider('autoglm');
                _initializeAgent();
              },
            ),
             const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.psychology, color: AppTheme.primaryBlack),
              title: Text(_getStr('modelDoubao')),
              trailing: SettingsRepository.instance.selectedProvider == 'doubao' 
                  ? const Icon(Icons.check_circle, color: AppTheme.primaryBlack) 
                  : null,
              onTap: () async {
                Navigator.pop(context);
                await SettingsRepository.instance.setSelectedProvider('doubao');
                _initializeAgent();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldWhite,
      appBar: AppBar(
        title: Text(_getStr('appName'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: AppTheme.scaffoldWhite,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leadingWidth: 120,
        leading: Container(
            margin: const EdgeInsets.only(left: 16),
            alignment: Alignment.centerLeft,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _showModelSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getModelDisplayName(),
                      style: const TextStyle(
                        color: AppTheme.primaryBlack,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 14, color: AppTheme.primaryBlack),
                  ],
                ),
              ),
            ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: _getStr('history'),
            onPressed: _showHistoryDrawer,
            style: IconButton.styleFrom(foregroundColor: AppTheme.primaryBlack),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: _getStr('newChat'),
            onPressed: _startNewConversation,
             style: IconButton.styleFrom(foregroundColor: AppTheme.primaryBlack),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: _getStr('settings'),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              // Re-init in case settings (like language) changed
              _agent.removeListener(_onAgentChanged);
              _agent.dispose();
              _initializeAgent(); 
            },
             style: IconButton.styleFrom(foregroundColor: AppTheme.primaryBlack),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _errorMessage != null ? _buildErrorView() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
                ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error', 
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initializeAgent,
              icon: const Icon(Icons.refresh),
              label: Text(_getStr('retry')),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlack, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
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
               color: AppTheme.grey50,
            ),
            child: const Icon(Icons.auto_awesome_outlined, size: 48, color: AppTheme.grey400),
          ),
          const SizedBox(height: 24),
          Text(
            _getStr('helpPrompt'),
            style: const TextStyle(
              color: AppTheme.primaryBlack, 
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             decoration: BoxDecoration(
               color: AppTheme.grey50,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Text(
              _getStr('tryAsk'),
              style: const TextStyle(color: AppTheme.textHint, fontSize: 13, fontWeight: FontWeight.w500),
             ),
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
          decoration: BoxDecoration(
            color: AppTheme.primaryBlack,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            msg.message ?? '', 
            style: const TextStyle(
              fontSize: 15, 
              color: Colors.white,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24, right: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppTheme.grey100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.thinking != null && msg.thinking!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9), 
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: AppTheme.grey600),
                        const SizedBox(width: 8),
                        Text(
                          _getStr('thinking'),
                          style: const TextStyle(
                            color: AppTheme.grey600, 
                            fontSize: 12, 
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      msg.thinking!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary, 
                        fontSize: 13, 
                        height: 1.5,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
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
            
            if (msg.message != null && (msg.action == null || msg.message != msg.action))
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppTheme.grey100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taskController,
                focusNode: _focusNode,
                enabled: _isInitialized && !isRunning,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _startTask(),
                decoration: InputDecoration(
                  hintText: isRunning ? _getStr('working') : _getStr('askHint'),
                  hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 15, fontWeight: FontWeight.normal),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16, color: AppTheme.primaryBlack, fontWeight: FontWeight.w500),
                cursorColor: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(width: 4),
            // Send Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: isRunning ? AppTheme.grey100 : AppTheme.primaryBlack,
                shape: BoxShape.circle,
                boxShadow: isRunning ? null : [
                  BoxShadow(
                    color: AppTheme.primaryBlack.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: isRunning ? _stopTask : _startTask,
                  customBorder: const CircleBorder(),
                  child: Icon(
                    isRunning ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                    color: isRunning ? AppTheme.primaryBlack : Colors.white,
                    size: 22,
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
            Text(
              _getStr('permissionNotReady'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getStr('permissionGuide'),
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                child: Text(_getStr('goToEnable'), style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_getStr('cancel'), style: const TextStyle(color: AppTheme.textHint)),
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
        SnackBar(content: Text(_getStr('waitCurrentTask'))),
      );
      return;
    }

    final permissionsOk = await _ensureRequiredPermissions();
    if (!permissionsOk) return;
    
    // Create new session if needed
    if (_currentSessionId == null) {
      _currentSessionId = const Uuid().v4();
      final newSession = ConversationSession(
        id: _currentSessionId!,
        title: task, // First task is the title
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
      final  errorMsg = 'Error: $e';
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
        title: Text(_getStr('stopTask')),
        content: Text(_getStr('confirmStop')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_getStr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text(_getStr('stopTask'), style: const TextStyle(color: Colors.white)),
          ),
        ],
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
    final sessions = HistoryRepository.instance.getSessions();
    
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
              Text(
                _getStr('history'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const Spacer(),
              if (sessions.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await HistoryRepository.instance.clearAll();
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: Text(_getStr('clearHistory'), style: const TextStyle(color: AppTheme.error)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 8),
          
          Expanded(
            child: sessions.isEmpty
                ? Center(
                    child: Text(
                      _getStr('noHistory'),
                      style: const TextStyle(color: AppTheme.textHint),
                    ),
                  )
                : ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      // Simple date formatting
                      final date = session.lastUpdatedAt;
                      final dateStr = '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                      
                      return ListTile(
                        leading: const Icon(Icons.chat_bubble_outline, size: 20, color: AppTheme.textSecondary),
                        title: Text(
                          session.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          dateStr,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.grey300),
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          // Load session (Logic not fully implemented but structure is here)
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

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
