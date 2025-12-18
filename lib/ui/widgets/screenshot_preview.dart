import 'package:flutter/material.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

/// 截图预览卡片组件
class ScreenshotPreview extends StatelessWidget {
  /// Base64编码的截图数据
  final String? base64Data;
  
  /// 截图宽度
  final int? width;
  
  /// 截图高度
  final int? height;
  
  /// 是否正在加载
  final bool isLoading;
  
  /// 加载进度（0-1）
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
          color: AppTheme.grey50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grey200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11), // 略小于外边框
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
      color: AppTheme.grey50,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_android,
            size: 48,
            color: AppTheme.grey300,
          ),
          SizedBox(height: 12),
          Text(
            '等待截图...',
            style: TextStyle(
              color: AppTheme.textHint,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  value: loadingProgress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '执行中...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric( horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          stepInfo!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
