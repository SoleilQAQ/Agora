/// 天气服务
/// 从天气 API 获取天气数据
library;

import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'auth_storage.dart';

/// 天气信息
class WeatherInfo {
  final String condition;
  final String description;
  final double temperature;
  final double feelsLike;
  final double minTemp;
  final double maxTemp;
  final int humidity;
  final int pressure;
  final double windSpeed;
  final int? windDegree;
  final double? windGust;
  final int visibility;
  final int clouds;
  final String icon;
  final String iconUrl;
  final String cityName;
  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? dataTime;

  const WeatherInfo({
    required this.condition,
    required this.description,
    required this.temperature,
    required this.feelsLike,
    required this.minTemp,
    required this.maxTemp,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    this.windDegree,
    this.windGust,
    required this.visibility,
    this.clouds = 0,
    required this.icon,
    required this.iconUrl,
    required this.cityName,
    this.sunrise,
    this.sunset,
    this.dataTime,
  });

  /// 从 API JSON 创建
  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final location = data['location'] as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>;
    final temp = current['temperature'] as Map<String, dynamic>;
    final wind = current['wind'] as Map<String, dynamic>;

    // 解析时间戳
    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
      return null;
    }

    return WeatherInfo(
      condition: current['main'] as String? ?? '未知',
      description: current['description'] as String? ?? '未知',
      temperature: (temp['current'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (temp['feels_like'] as num?)?.toDouble() ?? 0.0,
      minTemp: (temp['min'] as num?)?.toDouble() ?? 0.0,
      maxTemp: (temp['max'] as num?)?.toDouble() ?? 0.0,
      humidity: current['humidity'] as int? ?? 0,
      pressure: current['pressure'] as int? ?? 0,
      windSpeed: (wind['speed'] as num?)?.toDouble() ?? 0.0,
      windDegree: wind['degree'] as int?,
      windGust: (wind['gust'] as num?)?.toDouble(),
      visibility: current['visibility'] as int? ?? 0,
      clouds: current['clouds'] as int? ?? 0,
      icon: current['icon'] as String? ?? '01d',
      iconUrl: current['iconUrl'] as String? ?? '',
      cityName: location['cityName'] as String? ?? '未知',
      sunrise: parseTimestamp(current['sunrise']),
      sunset: parseTimestamp(current['sunset']),
      dataTime: parseTimestamp(current['dataTime']),
    );
  }

  /// 从缓存 JSON 创建
  factory WeatherInfo.fromCacheJson(Map<String, dynamic> json) {
    return WeatherInfo(
      condition: json['condition'] as String? ?? '未知',
      description: json['description'] as String? ?? '未知',
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      feelsLike: (json['feelsLike'] as num?)?.toDouble() ?? 0.0,
      minTemp: (json['minTemp'] as num?)?.toDouble() ?? 0.0,
      maxTemp: (json['maxTemp'] as num?)?.toDouble() ?? 0.0,
      humidity: json['humidity'] as int? ?? 0,
      pressure: json['pressure'] as int? ?? 0,
      windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
      windDegree: json['windDegree'] as int?,
      windGust: (json['windGust'] as num?)?.toDouble(),
      visibility: json['visibility'] as int? ?? 0,
      clouds: json['clouds'] as int? ?? 0,
      icon: json['icon'] as String? ?? '01d',
      iconUrl: json['iconUrl'] as String? ?? '',
      cityName: json['cityName'] as String? ?? '未知',
      sunrise: json['sunrise'] != null
          ? DateTime.tryParse(json['sunrise'] as String)
          : null,
      sunset: json['sunset'] != null
          ? DateTime.tryParse(json['sunset'] as String)
          : null,
      dataTime: json['dataTime'] != null
          ? DateTime.tryParse(json['dataTime'] as String)
          : null,
    );
  }

  /// 转换为缓存 JSON
  Map<String, dynamic> toCacheJson() {
    return {
      'condition': condition,
      'description': description,
      'temperature': temperature,
      'feelsLike': feelsLike,
      'minTemp': minTemp,
      'maxTemp': maxTemp,
      'humidity': humidity,
      'pressure': pressure,
      'windSpeed': windSpeed,
      'windDegree': windDegree,
      'windGust': windGust,
      'visibility': visibility,
      'clouds': clouds,
      'icon': icon,
      'iconUrl': iconUrl,
      'cityName': cityName,
      'sunrise': sunrise?.toIso8601String(),
      'sunset': sunset?.toIso8601String(),
      'dataTime': dataTime?.toIso8601String(),
    };
  }

  /// 获取风向描述
  String get windDirection {
    if (windDegree == null) return '';
    final degree = windDegree!;
    if (degree >= 337.5 || degree < 22.5) return '北风';
    if (degree >= 22.5 && degree < 67.5) return '东北风';
    if (degree >= 67.5 && degree < 112.5) return '东风';
    if (degree >= 112.5 && degree < 157.5) return '东南风';
    if (degree >= 157.5 && degree < 202.5) return '南风';
    if (degree >= 202.5 && degree < 247.5) return '西南风';
    if (degree >= 247.5 && degree < 292.5) return '西风';
    if (degree >= 292.5 && degree < 337.5) return '西北风';
    return '';
  }

  /// 获取风力等级
  String get windLevel {
    if (windSpeed < 0.3) return '0级';
    if (windSpeed < 1.6) return '1级';
    if (windSpeed < 3.4) return '2级';
    if (windSpeed < 5.5) return '3级';
    if (windSpeed < 8.0) return '4级';
    if (windSpeed < 10.8) return '5级';
    if (windSpeed < 13.9) return '6级';
    if (windSpeed < 17.2) return '7级';
    if (windSpeed < 20.8) return '8级';
    if (windSpeed < 24.5) return '9级';
    if (windSpeed < 28.5) return '10级';
    if (windSpeed < 32.7) return '11级';
    return '12级+';
  }

  /// 获取能见度描述
  String get visibilityDesc {
    // TODO
    final km = visibility / 1000;
    if (km >= 10) return '${km.toStringAsFixed(0)}km (优)';
    if (km >= 5) return '${km.toStringAsFixed(1)}km (良)';
    if (km >= 1) return '${km.toStringAsFixed(1)}km (中)';
    return '${visibility}m (差)';
  }

  /// 获取天气图标 emoji
  String get iconEmoji {
    // 根据 OpenWeatherMap icon code 返回对应的 emoji
    switch (icon) {
      case '01d': // 晴天（白天）
        return '☀️';
      case '01n': // 晴天（夜间）
        return '🌙';
      case '02d': // 少云（白天）
        return '🌤️';
      case '02n': // 少云（夜间）
        return '☁️';
      case '03d': // 多云
      case '03n':
        return '☁️';
      case '04d': // 阴天
      case '04n':
        return '☁️';
      case '09d': // 阵雨
      case '09n':
        return '🌧️';
      case '10d': // 雨（白天）
        return '🌦️';
      case '10n': // 雨（夜间）
        return '🌧️';
      case '11d': // 雷雨
      case '11n':
        return '⛈️';
      case '13d': // 雪
      case '13n':
        return '🌨️';
      case '50d': // 雾
      case '50n':
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  /// 默认天气数据（API 请求失败时使用）
  static WeatherInfo defaultWeather() {
    return const WeatherInfo(
      condition: 'Unknown',
      description: '暂无数据',
      temperature: 0,
      feelsLike: 0,
      minTemp: 0,
      maxTemp: 0,
      humidity: 0,
      pressure: 0,
      windSpeed: 0,
      visibility: 0,
      icon: '01d',
      iconUrl: '',
      cityName: '未知',
    );
  }
}

/// 天气服务
class WeatherService {
  static const String _baseUrl = 'http://47.122.112.62:8000';

  Dio? _dio;

  /// 懒加载 Dio 实例，减少内存占用
  Dio get dio {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio?.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));



    return _dio!;
  }



  WeatherService();

  /// 从缓存获取天气（如果有效）
  Future<WeatherInfo?> _getFromCache() async {
    try {
      final (cacheData, isValid) = await AuthStorage.getWeatherCache();
      if (cacheData != null && isValid) {
        final json = jsonDecode(cacheData) as Map<String, dynamic>;
        return WeatherInfo.fromCacheJson(json);
      }
    } catch (e) {
      debugPrint('读取天气缓存失败: $e');
    }
    return null;
  }

  /// 保存天气到缓存
  Future<void> _saveToCache(WeatherInfo weather) async {
    try {
      final json = jsonEncode(weather.toCacheJson());
      await AuthStorage.saveWeatherCache(json);
    } catch (e) {
      ('保存天气缓存失败: $e');
    }
  }

  /// 根据城市名获取天气（拼音格式）
  /// [cityPinyin] 城市拼音，如 "beijing", "changsha", "loudi"
  Future<WeatherInfo> getWeatherByCity({
    required String cityPinyin,
    bool forceRefresh = false,
  }) async {
    // 如果不是强制刷新，先尝试从缓存获取
    if (!forceRefresh) {
      final cached = await _getFromCache();
      if (cached != null) {
        ('使用天气缓存数据');
        return cached;
      }
    }

    try {
      final response = await dio.get(
        '/api/weather/current',
        // '/api/weather',
        queryParameters: {'city': cityPinyin},
      );

      if (response.statusCode == 200 && response.data != null) {
        final json = response.data as Map<String, dynamic>;
        debugPrint("the info of the weather: $json");
        if (json['success'] == true) {
          final weather = WeatherInfo.fromJson(json);
          // 保存到缓存
          await _saveToCache(weather);
          return weather;
        }
      }

      ('天气 API 返回异常: ${response.data}');
      // API失败时尝试返回过期缓存
      final (cacheData, _) = await AuthStorage.getWeatherCache();
      if (cacheData != null) {
        final json = jsonDecode(cacheData) as Map<String, dynamic>;
        return WeatherInfo.fromCacheJson(json);
      }
      return WeatherInfo.defaultWeather();
    } catch (e) {
      debugPrint('获取天气失败: $e');
      // 网络失败时尝试返回过期缓存
      final (cacheData, _) = await AuthStorage.getWeatherCache();
      if (cacheData != null) {
        final json = jsonDecode(cacheData) as Map<String, dynamic>;
        return WeatherInfo.fromCacheJson(json);
      }
      return WeatherInfo.defaultWeather();
    }
  }

  /// 获取天气（使用用户保存的城市或默认城市）
  /// 如果用户没有设置城市，返回 null，提示用户先选择城市
  Future<WeatherInfo?> getWeather({bool forceRefresh = false}) async {
    // 如果不是强制刷新，先尝试从缓存获取
    if (!forceRefresh) {
      final cached = await _getFromCache();
      if (cached != null) {
        debugPrint('使用天气缓存数据');
        return cached;
      }
    }

    // 获取用户保存的城市
    final cityPinyin = await AuthStorage.getWeatherCity();

    // 如果用户没有设置城市，返回 null
    if (cityPinyin == null || cityPinyin.isEmpty) {
      return null;
    }

    return getWeatherByCity(
      cityPinyin: cityPinyin,
      forceRefresh: true, // 已经检查过缓存了
    );
  }

  /// 检查用户是否已设置天气城市
  Future<bool> hasCity() async {
    final cityPinyin = await AuthStorage.getWeatherCity();
    return cityPinyin != null && cityPinyin.isNotEmpty;
  }

  void dispose() {
    _dio?.close();
    _dio = null;
  }
}

