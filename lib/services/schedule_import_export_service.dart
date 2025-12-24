/// 课表导出/导入服务
///
/// - 导入：file_selector openFile（SAF / ACTION_OPEN_DOCUMENT）
/// - 导出：使用 file_selector getSaveLocation 让用户选择保存位置
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import 'auth_storage.dart';

class ScheduleImportExportService {
  /// 导出课表为 JSON 字符串
  static String exportToJson(Schedule schedule) {
    final map = schedule.toJson();
    return jsonEncode(map);
  }

  /// 从 JSON 字符串导入课表（解析失败返回 null）
  static Schedule? importFromJson(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('导入课表失败: JSON 顶层不是对象');
        return null;
      }
      return Schedule.fromJson(decoded);
    } catch (e) {
      debugPrint('导入课表失败: $e');
      return null;
    }
  }

  /// =========================
  /// 导入（SAF）
  /// =========================
  static Future<Schedule?> importFromFile() async {
    try {
      final typeGroup = XTypeGroup(
        label: 'JSON',
        extensions: const ['json'],
        mimeTypes: const ['application/json', 'text/json', 'text/plain'],
      );

      final XFile? xfile = await openFile(acceptedTypeGroups: [typeGroup]);
      if (xfile == null) {
        debugPrint('未选择文件');
        return null;
      }

      // 双保险校验
      final nameLower = xfile.name.toLowerCase();
      if (!nameLower.endsWith('.json')) {
        throw Exception('请选择 JSON 格式的文件（.json）');
      }

      final bytes = await xfile.readAsBytes();
      String jsonString = utf8.decode(bytes, allowMalformed: true).trim();
      if (jsonString.startsWith('\uFEFF')) {
        jsonString = jsonString.substring(1);
      }

      final schedule = importFromJson(jsonString);
      if (schedule == null) {
        throw Exception('JSON 解析失败：请确认文件结构正确');
      }
      return schedule;
    } catch (e) {
      debugPrint('从文件导入课表失败: $e');
      throw Exception('导入失败：$e');
    }
  }

  /// =========================
  /// 导出到应用文档目录（最稳定的方式）
  /// =========================
  static Future<String?> exportToAppDocuments(
      Schedule schedule, {
        String? filename,
      }) async {
    try {
      final jsonString = exportToJson(schedule);
      final dir = await getApplicationDocumentsDirectory();
      final name = filename ??
          'schedule_${DateTime.now().millisecondsSinceEpoch}.json';
      final filePath = '${dir.path}/$name';

      final file = File(filePath);
      await file.writeAsString(jsonString, flush: true);

      debugPrint('课表导出到应用文档目录成功: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('导出到应用文档目录失败: $e');
      return null;
    }
  }

  /// =========================
  /// 导出到用户选择的位置
  /// Android: 使用 MediaStore API 保存到公共下载目录
  /// iOS: 先保存到应用文档目录，然后通过分享让用户选择保存位置
  /// 桌面: 使用 SAF 让用户选择保存位置
  /// =========================
  static Future<(bool, String?)> exportToUserSelectedLocation(Schedule schedule) async {
    try {
      final jsonString = exportToJson(schedule);
      
      // 生成默认文件名
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final suggestedName = 'schedule_$dateStr.json';
      
      // Android 使用 MediaStore API 保存到公共下载目录
      if (Platform.isAndroid) {
        final result = await _saveToDownloadsAndroid(suggestedName, jsonString);
        return result;
      }
      
      // iOS 使用分享功能让用户选择保存位置（"存储到文件"选项）
      if (Platform.isIOS) {
        final result = await _saveViaShareIOS(suggestedName, jsonString);
        return result;
      }
      
      // 桌面平台使用 SAF 让用户选择保存位置
      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );
      
      if (saveLocation == null) {
        debugPrint('用户取消了保存');
        return (false, null);
      }
      
      // 写入文件
      final file = File(saveLocation.path);
      await file.writeAsString(jsonString, flush: true);
      
      debugPrint('课表导出成功: ${saveLocation.path}');
      return (true, saveLocation.path);
    } catch (e) {
      debugPrint('导出课表失败: $e');
      return (false, null);
    }
  }

  /// iOS 通过分享功能保存文件
  /// 用户可以在分享菜单中选择"存储到文件"来保存到任意位置
  static Future<(bool, String?)> _saveViaShareIOS(String filename, String content) async {
    try {
      // 先保存到临时目录
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);
      await file.writeAsString(content, flush: true);
      
      // 使用分享功能，用户可以选择"存储到文件"
      final result = await Share.shareXFiles(
        [XFile(filePath)],
      );
      
      // 检查分享结果
      if (result.status == ShareResultStatus.success || 
          result.status == ShareResultStatus.dismissed) {
        // dismissed 也算成功，因为用户可能已经保存了文件
        debugPrint('iOS 课表导出完成');
        return (true, '已通过分享保存');
      }
      
      return (false, null);
    } catch (e) {
      debugPrint('iOS 保存文件失败: $e');
      return (false, null);
    }
  }

  /// Android 使用 MediaStore API 保存文件到公共下载目录
  static Future<(bool, String?)> _saveToDownloadsAndroid(String filename, String content) async {
    try {
      const channel = MethodChannel('com.soleil.agora/file_saver');
      final result = await channel.invokeMethod<String>('saveToDownloads', {
        'filename': filename,
        'content': content,
        'mimeType': 'application/json',
      });
      
      if (result != null) {
        debugPrint('课表导出成功: $result');
        return (true, result);
      }
      return (false, null);
    } catch (e) {
      debugPrint('保存到下载目录失败: $e');
      return (false, null);
    }
  }

  /// =========================
  /// 分享课表 JSON 文件
  /// =========================
  static Future<bool> shareScheduleFile(Schedule schedule) async {
    try {
      final jsonString = exportToJson(schedule);
      final directory = await getTemporaryDirectory();
      // 使用纯英文文件名避免兼容性问题
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final filename = 'schedule_$dateStr.json';
      final filePath = '${directory.path}/$filename';

      final file = File(filePath);
      await file.writeAsString(jsonString, flush: true);

      // 使用 shareXFiles 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
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

  /// =========================
  /// UI 封装：导出选项对话框
  /// =========================
  static Future<void> showExportOptionsDialog(
      BuildContext context,
      Schedule schedule,
      ) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示器
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outline.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // 标题
            Text(
              '导出课表',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '选择导出方式',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            // 保存到文件
            _buildExportOption(
              context,
              theme,
              colorScheme,
              Icons.save_rounded,
              '保存到文件',
              '保存到下载目录',
              () async {
                Navigator.pop(context);
                final (success, path) = await exportToUserSelectedLocation(schedule);
                if (context.mounted) {
                  if (success && path != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        icon: Icon(Icons.check_circle, color: colorScheme.primary, size: 48),
                        title: const Text('导出成功'),
                        content: Text('文件已保存到:\n$path'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('导出失败'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            // 分享给他人
            _buildExportOption(
              context,
              theme,
              colorScheme,
              Icons.share_rounded,
              '分享给他人',
              '通过微信、QQ等应用发送课表文件',
              () async {
                Navigator.pop(context);
                final success = await shareScheduleFile(schedule);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? '已打开分享' : '分享失败'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  /// 构建导出选项按钮
  static Widget _buildExportOption(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// UI 封装：导入
  static Future<Schedule?> showImportOptionsDialog(BuildContext context) async {
    try {
      return await importFromFile();
    } catch (e) {
      rethrow;
    }
  }
}
