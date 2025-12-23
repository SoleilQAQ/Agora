/// 课表导出/导入服务
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'auth_storage.dart';

/// 课表导出/导入服务
class ScheduleImportExportService {
  /// 导出课表为JSON字符串
  static String exportToJson(Schedule schedule) {
    final json = schedule.toJson();
    return jsonEncode(json);
  }

  /// 从JSON字符串导入课表
  static Schedule? importFromJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return Schedule.fromJson(json);
    } catch (e) {
      debugPrint('导入课表失败: $e');
      return null;
    }
  }

  /// 导出课表为JSON文件
  static Future<bool> exportToFile(Schedule schedule, String filename) async {
    try {
      final jsonString = exportToJson(schedule);

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';

      // 写入文件
      final file = File(filePath);
      await file.writeAsString(jsonString);

      debugPrint('课表导出成功: $filePath');
      return true;
    } catch (e) {
      debugPrint('导出课表到文件失败: $e');
      return false;
    }
  }

  /// 从文件导入课表
  static Future<Schedule?> importFromFile() async {
    PlatformFile? file;
    
    try {
      // 选择文件 - 使用 FileType.any 避免某些设备不支持自定义扩展名过滤
      // withReadStream: false 避免某些设备上的兼容性问题
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true, // 直接读取文件数据，避免路径访问问题
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('未选择文件');
        return null;
      }

      file = result.files.single;
    } catch (e) {
      // 某些设备（如部分国产 ROM）在文件选择器关闭时可能崩溃
      // 这是系统级 bug，我们无法修复，只能捕获并提示用户
      debugPrint('文件选择器异常: $e');
      throw Exception('文件选择器出现问题，请尝试重启应用后再试');
    }
    
    if (file == null) {
      return null;
    }

    // 手动验证文件扩展名
    final fileName = file.name.toLowerCase();
    if (!fileName.endsWith('.json')) {
      debugPrint('文件格式错误: 请选择 JSON 文件');
      throw Exception('请选择 JSON 格式的文件');
    }

    // 优先使用内存中的数据
    String jsonString;
    try {
      if (file.bytes != null) {
        jsonString = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        // 回退到文件路径读取
        final diskFile = File(file.path!);
        jsonString = await diskFile.readAsString();
      } else {
        throw Exception('无法读取文件内容');
      }
    } catch (e) {
      debugPrint('读取文件内容失败: $e');
      throw Exception('读取文件失败: $e');
    }

    return importFromJson(jsonString);
  }

  /// 分享课表JSON文件
  static Future<bool> shareScheduleFile(Schedule schedule) async {
    try {
      final jsonString = exportToJson(schedule);

      // 获取临时目录
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/schedule_$timestamp.json';

      // 写入文件
      final file = File(filePath);
      await file.writeAsString(jsonString);

      // 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: '课程表',
        text: '分享课程表文件',
      );

      debugPrint('课表文件分享成功');
      return true;
    } catch (e) {
      debugPrint('分享课表文件失败: $e');
      return false;
    }
  }

  /// 保存导入的课表到缓存
  static Future<bool> saveImportedSchedule(Schedule schedule) async {
    try {
      final jsonString = exportToJson(schedule);
      await AuthStorage.saveScheduleCache(jsonString);
      debugPrint('导入的课表已保存到缓存');
      return true;
    } catch (e) {
      debugPrint('保存导入的课表失败: $e');
      return false;
    }
  }

  /// 导出课表为文件
  static Future<void> showExportOptionsDialog(
    BuildContext context,
    Schedule schedule,
  ) async {
    final success = await shareScheduleFile(schedule);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success ? '导出成功' : '导出失败')));
    }
  }

  /// 从文件导入课表
  static Future<Schedule?> showImportOptionsDialog(BuildContext context) async {
    try {
      return await importFromFile();
    } catch (e) {
      // 将异常重新抛出，让调用方处理并显示错误信息
      rethrow;
    }
  }
}
