import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 任务执行状态
enum TaskStatus {
  pending,    // 等待开始
  running,    // 执行中
  paused,     // 已暂停
  completed,  // 已完成
  failed,     // 失败
}

/// 单个动作记录
class ActionRecord {
  final String id;
  final String actionType;     // tap, swipe, type, scroll, open_app 等
  final String description;    // 人类可读描述，如 "点击登录按钮"
  final String? thinking;      // AI 思考过程
  final String? screenshotPath; // 执行时的截图路径
  final DateTime timestamp;
  final bool isSuccess;
  final Map<String, dynamic>? params; // 动作参数
  
  ActionRecord({
    required this.id,
    required this.actionType,
    required this.description,
    this.thinking,
    this.screenshotPath,
    required this.timestamp,
    this.isSuccess = true,
    this.params,
  });

  /// 获取动作图标
  IconData get icon {
    switch (actionType) {
      case 'tap':
      case 'click':
        return Icons.touch_app_rounded;
      case 'swipe':
      case 'scroll':
        return Icons.swipe_rounded;
      case 'type':
      case 'input':
        return Icons.keyboard_rounded;
      case 'open_app':
      case 'launch':
        return Icons.launch_rounded;
      case 'back':
        return Icons.arrow_back_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'screenshot':
        return Icons.screenshot_rounded;
      case 'wait':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.radio_button_checked_rounded;
    }
  }

  /// 获取动作颜色
  Color get statusColor {
    if (!isSuccess) return AppTheme.error;
    return AppTheme.grey900;
  }
}

/// 任务执行记录
class TaskExecution {
  final String taskId;
  final String taskDescription;
  final TaskStatus status;
  final List<ActionRecord> actions;
  final DateTime startTime;
  final DateTime? endTime;
  final String? errorMessage;
  
  TaskExecution({
    required this.taskId,
    required this.taskDescription,
    this.status = TaskStatus.pending,
    this.actions = const [],
    required this.startTime,
    this.endTime,
    this.errorMessage,
  });
  
  TaskExecution copyWith({
    String? taskId,
    String? taskDescription,
    TaskStatus? status,
    List<ActionRecord>? actions,
    DateTime? startTime,
    DateTime? endTime,
    String? errorMessage,
  }) {
    return TaskExecution(
      taskId: taskId ?? this.taskId,
      taskDescription: taskDescription ?? this.taskDescription,
      status: status ?? this.status,
      actions: actions ?? this.actions,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
  
  /// 当前步骤
  int get currentStep => actions.length;
  
  /// 是否正在运行
  bool get isRunning => status == TaskStatus.running;
  
  /// 最后一个动作
  ActionRecord? get lastAction => actions.isNotEmpty ? actions.last : null;
  
  /// 执行时长
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }
  
  /// 格式化时长
  String get formattedDuration {
    final d = duration;
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    return '${d.inSeconds}s';
  }
}

/// 任务执行卡片 - 在聊天中显示的可点击卡片
class TaskExecutionCard extends StatefulWidget {
  final TaskExecution execution;
  final VoidCallback onTap;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  
  const TaskExecutionCard({
    super.key,
    required this.execution,
    required this.onTap,
    this.onPause,
    this.onResume,
    this.onStop,
  });
  
