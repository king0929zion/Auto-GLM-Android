import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 任务输入框组�?
class TaskInputField extends StatefulWidget {
  /// 输入控制�?
  final TextEditingController? controller;
  
  /// 提交回调
  final void Function(String task)? onSubmit;
  
  /// 是否禁用
  final bool disabled;
  
  /// 提示文本
  final String hintText;
  
  /// 是否正在加载
  final bool isLoading;

  const TaskInputField({
    super.key,
    this.controller,
    this.onSubmit,
    this.disabled = false,
    this.hintText = '描述你想要完成的任务...',
    this.isLoading = false,
  });

  @override
  State<TaskInputField> createState() => _TaskInputFieldState();
}

class _TaskInputFieldState extends State<TaskInputField> {
  late TextEditingController _controller;
  bool _hasText = false;
  
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _hasText = _controller.text.isNotEmpty;
  }
  
  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }
  
  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }
  
  void _handleSubmit() {
    if (widget.disabled || !_hasText || widget.isLoading) return;
    
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSubmit?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 输入区域
          TextField(
            controller: _controller,
            enabled: !widget.disabled,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                color: AppTheme.textHint,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(AppTheme.spacingMD),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSubmit(),
          ),
          
          // 底部工具�?
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingSM,
              vertical: AppTheme.spacingSM,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppTheme.warmBeige,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // 语音输入按钮
                IconButton(
                  onPressed: widget.disabled ? null : _showVoiceInput,
                  icon: Icon(
                    Icons.mic_outlined,
                    color: widget.disabled 
                      ? AppTheme.textHint 
                      : AppTheme.textSecondary,
                  ),
                  tooltip: '语音输入',
                ),
                
                // 示例任务按钮
                IconButton(
                  onPressed: widget.disabled ? null : _showExamples,
                  icon: Icon(
                    Icons.lightbulb_outline,
                    color: widget.disabled 
                      ? AppTheme.textHint 
                      : AppTheme.textSecondary,
                  ),
                  tooltip: '任务示例',
                ),
                
                const Spacer(),
                
                // 发送按�?
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: widget.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.accentOrange,
                          ),
                        ),
                      )
                    : IconButton(
                        onPressed: (_hasText && !widget.disabled)
                          ? _handleSubmit
                          : null,
                        icon: Icon(
                          Icons.send_rounded,
                          color: (_hasText && !widget.disabled)
                            ? AppTheme.accentOrange
                            : AppTheme.textHint,
                        ),
                        tooltip: '开始执�?,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showVoiceInput() {
    // TODO: 实现语音输入
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('语音输入功能即将推出')),
    );
  }
  
  void _showExamples() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaskExamplesSheet(
        onSelect: (example) {
          _controller.text = example;
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// 任务示例弹窗
class _TaskExamplesSheet extends StatelessWidget {
  final void Function(String example) onSelect;
  
  const _TaskExamplesSheet({required this.onSelect});
  
  static const List<String> examples = [
    '打开微信，给张三发一条消息说"明天�?',
    '打开淘宝，搜�?蓝牙耳机"，筛选价�?00-200�?,
    '打开美团，点一份附近的麻辣烫外�?,
    '打开高德地图，导航到最近的星巴�?,
    '打开抖音，搜索并关注"官方账号"',
    '打开设置，打开WiFi并连接家里的网络',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动�?
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.warmBeige,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            child: Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.accentOrange,
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  '任务示例',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // 示例列表
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
              ),
              itemCount: examples.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    examples[index],
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textHint,
                  ),
                  onTap: () => onSelect(examples[index]),
                );
              },
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom + AppTheme.spacingMD),
        ],
      ),
    );
  }
}
