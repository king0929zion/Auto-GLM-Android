import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/models.dart';
import 'app_config.dart';

/// 设置存储服务
/// 负责持久化和加载应用配置
class SettingsRepository {
  static SettingsRepository? _instance;
  SharedPreferences? _prefs;
  
  SettingsRepository._();
  
  /// 获取单例实例
  static SettingsRepository get instance {
    _instance ??= SettingsRepository._();
    return _instance!;
  }
  
  /// 初始化
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// 获取SharedPreferences实例
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('SettingsRepository not initialized. Call init() first.');
    }
    return _prefs!;
  }
  
  // ===== 模型配置 =====
  
  /// 获取保存的模型配置
  ModelConfig getModelConfig() {
    return ModelConfig(
      baseUrl: prefs.getString(AppConfig.keyBaseUrl) ?? AppConfig.defaultBaseUrl,
      apiKey: prefs.getString(AppConfig.keyApiKey) ?? AppConfig.defaultApiKey,
      modelName: prefs.getString(AppConfig.keyModelName) ?? AppConfig.defaultModelName,
      maxTokens: AppConfig.defaultMaxTokens,
      temperature: AppConfig.defaultTemperature,
      topP: AppConfig.defaultTopP,
      frequencyPenalty: AppConfig.defaultFrequencyPenalty,
    );
  }
  
  /// 保存模型配置
  Future<void> saveModelConfig(ModelConfig config) async {
    await prefs.setString(AppConfig.keyBaseUrl, config.baseUrl);
    await prefs.setString(AppConfig.keyApiKey, config.apiKey);
    await prefs.setString(AppConfig.keyModelName, config.modelName);
  }
  
  /// 获取API基础URL
  String get baseUrl => 
      prefs.getString(AppConfig.keyBaseUrl) ?? AppConfig.defaultBaseUrl;
  
  /// 设置API基础URL
  Future<void> setBaseUrl(String url) async {
    await prefs.setString(AppConfig.keyBaseUrl, url);
  }
  
  /// 获取API密钥
  String get apiKey => 
      prefs.getString(AppConfig.keyApiKey) ?? AppConfig.defaultApiKey;
  
  /// 设置API密钥
  Future<void> setApiKey(String key) async {
    await prefs.setString(AppConfig.keyApiKey, key);
  }
  
  /// 获取模型名称
  String get modelName => 
      prefs.getString(AppConfig.keyModelName) ?? AppConfig.defaultModelName;
  
  /// 设置模型名称
  Future<void> setModelName(String name) async {
    await prefs.setString(AppConfig.keyModelName, name);
  }
  
  // ===== Agent配置 =====
  
  /// 获取最大步骤数
  int get maxSteps => 
      prefs.getInt(AppConfig.keyMaxSteps) ?? AppConfig.maxSteps;
  
  /// 设置最大步骤数
  Future<void> setMaxSteps(int steps) async {
    await prefs.setInt(AppConfig.keyMaxSteps, steps);
  }
  
  /// 获取语言设置
  String get language => 
      prefs.getString(AppConfig.keyLanguage) ?? AppConfig.defaultLanguage;
  
  /// 设置语言
  Future<void> setLanguage(String lang) async {
    await prefs.setString(AppConfig.keyLanguage, lang);
  }
  
  // ===== 任务历史 =====
  
  static const String _keyTaskHistory = 'task_history';
  static const int _maxHistorySize = 50;
  
  /// 获取任务历史
  List<String> get taskHistory {
    return prefs.getStringList(_keyTaskHistory) ?? [];
  }
  
  /// 添加任务到历史
  Future<void> addTaskToHistory(String task) async {
    final history = taskHistory;
    
    // 移除重复项
    history.remove(task);
    
    // 添加到开头
    history.insert(0, task);
    
    // 限制大小
    if (history.length > _maxHistorySize) {
      history.removeRange(_maxHistorySize, history.length);
    }
    
    await prefs.setStringList(_keyTaskHistory, history);
  }
  
  /// 清除任务历史
  Future<void> clearTaskHistory() async {
    await prefs.remove(_keyTaskHistory);
  }
  
  // ===== 首次运行 =====
  
  static const String _keyFirstRun = 'first_run';
  
  /// 是否首次运行
  bool get isFirstRun => prefs.getBool(_keyFirstRun) ?? true;
  
  /// 设置已运行过
  Future<void> setFirstRunCompleted() async {
    await prefs.setBool(_keyFirstRun, false);
  }
  
  // ===== Shizuku状态 =====
  
  static const String _keyShizukuWarned = 'shizuku_warned';
  
  /// 是否已显示过Shizuku警告
  bool get hasShownShizukuWarning => prefs.getBool(_keyShizukuWarned) ?? false;
  
  /// 设置已显示Shizuku警告
  Future<void> setShizukuWarningShown() async {
    await prefs.setBool(_keyShizukuWarned, true);
  }
}