  @override
  State<TaskExecutionCard> createState() => _TaskExecutionCardState();
}

class _TaskExecutionCardState extends State<TaskExecutionCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.execution.isRunning) {
      _pulseController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(TaskExecutionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.execution.isRunning && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.execution.isRunning && _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final exec = widget.execution;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.space16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: exec.isRunning 
              ? Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：状态和控制
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(
                children: [
                  // 状态指示器
                  _StatusIndicator(
                    status: exec.status,
                    pulseController: _pulseController,
                  ),
                  const SizedBox(width: 10),
                  
                  // 步骤信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusText(exec.status),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(exec.status),
                          ),
                        ),
                        if (exec.currentStep > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${exec.currentStep} 步 · ${exec.formattedDuration}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // 控制按钮
                  if (exec.isRunning) ...[
                    _ControlButton(
                      icon: Icons.pause_rounded,
                      onTap: widget.onPause,
                    ),
                    const SizedBox(width: 4),
                    _ControlButton(
                      icon: Icons.stop_rounded,
                      onTap: widget.onStop,
                      isDestructive: true,
                    ),
                  ],
                  
                  // 展开箭头
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ],
              ),
            ),
            
            // 虚拟屏幕预览缩略图
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // 模拟手机边框的缩略图
                  _MiniPhonePreview(execution: exec),
                  const SizedBox(width: 12),
                  
                  // 最近动作列表
                  Expanded(
                    child: _RecentActionsList(execution: exec),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return '准备中...';
      case TaskStatus.running:
        return '执行中';
      case TaskStatus.paused:
        return '已暂停';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '执行失败';
    }
  }
  
  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.running:
        return Colors.greenAccent;
      case TaskStatus.paused:
        return Colors.orangeAccent;
      case TaskStatus.completed:
        return Colors.white;
      case TaskStatus.failed:
        return Colors.redAccent;
      default:
        return Colors.white.withOpacity(0.7);
    }
  }
}

/// 状态指示器
class _StatusIndicator extends StatelessWidget {
  final TaskStatus status;
  final AnimationController pulseController;
  
  const _StatusIndicator({
    required this.status,
    required this.pulseController,
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final scale = status == TaskStatus.running 
            ? 1.0 + (pulseController.value * 0.3)
            : 1.0;
        final opacity = status == TaskStatus.running 
            ? 0.5 + (pulseController.value * 0.5)
            : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getColor(),
                boxShadow: status == TaskStatus.running ? [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ] : null,
              ),
            ),
          ),
        );
      },
    );
  }
  
  Color _getColor() {
    switch (status) {
      case TaskStatus.running:
        return Colors.greenAccent;
      case TaskStatus.paused:
        return Colors.orangeAccent;
      case TaskStatus.completed:
        return Colors.white;
      case TaskStatus.failed:
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}

/// 控制按钮
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;
  
  const _ControlButton({
    required this.icon,
    this.onTap,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDestructive 
              ? Colors.redAccent 
              : Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }
}

/// 迷你手机预览
class _MiniPhonePreview extends StatelessWidget {
  final TaskExecution execution;
  
  const _MiniPhonePreview({required this.execution});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // 顶部刘海
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 屏幕区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: execution.isRunning
                    ? const _PulsingDot()
                    : Icon(
                        _getStatusIcon(),
                        size: 20,
                        color: Colors.white.withOpacity(0.4),
                      ),
              ),
            ),
          ),
          
          // 底部横条
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            width: 24,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
  
  IconData _getStatusIcon() {
    switch (execution.status) {
      case TaskStatus.completed:
        return Icons.check_rounded;
      case TaskStatus.failed:
        return Icons.close_rounded;
      case TaskStatus.paused:
        return Icons.pause_rounded;
      default:
        return Icons.phone_android_rounded;
    }
  }
}

/// 脉冲点动画
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8 + (_controller.value * 4),
          height: 8 + (_controller.value * 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.greenAccent.withOpacity(0.6 + (_controller.value * 0.4)),
          ),
        );
      },
    );
  }
}

/// 最近动作列表
class _RecentActionsList extends StatelessWidget {
  final TaskExecution execution;
  
  const _RecentActionsList({required this.execution});
  
