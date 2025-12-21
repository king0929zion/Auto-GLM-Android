import 'package:uuid/uuid.dart';

/// 模型供应商
class ModelProvider {
  final String id;
  final String name;
  final String baseUrl;
  final String apiKey;
  final List<Model> models;
  final bool isBuiltIn;
  final bool enabled;
  
  const ModelProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.apiKey = '',
    this.models = const [],
    this.isBuiltIn = false,
    this.enabled = true,
  });
  
  ModelProvider copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? apiKey,
    List<Model>? models,
    bool? isBuiltIn,
    bool? enabled,
  }) {
    return ModelProvider(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      models: models ?? this.models,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      enabled: enabled ?? this.enabled,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'models': models.map((m) => m.toJson()).toList(),
    'isBuiltIn': isBuiltIn,
    'enabled': enabled,
  };
  
  factory ModelProvider.fromJson(Map<String, dynamic> json) {
    return ModelProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String? ?? '',
      models: (json['models'] as List<dynamic>?)
          ?.map((m) => Model.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// 模型
class Model {
  final String id;
  final String modelId;      // API 中使用的模型名称
  final String displayName;  // 显示名称
  final String providerId;   // 所属供应商ID
  final bool isSelected;     // 是否被选中 (最多5个)
  
  const Model({
    required this.id,
    required this.modelId,
    required this.displayName,
    required this.providerId,
    this.isSelected = false,
  });
  
  Model copyWith({
    String? id,
    String? modelId,
    String? displayName,
    String? providerId,
    bool? isSelected,
  }) {
    return Model(
      id: id ?? this.id,
      modelId: modelId ?? this.modelId,
      displayName: displayName ?? this.displayName,
      providerId: providerId ?? this.providerId,
      isSelected: isSelected ?? this.isSelected,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'modelId': modelId,
    'displayName': displayName,
    'providerId': providerId,
    'isSelected': isSelected,
  };
  
  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      id: json['id'] as String,
      modelId: json['modelId'] as String,
      displayName: json['displayName'] as String? ?? json['modelId'] as String,
      providerId: json['providerId'] as String,
      isSelected: json['isSelected'] as bool? ?? false,
    );
  }
  
  /// 从 API 响应创建
  factory Model.fromApiResponse(Map<String, dynamic> json, String providerId) {
    final modelId = json['id'] as String;
    return Model(
      id: const Uuid().v4(),
      modelId: modelId,
      displayName: modelId,
      providerId: providerId,
    );
  }
}

/// AutoGLM 配置 (独立于主模型)
class AutoGLMConfig {
  final String apiKey;
  final String baseUrl;
  final String modelName;
  
  const AutoGLMConfig({
    this.apiKey = '',
    this.baseUrl = 'https://open.bigmodel.cn/api/paas/v4',
    this.modelName = 'autoglm-phone',
  });
  
  AutoGLMConfig copyWith({
    String? apiKey,
    String? baseUrl,
    String? modelName,
  }) {
    return AutoGLMConfig(
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      modelName: modelName ?? this.modelName,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'modelName': modelName,
  };
  
  factory AutoGLMConfig.fromJson(Map<String, dynamic> json) {
    return AutoGLMConfig(
      apiKey: json['apiKey'] as String? ?? '',
      baseUrl: json['baseUrl'] as String? ?? 'https://open.bigmodel.cn/api/paas/v4',
      modelName: json['modelName'] as String? ?? 'autoglm-phone',
    );
  }
  
  bool get isConfigured => apiKey.isNotEmpty;
}
