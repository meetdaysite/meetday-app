import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Future<String?>? _firebaseTokenRefresh;

  static ApiClient? _instance;

  static ApiClient get instance =>
      _instance ??= ApiClient._(AppConfig.fromEnvironment());

  Dio get dio => _dio;
  String get socketUrl => _config.socketUrl;

  late final Dio _dio = _buildDio();

  void setIdToken(String? token) {
    _idToken = token;
  }

  Future<String?> _refreshFirebaseIdToken() {
    final pendingRefresh = _firebaseTokenRefresh;
    if (pendingRefresh != null) return pendingRefresh;

    final refresh = () async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        final token = await user.getIdToken(true);
        if (token == null || token.isEmpty) return null;
        _idToken = token;
        await _secureStorage.write(key: 'firebase_id_token', value: token);
        return token;
      } catch (_) {
        return null;
      }
    }();
    _firebaseTokenRefresh = refresh;
    return refresh.whenComplete(() {
      if (identical(_firebaseTokenRefresh, refresh)) {
        _firebaseTokenRefresh = null;
      }
    });
  }

  Future<Map<String, dynamic>> getHostCommunityProfile() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/hosts/community',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getHostProfile() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/hosts/me',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> updateHostProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '/hosts/profile',
      data: payload,
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getBrandProfile() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/brands/me',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getSpaceProfile() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/spaces/me',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> updateSpaceProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '/spaces/me',
      data: payload,
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getSpaceCommunityProfile() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/spaces/community',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> activateSpaceCommunityProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/spaces/community',
      data: payload,
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>?> getSpaceDeal(String interestId) async {
    try {
      final response = await dio.get<dynamic>(
        '/spaces/chats/$interestId/deal',
        options: Options(headers: _authHeaders()),
      );
      final dynamic raw = response.data;
      if (raw is Map && raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSpaceDealReport(
    String interestId, [
    String role = 'SPACE',
  ]) async {
    try {
      final response = await dio.get<dynamic>(
        '/spaces/chats/$interestId/deal/report',
        queryParameters: {'role': role},
        options: Options(headers: _authHeaders()),
      );
      final dynamic raw = response.data;
      if (raw is Map && raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      if (raw is Map) return Map<String, dynamic>.from(raw);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> updateBrandProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '/brands/me',
      data: payload,
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getBrandTeamMembers() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/brands/members',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> inviteBrandTeamMember(String email) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/brands/members',
      data: {'email': email},
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<void> removeBrandTeamMember(String memberId) async {
    await dio.delete<void>(
      '/brands/members/$memberId',
      options: Options(headers: _authHeaders()),
    );
  }

  Future<void> setBrandMemberPermission(
    String memberId,
    bool canManageMembers,
  ) async {
    await dio.patch<void>(
      '/brands/members/$memberId/permission',
      data: {'canManageMembers': canManageMembers},
      options: Options(headers: _authHeaders()),
    );
  }

  Future<Map<String, dynamic>> markSponsorshipInterest(String id) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/sponsorships/published/$id/interest',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<void> deleteProposal(String id) async {
    await dio.delete<dynamic>(
      '/sponsorships/$id',
      options: Options(headers: _authHeaders()),
    );
  }

  Future<List<dynamic>> getMyCampaigns() async {
    final response = await dio.get<dynamic>(
      '/campaigns',
      options: Options(headers: _authHeaders()),
    );
    final dynamic raw = response.data;
    if (raw is List) return raw;
    if (raw is Map) {
      final inner = raw['data'] ?? raw['campaigns'];
      if (inner is List) return inner;
      if (inner is Map && inner['campaigns'] is List) {
        return inner['campaigns'] as List;
      }
    }
    return [];
  }

  Future<Map<String, dynamic>> createCampaign(
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/campaigns',
      data: payload,
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> updateCampaign(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await dio.patch<Map<String, dynamic>>(
      '/campaigns/$id',
      data: payload,
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<void> deleteCampaign(String id) async {
    await dio.delete<void>(
      '/campaigns/$id',
      options: Options(headers: _authHeaders()),
    );
  }

  Future<Map<String, dynamic>> generateCampaignDraft(String prompt) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/campaigns/copilot/generate-draft',
      data: {'prompt': prompt},
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<String> extractCampaignCopilotDocument(String path) async {
    final fileName = path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(path, filename: fileName),
    });
    final response = await dio.post<dynamic>(
      '/campaigns/copilot/extract-document',
      data: formData,
      options: Options(
        headers: _authHeaders(),
        contentType: Headers.multipartFormDataContentType,
      ),
    );
    final payload = response.data is Map && response.data['data'] is Map
        ? response.data['data'] as Map
        : response.data;
    return payload is Map ? (payload['text'] ?? '').toString() : '';
  }

  Future<Map<String, dynamic>> getHostTeamMembers() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/hosts/community/members',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getCommunityTeamMembers() =>
      getHostTeamMembers();

  Future<Map<String, dynamic>> inviteHostTeamMember(String email) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/hosts/community/members',
      data: {'email': email},
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<void> removeHostTeamMember(String memberId) async {
    await dio.delete<void>(
      '/hosts/community/members/$memberId',
      options: Options(headers: _authHeaders()),
    );
  }

  Future<void> setHostMemberPermission(
    String memberId,
    bool canManageMembers,
  ) async {
    await dio.patch<void>(
      '/hosts/community/members/$memberId/permission',
      data: {'canManageMembers': canManageMembers},
      options: Options(headers: _authHeaders()),
    );
  }

  Future<void> deleteAccount({String? reason}) async {
    await dio.delete<void>(
      '/users/me',
      data: reason != null && reason.isNotEmpty ? {'reason': reason} : null,
      options: Options(headers: _authHeaders()),
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/auth/me',
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    if (isRead != null) query['isRead'] = isRead;
    final response = await dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: query,
      options: Options(headers: _authHeaders()),
    );
    return _unwrapData(response.data);
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/notifications/unread-count',
        options: Options(headers: _authHeaders()),
      );
      final data = _unwrapData(response.data);
      return (data['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationRead(String id) async {
    await dio.patch<dynamic>(
      '/notifications/$id/read',
      options: Options(headers: _authHeaders()),
    );
  }

  Future<void> markAllNotificationsRead() async {
    await dio.patch<dynamic>(
      '/notifications/read-all',
      options: Options(headers: _authHeaders()),
    );
  }

  Future<bool> checkConnection() async {
    try {
      final apiUri = Uri.parse(_config.baseUrl);
      final healthUri = apiUri.replace(
        path: '/health',
        query: null,
        fragment: null,
      );
      await dio.getUri<void>(healthUri);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<dynamic> getRequest(String path) async {
    final response = await dio.get<dynamic>(path);
    return _unwrapResponseData(response.data);
  }

  Future<dynamic> postRequest(String path, [dynamic data]) async {
    final response = await dio.post<dynamic>(path, data: data);
    return _unwrapResponseData(response.data);
  }

  Future<dynamic> putRequest(String path, [dynamic data]) async {
    final response = await dio.put<dynamic>(path, data: data);
    return _unwrapResponseData(response.data);
  }

  Future<dynamic> uploadFile(String path, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await dio.post<dynamic>(path, data: formData);
    return _unwrapResponseData(response.data);
  }

  dynamic _unwrapResponseData(dynamic response) {
    if (response is Map && response.containsKey('data')) {
      return response['data'];
    }
    return response;
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
            final request = error.requestOptions;
            if (request.extra['firebaseTokenRetried'] != true) {
              final token = await _refreshFirebaseIdToken();
              if (token != null) {
                request.extra['firebaseTokenRetried'] = true;
                request.headers['Authorization'] = 'Bearer $token';
                try {
                  final response = await dio.fetch<dynamic>(request);
                  return handler.resolve(response);
                } on DioException catch (retryError) {
                  return handler.next(retryError);
                }
              }
            }
          }

          return handler.next(error);
        },
      ),
    ]);

    return dio;
  }

  Future<String?> uploadMediaFile({
    required List<int> bytes,
    required String fileName,
    required String context,
    String? resourceId,
  }) async {
    try {
      final ext = fileName.split('.').last.toLowerCase();
      String contentType = 'application/octet-stream';
      if (ext == 'png') {
        contentType = 'image/png';
      } else if (ext == 'jpg' || ext == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (ext == 'webp') {
        contentType = 'image/webp';
      } else if (ext == 'pdf') {
        contentType = 'application/pdf';
      }

      final payload = <String, dynamic>{
        'context': context,
        'contentType': contentType,
      };
      if (resourceId != null) {
        payload['resourceId'] = resourceId;
      }

      final res = await dio.post<dynamic>('/storage/upload-url', data: payload);

      final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
      final uploadUrl = (data is Map)
          ? (data['uploadUrl'] ?? data['url'])?.toString()
          : null;
      final key = (data is Map) ? data['key']?.toString() : null;
      if (uploadUrl != null && key != null) {
        await Dio().put<void>(
          uploadUrl,
          data: Stream.fromIterable([bytes]),
          options: Options(
            headers: {
              'Content-Type': contentType,
              'Content-Length': bytes.length.toString(),
            },
          ),
        );
        return key;
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
    }
    return null;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);
