import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/environment.dart';

class ApiClient {
  ApiClient._(this._config);

  final AppConfig _config;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static ApiClient? _instance;

  static ApiClient get instance =>
      _instance ??= ApiClient._(AppConfig.fromEnvironment());

  Dio get dio => _dio;

  late final Dio _dio = _buildDio();

  Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: _config.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: 'firebase_id_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          if (_config.useDebugLogs) {
            debugPrint('API REQUEST: ${options.method} ${options.path}');
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (_config.useDebugLogs) {
            debugPrint(
              'API RESPONSE: ${response.statusCode} ${response.requestOptions.path}',
            );
          }
          return handler.next(response);
        },
        onError: (error, handler) async {
          if (_config.useDebugLogs) {
            debugPrint(
              'API ERROR: ${error.response?.statusCode} ${error.message}',
            );
          }

          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: 'Network error. Please check your connection.',
                type: DioExceptionType.connectionError,
              ),
            );
          }

          if (error.response?.statusCode == 401) {
            // TODO: trigger re-auth flow when backend auth is implemented.
          }

          return handler.next(error);
        },
      ),
    ]);

    return dio;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);
