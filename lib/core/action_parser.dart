import '../data/models/models.dart';

/// 动作解析器
/// 复刻原Python项目的 parse_action 函数
/// 支持更健壮的解析，处理各种边界情况
class ActionParser {
  
  /// 解析模型响应中的动作
  /// 支持 do(...) 和 finish(...) 格式
  static ActionData parse(String response) {
    final trimmed = response.trim();
    
    // 优先查找 do 动作（即使响应中包含 finish 关键字）
    final doIndex = trimmed.indexOf('do(');
    if (doIndex >= 0) {
      // 提取从 do 开始的部分
      final doStr = _extractFunctionCall(trimmed.substring(doIndex), 'do');
      if (doStr != null) {
        return _parseDo(doStr);
      }
    }
    
    // 尝试解析完整的 finish(...) 动作
    final finishIndex = trimmed.indexOf('finish(');
    if (finishIndex >= 0) {
      final finishStr = _extractFunctionCall(trimmed.substring(finishIndex), 'finish');
      if (finishStr != null) {
        return _parseFinish(finishStr);
      }
    }
    
    // 如果只是单独的 "finish" 关键字（没有括号），忽略它，继续查找其他动作
    // 这种情况通常是模型输出格式不规范
    
    // 无法识别的格式，作为finish处理
    return ActionData(
      type: ActionType.finish,
      actionName: 'finish',
      message: response,
      metadata: 'finish',
    );
  }
  
  /// 提取函数调用字符串（处理括号匹配）
  static String? _extractFunctionCall(String text, String functionName) {
    final startIndex = text.indexOf('$functionName(');
    if (startIndex < 0) return null;
    
    int openCount = 0;
    int closeIndex = -1;
    
    for (int i = startIndex + functionName.length; i < text.length; i++) {
      if (text[i] == '(') {
        openCount++;
      } else if (text[i] == ')') {
        openCount--;
        if (openCount == 0) {
          closeIndex = i;
          break;
        }
      }
    }
    
    if (closeIndex > 0) {
      return text.substring(startIndex, closeIndex + 1);
    }
    
    return null;
  }
  
  /// 解析 finish 动作
  static ActionData _parseFinish(String response) {
    String? message;
    
    // 尝试多种格式的消息提取
    // 格式1: finish(message="xxx")
    // 格式2: finish(message='xxx')
    // 格式3: finish("xxx")
    
    final patterns = [
      RegExp(r'message\s*=\s*"([^"]*)"'),
      RegExp(r"message\s*=\s*'([^']*)'"),
      RegExp(r'finish\s*\(\s*"([^"]*)"\s*\)'),
      RegExp(r"finish\s*\(\s*'([^']*)'\s*\)"),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(response);
      if (match != null) {
        message = match.group(1);
        break;
      }
    }
    
    return ActionData(
      type: ActionType.finish,
      actionName: 'finish',
      message: message ?? _extractBetweenParens(response),
      metadata: 'finish',
    );
  }
  
  /// 解析 do 动作
  static ActionData _parseDo(String response) {
    // 提取 action 参数 - 支持双引号或单引号
    final actionMatch = RegExp(r'''action\s*=\s*["']([^"']+)["']''')
        .firstMatch(response);
    
    if (actionMatch == null) {
      return ActionData(
        type: ActionType.unknown,
        actionName: 'unknown',
        message: 'Failed to parse action from: $response',
        metadata: 'do',
      );
    }
    
    final actionName = actionMatch.group(1)!;
    final type = _parseActionType(actionName);
    
    // 提取各种参数
    final app = _extractStringParam(response, 'app');
    final text = _extractStringParam(response, 'text');
    final message = _extractStringParam(response, 'message');
    final duration = _extractStringParam(response, 'duration');
    final instruction = _extractStringParam(response, 'instruction');
    
    // 提取坐标参数
    final element = _extractCoordinate(response, 'element');
    final start = _extractCoordinate(response, 'start');
    final end = _extractCoordinate(response, 'end');
    
    return ActionData(
      type: type,
      actionName: actionName,
      app: app,
      text: text,
      message: message,
      duration: duration,
      instruction: instruction,
      element: element,
      start: start,
      end: end,
      isSensitive: message != null && type == ActionType.tap,
      metadata: 'do',
    );
  }
  
