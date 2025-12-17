import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../data/models/task_record.dart';

class HistoryService {
  static const String _fileName = 'task_history.json';
  static const String _tmpFileName = 'task_history.json.tmp';
  static Future<void> _writeQueue = Future.value();
  
  Future<File> get _file async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  /// 保存新记录
  Future<void> saveRecord(TaskRecord record) async {
    _writeQueue = _writeQueue.then((_) async {
      final records = await getAllRecords();
      // 新记录插到最前面
      records.insert(0, record);

      // 只保留最近50条
      if (records.length > 50) {
        records.removeRange(50, records.length);
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      final tmpFile = File('${directory.path}/$_tmpFileName');

      final content = jsonEncode(records.map((e) => e.toJson()).toList());
      await tmpFile.writeAsString(content, flush: true);
      await tmpFile.rename(file.path);
    });
    await _writeQueue;
  }

  /// 获取所有记录
  Future<List<TaskRecord>> getAllRecords() async {
    try {
      final file = await _file;
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      if (content.isEmpty) return [];
      
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => TaskRecord.fromJson(e)).toList();
    } catch (e) {
      print('Error reading history: $e');
      return [];
    }
  }

  /// 清空历史
  Future<void> clearHistory() async {
    _writeQueue = _writeQueue.then((_) async {
      final file = await _file;
      if (await file.exists()) {
        await file.delete();
      }
    });
    await _writeQueue;
  }
}