  @override
  Widget build(BuildContext context) {
    final actions = execution.actions;
    if (actions.isEmpty) {
      return Text(
        '等待执行...',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.5),
        ),
      );
    }
    
    // 显示最近 3 个动作
    final recentActions = actions.length > 3 
        ? actions.sublist(actions.length - 3) 
        : actions;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: recentActions.map((action) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(
              action.icon,
              size: 14,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                action.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

/// 虚拟屏幕预览页面 - 全屏模拟手机视图
class VirtualScreenPreviewPage extends StatefulWidget {
  final TaskExecution execution;
  final Stream<ActionRecord>? actionStream;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  
  const VirtualScreenPreviewPage({
    super.key,
    required this.execution,
    this.actionStream,
    this.onPause,
    this.onResume,
    this.onStop,
  });
  
  @override
  State<VirtualScreenPreviewPage> createState() => _VirtualScreenPreviewPageState();
}

class _VirtualScreenPreviewPageState extends State<VirtualScreenPreviewPage> {
  int? _expandedActionIndex;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部控制栏
            _buildTopBar(),
            
            // 主内容区：左侧动作列表 + 右侧虚拟屏幕
            Expanded(
              child: Row(
                children: [
                  // 左侧动作列表面板
                  Container(
                    width: 280,
                    color: const Color(0xFF0D0D0D),
                    child: _buildActionsList(),
                  ),
                  
                  // 右侧虚拟屏幕预览
                  Expanded(
                    child: _buildVirtualScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // 标题和状态
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '任务执行',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.execution.currentStep} 步 · ${widget.execution.formattedDuration}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          
          // 控制按钮
          if (widget.execution.isRunning) ...[
            _TopBarButton(
              icon: Icons.pause_rounded,
              label: '暂停',
              onTap: widget.onPause,
            ),
            const SizedBox(width: 8),
            _TopBarButton(
              icon: Icons.stop_rounded,
              label: '停止',
              isDestructive: true,
              onTap: widget.onStop,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildActionsList() {
    final actions = widget.execution.actions;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '执行步骤',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
        
        // 动作列表
        Expanded(
          child: actions.isEmpty
              ? Center(
                  child: Text(
                    '等待执行...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: actions.length,
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    final isExpanded = _expandedActionIndex == index;
                    
                    return _ActionListItem(
                      action: action,
                      index: index + 1,
                      isExpanded: isExpanded,
                      isLast: index == actions.length - 1,
                      onTap: () {
                        setState(() {
                          _expandedActionIndex = isExpanded ? null : index;
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildVirtualScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AspectRatio(
          aspectRatio: 9 / 19, // 手机屏幕比例
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                // 顶部刘海区域
                Container(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 听筒
                      Container(
                        width: 60,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 屏幕内容区
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F0F),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildScreenContent(),
                  ),
                ),
                
                // 底部导航条
                Container(
                  padding: const EdgeInsets.only(bottom: 12, top: 8),
                  child: Container(
                    width: 100,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildScreenContent() {
    final exec = widget.execution;
    
    if (!exec.isRunning && exec.actions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phone_android_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              '等待任务开始',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }
    
    // 显示最后一个动作的状态
    final lastAction = exec.lastAction;
    
    return Stack(
      children: [
        // 背景占位
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 当前动作图标
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lastAction?.icon ?? Icons.auto_awesome_rounded,
                  size: 28,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              
              if (lastAction != null) ...[
                Text(
                  lastAction.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
              
              if (exec.isRunning) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // 状态指示
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: exec.isRunning 
                  ? Colors.green.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: exec.isRunning ? Colors.greenAccent : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  exec.isRunning ? 'LIVE' : 'DONE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: exec.isRunning 
                        ? Colors.greenAccent 
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 顶部栏按钮
class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;
  
  const _TopBarButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withOpacity(0.15)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDestructive ? Colors.redAccent : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.redAccent : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 动作列表项
class _ActionListItem extends StatelessWidget {
  final ActionRecord action;
  final int index;
  final bool isExpanded;
  final bool isLast;
  final VoidCallback onTap;
  
  const _ActionListItem({
    required this.action,
    required this.index,
    required this.isExpanded,
    required this.isLast,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isExpanded 
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isLast && !isExpanded
              ? Border.all(
                  color: Colors.greenAccent.withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 步骤编号
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isLast 
                        ? Colors.greenAccent.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isLast 
                            ? Colors.greenAccent 
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                
                // 动作图标
                Icon(
                  action.icon,
                  size: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                
                // 描述
                Expanded(
                  child: Text(
                    action.description,
                    maxLines: isExpanded ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                
                // 展开指示
                Icon(
                  isExpanded 
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
            
            // 展开内容：思考过程
            if (isExpanded && action.thinking != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          size: 14,
                          color: Colors.white.withOpacity(0.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI 思考',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      action.thinking!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
