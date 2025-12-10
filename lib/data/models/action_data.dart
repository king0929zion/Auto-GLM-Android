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

/// 动作数据类
class ActionData {
  /// 动作类型
  final ActionType type;
  
  /// 原始动作名称
  final String actionName;
  
  /// 应用名称（用于Launch）
  final String? app;
  
  /// 元素坐标 [x, y]（用于Tap、DoubleTap、LongPress）
  final List<int>? element;
  
  /// 文本内容（用于Type）
  final String? text;
  
  /// 起始坐标 [x, y]（用于Swipe）
  final List<int>? start;
  
  /// 结束坐标 [x, y]（用于Swipe）
  final List<int>? end;
  
  /// 等待时长（用于Wait）
  final String? duration;
  
  /// 消息内容
  final String? message;
  
  /// 指令内容（用于Call_API）
  final String? instruction;
  
  /// 是否为敏感操作
  final bool isSensitive;
  
  /// 元数据标记
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
  
  /// 从模型响应解析动作
  factory ActionData.parse(String response) {
    final trimmed = response.trim();
    
    // 解析 finish 动作
    if (trimmed.startsWith('finish')) {
      final msgMatch = RegExp(r'message=["\'](.+?)["\']').firstMatch(trimmed);
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
  
  /// 解析do动作
  static ActionData _parseDoAction(String response) {
    // 提取action参数
    final actionMatch = RegExp(r'action=["\'](.+?)["\']').firstMatch(response);
    if (actionMatch == null) {
      return ActionData(
        type: ActionType.unknown,
        actionName: 'unknown',
        message: 'Failed to parse action',
        metadata: 'do',
      );
    }
    
    final actionName = actionMatch.group(1)!;
    final type = _parseActionType(actionName);
    
    // 提取各种参数
    final appMatch = RegExp(r'app=["\'](.+?)["\']').firstMatch(response);
    final textMatch = RegExp(r'text=["\'](.+?)["\']').firstMatch(response);
    final messageMatch = RegExp(r'message=["\'](.+?)["\']').firstMatch(response);
    final durationMatch = RegExp(r'duration=["\'](.+?)["\']').firstMatch(response);
    final instructionMatch = RegExp(r'instruction=["\'](.+?)["\']').firstMatch(response);
    
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
      app: appMatch?.group(1),
      text: textMatch?.group(1),
      message: messageMatch?.group(1),
      duration: durationMatch?.group(1),
      instruction: instructionMatch?.group(1),
      element: parseCoord(elementMatch),
      start: parseCoord(startMatch),
      end: parseCoord(endMatch),
      isSensitive: messageMatch != null && type == ActionType.tap,
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
  
  /// 是否为结束动作
  bool get isFinish => type == ActionType.finish;
  
  /// 是否为do动作
  bool get isDo => metadata == 'do';
  
  /// 转换为JSON字符串表示
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
