/// 模型配置数据�?
class ModelConfig {
  /// API基础URL
  final String baseUrl;
  
  /// API密钥
  final String apiKey;
  
  /// 模型名称
  final String modelName;
  
  /// 最大token�?
  final int maxTokens;
  
  /// 温度参数
  final double temperature;
  
  /// Top P 参数
  final double topP;
  
  /// 频率惩罚
  final double frequencyPenalty;
  
  const ModelConfig({
    this.baseUrl = 'http://localhost:8000/v1',
    this.apiKey = 'EMPTY',
    this.modelName = 'autoglm-phone-9b',
    this.maxTokens = 3000,
    this.temperature = 0.0,
    this.topP = 0.85,
    this.frequencyPenalty = 0.2,
  });
  
  /// 从JSON创建
  factory ModelConfig.fromJson(Map<String, dynamic> json) {
    return ModelConfig(
      baseUrl: json['baseUrl'] as String? ?? 'http://localhost:8000/v1',
      apiKey: json['apiKey'] as String? ?? 'EMPTY',
      modelName: json['modelName'] as String? ?? 'autoglm-phone-9b',
      maxTokens: json['maxTokens'] as int? ?? 3000,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.85,
      frequencyPenalty: (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.2,
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'modelName': modelName,
      'maxTokens': maxTokens,
      'temperature': temperature,
      'topP': topP,
      'frequencyPenalty': frequencyPenalty,
    };
  }
  
  /// 复制并修�?
  ModelConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? modelName,
    int? maxTokens,
    double? temperature,
    double? topP,
    double? frequencyPenalty,
  }) {
    return ModelConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
    );
  }
}
