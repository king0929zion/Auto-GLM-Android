import 'package:flutter/material.dart';
import '../../core/phone_agent.dart';
import '../../data/models/models.dart';
import '../../config/settings_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// 主页�?- 任务执行界面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late PhoneAgent _agent;
  final TextEditingController _taskController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<StepResult> _steps = [];
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeAgent();
  }

  Future<void> _initializeAgent() async {
    // 从设置加载配�?
    final settings = SettingsRepository.instance;
    final modelConfig = settings.getModelConfig();
    final agentConfig = AgentConfig(
      maxSteps: settings.maxSteps,
      lang: settings.language,
      verbose: true,
    );
    
    _agent = PhoneAgent(
      modelConfig: modelConfig,
      agentConfig: agentConfig,
    );
    
    // 设置回调
    _agent.onConfirmationRequired = _showConfirmationDialog;
    _agent.onTakeoverRequired = _showTakeoverDialog;
    _agent.onStepCompleted = _onStepCompleted;

    
    try {
      await _agent.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '初始化失�? $e';
      });
    }
    
    _agent.addListener(_onAgentChanged);
  }

  void _onAgentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onStepCompleted(StepResult result) {
    setState(() {
      _steps.add(result);
    });
    
    // 滚动到底�?
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
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.warning),
            const SizedBox(width: 8),
            const Text('敏感操作确认'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认执行'),
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
        title: Row(
          children: [
            Icon(Icons.pan_tool_alt, color: AppTheme.info),
            const SizedBox(width: 8),
            const Text('需要手动操�?),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            const Text(
              '请在手机上完成操作后点击"继续"',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  void _startTask() async {
    final task = _taskController.text.trim();
    if (task.isEmpty) return;
    
    // 保存到任务历�?
    await SettingsRepository.instance.addTaskToHistory(task);
    
    setState(() {
      _steps.clear();
    });
    
    try {
      final result = await _agent.run(task);
      _showResultSnackbar(result);
    } catch (e) {
      _showResultSnackbar('执行失败: $e', isError: true);
    }
  }

  void _showResultSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _agent.removeListener(_onAgentChanged);
    _agent.dispose();
    _taskController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(),
      body: _errorMessage != null
          ? _buildErrorView()
          : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accentOrange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          const Text('AutoGLM'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
          tooltip: '设置',
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.error,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
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
        // 任务状态栏
        if (_agent.currentTask != null)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: TaskStatusBar(
              task: _agent.currentTask,
              onPause: _agent.isRunning ? () => _agent.pause() : null,
              onCancel: _agent.isRunning ? () => _agent.reset() : null,
            ),
          ),
        
        // 截图预览�?
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
          child: ScreenshotPreview(
            base64Data: _agent.latestScreenshot?.base64Data,
            width: _agent.latestScreenshot?.width,
            height: _agent.latestScreenshot?.height,
            isLoading: _agent.isRunning,
            stepInfo: _agent.isRunning 
              ? '步骤 ${_agent.stepCount}' 
              : null,
          ),
        ),
        
        // 思考历史列�?
        Expanded(
          child: _buildStepsList(),
        ),
        
        // 底部输入�?
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            color: AppTheme.primaryBeige,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: TaskInputField(
              controller: _taskController,
              onSubmit: (_) => _startTask(),
              disabled: !_isInitialized || _agent.isRunning,
              isLoading: _agent.isRunning,
              hintText: '描述你想要完成的任务...',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepsList() {
    if (_steps.isEmpty) {
      return _buildEmptyState();
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
      itemCount: _steps.length,
      itemBuilder: (context, index) {
        final step = _steps[index];
        return ThinkingCard(
          thinking: step.thinking,
          action: step.action,
          stepNumber: index + 1,
          isExecuting: index == _steps.length - 1 && _agent.isRunning,
          isSuccess: step.success,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 48,
              color: AppTheme.accentOrangeLight,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              '输入任务开始自动化',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              '例如：打开微信给张三发消息',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
