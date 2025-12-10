import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../config/settings_repository.dart';

/// 任务历史页面
class TaskHistoryPage extends StatefulWidget {
  /// 选择任务的回�?
  final void Function(String task)? onTaskSelected;
  
  const TaskHistoryPage({super.key, this.onTaskSelected});

  @override
  State<TaskHistoryPage> createState() => _TaskHistoryPageState();
}

class _TaskHistoryPageState extends State<TaskHistoryPage> {
  late List<String> _history;
  
  @override
  void initState() {
    super.initState();
    _loadHistory();
  }
  
  void _loadHistory() {
    _history = SettingsRepository.instance.taskHistory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('任务历史'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmClear,
              tooltip: '清除历史',
            ),
        ],
      ),
      body: _history.isEmpty
          ? _buildEmptyState()
          : _buildHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          const Text(
            '暂无任务历史',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          const Text(
            '执行任务后会自动保存',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final task = _history[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
          child: Dismissible(
            key: Key(task),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _removeTask(index),
            child: _buildTaskCard(task, index),
          ),
        );
      },
    );
  }

  Widget _buildTaskCard(String task, int index) {
    return Material(
      color: AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: InkWell(
        onTap: () {
          if (widget.onTaskSelected != null) {
            widget.onTaskSelected!(task);
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              // 序号
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBeige,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentOrangeDeep,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              
              // 任务内容
              Expanded(
                child: Text(
                  task,
                  style: const TextStyle(fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // 箭头
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeTask(int index) async {
    final removedTask = _history[index];
    setState(() {
      _history.removeAt(index);
    });
    
    // 更新存储
    final prefs = SettingsRepository.instance;
    await prefs.clearTaskHistory();
    for (final task in _history.reversed) {
      await prefs.addTaskToHistory(task);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已删�?),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              setState(() {
                _history.insert(index, removedTask);
              });
              prefs.addTaskToHistory(removedTask);
            },
          ),
        ),
      );
    }
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除历史'),
        content: const Text('确定要清除所有任务历史吗�?),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await SettingsRepository.instance.clearTaskHistory();
              setState(() {
                _history.clear();
              });
              if (mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }
}
