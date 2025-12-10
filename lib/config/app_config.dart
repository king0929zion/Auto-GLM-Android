/// 应用配置常量
class AppConfig {
  /// 应用名称
  static const String appName = 'AutoGLM Mobile';
  
  /// 应用版本
  static const String appVersion = '1.0.0';
  
  /// 默认API配置
  static const String defaultBaseUrl = 'http://localhost:8000/v1';
  static const String defaultApiKey = 'EMPTY';
  static const String defaultModelName = 'autoglm-phone-9b';
  
  /// 模型参数默认�?
  static const int defaultMaxTokens = 3000;
  static const double defaultTemperature = 0.0;
  static const double defaultTopP = 0.85;
  static const double defaultFrequencyPenalty = 0.2;
  
  /// Agent 配置
  static const int maxSteps = 100;
  static const int httpTimeoutSeconds = 30;
  static const int screenshotTimeoutMs = 10000;
  
  /// 设备操作延迟（毫秒）
  static const int tapDelayMs = 1000;
  static const int swipeDelayMs = 1000;
  static const int typeDelayMs = 1000;
  static const int longPressDelayMs = 1000;
  static const int longPressDurationMs = 3000;
  
  /// 屏幕坐标系统范围
  static const int coordinateSystemMax = 1000;
  
  /// SharedPreferences 键名
  static const String keyBaseUrl = 'base_url';
  static const String keyApiKey = 'api_key';
  static const String keyModelName = 'model_name';
  static const String keyLanguage = 'language';
  static const String keyMaxSteps = 'max_steps';
  
  /// 支持的语言
  static const List<String> supportedLanguages = ['cn', 'en'];
  
  /// 默认语言
  static const String defaultLanguage = 'cn';
}
