import 'package:flutter/material.dart';
import '../../data/repositories/task_history_repository.dart';
import '../../data/models/task_info.dart';
import '../theme/app_theme.dart';

/// 任务历史页面
class TaskHistoryPage extends StatefulWidget {
  const TaskHistoryPage({super.key});

  @override
  State<TaskHistoryPage> createState() => _TaskHistoryPageState();
}

class _TaskHistoryPageState extends State<TaskHistoryPage> {
  List<TaskHistory> _histories = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, success, failed

  @override
  void initState() {
    super.initState();
    _loadHistories();
  }

  Future<void> _loadHistories() async {
    await TaskHistoryRepository.instance.init();
    setState(() {
      _histories = TaskHistoryRepository.instance.getAll();
      _isLoading = false;
    });
  }

  List<TaskHistory> get _filteredHistories {
    switch (_filter) {
      case 'success':
        return _histories.where((h) => h.isSuccess).toList();
      case 'failed':
        return _histories.where((h) => !h.isSuccess).toList();
      default:
        return _histories;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.grey50,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.grey900),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '任务历史',
          style: TextStyle(
            color: AppTheme.grey900,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_histories.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.grey500),
              onPressed: _showClearConfirmDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // 筛选栏
          _buildFilterBar(),
          
          // 历史列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredHistories.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.white,
      child: Row(
        children: [
          _FilterChip(
            label: '全部',
            isSelected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '成功',
            isSelected: _filter == 'success',
            onTap: () => setState(() => _filter = 'success'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '失败',
            isSelected: _filter == 'failed',
            onTap: () => setState(() => _filter = 'failed'),
          ),
          const Spacer(),
          Text(
            '${_filteredHistories.length} 条记录',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.grey100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 40,
              color: AppTheme.grey400,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无历史记录',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.grey500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '执行的任务会显示在这里',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.grey400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredHistories.length,
      itemBuilder: (context, index) {
        final history = _filteredHistories[index];
        return _HistoryCard(
          history: history,
          onTap: () => _showHistoryDetail(history),
          onDelete: () => _deleteHistory(history),
        );
      },
    );
  }

  void _showHistoryDetail(TaskHistory history) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HistoryDetailSheet(history: history),
    );
  }

  Future<void> _deleteHistory(TaskHistory history) async {
    await TaskHistoryRepository.instance.delete(history.id);
    _loadHistories();
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有任务历史吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await TaskHistoryRepository.instance.clear();
              _loadHistories();
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 筛选芯片
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.grey900 : AppTheme.grey100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppTheme.white : AppTheme.grey600,
          ),
        ),
      ),
    );
  }
}

/// 历史记录卡片
class _HistoryCard extends StatelessWidget {
  final TaskHistory history;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.history,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 状态图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: history.isSuccess
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    history.isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: history.isSuccess ? Colors.green : Colors.red,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                
                // 任务描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        history.taskDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.grey900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${history.formattedDate} · ${history.stepCount}步 · ${history.formattedDuration}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.grey400,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 删除按钮
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.grey300,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            
            // 错误信息
            if (!history.isSuccess && history.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        history.errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
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

/// 历史详情底部弹窗
class _HistoryDetailSheet extends StatelessWidget {
  final TaskHistory history;

  const _HistoryDetailSheet({required this.history});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 拖动指示条
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 标题
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: history.isSuccess
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            history.isSuccess ? '成功' : '失败',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: history.isSuccess ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          history.formattedDate,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.grey400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      history.taskDescription,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grey900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '执行了 ${history.stepCount} 步，耗时 ${history.formattedDuration}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.grey500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1),
              
              // 步骤列表
              Expanded(
                child: history.steps.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无步骤详情',
                          style: TextStyle(color: AppTheme.grey400),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: history.steps.length,
                        itemBuilder: (context, index) {
                          final step = history.steps[index];
                          return _StepItem(
                            step: step,
                            index: index + 1,
                            isLast: index == history.steps.length - 1,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 步骤项
class _StepItem extends StatelessWidget {
  final TaskHistoryStep step;
  final int index;
  final bool isLast;

  const _StepItem({
    required this.step,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间线
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: step.isSuccess
                    ? AppTheme.grey900
                    : Colors.red.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: step.isSuccess ? AppTheme.white : Colors.red,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: AppTheme.grey200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        
        // 内容
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grey900,
                  ),
                ),
                if (step.thinking != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.grey50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.psychology_rounded,
                          size: 14,
                          color: AppTheme.grey400,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            step.thinking!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.grey500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
