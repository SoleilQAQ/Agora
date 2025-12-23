/// 定位服务
/// 负责获取用户当前位置并转换为城市信息
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// 位置权限状态
enum LocationPermissionStatus {
  /// 已授权
  granted,

  /// 已拒绝（可再次请求）
  denied,

  /// 永久拒绝（需要去设置开启）
  deniedForever,

  /// 定位服务已关闭
  serviceDisabled,
}

/// 定位错误类型
enum LocationError {
  /// 权限被拒绝
  permissionDenied,

  /// 权限被永久拒绝
  permissionDeniedForever,

  /// 定位服务未开启
  serviceDisabled,

  /// 定位超时
  timeout,

  /// 反向地理编码失败
  geocodeFailed,

  /// 网络错误
  networkError,

  /// 未知错误
  unknown,
}

/// 定位结果
class LocationResult {
  final bool success;
  final double? latitude;
  final double? longitude;
  final LocationError? error;
  final String? errorMessage;

  const LocationResult({
    required this.success,
    this.latitude,
    this.longitude,
    this.error,
    this.errorMessage,
  });

  /// 创建成功结果
  factory LocationResult.success({
    required double latitude,
    required double longitude,
  }) {
    return LocationResult(
      success: true,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// 创建失败结果
  factory LocationResult.failure({
    required LocationError error,
    String? errorMessage,
  }) {
    return LocationResult(
      success: false,
      error: error,
      errorMessage: errorMessage,
    );
  }
}

/// 城市信息
class CityInfo {
  /// 城市显示名称
  final String name;

  /// 城市拼音（用于 API 请求）
  final String pinyin;

  /// 省份（可选）
  final String? province;

  /// 区县（可选）
  final String? district;

  const CityInfo({
    required this.name,
    required this.pinyin,
    this.province,
    this.district,
  });

  /// 从 API JSON 创建
  factory CityInfo.fromJson(Map<String, dynamic> json) {
    return CityInfo(
      name: json['city'] as String? ?? '',
      pinyin: json['cityPinyin'] as String? ?? '',
      province: json['province'] as String?,
      district: json['district'] as String?,
    );
  }

  @override
  String toString() {
    return 'CityInfo(name: $name, pinyin: $pinyin, province: $province, district: $district)';
  }
}

/// 定位城市结果
class LocationCityResult {
  final bool success;
  final CityInfo? city;
  final LocationError? error;
  final String? errorMessage;

  const LocationCityResult({
    required this.success,
    this.city,
    this.error,
    this.errorMessage,
  });

  /// 创建成功结果
  factory LocationCityResult.success(CityInfo city) {
    return LocationCityResult(
      success: true,
      city: city,
    );
  }

  /// 创建失败结果
  factory LocationCityResult.failure({
    required LocationError error,
    String? errorMessage,
  }) {
    return LocationCityResult(
      success: false,
      error: error,
      errorMessage: errorMessage,
    );
  }
}


/// 定位服务
/// 负责获取用户当前位置并转换为城市信息
class LocationService {
  static const String _baseUrl = 'http://47.122.112.62:8000';
  static const Duration _locationTimeout = Duration(seconds: 15);

  Dio? _dio;

  /// 懒加载 Dio 实例
  Dio get dio {
    _dio ??= Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    return _dio!;
  }

  /// 检查位置权限状态
  Future<LocationPermissionStatus> checkPermission() async {
    // 首先检查定位服务是否开启
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    // 检查权限状态
    final permission = await Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  /// 请求位置权限
  Future<LocationPermissionStatus> requestPermission() async {
    // 首先检查定位服务是否开启
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    // 检查当前权限状态
    var permission = await Geolocator.checkPermission();

    // 如果权限被拒绝，请求权限
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return _mapPermission(permission);
  }

  /// 将 geolocator 权限映射到自定义枚举
  LocationPermissionStatus _mapPermission(LocationPermission permission) {
    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.denied;
    }
  }

  /// 获取当前位置
  /// 返回经纬度坐标
  Future<LocationResult> getCurrentLocation() async {
    try {
      // 检查定位服务是否开启
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure(
          error: LocationError.serviceDisabled,
          errorMessage: '定位服务未开启，请在系统设置中开启定位服务',
        );
      }

      // 检查权限
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure(
            error: LocationError.permissionDenied,
            errorMessage: '位置权限被拒绝',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          error: LocationError.permissionDeniedForever,
          errorMessage: '位置权限被永久拒绝，请在设置中手动开启',
        );
      }

      // 获取位置
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _locationTimeout,
        ),
      );

      return LocationResult.success(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      return LocationResult.failure(
        error: LocationError.timeout,
        errorMessage: '定位超时，请检查网络或GPS信号',
      );
    } on LocationServiceDisabledException {
      return LocationResult.failure(
        error: LocationError.serviceDisabled,
        errorMessage: '定位服务未开启',
      );
    } catch (e) {
      debugPrint('定位失败: $e');
      return LocationResult.failure(
        error: LocationError.unknown,
        errorMessage: '定位失败: $e',
      );
    }
  }

  /// 反向地理编码
  /// 将经纬度转换为城市信息
  Future<CityInfo?> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await dio.get(
        '/api/geo/reverse',
        queryParameters: {
          'lat': latitude,
          'lng': longitude,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final json = response.data as Map<String, dynamic>;
        if (json['success'] == true && json['data'] != null) {
          return CityInfo.fromJson(json['data'] as Map<String, dynamic>);
        }
      }

      debugPrint('反向地理编码失败: ${response.data}');
      return null;
    } catch (e) {
      debugPrint('反向地理编码请求失败: $e');
      return null;
    }
  }

  /// 获取当前位置的城市信息（组合方法）
  /// 包含权限检查、定位、反向编码的完整流程
  Future<LocationCityResult> getCurrentCity() async {
    // 1. 获取当前位置
    final locationResult = await getCurrentLocation();
    if (!locationResult.success) {
      return LocationCityResult.failure(
        error: locationResult.error!,
        errorMessage: locationResult.errorMessage,
      );
    }

    // 2. 反向地理编码
    final cityInfo = await reverseGeocode(
      locationResult.latitude!,
      locationResult.longitude!,
    );

    if (cityInfo == null) {
      return LocationCityResult.failure(
        error: LocationError.geocodeFailed,
        errorMessage: '无法获取城市信息，请稍后重试',
      );
    }

    return LocationCityResult.success(cityInfo);
  }

  /// 打开应用设置（用于用户手动开启权限）
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// 打开位置服务设置
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// 释放资源
  void dispose() {
    _dio?.close();
    _dio = null;
  }
}
