import 'package:shared_preferences/shared_preferences.dart';
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
  
  // ===== 首次运行 =====
  
  static const String _keyFirstRun = 'first_run';
  
  /// 是否首次运行
  bool get isFirstRun => prefs.getBool(_keyFirstRun) ?? true;
  
  /// 设置已运行过
  Future<void> setFirstRunCompleted() async {
    await prefs.setBool(_keyFirstRun, false);
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
