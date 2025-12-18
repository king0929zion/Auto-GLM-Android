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
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
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
            if (widget.thinking.isNotEmpty)
              _buildThinkingContent(),
            
            if (widget.action != null)
              _buildActionContent(),
          ],
        ],
      ),
    );
  }
  
  Color _getBorderColor() {
    if (widget.isExecuting) return AppTheme.primaryBlack;
    if (widget.isSuccess == false) return AppTheme.error.withOpacity(0.3);
    return AppTheme.grey200;
  }
  
  Widget _buildHeader() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            // 步骤标识
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _getStepColor(),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: widget.isExecuting
                ? const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '${widget.stepNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
                  Row(
                    children: [
                      Text(
                        widget.isExecuting ? 'Thinking...' : 'Action',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (widget.isSuccess == false)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                             '失败',
                             style: TextStyle(fontSize: 10, color: AppTheme.error),
                          ),
                        ),
                    ],
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
    if (widget.isSuccess == false) return AppTheme.error;
    if (widget.isSuccess == true) return AppTheme.primaryBlack; // Success is also black
    return AppTheme.grey300; // History items
  }
  
  Widget _buildThinkingContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          SelectableText(
            widget.thinking,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionContent() {
    final action = widget.action!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.grey50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.grey100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 const Text(
                  'PARAMETERS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textHint,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  action.toJsonString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
