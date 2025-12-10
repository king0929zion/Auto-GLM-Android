import 'dart:async';
import 'package:flutter/services.dart';
import '../../data/models/models.dart';

/// 设备控制服务
/// 通过Platform Channel与Android原生层通信�?
/// 使用Shizuku/InputManager执行设备操作
class DeviceController {
  /// 平台通道名称
  static const String channelName = 'com.autoglm.mobile/device';
  
  /// 方法通道
  static const MethodChannel _channel = MethodChannel(channelName);
  
  /// 屏幕宽度
  int _screenWidth = 1080;
  
  /// 屏幕高度
  int _screenHeight = 2400;
  
  /// 坐标系统最大值（0-1000�?
  static const int coordinateMax = 1000;
  
  /// 获取屏幕宽度
  int get screenWidth => _screenWidth;
  
  /// 获取屏幕高度
  int get screenHeight => _screenHeight;

  /// 初始化设备控制器
  Future<void> initialize() async {
    try {
      final result = await _channel.invokeMethod<Map>('initialize');
      if (result != null) {
        _screenWidth = result['width'] as int? ?? 1080;
        _screenHeight = result['height'] as int? ?? 2400;
      }
    } on PlatformException catch (e) {
      throw DeviceControlException('Failed to initialize: ${e.message}');
    }
  }
  
  /// 获取截图
  Future<ScreenshotData> getScreenshot({int timeoutMs = 10000}) async {
    try {
      final result = await _channel.invokeMethod<Map>('getScreenshot', {
        'timeout': timeoutMs,
      });
      
      if (result == null) {
        return ScreenshotData.placeholder(
          width: _screenWidth,
          height: _screenHeight,
        );
      }
      
      return ScreenshotData(
        base64Data: result['base64'] as String? ?? '',
        width: result['width'] as int? ?? _screenWidth,
        height: result['height'] as int? ?? _screenHeight,
        isSensitive: result['isSensitive'] as bool? ?? false,
        timestamp: DateTime.now(),
      );
    } on PlatformException catch (e) {
      // 截图失败，返回占位图
      return ScreenshotData.placeholder(
        width: _screenWidth,
        height: _screenHeight,
        isSensitive: e.message?.contains('secure') ?? false,
      );
    }
  }
  
  /// 获取当前前台应用
  Future<String> getCurrentApp() async {
    try {
      final result = await _channel.invokeMethod<String>('getCurrentApp');
      return result ?? 'System Home';
    } on PlatformException {
      return 'System Home';
    }
  }
  
  /// 点击指定坐标
  /// [x], [y] 为相对坐�?(0-1000)
  Future<bool> tap(int x, int y, {int delayMs = 1000}) async {
    final absX = _convertToAbsolute(x, _screenWidth);
    final absY = _convertToAbsolute(y, _screenHeight);
    
    try {
      await _channel.invokeMethod('tap', {
        'x': absX,
        'y': absY,
        'delay': delayMs,
      });
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Tap failed: ${e.message}');
    }
  }
  
  /// 双击指定坐标
  Future<bool> doubleTap(int x, int y, {int delayMs = 1000}) async {
    final absX = _convertToAbsolute(x, _screenWidth);
    final absY = _convertToAbsolute(y, _screenHeight);
    
    try {
      await _channel.invokeMethod('doubleTap', {
        'x': absX,
        'y': absY,
        'delay': delayMs,
      });
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Double tap failed: ${e.message}');
    }
  }
  
  /// 长按指定坐标
  Future<bool> longPress(int x, int y, {
    int durationMs = 3000,
    int delayMs = 1000,
  }) async {
    final absX = _convertToAbsolute(x, _screenWidth);
    final absY = _convertToAbsolute(y, _screenHeight);
    
    try {
      await _channel.invokeMethod('longPress', {
        'x': absX,
        'y': absY,
        'duration': durationMs,
        'delay': delayMs,
      });
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Long press failed: ${e.message}');
    }
  }
  
  /// 滑动手势
  /// 所有坐标为相对坐标 (0-1000)
  Future<bool> swipe(
    int startX, int startY,
    int endX, int endY, {
    int? durationMs,
    int delayMs = 1000,
  }) async {
    final absStartX = _convertToAbsolute(startX, _screenWidth);
    final absStartY = _convertToAbsolute(startY, _screenHeight);
    final absEndX = _convertToAbsolute(endX, _screenWidth);
    final absEndY = _convertToAbsolute(endY, _screenHeight);
    
    // 如果未指定时长，根据距离计算
    final duration = durationMs ?? _calculateSwipeDuration(
      absStartX, absStartY, absEndX, absEndY,
    );
    
    try {
      await _channel.invokeMethod('swipe', {
        'startX': absStartX,
        'startY': absStartY,
        'endX': absEndX,
        'endY': absEndY,
        'duration': duration,
        'delay': delayMs,
      });
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Swipe failed: ${e.message}');
    }
  }
  
  /// 输入文本
  Future<bool> typeText(String text) async {
    try {
      // 先清除现有文�?
      await _channel.invokeMethod('clearText');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 输入新文�?
      await _channel.invokeMethod('typeText', {'text': text});
      await Future.delayed(const Duration(milliseconds: 500));
      
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Type text failed: ${e.message}');
    }
  }
  
  /// 按下返回�?
  Future<bool> pressBack({int delayMs = 1000}) async {
    try {
      await _channel.invokeMethod('pressBack', {'delay': delayMs});
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Press back failed: ${e.message}');
    }
  }
  
  /// 按下Home�?
  Future<bool> pressHome({int delayMs = 1000}) async {
    try {
      await _channel.invokeMethod('pressHome', {'delay': delayMs});
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Press home failed: ${e.message}');
    }
  }
  
  /// 启动应用
  Future<bool> launchApp(String packageName) async {
    try {
      await _channel.invokeMethod('launchApp', {'package': packageName});
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Launch app failed: ${e.message}');
    }
  }
  
  /// 将相对坐标转换为绝对坐标
  int _convertToAbsolute(int relative, int screenSize) {
    return (relative / coordinateMax * screenSize).round();
  }
  
  /// 计算滑动时长
  int _calculateSwipeDuration(int x1, int y1, int x2, int y2) {
    final distSq = (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
    final duration = (distSq / 1000).round();
    return duration.clamp(1000, 2000);
  }
  
  /// 释放资源
  void dispose() {
    // 清理资源
  }
}

/// 设备控制异常
class DeviceControlException implements Exception {
  final String message;
  
  const DeviceControlException(this.message);
  
  @override
  String toString() => 'DeviceControlException: $message';
}
