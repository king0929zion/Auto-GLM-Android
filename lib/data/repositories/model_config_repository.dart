import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/model_provider.dart';
import '../../config/default_providers.dart';

/// 模型配置仓库
/// 管理供应商、模型选择、AutoGLM配置
class ModelConfigRepository {
  static const String _providersKey = 'model_providers';
  static const String _selectedModelsKey = 'selected_models';
  static const String _activeModelKey = 'active_model';
  static const String _autoglmConfigKey = 'autoglm_config';
  static const int maxSelectedModels = 5;
  
  static ModelConfigRepository? _instance;
  static ModelConfigRepository get instance {
    _instance ??= ModelConfigRepository._();
    return _instance!;
  }
  
  ModelConfigRepository._();
  
  List<ModelProvider> _providers = [];
  List<String> _selectedModelIds = [];
  String? _activeModelId;
  AutoGLMConfig _autoglmConfig = const AutoGLMConfig();
  bool _initialized = false;
  
  // Getters
  List<ModelProvider> get providers => List.unmodifiable(_providers);
  List<String> get selectedModelIds => List.unmodifiable(_selectedModelIds);
  String? get activeModelId => _activeModelId;
  AutoGLMConfig get autoglmConfig => _autoglmConfig;
  bool get initialized => _initialized;
  
  /// 获取已选择的模型列表
  List<Model> get selectedModels {
    final models = <Model>[];
    for (final provider in _providers) {
      for (final model in provider.models) {
        if (_selectedModelIds.contains(model.id)) {
          models.add(model);
        }
      }
    }
    return models;
  }
  
  /// 获取当前活动模型
  Model? get activeModel {
    if (_activeModelId == null) return null;
    for (final provider in _providers) {
      for (final model in provider.models) {
        if (model.id == _activeModelId) {
          return model;
        }
      }
    }
    return null;
  }
  
  /// 获取模型所属供应商
  ModelProvider? getProviderForModel(String modelId) {
    for (final provider in _providers) {
      for (final model in provider.models) {
        if (model.id == modelId) {
          return provider;
        }
      }
    }
    return null;
  }
  
  /// 初始化
  Future<void> init() async {
    if (_initialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    
    // 加载供应商
    final providersJson = prefs.getString(_providersKey);
    if (providersJson != null) {
      final list = jsonDecode(providersJson) as List<dynamic>;
      _providers = list.map((e) => ModelProvider.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      // 初始化预设供应商
      _providers = defaultProviders.map((dp) => ModelProvider(
        id: dp.id,
        name: dp.name,
        baseUrl: dp.baseUrl,
        isBuiltIn: true,
      )).toList();
    }
    
    // 加载已选模型
    final selectedJson = prefs.getStringList(_selectedModelsKey);
    if (selectedJson != null) {
      _selectedModelIds = selectedJson;
    }
    
    // 加载活动模型
    _activeModelId = prefs.getString(_activeModelKey);
    
    // 加载 AutoGLM 配置
    final autoglmJson = prefs.getString(_autoglmConfigKey);
    if (autoglmJson != null) {
      _autoglmConfig = AutoGLMConfig.fromJson(jsonDecode(autoglmJson) as Map<String, dynamic>);
    }
    
    _initialized = true;
  }
  
  /// 保存供应商
  Future<void> _saveProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_providers.map((p) => p.toJson()).toList());
    await prefs.setString(_providersKey, json);
  }
  
  /// 更新供应商 API Key
  Future<void> updateProviderApiKey(String providerId, String apiKey) async {
    final index = _providers.indexWhere((p) => p.id == providerId);
    if (index != -1) {
      _providers[index] = _providers[index].copyWith(apiKey: apiKey);
      await _saveProviders();
    }
  }
  
  /// 更新供应商模型列表
  Future<void> updateProviderModels(String providerId, List<Model> models) async {
    final index = _providers.indexWhere((p) => p.id == providerId);
    if (index != -1) {
      _providers[index] = _providers[index].copyWith(models: models);
      await _saveProviders();
    }
  }

