import 'dart:convert';

/// 动作类型枚举
enum ActionType {
  launch,
  tap,
  type,
  typeName,
  swipe,
  back,
  home,
  doubleTap,
  longPress,
  wait,
  takeOver,
  note,
  callApi,
  interact,
  finish,
  unknown,
}

/// 动作数据�?
class ActionData {
  /// 动作类型
  final ActionType type;
  
  /// 原始动作名称
  final String actionName;
  
  /// 应用名称（用于Launch�?
  final String? app;
  
  /// 元素坐标 [x, y]（用于Tap、DoubleTap、LongPress�?
  final List<int>? element;
  
  /// 文本内容（用于Type�?
  final String? text;
  
  /// 起始坐标 [x, y]（用于Swipe�?
  final List<int>? start;
  
  /// 结束坐标 [x, y]（用于Swipe�?
  final List<int>? end;
  
  /// 等待时长（用于Wait�?
  final String? duration;
  
  /// 消息内容
  final String? message;
  
  /// 指令内容（用于Call_API�?
  final String? instruction;
  
  /// 是否为敏感操�?
  final bool isSensitive;
  
  /// 元数据标�?
  final String? metadata;

  const ActionData({
    required this.type,
    required this.actionName,
    this.app,
    this.element,
    this.text,
    this.start,
    this.end,
    this.duration,
    this.message,
    this.instruction,
    this.isSensitive = false,
    this.metadata,
  });
  
  /// 从模型响应解析动�?
  factory ActionData.parse(String response) {
    final trimmed = response.trim();
    
    // 解析 finish 动作
    if (trimmed.startsWith('finish')) {
      final msgMatch = RegExp(r'message=["' "'" r'](.+?)["' "'" r']').firstMatch(trimmed);
      return ActionData(
        type: ActionType.finish,
        actionName: 'finish',
        message: msgMatch?.group(1),
        metadata: 'finish',
      );
    }
    
    // 解析 do 动作
    if (trimmed.startsWith('do')) {
      return _parseDoAction(trimmed);
    }
    
    // 无法解析，返回finish
    return ActionData(
      type: ActionType.finish,
      actionName: 'finish',
      message: response,
      metadata: 'finish',
    );
  }
  
  /// 提取字符串参数的辅助方法
  static String? _extractStringParam(String response, String paramName) {
    // 尝试双引�?
    var pattern = RegExp(paramName + r'="([^"]*)"');
    var match = pattern.firstMatch(response);
    if (match != null) return match.group(1);
    
    // 尝试单引�?
    pattern = RegExp(paramName + r"='([^']*)'");
    match = pattern.firstMatch(response);
    if (match != null) return match.group(1);
    
    return null;
  }
  
  /// 解析do动作
  static ActionData _parseDoAction(String response) {
    // 提取action参数
    final actionName = _extractStringParam(response, 'action');
    if (actionName == null) {
      return ActionData(
        type: ActionType.unknown,
        actionName: 'unknown',
        message: 'Failed to parse action',
        metadata: 'do',
      );
    }
    
    final type = _parseActionType(actionName);
    
    // 提取各种参数
    final app = _extractStringParam(response, 'app');
    final text = _extractStringParam(response, 'text');
    final message = _extractStringParam(response, 'message');
    final duration = _extractStringParam(response, 'duration');
    final instruction = _extractStringParam(response, 'instruction');
    
    // 提取坐标
    final elementMatch = RegExp(r'element=\[(\d+),\s*(\d+)\]').firstMatch(response);
    final startMatch = RegExp(r'start=\[(\d+),\s*(\d+)\]').firstMatch(response);
    final endMatch = RegExp(r'end=\[(\d+),\s*(\d+)\]').firstMatch(response);
    
    List<int>? parseCoord(RegExpMatch? match) {
      if (match == null) return null;
      return [int.parse(match.group(1)!), int.parse(match.group(2)!)];
    }
    
    return ActionData(
      type: type,
      actionName: actionName,
      app: app,
      text: text,
      message: message,
      duration: duration,
      instruction: instruction,
      element: parseCoord(elementMatch),
      start: parseCoord(startMatch),
      end: parseCoord(endMatch),
      isSensitive: message != null && type == ActionType.tap,
      metadata: 'do',
    );
  }
  
  /// 解析动作类型
  static ActionType _parseActionType(String actionName) {
    switch (actionName) {
      case 'Launch':
        return ActionType.launch;
      case 'Tap':
        return ActionType.tap;
      case 'Type':
        return ActionType.type;
      case 'Type_Name':
        return ActionType.typeName;
      case 'Swipe':
        return ActionType.swipe;
      case 'Back':
        return ActionType.back;
      case 'Home':
        return ActionType.home;
      case 'Double Tap':
        return ActionType.doubleTap;
      case 'Long Press':
        return ActionType.longPress;
      case 'Wait':
        return ActionType.wait;
      case 'Take_over':
        return ActionType.takeOver;
      case 'Note':
        return ActionType.note;
      case 'Call_API':
        return ActionType.callApi;
      case 'Interact':
        return ActionType.interact;
      default:
        return ActionType.unknown;
    }
  }
  
  /// 是否为结束动�?
  bool get isFinish => type == ActionType.finish;
  
  /// 是否为do动作
  bool get isDo => metadata == 'do';
  
  /// 转换为JSON字符串表�?
  String toJsonString() {
    final map = <String, dynamic>{
      'action': actionName,
    };
    
    if (app != null) map['app'] = app;
    if (element != null) map['element'] = element;
    if (text != null) map['text'] = text;
    if (start != null) map['start'] = start;
    if (end != null) map['end'] = end;
    if (duration != null) map['duration'] = duration;
    if (message != null) map['message'] = message;
    if (instruction != null) map['instruction'] = instruction;
    
    return const JsonEncoder.withIndent('  ').convert(map);
  }
  
  @override
  String toString() {
    return 'ActionData(type: $type, name: $actionName)';
  }
}
