/// 教务系统 API 服务（后端 API 版本）
///
/// 通过后端 API 与教务系统交互，处理 JSON 响应
library;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';

import '../models/models.dart';

/// 登录结果
sealed class LoginResult {
  const LoginResult();
}

/// 登录成功
class LoginSuccess extends LoginResult {
  final User user;

  const LoginSuccess(this.user);
}

/// 登录失败
class LoginFailure extends LoginResult {
  final String message;

  const LoginFailure(this.message);
}

/// 教务系统服务
class JwxtService {
  /// 后端 API 基础 URL
  final String baseUrl;

  /// HTTP 客户端
  late final Dio _dio;

  /// 当前会话 ID
  String? _sessionId;

  /// 会话过期时间（用于本地参考，实际过期检测通过 HTTP 401 状态码）
  DateTime? _sessionExpiresAt;

  /// 是否已登录
  /// 注意：实际会话过期检测通过 HTTP 401 状态码在拦截器中处理
  bool get isLoggedIn => _sessionId != null;

  /// 当前用户
  User? _currentUser;

  User? get currentUser => _currentUser;

  /// 自动重登回调
  Future<bool> Function()? _autoReloginCallback;

  /// 设置自动重登回调
  void setAutoReloginCallback(Future<bool> Function()? callback) {
    _autoReloginCallback = callback;
  }

