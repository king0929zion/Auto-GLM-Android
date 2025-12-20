import 'dart:async';
import 'package:flutter/services.dart';
import '../../data/models/models.dart';

/// 设备控制服务
/// 通过Platform Channel与Android原生层通信，
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
  
  /// 坐标系统最大值（0-1000）
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
  
  /// 检查Shizuku是否已安装
  Future<bool> isShizukuInstalled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isShizukuInstalled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 检查Shizuku服务是否运行
  Future<bool> isShizukuRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isShizukuRunning');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 检查是否已获得Shizuku授权
  Future<bool> isShizukuAuthorized() async {
    try {
      final result = await _channel.invokeMethod<bool>('isShizukuAuthorized');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 请求Shizuku授权
  Future<bool> requestShizukuPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestShizukuPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 检查无障碍服务是否启用
  Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 打开无障碍服务设置页面
  Future<bool> openAccessibilitySettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAccessibilitySettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 检查悬浮窗权限
  Future<bool> checkOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkOverlayPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 打开悬浮窗设置页面
  Future<bool> openOverlaySettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openOverlaySettings');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 检查是否已忽略电池优化
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 请求忽略电池优化（加入白名单）
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 启动保活前台服务
  Future<bool> startKeepAliveService() async {
    try {
      final result = await _channel.invokeMethod<bool>('startKeepAliveService');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 停止保活前台服务
  Future<bool> stopKeepAliveService() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopKeepAliveService');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 检查AutoZi输入法是否已启用
  Future<bool> isAutoZiImeEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAutoZiImeEnabled');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 打开输入法设置页面
  Future<bool> openInputMethodSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openInputMethodSettings');
      return result ?? false;
    } on PlatformException {
      return false;
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
  /// [x], [y] 为相对坐标 (0-1000)
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
      // 输入新文本（原生侧会按"聚焦→清空→输入"的顺序处理，尽量对齐 Python 版）
      await _channel.invokeMethod('typeText', {'text': text});
      await Future.delayed(const Duration(milliseconds: 500));
      
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Type text failed: ${e.message}');
    }
  }
  
  /// 按下返回键
  Future<bool> pressBack({int delayMs = 1000}) async {
    try {
      await _channel.invokeMethod('pressBack', {'delay': delayMs});
      return true;
    } on PlatformException catch (e) {
      throw DeviceControlException('Press back failed: ${e.message}');
    }
  }
  
  /// 按下Home键
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
  
  /// 显示悬浮窗
  Future<bool> showFloatingWindow(String content) async {
    try {
      await _channel.invokeMethod('showFloatingWindow', {'content': content});
      return true;
    } on PlatformException {
      return false;
    }
  }
  
  /// 隐藏悬浮窗
  Future<bool> hideFloatingWindow() async {
    try {
      await _channel.invokeMethod('hideFloatingWindow');
      return true;
    } on PlatformException {
      return false;
    }
  }
  
  /// 更新运行指示器
  Future<bool> updateFloatingWindow(String content) async {
    try {
      await _channel.invokeMethod('updateFloatingWindow', {
        'content': content,
      });
      return true;
    } on PlatformException {
      return false;
    }
  }
  
  /// 显示Takeover弹窗
  Future<bool> showTakeover(String message) async {
    try {
      await _channel.invokeMethod('showTakeover', {'message': message});
      return true;
    } on PlatformException {
      return false;
    }
  }
  
  /// 隐藏Takeover弹窗
  Future<bool> hideTakeover() async {
    try {
      await _channel.invokeMethod('hideTakeover');
      return true;
    } on PlatformException {
      return false;
    }
  }
  
  // ========================================
  // 虚拟屏幕相关方法
  // ========================================
  
  /// 创建虚拟屏幕
  /// 返回虚拟屏幕的信息
  Future<VirtualScreenInfo?> createVirtualScreen() async {
    try {
      final result = await _channel.invokeMethod<Map>('createVirtualScreen');
      if (result == null) return null;
      
      return VirtualScreenInfo(
        displayId: result['displayId'] as int? ?? 0,
        width: result['width'] as int? ?? _screenWidth,
        height: result['height'] as int? ?? _screenHeight,
        density: result['density'] as int? ?? 420,
      );
    } on PlatformException {
      return null;
    }
  }
  
  /// 释放虚拟屏幕
  Future<bool> releaseVirtualScreen() async {
    try {
      final result = await _channel.invokeMethod<bool>('releaseVirtualScreen');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 获取虚拟屏幕最新帧
  Future<ScreenshotData> getVirtualScreenFrame() async {
    try {
      final result = await _channel.invokeMethod<Map>('getVirtualScreenFrame');
      
      if (result == null || (result['base64'] as String?)?.isEmpty == true) {
        return ScreenshotData.placeholder(
          width: _screenWidth,
          height: _screenHeight,
        );
      }
      
      return ScreenshotData(
        base64Data: result['base64'] as String? ?? '',
        width: result['width'] as int? ?? _screenWidth,
        height: result['height'] as int? ?? _screenHeight,
        isSensitive: false,
        timestamp: DateTime.now(),
      );
    } on PlatformException {
      return ScreenshotData.placeholder(
        width: _screenWidth,
        height: _screenHeight,
      );
    }
  }
  
  /// 在虚拟屏幕上启动应用
  Future<bool> launchAppOnVirtualScreen(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>('launchAppOnVirtualScreen', {
        'package': packageName,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
  
  /// 检查虚拟屏幕是否激活
  Future<bool> isVirtualScreenActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isVirtualScreenActive');
      return result ?? false;
    } on PlatformException {
      return false;
    }
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
