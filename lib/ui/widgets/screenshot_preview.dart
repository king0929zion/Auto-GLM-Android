import 'package:flutter/material.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

/// 截图预览卡片组件
class ScreenshotPreview extends StatelessWidget {
  /// Base64编码的截图数�?
  final String? base64Data;
  
  /// 截图宽度
  final int? width;
  
  /// 截图高度
  final int? height;
  
  /// 是否正在加载
  final bool isLoading;
  
  /// 加载进度�?-1�?
  final double? loadingProgress;
  
  /// 当前步骤信息
  final String? stepInfo;
  
  /// 点击回调
  final VoidCallback? onTap;

  const ScreenshotPreview({
    super.key,
    this.base64Data,
    this.width,
    this.height,
    this.isLoading = false,
    this.loadingProgress,
    this.stepInfo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Stack(
            children: [
              // 截图内容
              _buildContent(context),
              
              // 加载遮罩
              if (isLoading) _buildLoadingOverlay(context),
              
              // 步骤信息
              if (stepInfo != null) _buildStepBadge(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildContent(BuildContext context) {
    if (base64Data == null || base64Data!.isEmpty) {
      return _buildPlaceholder(context);
    }
    
    try {
      return Image.memory(
        base64Decode(base64Data!),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(context);
        },
      );
    } catch (e) {
      return _buildPlaceholder(context);
    }
  }
  
  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      color: AppTheme.backgroundGrey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_android,
            size: 64,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: AppTheme.spacingMD),
          Text(
            '等待截图...',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  value: loadingProgress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.accentOrange,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                '执行�?..',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStepBadge(BuildContext context) {
    return Positioned(
      top: AppTheme.spacingSM,
      left: AppTheme.spacingSM,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSM,
          vertical: AppTheme.spacingXS,
        ),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Text(
          stepInfo!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