  JwxtService({required this.baseUrl}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 添加拦截器处理会话头和 401 响应
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 自动附加会话头
          if (_sessionId != null) {
            options.headers['X-Academic-Session'] = _sessionId;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // 处理 401 未授权响应（会话过期）
          if (error.response?.statusCode == 401) {
            debugPrint('检测到 401 响应，会话已过期');
            if (await _tryAutoRelogin()) {
              // 重试原请求
              try {
                final options = error.requestOptions;
                // 更新会话头
                options.headers['X-Academic-Session'] = _sessionId;
                final response = await _dio.fetch(options);
                handler.resolve(response);
                return;
              } catch (e) {
                debugPrint('重试请求失败: $e');
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  /// 尝试自动重新登录
  Future<bool> _tryAutoRelogin() async {
    if (_autoReloginCallback == null) {
      debugPrint('未设置自动重登回调');
      return false;
    }

    debugPrint('会话已过期，尝试自动重新登录...');
    _sessionId = null;
    _sessionExpiresAt = null;

    try {
      final success = await _autoReloginCallback!();
      if (success) {
        debugPrint('自动重新登录成功');
        return true;
      }
    } catch (e) {
      debugPrint('自动重新登录失败: $e');
    }

    return false;
  }

  /// 自动登录
  ///
  /// [username] 学号
  /// [password] 密码
  /// [maxRetry] 最大重试次数（保留参数以保持 API 兼容）
  /// [onProgress] 进度回调
  Future<LoginResult> autoLogin({
    required String username,
    required String password,
    int maxRetry = 3,
    void Function(String message)? onProgress,
  }) async {
    onProgress?.call('正在登录...');
    return await login(username: username, password: password);
  }

  /// 执行登录
  ///
  /// [username] 学号
  /// [password] 密码
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    try {
      debugPrint('=== 登录调试信息 ===');
      debugPrint('username: $username');

      final response = await _dio.post(
        '/api/academic/login',
        data: {
          'username': username,
          'password': password,
        },
      );

      debugPrint('response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = response.data as Map<String, dynamic>;

        if (json['success'] == true) {
          final data = json['data'] as Map<String, dynamic>?;
          if (data == null) {
            debugPrint('登录响应缺少 data 字段');
            return const LoginFailure('登录响应格式错误');
          }

          final sessionId = data['sessionId'] as String?;
          final expiresAt = data['expiresAt'] as String?;

          if (sessionId == null || expiresAt == null) {
            debugPrint('登录响应缺少 sessionId 或 expiresAt');
            return const LoginFailure('登录响应格式错误');
          }

          _sessionId = sessionId;
          _sessionExpiresAt = DateTime.parse(expiresAt);
          _currentUser = User(studentId: username);

          debugPrint('登录成功！sessionId: $_sessionId');
          return LoginSuccess(_currentUser!);
        } else {
          final message = json['message'] as String? ?? '登录失败';
          debugPrint('登录失败: $message');
          return LoginFailure(message);
        }
      }

      return const LoginFailure('登录失败，请检查账号密码');
    } on DioException catch (e) {
      debugPrint('DioException: ${e.type} - ${e.message}');

      // 处理后端返回的错误响应
      if (e.response != null) {
        final json = e.response?.data;
        if (json is Map<String, dynamic>) {
          final message = json['message'] as String? ?? '登录失败';
          return LoginFailure(message);
        }
      }

      if (e.message == null) {
        return const LoginFailure('网络错误');
      }
      return LoginFailure('网络错误: ${e.message}');
    } catch (e) {
      debugPrint('Exception: $e');
      return LoginFailure('登录失败: $e');
    }
  }

  /// 登出
  Future<void> logout() async {
    try {
      debugPrint('登出');
      await _dio.post('/api/academic/logout');
    } catch (_) {
      // 忽略登出错误
    } finally {
      _sessionId = null;
      _sessionExpiresAt = null;
      _currentUser = null;
    }
  }

  /// 获取课程表
  ///
  /// [xnxq] 学年学期，格式如 "2024-2025-1"，为空则获取当前学期
  /// [refresh] 是否强制刷新缓存
  Future<Schedule?> getSchedule({String? xnxq, bool refresh = false}) async {
    if (!isLoggedIn) return null;

    try {
      final queryParams = <String, dynamic>{};
      if (xnxq != null) queryParams['xnxq'] = xnxq;
      if (refresh) queryParams['refresh'] = 'true';

      final response = await _dio.get(
        '/api/academic/schedule',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final json = response.data as Map<String, dynamic>;
        if (json['success'] == true) {
          // 后端可能直接返回数据，也可能包装在 data 字段中
          final data = json['data'] as Map<String, dynamic>? ?? json;
          return _parseScheduleFromJson(data);
        }
      }

      return null;
    } catch (e) {
      debugPrint('获取课程表失败: $e');
      return null;
    }
  }

  /// 从 JSON 解析课程表
  Schedule _parseScheduleFromJson(Map<String, dynamic> json) {
    final courses = <Course>[];

    // 后端可能使用 'courses' 或 'schedule' 作为课程列表的键
    final scheduleList =
        json['courses'] as List<dynamic>? ??
        json['schedule'] as List<dynamic>? ??
        [];
    for (final item in scheduleList) {
      final courseJson = item as Map<String, dynamic>;

      // 处理 weeks 字段：可能是数组或需要从 startWeek/endWeek 生成
      List<int> weeks;
      final weeksData = courseJson['weeks'];
      if (weeksData is List) {
        // 后端直接返回 weeks 数组
        weeks = weeksData.cast<int>();
      } else {
        // 根据 startWeek/endWeek 生成 weeks 列表
        final startWeek = courseJson['startWeek'] as int? ?? 1;
        final endWeek = courseJson['endWeek'] as int? ?? 20;
        weeks = List.generate(
          endWeek - startWeek + 1,
          (i) => startWeek + i,
        );
      }

      courses.add(
        Course(
          // 后端可能使用 'name' 或 'courseName' 作为课程名称
          name: courseJson['name'] as String? ??
              courseJson['courseName'] as String? ??
              '',
          teacher: courseJson['teacher'] as String?,
          location: courseJson['location'] as String?,
          weekday: courseJson['weekday'] as int? ?? 1,
          startSection: courseJson['startSection'] as int? ?? 1,
          endSection: courseJson['endSection'] as int? ?? 2,
          weekRange: courseJson['weekRange'] as String?,
          weeks: weeks,
        ),
      );
    }

    return Schedule(
      semester: json['semester'] as String?,
      currentWeek: json['currentWeek'] as int? ?? 1,
      courses: courses,
    );
  }

  /// 获取成绩
  ///
  /// [kksj] 开课时间（学期），如 "2024-2025-1"，为空则获取所有成绩
  /// [refresh] 是否强制刷新缓存
  Future<List<SemesterGrades>?> getGrades({
    String? kksj,
    bool refresh = false,
  }) async {
    if (!isLoggedIn) return null;

    try {
      final queryParams = <String, dynamic>{};
      if (kksj != null) queryParams['semester'] = kksj;
      if (refresh) queryParams['refresh'] = 'true';

      final response = await _dio.get(
        '/api/academic/grades',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final json = response.data as Map<String, dynamic>;
        if (json['success'] == true) {
          // 后端可能返回 'data' 数组或 'rows' 数组
          final dataList = json['data'] as List<dynamic>? ??
              json['rows'] as List<dynamic>? ??
              [];
          return _parseGradesFromJson(dataList, json);
        }
      }

      return null;
    } catch (e) {
      debugPrint('获取成绩失败: $e');
      return null;
    }
  }

  /// 从 JSON 解析成绩列表
  /// 
  /// 支持两种格式：
  /// 1. 按学期分组的格式: [{"semester": "...", "courses": [...]}]
  /// 2. 扁平的中文键名格式: [{"开课学期": "...", "课程名称": "...", ...}]
  List<SemesterGrades> _parseGradesFromJson(
    List<dynamic> jsonList,
    Map<String, dynamic> rootJson,
  ) {
    if (jsonList.isEmpty) return [];

    // 检测数据格式
    final firstItem = jsonList.first as Map<String, dynamic>;
    
    // 如果包含中文键名，使用扁平格式解析
    if (firstItem.containsKey('开课学期') || firstItem.containsKey('课程名称')) {
      return _parseGradesFromFlatJson(jsonList);
    }
    
    // 否则使用按学期分组的格式解析
    return _parseGradesFromGroupedJson(jsonList);
  }

  /// 从扁平的中文键名格式解析成绩
  List<SemesterGrades> _parseGradesFromFlatJson(List<dynamic> jsonList) {
    // 按学期分组
    final semesterMap = <String, List<Grade>>{};

    for (final item in jsonList) {
      final gradeJson = item as Map<String, dynamic>;
      
      final semester = gradeJson['开课学期'] as String? ?? '未知学期';
      final courseName = gradeJson['课程名称'] as String? ?? '';
      final courseCode = gradeJson['课程编号'] as String?;
      final score = gradeJson['成绩']?.toString() ?? '';
      final creditStr = gradeJson['学分'] as String? ?? '0';
      final gpaStr = gradeJson['绩点'] as String?;
      final courseType = gradeJson['课程属性'] as String?;
      
      final grade = Grade(
        courseName: courseName,
        courseCode: courseCode,
        score: score,
        gpa: gpaStr != null ? double.tryParse(gpaStr) : null,
        credit: double.tryParse(creditStr) ?? 0.0,
        courseType: courseType,
        semester: semester,
      );

      semesterMap.putIfAbsent(semester, () => []).add(grade);
    }

    // 转换为 SemesterGrades 列表
    final result = semesterMap.entries
        .map((e) => SemesterGrades(semester: e.key, grades: e.value))
        .toList();

    // 按学期倒序排列
    result.sort((a, b) => b.semester.compareTo(a.semester));
    return result;
  }

  /// 从按学期分组的格式解析成绩
  List<SemesterGrades> _parseGradesFromGroupedJson(List<dynamic> jsonList) {
    final result = <SemesterGrades>[];

    for (final semesterData in jsonList) {
      final semesterJson = semesterData as Map<String, dynamic>;
      final semester = semesterJson['semester'] as String? ?? '未知学期';
      final coursesJson = semesterJson['courses'] as List<dynamic>? ?? [];

      final grades = <Grade>[];
      for (final courseData in coursesJson) {
        final courseJson = courseData as Map<String, dynamic>;

        // 处理 score 类型转换（数字转字符串）
        final scoreValue = courseJson['score'];
        final score = scoreValue?.toString() ?? '';

        grades.add(
          Grade(
            courseName: courseJson['courseName'] as String? ?? '',
            courseCode: courseJson['courseId'] as String?,
            score: score,
            gpa: (courseJson['gradePoint'] as num?)?.toDouble(),
            credit: (courseJson['credit'] as num?)?.toDouble() ?? 0.0,
            courseType: courseJson['courseType'] as String?,
            teacher: courseJson['teacher'] as String?,
            semester: semester,
          ),
        );
      }

      result.add(SemesterGrades(semester: semester, grades: grades));
    }

    // 按学期倒序排列
    result.sort((a, b) => b.semester.compareTo(a.semester));
    return result;
  }

  /// 获取用户信息
  ///
  /// [refresh] 是否强制刷新缓存
  Future<User?> getUserInfo({bool refresh = false}) async {
    if (!isLoggedIn) return null;

    try {
      final queryParams = <String, dynamic>{};
      if (refresh) queryParams['refresh'] = 'true';

      final response = await _dio.get(
        '/api/academic/me',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final json = response.data as Map<String, dynamic>;
        if (json['success'] == true) {
          _currentUser = _parseUserFromJson(json['data'] as Map<String, dynamic>);
          return _currentUser;
        }
      }

      return _currentUser;
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return _currentUser;
    }
  }

  /// 从 JSON 解析用户信息
  User _parseUserFromJson(Map<String, dynamic> json) {
    return User(
      studentId: json['studentId'] as String? ?? '',
      name: json['name'] as String?,
      college: json['college'] as String?,
      major: json['major'] as String?,
      className: json['className'] as String?,
      enrollmentYear: json['enrollmentYear'] as String?,
      studyLevel: json['studyLevel'] as String?,
    );
  }

  /// 获取可用学期列表
  ///
  /// [refresh] 是否强制刷新缓存
  /// 返回学期 ID 列表，如 ["2024-2025-1", "2023-2024-2"]
  Future<List<String>> getAvailableSemesters({bool refresh = false}) async {
    if (!isLoggedIn) return [];

    try {
      final queryParams = <String, dynamic>{};
      if (refresh) queryParams['refresh'] = 'true';

      final response = await _dio.get(
        '/api/academic/semesters',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final json = response.data as Map<String, dynamic>;
        if (json['success'] == true) {
          final data = json['data'] as Map<String, dynamic>?;
          if (data != null) {
            // API 返回格式: { "semesters": [{ "id": "...", "name": "..." }, ...] }
            final semestersList = data['semesters'] as List<dynamic>? ?? [];
            return semestersList.map((item) {
              if (item is Map<String, dynamic>) {
                // 返回学期 ID
                return item['id'] as String? ?? '';
              }
              return item.toString();
            }).where((id) => id.isNotEmpty).toList();
          }
        }
      }

      return [];
    } catch (e) {
      debugPrint('获取学期列表失败: $e');
      return [];
    }
  }

  /// 释放资源
  void dispose() {
    // 清除会话状态
    _sessionId = null;
    _sessionExpiresAt = null;
    _currentUser = null;
    _autoReloginCallback = null;
    
    // 关闭 HTTP 客户端
    _dio.close();
  }
}
