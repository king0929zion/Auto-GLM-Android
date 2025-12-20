import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/models.dart';
import 'app_config.dart';

/// 设置存储服务
/// 负责持久化和加载应用配置
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
    // Migration: If we have an old generic key but no specific AutoGLM key, copy it.
    if (_prefs!.containsKey(AppConfig.keyApiKey) && !_prefs!.containsKey(AppConfig.keyAutoglmApiKey)) {
        await _prefs!.setString(AppConfig.keyAutoglmApiKey, _prefs!.getString(AppConfig.keyApiKey)!);
    }
  }
  
  /// 获取SharedPreferences实例
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('SettingsRepository not initialized. Call init() first.');
    }
    return _prefs!;
  }
  
  // ===== Provider Selection =====
  String get selectedProvider => prefs.getString(AppConfig.keySelectedProvider) ?? 'autoglm';
  
  Future<void> setSelectedProvider(String provider) async {
      await prefs.setString(AppConfig.keySelectedProvider, provider);
  }

  // ===== 模型配置 =====
  
  /// 获取当前生效的模型配置
  ModelConfig getModelConfig() {
    if (selectedProvider == 'doubao') {
        return ModelConfig(
            baseUrl: AppConfig.doubaoBaseUrl,
            apiKey: doubaoApiKey, // Must be set by user
            modelName: doubaoModelName,
            maxTokens: AppConfig.defaultMaxTokens,
            temperature: AppConfig.defaultTemperature,
            topP: AppConfig.defaultTopP,
            frequencyPenalty: AppConfig.defaultFrequencyPenalty,
        );
    } else {
        // Default to AutoGLM
        return ModelConfig(
            baseUrl: AppConfig.defaultBaseUrl,
            apiKey: autoglmApiKey,
            modelName: AppConfig.defaultModelName,
            maxTokens: AppConfig.defaultMaxTokens,
            temperature: AppConfig.defaultTemperature,
            topP: AppConfig.defaultTopP,
            frequencyPenalty: AppConfig.defaultFrequencyPenalty,
        );
    }
  }
  
  // ===== AutoGLM Settings (Read/Write) =====
  String get autoglmApiKey => prefs.getString(AppConfig.keyAutoglmApiKey) ?? '';
  
  Future<void> setAutoglmApiKey(String key) async {
      await prefs.setString(AppConfig.keyAutoglmApiKey, key);
      // Also update legacy key for backward compact if needed, or just ignore it.
      await prefs.setString(AppConfig.keyApiKey, key); 
  }

  // ===== Doubao Settings (Read/Write) =====
  String get doubaoApiKey => prefs.getString(AppConfig.keyDoubaoApiKey) ?? '';
  String get doubaoModelName => prefs.getString(AppConfig.keyDoubaoModelName) ?? AppConfig.defaultDoubaoModel;

  Future<void> setDoubaoApiKey(String key) async {
      await prefs.setString(AppConfig.keyDoubaoApiKey, key);
  }
  
  Future<void> setDoubaoModelName(String name) async {
      await prefs.setString(AppConfig.keyDoubaoModelName, name);
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
  
  // ===== 用户昵称 =====
  
  static const String _keyNickname = 'user_nickname';
  
  /// 获取用户昵称
  String? getNickname() => prefs.getString(_keyNickname);
  
  /// 设置用户昵称
  Future<void> setNickname(String nickname) async {
    await prefs.setString(_keyNickname, nickname);
  }
}
