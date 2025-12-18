import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../data/models/models.dart';

/// 思考过程卡片组件
class ThinkingCard extends StatefulWidget {
  /// 思考内容
  final String thinking;
  
  /// 动作数据
  final ActionData? action;
  
  /// 步骤编号
  final int stepNumber;
  
  /// 是否正在执行
  final bool isExecuting;
  
  /// 是否成功
  final bool? isSuccess;

  const ThinkingCard({
    super.key,
    required this.thinking,
    this.action,
    this.stepNumber = 0,
    this.isExecuting = false,
    this.isSuccess,
  });

  @override
  State<ThinkingCard> createState() => _ThinkingCardState();
}

class _ThinkingCardState extends State<ThinkingCard> 
    with SingleTickerProviderStateMixin {
  bool _isExpanded = true;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          _buildHeader(),
          
          // 思考内容
          if (_isExpanded) ...[
            _buildThinkingContent(),
            
            // 动作信息
            if (widget.action != null) ...[
              _buildActionContent(),
            ],
          ],
        ],
      ),
    );
  }
  
  Color _getBorderColor() {
    if (widget.isExecuting) return AppTheme.primaryBlack;
    if (widget.isSuccess == false) return AppTheme.error.withOpacity(0.5);
    return AppTheme.grey200;
  }
  
  Widget _buildHeader() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 步骤标识
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getStepColor(),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: widget.isExecuting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '${widget.stepNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
            
            const SizedBox(width: 12),
            
            // 标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isExecuting ? 'Agent 思考中...' : 'Agent 动作',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (widget.action != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.action!.actionName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 展开/收起图标
            Icon(
              _isExpanded 
                ? Icons.keyboard_arrow_up 
                : Icons.keyboard_arrow_down,
              color: AppTheme.grey400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStepColor() {
    if (widget.isExecuting) return AppTheme.primaryBlack;
    if (widget.isSuccess == true) return AppTheme.success;
    if (widget.isSuccess == false) return AppTheme.error;
    return AppTheme.grey400; // Grey for history items
  }
  
  Widget _buildThinkingContent() {
    if (widget.thinking.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.grey100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt, size: 14, color: AppTheme.grey600),
              const SizedBox(width: 6),
              const Text(
                '思考逻辑',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            widget.thinking,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildActionContent() {
    final action = widget.action!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.grey100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal, size: 14, color: AppTheme.grey600),
              const SizedBox(width: 6),
              const Text(
                '参数详情',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grey600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              action.toJsonString(),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
