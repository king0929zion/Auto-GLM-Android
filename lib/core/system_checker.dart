import 'package:dio/dio.dart';
import '../services/model/model_client.dart';
import '../data/models/models.dart';

/// 系统检查结果
class SystemCheckResult {
  final bool passed;
  final String name;
  final String message;
  final String? solution;

  const SystemCheckResult({
    required this.passed,
    required this.name,
    required this.message,
    this.solution,
  });
}

/// 系统检查服务
/// 复刻原Python项目的 check_system_requirements 和 check_model_api
class SystemChecker {
  
  /// 检查所有系统要求
  /// 移动端版本检查：Shizuku状态、模型API连接
  static Future<List<SystemCheckResult>> checkAll({
    required String baseUrl,
    required String modelName,
    required String apiKey,
    required Future<bool> Function() checkShizuku,
  }) async {
    final results = <SystemCheckResult>[];
    
    // 1. 检查Shizuku
    results.add(await _checkShizukuService(checkShizuku));
    
    // 2. 检查API连接
    results.add(await _checkApiConnectivity(baseUrl, apiKey));
    
    // 3. 检查模型可用性 (可选)
    // results.add(await _checkModelAvailability(baseUrl, modelName, apiKey));
    
    return results;
  }
  
  /// 检查Shizuku服务状态
  static Future<SystemCheckResult> _checkShizukuService(
    Future<bool> Function() checkShizuku,
  ) async {
    try {
      final isAvailable = await checkShizuku();
      
      if (isAvailable) {
        return const SystemCheckResult(
          passed: true,
          name: 'Shizuku 服务',
          message: '已连接并授权',
        );
      } else {
        return const SystemCheckResult(
          passed: false,
          name: 'Shizuku 服务',
          message: 'Shizuku 未就绪',
          solution: '''1. 安装 Shizuku 应用
2. 通过 ADB 或无线调试启动 Shizuku 服务
3. 在 Shizuku 中授权本应用''',
        );
      }
    } catch (e) {
      return SystemCheckResult(
        passed: false,
        name: 'Shizuku 服务',
        message: '检查失败: $e',
        solution: '请确保已安装 Shizuku 应用',
      );
    }
  }
  
  /// 检查API连接性
  static Future<SystemCheckResult> _checkApiConnectivity(
    String baseUrl,
    String apiKey,
  ) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ));
      
      final response = await dio.get('/models');
      
      if (response.statusCode == 200) {
        final models = response.data['data'] as List?;
        final modelCount = models?.length ?? 0;
        
        return SystemCheckResult(
          passed: true,
          name: 'API 连接',
          message: '连接成功 ($modelCount 个可用模型)',
        );
      } else {
        return SystemCheckResult(
          passed: false,
          name: 'API 连接',
          message: 'HTTP ${response.statusCode}',
          solution: '请检查 API URL 是否正确',
        );
      }
    } on DioException catch (e) {
      String message;
      String solution;
      
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        message = '连接超时';
        solution = '''1. 检查网络连接
2. 确认模型服务器正在运行
3. 检查 URL 是否正确''';
      } else if (e.type == DioExceptionType.connectionError) {
        message = '无法连接到服务器';
        solution = '''1. 确认模型服务器正在运行
2. 检查 URL 和端口是否正确
3. 确认手机与服务器在同一网络''';
      } else {
        message = e.message ?? '未知错误';
        solution = '请检查 API 配置';
      }
      
      return SystemCheckResult(
        passed: false,
        name: 'API 连接',
        message: message,
        solution: solution,
      );
    } catch (e) {
      return SystemCheckResult(
        passed: false,
        name: 'API 连接',
        message: '检查失败: $e',
        solution: '请检查网络连接和 API 配置',
      );
    }
  }
  
  /// 检查模型可用性
  static Future<SystemCheckResult> _checkModelAvailability(
    String baseUrl,
    String modelName,
    String apiKey,
  ) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ));
      
      final response = await dio.get('/models');
      
      if (response.statusCode == 200) {
        final models = response.data['data'] as List?;
        final modelIds = models?.map((m) => m['id'] as String).toList() ?? [];
        
        if (modelIds.contains(modelName)) {
          return SystemCheckResult(
            passed: true,
            name: '模型 "$modelName"',
            message: '模型可用',
          );
        } else {
          final availableModels = modelIds.take(5).join(', ');
          return SystemCheckResult(
            passed: false,
            name: '模型 "$modelName"',
            message: '模型不存在',
            solution: '可用模型: $availableModels',
          );
        }
      } else {
        return SystemCheckResult(
          passed: false,
          name: '模型 "$modelName"',
          message: '无法获取模型列表',
        );
      }
    } catch (e) {
      return SystemCheckResult(
        passed: false,
        name: '模型 "$modelName"',
        message: '检查失败: $e',
      );
    }
  }
  
  /// 快速检查API是否可用
  static Future<bool> quickCheckApi(String baseUrl, String apiKey) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ));
      
      final response = await dio.get('/models');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
