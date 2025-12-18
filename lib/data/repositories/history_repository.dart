import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_history.dart';

class HistoryRepository {
  static HistoryRepository? _instance;
  SharedPreferences? _prefs;

  static const String _keyHistoryMeta = 'history_meta';
  static const String _keySessionPrefix = 'session_';

  HistoryRepository._();

  static HistoryRepository get instance {
    _instance ??= HistoryRepository._();
    return _instance!;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('HistoryRepository not initialized. Call init() first.');
    }
    return _prefs!;
  }

  /// Get all sessions (metadata only, messages list is empty)
  List<ConversationSession> getSessions() {
    final jsonString = prefs.getString(_keyHistoryMeta);
    if (jsonString == null) return [];

    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((e) => ConversationSession.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt)); // Newest first
    } catch (e) {
      return [];
    }
  }

  /// Get full session details including messages
  ConversationSession? getSession(String id) {
    // 1. Check if it exists in meta
    final sessions = getSessions();
    final meta = sessions.where((s) => s.id == id).firstOrNull;
    if (meta == null) return null;

    // 2. Load content
    final contentJson = prefs.getString('$_keySessionPrefix$id');
    if (contentJson == null) {
      // Fallback: if content missing but meta exists, return empty session
      return meta;
    }

    try {
      return ConversationSession.fromJson(jsonDecode(contentJson));
    } catch (e) {
      return meta;
    }
  }

  /// Save or Update a session
  Future<void> saveSession(ConversationSession session) async {
    // 1. Save full content
    await prefs.setString(
        '$_keySessionPrefix${session.id}', jsonEncode(session.toJson()));

    // 2. Update meta list
    final sessions = getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);

    // Create a meta version (without messages for lightweight list)
    final metaSession = session.copyWith(messages: []);

    if (index >= 0) {
      sessions[index] = metaSession;
    } else {
      sessions.add(metaSession);
    }

    await prefs.setString(
        _keyHistoryMeta, jsonEncode(sessions.map((e) => e.toJson()).toList()));
  }

  /// Delete a session
  Future<void> deleteSession(String id) async {
    // 1. Remove content
    await prefs.remove('$_keySessionPrefix$id');

    // 2. Remove from meta
    final sessions = getSessions();
    sessions.removeWhere((s) => s.id == id);
    await prefs.setString(
        _keyHistoryMeta, jsonEncode(sessions.map((e) => e.toJson()).toList()));
  }

  /// Clear all history
  Future<void> clearAll() async {
    final sessions = getSessions();
    for (final s in sessions) {
      await prefs.remove('$_keySessionPrefix${s.id}');
    }
    await prefs.remove(_keyHistoryMeta);
  }
}

extension ListFirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