/// 城市数据 - 省市区三级联动（从 JSON 文件动态加载）
class ChinaRegionData {
  // 缓存解析后的数据
  static Map<String, Map<String, Map<String, String>>>? _regionData;
  static bool _isLoading = false;
  static List<Map<String, dynamic>>? _rawData;

  /// 初始化城市数据（从 assets 加载 JSON）
  static Future<void> init() async {
    if (_regionData != null || _isLoading) return;
    _isLoading = true;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/china_regions.json',
      );
      final List<dynamic> jsonData = json.decode(jsonString);
      _rawData = jsonData.cast<Map<String, dynamic>>();
      _parseRegionData();
    } catch (e) {
      print('加载城市数据失败: $e');
      _regionData = {};
    } finally {
      _isLoading = false;
    }
  }

  /// 解析 JSON 数据为省市区结构
  /// 解析 JSON 数据为省市区结构
  static void _parseRegionData() {
    if (_rawData == null) return;

    _regionData = {};

    for (final item in _rawData!) {
      final String rawAdmin = (item['行政归属'] ?? '').toString().trim();
      final String rawShort = (item['城市简称'] ?? '').toString().trim();
      final String pinyin = (item['拼音'] ?? '').toString().toLowerCase();

      if (rawAdmin.isEmpty || pinyin.isEmpty) continue;

      // 拆分两个路径
      final adminParts =
      rawAdmin.split('/').where((e) => e.trim().isNotEmpty).toList();
      final shortParts =
      rawShort.split('/').where((e) => e.trim().isNotEmpty).toList();

      if (adminParts.isEmpty) continue;

      String province = adminParts[0].trim();
      String city = '';
      String district = '';

      // 统一名字
      if (province.contains('台湾')) province = '台湾';
      if (province.contains('香港')) province = '香港';
      if (province.contains('澳门')) province = '澳门';

      const municipalities = ['北京市', '天津市', '上海市', '重庆市'];

      // ===== 1. 香港 / 澳门：省 = 市 = “香港/澳门”，区从 城市简称 来 =====
      if (province == '香港' || province == '澳门') {
        city = province;

        // 城市简称就是各个“区”的名字：香港 / 九龙 / 荃湾 / 新界 / 澳门 / 路环岛…
        if (shortParts.isNotEmpty) {
          district = shortParts.last.trim();
        } else {
          district = province;
        }
      }
      // ===== 2. 台湾：省 = 台湾，市 = 高雄/台中/台北，区从城市简称最后一段取 =====
      else if (province == '台湾') {
        if (adminParts.length >= 2) {
          city = adminParts[1].trim(); // 高雄 / 台中 / 台北
        } else if (shortParts.length >= 2) {
          city = shortParts[1].trim();
        } else {
          city = '台北';
        }

        // 城市简称：台湾/高雄/恒春 -> 恒春
        if (shortParts.length >= 3) {
          district = shortParts[2].trim();
        } else if (shortParts.length >= 2 &&
            shortParts.last.trim() != city) {
          // 类似“台湾/高雄/屏东”也可以兜一下
          district = shortParts.last.trim();
        } else {
          district = '';
        }
      }
      // ===== 3. 直辖市：北京市 等 =====
      else if (municipalities.contains(province)) {
        city = province; // 北京市 / 上海市 / 天津市 / 重庆市

        // 优先使用 行政归属 的最后一段，通常是“朝阳区 / 海淀区 / 浦东新区”等全称
        if (adminParts.length >= 2) {
          district = adminParts.last.trim();    // "朝阳区"
        } else if (shortParts.length >= 2) {
          district = shortParts.last.trim();    // 才退回短名 "朝阳"
        }
      }
      // ===== 4. 普通省份 =====
      else {
        // 1) city 优先用 行政归属 第二段
        if (adminParts.length >= 2) {
          city = adminParts[1].trim();          // 比如 "广州市"
        } else if (shortParts.length >= 2) {
          city = shortParts[1].trim();          // 兜底
        }

        // 2) district 优先用 行政归属 的最后一段（带“区/县/旗”等后缀）
        if (adminParts.length >= 3) {
          district = adminParts.last.trim();    // 比如 "天河区"
        } else if (shortParts.length >= 3) {
          district = shortParts[2].trim();      // 兜底短名
        } else if (shortParts.length >= 2 &&
            shortParts.last.trim() != city) {
          district = shortParts.last.trim();
        }
      }

      if (city.isEmpty) continue;

      // 初始化省 & 市
      _regionData!.putIfAbsent(province, () => {});
      _regionData![province]!.putIfAbsent(city, () => {});

      final cityMap = _regionData![province]![city]!;

      // 1) 如果有真正的“区”，并且区名 != city，就作为第三级存进去
      if (district.isNotEmpty && district != city) {
        cityMap[district] = pinyin;
      } else {
        // 2) 否则把城市本身的拼音当成一个兜底（比如 台湾/台北）
        cityMap.putIfAbsent(city, () => pinyin);
      }

      if (province == '北京市' && city == '北京市') {
        debugPrint('DEBUG: 北京市下的区列表: ${_regionData![province]![city]!.keys.toList()}');
      }
    }


    _rawData = null;
  }


  /// 确保数据已加载
  static Future<void> _ensureLoaded() async {
    if (_regionData == null && !_isLoading) {
      await init();
    }
    // 等待加载完成
    while (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// 获取所有省份（同步版本，需先调用 init）
  static List<String> getProvinces() {
    if (_regionData == null) return [];
    return _regionData!.keys.toList();
  }

  /// 获取所有省份（异步版本）
  static Future<List<String>> getProvincesAsync() async {
    await _ensureLoaded();
    return _regionData?.keys.toList() ?? [];
  }

  /// 获取省份下的城市
  static List<String> getCities(String province) {
    if (_regionData == null) return [];
    final provinceData = _regionData![province];
    if (provinceData == null) return [];
    return provinceData.keys.toList();
  }

  /// 获取省份下的城市（异步版本）
  static Future<List<String>> getCitiesAsync(String province) async {
    await _ensureLoaded();
    return getCities(province);
  }

  /// 获取城市下的区县
/*  static List<String> getDistricts(String province, String city) {
    if (_regionData == null) return [];
    final provinceData = _regionData![province];
    if (provinceData == null) return [];
    final cityData = provinceData[city];
    if (cityData == null) return [];

    // 过滤掉“与城市同名”的那一条（如 北京市/北京市/北京市、济南市/济南市/济南市 里的最后一级）
    final districts = cityData.keys
        .where((name) => name != city)
        .toList();

    // 去掉与城市同名的“汇总区县”，比如 “济南市/济南市”
    districts.removeWhere((d) => d == city);

    return districts;
  }*/

  static String _normalizeName(String name) {
    // 去掉末尾的 常见行政后缀：市 / 区 / 县 / 盟 / 州 / 特别行政区 之类
    return name
        .replaceAll(RegExp(r'(特别行政区)$'), '')
        .replaceAll(RegExp(r'[市区县盟州]$'), '')
        .trim();
  }

  /// 获取城市下的区县列表
  static List<String> getDistricts(String province, String city) {
    if (_regionData == null) return [];

    final cityMap = _regionData![province]?[city];
    if (cityMap == null) return [];

    final districts = cityMap.keys.toList();

    final normalizedCity = _normalizeName(city);

    districts.removeWhere((name) {
      final normalizedName = _normalizeName(name);
      return normalizedName == normalizedCity;
    });

    return districts;
  }

  /// 获取城市下的区县（异步版本）
  static Future<List<String>> getDistrictsAsync(
    String province,
    String city,
  ) async {
    await _ensureLoaded();
    return getDistricts(province, city);
  }

  /// 获取区县的拼音
  static String? getPinyin(String province, String city, String? district) {
    if (_regionData == null) return null;
    final provinceData = _regionData![province];
    if (provinceData == null) return null;
    final cityData = provinceData[city];
    if (cityData == null) return null;

    if (district != null &&
        district.isNotEmpty &&
        cityData.containsKey(district)) {
      return cityData[district];
    }
    // 如果没有选择区县，返回城市的第一个区的拼音（通常是市区）
    if (cityData.isNotEmpty) {
      return cityData.values.first;
    }
    return null;
  }

  /// 获取区县的拼音（异步版本）
  static Future<String?> getPinyinAsync(
    String province,
    String city,
    String? district,
  ) async {
    await _ensureLoaded();
    return getPinyin(province, city, district);
  }

  /// 检查数据是否已加载
  static bool get isLoaded => _regionData != null;
}
