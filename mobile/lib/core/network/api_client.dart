// lib/core/network/api_client.dart
// Calc-Calories — Dio HTTP Client with Auth Interceptor

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../utils/constants.dart';

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ApiClient._internal(this._secureStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiV1,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Auth token interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: AppConstants.tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Token expired — clear storage
            await _secureStorage.delete(key: AppConstants.tokenKey);
            await _secureStorage.delete(key: AppConstants.userIdKey);
          }
          return handler.next(error);
        },
      ),
    );

    // Request/response logger (debug builds only)
    assert(() {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          compact: true,
        ),
      );
      return true;
    }());
  }

  factory ApiClient({FlutterSecureStorage? secureStorage}) {
    _instance ??= ApiClient._internal(
      secureStorage ?? const FlutterSecureStorage(),
    );
    return _instance!;
  }

  Dio get dio => _dio;

  /// Save auth token to secure storage
  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: AppConstants.tokenKey, value: token);
  }

  /// Clear all auth data
  Future<void> clearAuth() async {
    await _secureStorage.delete(key: AppConstants.tokenKey);
    await _secureStorage.delete(key: AppConstants.userIdKey);
    await _secureStorage.delete(key: 'is_premium');
    
    // Clear onboarding flag from shared preferences as well
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('onboarding_completed');
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.read(key: AppConstants.tokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Save isPremium to secure storage
  Future<void> saveIsPremium(bool isPremium) async {
    await _secureStorage.write(key: 'is_premium', value: isPremium ? 'true' : 'false');
  }

  /// Get isPremium status from secure storage
  Future<bool> getIsPremium() async {
    final val = await _secureStorage.read(key: 'is_premium');
    return val == 'true';
  }
}