  /// 提取字符串参数
  static String? _extractStringParam(String response, String paramName) {
    // 支持双引号和单引号
    // 使用动态构建正则表达式，因为paramName是变量
    final doubleQuotePattern = RegExp('$paramName\\s*=\\s*"([^"]*)"');
    final singleQuotePattern = RegExp("$paramName\\s*=\\s*'([^']*)'");
    
    final doubleMatch = doubleQuotePattern.firstMatch(response);
    if (doubleMatch != null) {
      return doubleMatch.group(1);
    }
    
    final singleMatch = singleQuotePattern.firstMatch(response);
    if (singleMatch != null) {
      return singleMatch.group(1);
    }
    
    return null;
  }
  
  /// 提取坐标参数
  static List<int>? _extractCoordinate(String response, String paramName) {
    // 支持多种格式: element=[x,y], element=[x, y], element = [x,y]
    final pattern = RegExp(r'(\w+)\s*=\s*\[\s*(\d+)\s*,\s*(\d+)\s*\]');
    final matches = pattern.allMatches(response);
    
    for (final match in matches) {
      if (match.group(1) == paramName) {
        return [
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
        ];
      }
    }
    
    return null;
  }
  
  /// 提取括号内的内容
  static String? _extractBetweenParens(String response) {
    final start = response.indexOf('(');
    final end = response.lastIndexOf(')');
    
    if (start >= 0 && end > start) {
      return response.substring(start + 1, end).trim();
    }
    
    return null;
  }
  
  /// 解析动作类型
  static ActionType _parseActionType(String actionName) {
    // 标准化动作名称（处理大小写和空格）
    final normalized = actionName.toLowerCase().trim();
    
    switch (normalized) {
      case 'launch':
        return ActionType.launch;
      case 'tap':
        return ActionType.tap;
      case 'type':
        return ActionType.type;
      case 'type_name':
        return ActionType.typeName;
      case 'swipe':
        return ActionType.swipe;
      case 'back':
        return ActionType.back;
      case 'home':
        return ActionType.home;
      case 'double tap':
      case 'doubletap':
        return ActionType.doubleTap;
      case 'long press':
      case 'longpress':
        return ActionType.longPress;
      case 'wait':
        return ActionType.wait;
      case 'take_over':
      case 'takeover':
        return ActionType.takeOver;
      case 'note':
        return ActionType.note;
      case 'call_api':
      case 'callapi':
        return ActionType.callApi;
      case 'interact':
        return ActionType.interact;
      default:
        return ActionType.unknown;
    }
  }
  
  /// 验证动作数据是否有效
  static bool validateAction(ActionData action) {
    switch (action.type) {
      case ActionType.launch:
        return action.app != null && action.app!.isNotEmpty;
      case ActionType.tap:
      case ActionType.doubleTap:
      case ActionType.longPress:
        return action.element != null && action.element!.length >= 2;
      case ActionType.swipe:
        return action.start != null && action.start!.length >= 2 &&
               action.end != null && action.end!.length >= 2;
      case ActionType.type:
      case ActionType.typeName:
        return action.text != null;
      case ActionType.wait:
        return true; // duration 可选
      case ActionType.finish:
        return true;
      default:
        return true;
    }
  }
  
  /// 获取动作描述（用于UI显示）
  static String getActionDescription(ActionData action) {
    switch (action.type) {
      case ActionType.launch:
        return '启动应用: ${action.app}';
      case ActionType.tap:
        return '点击: (${action.element?[0]}, ${action.element?[1]})';
      case ActionType.doubleTap:
        return '双击: (${action.element?[0]}, ${action.element?[1]})';
      case ActionType.longPress:
        return '长按: (${action.element?[0]}, ${action.element?[1]})';
      case ActionType.swipe:
        return '滑动: (${action.start?[0]}, ${action.start?[1]}) → (${action.end?[0]}, ${action.end?[1]})';
      case ActionType.type:
      case ActionType.typeName:
        return '输入: "${action.text}"';
      case ActionType.back:
        return '返回';
      case ActionType.home:
        return '主页';
      case ActionType.wait:
        return '等待: ${action.duration ?? "1 seconds"}';
      case ActionType.takeOver:
        return '用户接管: ${action.message}';
      case ActionType.note:
        return '记录内容';
      case ActionType.callApi:
        return 'API调用: ${action.instruction}';
      case ActionType.interact:
        return '用户交互';
      case ActionType.finish:
        return '完成: ${action.message ?? "任务结束"}';
      case ActionType.unknown:
      default:
        return '未知动作: ${action.actionName}';
    }
  }
}
