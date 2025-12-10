import 'dart:async';
import '../../data/models/models.dart';
import '../../config/apps.dart';
import '../device/device_controller.dart';

/// 动作执行结果
class ActionResult {
  /// 是否成功
  final bool success;
  
  /// 是否应该结束任务
  final bool shouldFinish;
  
  /// 结果消息
  final String? message;
  
  /// 是否需要确�?
  final bool requiresConfirmation;

  const ActionResult({
    required this.success,
    required this.shouldFinish,
    this.message,
    this.requiresConfirmation = false,
  });
}

/// 动作处理�?
/// 负责将AI模型输出的动作转换为实际的设备操�?
class ActionHandler {
  /// 设备控制�?
  final DeviceController deviceController;
  
  /// 敏感操作确认回调
  final Future<bool> Function(String message)? confirmationCallback;
  
  /// 接管请求回调
  final Future<void> Function(String message)? takeoverCallback;

  ActionHandler({
    required this.deviceController,
    this.confirmationCallback,
    this.takeoverCallback,
  });

  /// 执行动作
  Future<ActionResult> execute(ActionData action) async {
    // 处理结束动作
    if (action.isFinish) {
      return ActionResult(
        success: true,
        shouldFinish: true,
        message: action.message,
      );
    }
    
    // 不是do动作
    if (!action.isDo) {
      return ActionResult(
        success: false,
        shouldFinish: true,
        message: 'Unknown action type: ${action.metadata}',
      );
    }
    
    // 根据动作类型执行
    try {
      switch (action.type) {
        case ActionType.launch:
          return await _handleLaunch(action);
        case ActionType.tap:
          return await _handleTap(action);
        case ActionType.type:
        case ActionType.typeName:
          return await _handleType(action);
        case ActionType.swipe:
          return await _handleSwipe(action);
        case ActionType.back:
          return await _handleBack(action);
        case ActionType.home:
          return await _handleHome(action);
        case ActionType.doubleTap:
          return await _handleDoubleTap(action);
        case ActionType.longPress:
          return await _handleLongPress(action);
        case ActionType.wait:
          return await _handleWait(action);
        case ActionType.takeOver:
          return await _handleTakeover(action);
        case ActionType.note:
          return _handleNote(action);
        case ActionType.callApi:
          return _handleCallApi(action);
        case ActionType.interact:
          return _handleInteract(action);
        default:
          return ActionResult(
            success: false,
            shouldFinish: false,
            message: 'Unknown action: ${action.actionName}',
          );
      }
    } catch (e) {
      return ActionResult(
        success: false,
        shouldFinish: false,
        message: 'Action failed: $e',
      );
    }
  }

  /// 处理启动应用
  Future<ActionResult> _handleLaunch(ActionData action) async {
    final appName = action.app;
    if (appName == null || appName.isEmpty) {
      return const ActionResult(
        success: false,
        shouldFinish: false,
        message: 'No app name specified',
      );
    }
    
    // 获取包名
    final packageName = AppPackages.getPackageName(appName);
    if (packageName == null) {
      return ActionResult(
        success: false,
        shouldFinish: false,
        message: 'App not found: $appName',
      );
    }
    
    await deviceController.launchApp(packageName);
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理点击
  Future<ActionResult> _handleTap(ActionData action) async {
    final element = action.element;
    if (element == null || element.length < 2) {
      return const ActionResult(
        success: false,
        shouldFinish: false,
        message: 'No element coordinates',
      );
    }
    
    // 检查敏感操�?
    if (action.isSensitive && action.message != null) {
      if (confirmationCallback != null) {
        final confirmed = await confirmationCallback!(action.message!);
        if (!confirmed) {
          return const ActionResult(
            success: false,
            shouldFinish: true,
            message: 'User cancelled sensitive operation',
          );
        }
      }
    }
    
    await deviceController.tap(element[0], element[1]);
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理输入
  Future<ActionResult> _handleType(ActionData action) async {
    final text = action.text ?? '';
    await deviceController.typeText(text);
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理滑动
  Future<ActionResult> _handleSwipe(ActionData action) async {
    final start = action.start;
    final end = action.end;
    
    if (start == null || start.length < 2 ||
        end == null || end.length < 2) {
      return const ActionResult(
        success: false,
        shouldFinish: false,
        message: 'Missing swipe coordinates',
      );
    }
    
    await deviceController.swipe(
      start[0], start[1],
      end[0], end[1],
    );
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理返回
  Future<ActionResult> _handleBack(ActionData action) async {
    await deviceController.pressBack();
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理返回主页
  Future<ActionResult> _handleHome(ActionData action) async {
    await deviceController.pressHome();
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理双击
  Future<ActionResult> _handleDoubleTap(ActionData action) async {
    final element = action.element;
    if (element == null || element.length < 2) {
      return const ActionResult(
        success: false,
        shouldFinish: false,
        message: 'No element coordinates',
      );
    }
    
    await deviceController.doubleTap(element[0], element[1]);
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理长按
  Future<ActionResult> _handleLongPress(ActionData action) async {
    final element = action.element;
    if (element == null || element.length < 2) {
      return const ActionResult(
        success: false,
        shouldFinish: false,
        message: 'No element coordinates',
      );
    }
    
    await deviceController.longPress(element[0], element[1]);
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理等待
  Future<ActionResult> _handleWait(ActionData action) async {
    final durationStr = action.duration ?? '1 seconds';
    
    // 解析等待时长
    final match = RegExp(r'(\d+)').firstMatch(durationStr);
    final seconds = match != null ? int.parse(match.group(1)!) : 1;
    
    await Future.delayed(Duration(seconds: seconds));
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理接管请求
  Future<ActionResult> _handleTakeover(ActionData action) async {
    final message = action.message ?? 'User intervention required';
    
    if (takeoverCallback != null) {
      await takeoverCallback!(message);
    }
    
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理Note动作
  ActionResult _handleNote(ActionData action) {
    // 记录页面内容，实际实现取决于具体需�?
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理Call_API动作
  ActionResult _handleCallApi(ActionData action) {
    // 总结或评论内容，实际实现取决于具体需�?
    return const ActionResult(success: true, shouldFinish: false);
  }

  /// 处理交互请求
  ActionResult _handleInteract(ActionData action) {
    return const ActionResult(
      success: true,
      shouldFinish: false,
      message: 'User interaction required',
    );
  }
}
