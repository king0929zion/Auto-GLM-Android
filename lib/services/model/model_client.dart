import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/models/models.dart';
import '../../data/repositories/model_config_repository.dart';

/// 模型响应数据类
class ModelResponse {
  /// AI思考过程
  final String thinking;
  
  /// 动作字符串
  final String action;
  
  /// 原始响应内容
  final String rawContent;

  const ModelResponse({
    required this.thinking,
    required this.action,
    required this.rawContent,
  });
}

/// OpenAI兼容的模型客户端
class ModelClient {
  final String? overrideBaseUrl;
  final String? overrideApiKey;
  final String? overrideModelName;
  
  CancelToken? _activeCancelToken;
  
  ModelClient({
    this.overrideBaseUrl,
    this.overrideApiKey,
    this.overrideModelName,
  });

  /// 创建 Dio 实例
  Dio _createDio(String baseUrl, String apiKey) {
    return Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
    ));
  }

  /// 发送请求到模型
  Future<ModelResponse> request(
    List<Map<String, dynamic>> messages, {
    CancelToken? cancelToken,
  }) async {
    // 获取配置
    String baseUrl;
    String apiKey;
    String modelName;

    // 优先使用覆盖配置（用于 AutoGLM）
    if (overrideBaseUrl != null && overrideApiKey != null && overrideModelName != null) {
      baseUrl = overrideBaseUrl!;
      apiKey = overrideApiKey!;
      modelName = overrideModelName!;
    } else {
      // 否则使用主模型配置
      final repo = ModelConfigRepository.instance;
      // 确保已初始化
      if (!repo.initialized) await repo.init();
      
      final activeModel = repo.activeModel;
      if (activeModel == null) {
        throw const ModelClientException('未选择任何模型，请在设置或首页选择模型');
      }
      
      final provider = repo.getProviderForModel(activeModel.id);
      if (provider == null) {
        throw const ModelClientException('模型配置错误：找不到对应的供应商');
      }
      
      if (provider.apiKey.isEmpty) {
        throw const ModelClientException('所选供应商未配置 API Key');
      }
      
      baseUrl = provider.baseUrl;
      apiKey = provider.apiKey;
      modelName = activeModel.modelId;
    }

    final token = cancelToken ?? CancelToken();
    _activeCancelToken = token;
    
    // 创建 Dio
    final dio = _createDio(baseUrl, apiKey);
    
    final body = {
      'model': modelName,
      'messages': messages,
      'temperature': 0.7, // 默认配置
      'stream': false,
    };

    // Debug log
    print('=== API Request ===');
    print('URL: $baseUrl/chat/completions');
    print('Model: $modelName');
    print('API Key: ${apiKey.length > 10 ? apiKey.substring(0, 10) : apiKey}...');

    try {
      final response = await dio.post(
        '/chat/completions',
        data: body,
        cancelToken: token,
      );

      print('=== API Response ===');
      print('Status: ${response.statusCode}');

      final data = response.data;
      final rawContent = data['choices'][0]['message']['content'] as String;

      print('=== Model Raw Response ===');
      print(rawContent);
      print('=' * 50);

      // 解析思考和动作
      final (thinking, action) = _parseResponse(rawContent);
      
      print('=== Parsed Result ===');
      print('Thinking: $thinking');
      print('Action: $action');
      print('=' * 50);

      return ModelResponse(
        thinking: thinking,
        action: action,
        rawContent: rawContent,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw const ModelClientCancelledException('请求已取消');
      }
      print('=== API Error ===');
      print('Type: ${e.type}');
      print('Message: ${e.message}');
      print('Response: ${e.response?.data}');
      print('Status Code: ${e.response?.statusCode}');
      
      String errorMsg;
      if (e.type == DioExceptionType.connectionError) {
        errorMsg = '网络连接失败，请检查网络';
      } else if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = '连接超时，请检查网络';
      } else if (e.response?.statusCode == 401) {
        errorMsg = 'API Key无效，请在设置中配置正确的API Key';
      } else if (e.response?.statusCode == 403) {
        errorMsg = 'API访问被拒绝，请检查API Key权限';
      } else if (e.response?.statusCode == 429) {
        errorMsg = '请求频率过高，请稍后重试';
      } else if (e.response?.statusCode == 500) {
        errorMsg = '服务器错误，请稍后重试';
      } else if (e.response != null) {
        final respData = e.response?.data;
        if (respData is Map) {
          // 魔搭API错误格式: {'errors': {'message': '...'}}
          if (respData['errors'] != null && respData['errors'] is Map) {
            errorMsg = '魔搭API错误: ${respData['errors']['message'] ?? respData['errors']}';
          }
          // OpenAI标准错误格式: {'error': {'message': '...'}}
          else if (respData['error'] != null) {
            errorMsg = 'API错误: ${respData['error']['message'] ?? respData['error']}';
          }
          else {
            errorMsg = '请求失败 (${e.response?.statusCode}): $respData';
          }
        } else {
          errorMsg = '请求失败 (${e.response?.statusCode}): $respData';
        }
      } else {
        errorMsg = '请求失败: ${e.message ?? e.type.name}';
      }
      throw ModelClientException(
        errorMsg,
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      print('=== Unknown Error ===');
      print('$e');
      throw ModelClientException('未知错误: $e');
    } finally {
      if (identical(_activeCancelToken, token)) {
        _activeCancelToken = null;
      }
    }
  }

  /// 解析模型响应
  (String, String) _parseResponse(String content) {
    String thinking = '';
    String action = '';
    
    // 优先使用 <answer> 标签
    if (content.contains('<answer>')) {
      final parts = content.split('<answer>');
      thinking = parts[0]
          .replaceAll('<think>', '')
          .replaceAll('</think>', '')
          .trim();
      action = parts[1]
          .replaceAll('</answer>', '')
          .trim();
    } else {
      // 没有 <answer> 标签，尝试提取 do(...) 或 finish(...)
      // 使用更复杂的正则来匹配带引号内容的括号
      final doIndex = content.indexOf('do(');
      final finishIndex = content.indexOf('finish(');
      
      if (doIndex != -1) {
        // 找到匹配的右括号
        final closeIndex = _findMatchingParen(content, doIndex + 2);
        if (closeIndex != -1) {
          action = content.substring(doIndex, closeIndex + 1);
          thinking = content.substring(0, doIndex).trim();
        } else {
          action = content.substring(doIndex).trim();
          thinking = content.substring(0, doIndex).trim();
        }
      } else if (finishIndex != -1) {
        final closeIndex = _findMatchingParen(content, finishIndex + 6);
        if (closeIndex != -1) {
          action = content.substring(finishIndex, closeIndex + 1);
          thinking = content.substring(0, finishIndex).trim();
        } else {
          action = content.substring(finishIndex).trim();
          thinking = content.substring(0, finishIndex).trim();
        }
      } else {
        // 无法识别，返回整个内容作为action让后续处理
        action = content.trim();
      }
    }
    
    print('=== Parsed Response ===');
    print('Thinking: ${thinking.length > 100 ? thinking.substring(0, 100) + "..." : thinking}');
    print('Action: $action');
    
    return (thinking, action);
  }
  
  /// 找到匹配的右括号，考虑引号内的内容
  int _findMatchingParen(String s, int openIndex) {
    int depth = 0;
    bool inDoubleQuote = false;
    bool inSingleQuote = false;
    
    for (int i = openIndex; i < s.length; i++) {
      final c = s[i];
      
      if (c == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
      } else if (c == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
      } else if (!inDoubleQuote && !inSingleQuote) {
        if (c == '(') {
          depth++;
        } else if (c == ')') {
          if (depth == 0) {
            return i;
          }
          depth--;
        }
      }
    }
    return -1;
  }

  /// 取消当前请求（用于停止任务）
  void cancelActiveRequest([String reason = '用户停止']) {
    try {
      _activeCancelToken?.cancel(reason);
    } catch (_) {
    } finally {
      _activeCancelToken = null;
    }
  }
}

