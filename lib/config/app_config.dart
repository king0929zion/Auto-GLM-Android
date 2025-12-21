/// 应用配置常量
class AppConfig {
  /// 应用名称
  static const String appName = 'AutoZi';
  
  /// 应用版本
  static const String appVersion = '1.0.0';
  
  /// Agent 配置
  static const int maxSteps = 200;
  /// SharedPreferences 键名
  static const String keyLanguage = 'language';
  static const String keyMaxSteps = 'max_steps';
  
  /// 支持的语言
  static const List<String> supportedLanguages = ['cn', 'en'];
  
  /// 默认语言
  static const String defaultLanguage = 'cn';
}
