import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/environment.dart';

class ApiClient {
  ApiClient({required AppConfig config})
    : _dio = Dio(
        BaseOptions(
          baseUrl: config.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: const {'Content-Type': 'application/json'},
        ),
      );

  final Dio _dio;
  String? _idToken;

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<bool> checkConnection() async {
    try {
      await _dio.get<void>('/health');
      return true;
    } on DioException {
      return false;
    }
  }

  Map<String, String> _authHeaders() => {
    if (_idToken != null && _idToken!.isNotEmpty)
      'Authorization': 'Bearer $_idToken',
  };

  Map<String, dynamic> _unwrapData(Map<String, dynamic>? response) {
    final data = response?['data'];
    if (data is Map<String, dynamic>) return data;
    return response ?? <String, dynamic>{};
  }
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(config: ref.watch(appConfigProvider));
});
