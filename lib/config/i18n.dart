import 'prompts_zh.dart';
import 'prompts_en.dart';

/// 国际化支持类
class I18n {
  /// 获取系统提示�?
  static String getSystemPrompt(String lang) {
    switch (lang) {
      case 'en':
        return PromptsEn.systemPrompt;
      case 'cn':
      default:
        return PromptsZh.systemPrompt;
    }
  }

  /// 获取UI消息
  static Map<String, String> getMessages(String lang) {
    switch (lang) {
      case 'en':
        return PromptsEn.messages;
      case 'cn':
      default:
        return PromptsZh.messages;
    }
  }

  /// 获取指定消息
  static String getMessage(String lang, String key, [String defaultValue = '']) {
    final messages = getMessages(lang);
    return messages[key] ?? defaultValue;
  }
}
