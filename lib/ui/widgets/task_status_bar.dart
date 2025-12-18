import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../data/models/models.dart';

/// 任务状态栏组件
class TaskStatusBar extends StatelessWidget {
  /// 任务信息
  final TaskInfo? task;
  
  /// 暂停回调
  final VoidCallback? onPause;
  
  /// 继续回调
  final VoidCallback? onResume;
  
  /// 取消回调
  final VoidCallback? onCancel;

  const TaskStatusBar({
    super.key,
    this.task,
    this.onPause,
    this.onResume,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (task == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.warmBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 任务标题和状态
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task!.task,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildStatusChip(),
                        const SizedBox(width: AppTheme.spacingSM),
                        Text(
                          '步骤 ${task!.currentStep}/${task!.maxSteps}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 控制按钮
              _buildControlButtons(),
            ],
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // 进度条
          _buildProgressBar(),
        ],
      ),
    );
  }
  
  Widget _buildStatusChip() {
    Color color;
    String text;
    IconData icon;
    
    switch (task!.status) {
      case TaskStatus.running:
        color = AppTheme.accentOrange;
        text = '执行中';
        icon = Icons.play_circle_outline;
        break;
      case TaskStatus.paused:
        color = AppTheme.warning;
        text = '已暂停';
        icon = Icons.pause_circle_outline;
        break;
      case TaskStatus.completed:
        color = AppTheme.success;
        text = '已完成';
        icon = Icons.check_circle_outline;
        break;
      case TaskStatus.failed:
        color = AppTheme.error;
        text = '失败';
        icon = Icons.error_outline;
        break;
      case TaskStatus.waitingConfirmation:
        color = AppTheme.warning;
        text = '待确认';
        icon = Icons.help_outline;
        break;
      case TaskStatus.waitingTakeover:
        color = AppTheme.info;
        text = '需接管';
        icon = Icons.pan_tool_alt_outlined;
        break;
      default:
        color = AppTheme.textHint;
        text = '空闲';
        icon = Icons.radio_button_unchecked;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButtons() {
    if (task!.isFinished) {
      return const SizedBox.shrink();
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 暂停/继续按钮
        if (task!.status == TaskStatus.running && onPause != null)
          IconButton(
            onPressed: onPause,
            icon: const Icon(Icons.pause_circle_filled),
            color: AppTheme.warning,
            tooltip: '暂停',
          )
        else if (task!.status == TaskStatus.paused && onResume != null)
          IconButton(
            onPressed: onResume,
            icon: const Icon(Icons.play_circle_filled),
            color: AppTheme.success,
            tooltip: '继续',
          ),
        
        // 取消按钮
        if (onCancel != null)
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel),
            color: AppTheme.error,
            tooltip: '取消',
          ),
      ],
    );
  }
  
  Widget _buildProgressBar() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: task!.isRunning ? null : task!.progress,
            backgroundColor: AppTheme.secondaryBeige,
            valueColor: AlwaysStoppedAnimation<Color>(
              task!.isFinished 
                ? (task!.status == TaskStatus.completed 
                    ? AppTheme.success 
                    : AppTheme.error)
                : AppTheme.accentOrange,
            ),
            minHeight: 6,
          ),
        ),
        
        // 时间信息
        if (task!.duration != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '耗时: ${_formatDuration(task!.duration!)}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textHint,
                ),
              ),
              if (task!.resultMessage != null)
                Flexible(
                  child: Text(
                    task!.resultMessage!,
                    style: TextStyle(
                      fontSize: 11,
                      color: task!.status == TaskStatus.completed
                        ? AppTheme.success
                        : AppTheme.error,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}分${seconds}秒';
  }
}
