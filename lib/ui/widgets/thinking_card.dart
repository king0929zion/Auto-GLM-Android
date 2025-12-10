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
        boxShadow: AppTheme.cardShadow,
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
            const Divider(height: 1, color: AppTheme.warmBeige),
            _buildThinkingContent(),
            
            // 动作信息
            if (widget.action != null) ...[
              const Divider(height: 1, color: AppTheme.warmBeige),
              _buildActionContent(),
            ],
          ],
        ],
      ),
    );
  }
  
  Color _getBorderColor() {
    if (widget.isExecuting) return AppTheme.accentOrange;
    if (widget.isSuccess == true) return AppTheme.success;
    if (widget.isSuccess == false) return AppTheme.error;
    return AppTheme.warmBeige;
  }
  
  Widget _buildHeader() {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Row(
          children: [
            // 步骤标识
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _getStepColor(),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: widget.isExecuting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '${widget.stepNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
            
            const SizedBox(width: AppTheme.spacingSM),
            
            // 标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isExecuting ? '思考中...' : '思考过程',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (widget.action != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '动作: ${widget.action!.actionName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
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
              color: AppTheme.textHint,
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getStepColor() {
    if (widget.isExecuting) return AppTheme.accentOrange;
    if (widget.isSuccess == true) return AppTheme.success;
    if (widget.isSuccess == false) return AppTheme.error;
    return AppTheme.accentOrangeDeep;
  }
  
  Widget _buildThinkingContent() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 16,
                color: AppTheme.accentOrange,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                '💭 思考',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: AppTheme.primaryBeige,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: SelectableText(
              widget.thinking.isEmpty ? '...' : widget.thinking,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionContent() {
    final action = widget.action!;
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app,
                size: 16,
                color: AppTheme.accentOrangeDeep,
              ),
              const SizedBox(width: AppTheme.spacingXS),
              Text(
                '🎯 动作',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: SelectableText(
              action.toJsonString(),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
