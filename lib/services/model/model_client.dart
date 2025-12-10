import 'dart:convert';
import 'package:dio/dio.dart';
import '../../data/models/models.dart';

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
  /// 模型配置
  final ModelConfig config;
  
  /// HTTP客户端
  late final Dio _dio;

  ModelClient({required this.config}) {
    _dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
    ));
  }

  /// 发送请求到模型
  Future<ModelResponse> request(List<Map<String, dynamic>> messages) async {
    final body = {
      'model': config.modelName,
      'messages': messages,
      'max_tokens': config.maxTokens,
      'temperature': config.temperature,
      'top_p': config.topP,
      'frequency_penalty': config.frequencyPenalty,
      'skip_special_tokens': false,
    };

    try {
      final response = await _dio.post(
        '/chat/completions',
        data: body,
      );

      final data = response.data;
      final rawContent = data['choices'][0]['message']['content'] as String;

      // 解析思考和动作
      final (thinking, action) = _parseResponse(rawContent);

      return ModelResponse(
        thinking: thinking,
        action: action,
        rawContent: rawContent,
      );
    } on DioException catch (e) {
      throw ModelClientException(
        'Request failed: ${e.message}',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ModelClientException('Unknown error: $e');
    }
  }

  /// 解析模型响应
  (String, String) _parseResponse(String content) {
    if (!content.contains('<answer>')) {
      return ('', content);
    }

    final parts = content.split('<answer>');
    final thinking = parts[0]
        .replaceAll('<think>', '')
        .replaceAll('</think>', '')
        .trim();
    final action = parts[1]
        .replaceAll('</answer>', '')
        .trim();

    return (thinking, action);
  }

  /// 检查API是否可用
  Future<bool> checkAvailability() async {
    try {
      final response = await _dio.get('/models');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 获取可用模型列表
  Future<List<String>> getModels() async {
    try {
      final response = await _dio.get('/models');
      final data = response.data;
      final models = (data['data'] as List)
          .map((m) => m['id'] as String)
          .toList();
      return models;
    } catch (e) {
      return [];
    }
  }

  /// 释放资源
  void dispose() {
    _dio.close();
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