  String _normalizeModelDisplayName(String modelId, String? displayName) {
    final trimmed = (displayName ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    return modelId.contains('/') ? modelId.split('/').last : modelId;
  }

  /// 手动添加模型（用于 OpenAI 兼容供应商）
  Future<void> addManualModel(
    String providerId, {
    required String modelId,
    String? displayName,
  }) async {
    final trimmedModelId = modelId.trim();
    if (trimmedModelId.isEmpty) {
      throw ArgumentError('modelId 不能为空');
    }

    final index = _providers.indexWhere((p) => p.id == providerId);
    if (index == -1) return;

    final provider = _providers[index];
    final exists = provider.models.any((m) => m.modelId == trimmedModelId);
    if (exists) {
      throw StateError('模型已存在');
    }

    final model = Model(
      id: const Uuid().v4(),
      modelId: trimmedModelId,
      displayName: _normalizeModelDisplayName(trimmedModelId, displayName),
      providerId: providerId,
    );

    _providers[index] = provider.copyWith(models: [...provider.models, model]);
    await _saveProviders();
  }

  /// 编辑模型（修改 modelId / 显示名）
  Future<void> updateModel(
    String providerId, {
    required String modelUuid,
    required String modelId,
    String? displayName,
  }) async {
    final trimmedModelId = modelId.trim();
    if (trimmedModelId.isEmpty) {
      throw ArgumentError('modelId 不能为空');
    }

    final providerIndex = _providers.indexWhere((p) => p.id == providerId);
    if (providerIndex == -1) return;

    final provider = _providers[providerIndex];
    final targetIndex = provider.models.indexWhere((m) => m.id == modelUuid);
    if (targetIndex == -1) return;

    final conflict = provider.models.any((m) => m.id != modelUuid && m.modelId == trimmedModelId);
    if (conflict) {
      throw StateError('该 modelId 已存在');
    }

    final old = provider.models[targetIndex];
    final updated = old.copyWith(
      modelId: trimmedModelId,
      displayName: _normalizeModelDisplayName(trimmedModelId, displayName),
    );

    final newModels = [...provider.models];
    newModels[targetIndex] = updated;
    _providers[providerIndex] = provider.copyWith(models: newModels);
    await _saveProviders();
  }

  /// 删除模型
  Future<void> deleteModel(String providerId, String modelUuid) async {
    final providerIndex = _providers.indexWhere((p) => p.id == providerId);
    if (providerIndex == -1) return;

    final provider = _providers[providerIndex];
    final existed = provider.models.any((m) => m.id == modelUuid);
    if (!existed) return;

    final newModels = provider.models.where((m) => m.id != modelUuid).toList();
    _providers[providerIndex] = provider.copyWith(models: newModels);

    _selectedModelIds.removeWhere((id) => id == modelUuid);
    if (_activeModelId == modelUuid) {
      _activeModelId = _selectedModelIds.isNotEmpty ? _selectedModelIds.first : null;
    }

    await _saveProviders();
    await _saveSelectedModels();
  }
  
  /// 添加自定义供应商
  Future<void> addCustomProvider(String name, String baseUrl) async {
    final provider = ModelProvider(
      id: const Uuid().v4(),
      name: name,
      baseUrl: baseUrl,
      isBuiltIn: false,
    );
    _providers.add(provider);
    await _saveProviders();
  }
  
  /// 删除自定义供应商
  Future<void> deleteProvider(String providerId) async {
    _providers.removeWhere((p) => p.id == providerId && !p.isBuiltIn);
    // 移除该供应商相关的已选模型
    _selectedModelIds.removeWhere((id) {
      for (final provider in _providers) {
        for (final model in provider.models) {
          if (model.id == id) return false;
        }
      }
      return true;
    });
    await _saveProviders();
    await _saveSelectedModels();
  }
  
  /// 切换模型选中状态
  Future<bool> toggleModelSelection(String modelId) async {
    if (_selectedModelIds.contains(modelId)) {
      _selectedModelIds.remove(modelId);
      if (_activeModelId == modelId) {
        _activeModelId = _selectedModelIds.isNotEmpty ? _selectedModelIds.first : null;
      }
    } else {
      if (_selectedModelIds.length >= maxSelectedModels) {
        return false; // 超出限制
      }
      _selectedModelIds.add(modelId);
      if (_activeModelId == null) {
        _activeModelId = modelId;
      }
    }
    await _saveSelectedModels();
    return true;
  }
  
  /// 设置活动模型
  Future<void> setActiveModel(String modelId) async {
    if (_selectedModelIds.contains(modelId)) {
      _activeModelId = modelId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeModelKey, modelId);
    }
  }
  
  Future<void> _saveSelectedModels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedModelsKey, _selectedModelIds);
    if (_activeModelId != null) {
      await prefs.setString(_activeModelKey, _activeModelId!);
    }
  }
  
  /// 更新 AutoGLM 配置
  Future<void> updateAutoGLMConfig(AutoGLMConfig config) async {
    _autoglmConfig = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoglmConfigKey, jsonEncode(config.toJson()));
  }
  
  /// 从 API 获取可用模型
  Future<List<Model>> fetchModels(String providerId) async {
    final provider = _providers.firstWhere((p) => p.id == providerId);
    if (provider.apiKey.isEmpty) {
      throw Exception('请先配置 API Key');
    }
    
    final dio = Dio(BaseOptions(
      baseUrl: provider.baseUrl,
      headers: {
        'Authorization': 'Bearer ${provider.apiKey}',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    
    try {
      // 使用相对路径，避免覆盖 baseUrl 中已有的 /v1 路径
      final baseUrl = provider.baseUrl;
      final normalized = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final path = (normalized.endsWith('/v1') || normalized.contains('/v1/')) ? 'models' : 'v1/models';
      final response = await dio.get(path);
      final data = response.data;
      
      List<dynamic> modelList;
      if (data is Map && data['data'] != null) {
        modelList = data['data'] as List<dynamic>;
      } else if (data is List) {
        modelList = data;
      } else {
        throw Exception('无法解析模型列表');
      }
      
      final models = modelList
          .map((m) => Model.fromApiResponse(m as Map<String, dynamic>, providerId))
          .toList();
      
      // 保留已选中状态
      final updatedModels = models.map((m) {
        final existingModel = provider.models.firstWhere(
          (existing) => existing.modelId == m.modelId,
          orElse: () => m,
        );
        return m.copyWith(
          id: existingModel.id,
          isSelected: _selectedModelIds.contains(existingModel.id),
        );
      }).toList();
      
      await updateProviderModels(providerId, updatedModels);
      return updatedModels;
    } catch (e) {
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          throw Exception('API Key 无效');
        } else if (e.response?.statusCode == 403) {
          throw Exception('API 访问被拒绝');
        }
      }
      throw Exception('获取模型失败: $e');
    } finally {
      dio.close();
    }
  }
}