/// 消息构建器
class MessageBuilder {
  /// 创建系统消息
  static Map<String, dynamic> createSystemMessage(String content) {
    return {'role': 'system', 'content': content};
  }

  /// 创建用户消息（可带图片）
  static Map<String, dynamic> createUserMessage({
    required String text,
    String? imageBase64,
  }) {
    final content = <Map<String, dynamic>>[];

    if (imageBase64 != null && imageBase64.isNotEmpty) {
      content.add({
        'type': 'image_url',
        'image_url': {'url': 'data:image/png;base64,$imageBase64'},
      });
    }

    content.add({'type': 'text', 'text': text});

    return {'role': 'user', 'content': content};
  }

  /// 创建助手消息
  static Map<String, dynamic> createAssistantMessage(String content) {
    return {'role': 'assistant', 'content': content};
  }

  /// 从消息中移除图片（节省上下文空间）
  static Map<String, dynamic> removeImagesFromMessage(
    Map<String, dynamic> message,
  ) {
    if (message['content'] is List) {
      final content = (message['content'] as List)
          .where((item) => item['type'] == 'text')
          .toList();
      return {...message, 'content': content};
    }
    return message;
  }

  /// 构建屏幕信息
  static String buildScreenInfo(String currentApp, [Map<String, dynamic>? extra]) {
    final info = {'current_app': currentApp, ...?extra};
    return jsonEncode(info);
  }
}

/// 模型客户端异常
class ModelClientException implements Exception {
  final String message;
  final int? statusCode;

  const ModelClientException(this.message, {this.statusCode});

  @override
  String toString() => 'ModelClientException: $message';
}

class ModelClientCancelledException extends ModelClientException {
  const ModelClientCancelledException(super.message);
}
