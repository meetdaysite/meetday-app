import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/environment.dart';

class ApiClient {
  ApiClient({required AppConfig config}) : _config = config;

  ApiClient._(this._config);

  final AppConfig _config;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _idToken;

  static ApiClient? _instance;

  static ApiClient get instance =>
      _instance ??= ApiClient._(AppConfig.fromEnvironment());

  Dio get dio => _dio;

  late final Dio _dio = _buildDio();

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<Map<String, dynamic>> getHostCommunityProfile() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/hosts/community',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<bool> checkConnection() async {
    try {
      await dio.get<void>('/health');
      return true;
    } on DioException {
      return false;
    }
  }

  Map<String, String> _authHeaders() {
    if (_idToken != null && _idToken!.isNotEmpty) {
      return {'Authorization': 'Bearer $_idToken'};
    }
    return {};
  }

  Map<String, dynamic> _unwrapData(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return response ?? <String, dynamic>{};
  }

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
          final token =
              _idToken ?? await _secureStorage.read(key: 'firebase_id_token');
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
