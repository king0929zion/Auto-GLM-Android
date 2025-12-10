import 'dart:typed_data';
import 'dart:convert';

/// 截图数据�?
class ScreenshotData {
  /// Base64编码的图片数�?
  final String base64Data;
  
  /// 屏幕宽度
  final int width;
  
  /// 屏幕高度
  final int height;
  
  /// 是否为敏感页面（如支付页面导致截图失败）
  final bool isSensitive;
  
  /// 截图时间�?
  final DateTime timestamp;

  const ScreenshotData({
    required this.base64Data,
    required this.width,
    required this.height,
    this.isSensitive = false,
    required this.timestamp,
  });
  
  /// 从字节数据创�?
  factory ScreenshotData.fromBytes({
    required Uint8List bytes,
    required int width,
    required int height,
    bool isSensitive = false,
  }) {
    return ScreenshotData(
      base64Data: base64Encode(bytes),
      width: width,
      height: height,
      isSensitive: isSensitive,
      timestamp: DateTime.now(),
    );
  }
  
  /// 创建黑色占位图（用于截图失败时）
  factory ScreenshotData.placeholder({
    int width = 1080,
    int height = 2400,
    bool isSensitive = false,
  }) {
    // 创建一个极简的黑色PNG
    // 实际应用中应该生成真正的黑色图片
    return ScreenshotData(
      base64Data: '',
      width: width,
      height: height,
      isSensitive: isSensitive,
      timestamp: DateTime.now(),
    );
  }
  
  /// 获取字节数据
  Uint8List get bytes => base64Decode(base64Data);
  
  /// 获取data URL格式
  String get dataUrl => 'data:image/png;base64,$base64Data';
  
  /// 复制并修�?
  ScreenshotData copyWith({
    String? base64Data,
    int? width,
    int? height,
    bool? isSensitive,
    DateTime? timestamp,
  }) {
    return ScreenshotData(
      base64Data: base64Data ?? this.base64Data,
      width: width ?? this.width,
      height: height ?? this.height,
      isSensitive: isSensitive ?? this.isSensitive,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
