import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

import '../../../config/environment.dart';
import '../../../core/network/api_client.dart';
import '../domain/account_role.dart';

abstract class AppSecureStorage {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class FlutterSecureStorageAdapter implements AppSecureStorage {
  FlutterSecureStorageAdapter({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.uid, this.role});

  final AuthStatus status;
  final String? uid;
  final AccountRole? role;

  AuthState copyWith({AuthStatus? status, String? uid, AccountRole? role}) {
    return AuthState(
      status: status ?? this.status,
      uid: uid ?? this.uid,
      role: role ?? this.role,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthController({AppSecureStorage? storage, ApiClient? api})
    : _storage = storage ?? FlutterSecureStorageAdapter(),
      _api = api,
      _googleSignIn = GoogleSignIn(
        serverClientId:
            '371293689986-srhldepau68oo8pm7o4s1d0j3q72bh04.apps.googleusercontent.com',
      );

  final AppSecureStorage _storage;
  final ApiClient? _api;
  final GoogleSignIn _googleSignIn;

  static String formatLoginError(
    Object error, {
    String fallback = 'Unable to sign in right now. Please try again.',
  }) {
    if (error is AuthException) return error.message;

    if (error is FirebaseAuthException) {
      return _firebaseMessage(error.code);
    }

    if (error is DioException) {
      final responseMessage = _extractDioMessage(error.response?.data);
      if (responseMessage.isNotEmpty) {
        return responseMessage;
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Network connection failed. Please check your internet and try again.';
      }

      if (error.response?.statusCode == 401) {
        return 'Your session has expired. Please sign in again.';
      }
    }

    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      final message = text.substring('Exception: '.length).trim();
      if (message.isNotEmpty) return message;
    }

    if (text.startsWith('FirebaseAuthException')) {
      final match = RegExp(r'code: \s*([A-Za-z0-9_-]+)').firstMatch(text);
      final code = match?.group(1);
      if (code != null && code.isNotEmpty) {
        return _firebaseMessage(code);
      }
    }

    return fallback;
  }

  static String _extractDioMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final value = responseData['message'] ?? responseData['error'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }

    if (responseData is Map) {
      final value = responseData['message'] ?? responseData['error'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }

    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData.trim();
    }

    return '';
  }

  static String _firebaseMessage(String code) => switch (code) {
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => 'Email or password is incorrect.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    _ => 'Unable to sign in with these details.',
  };

  @override
  AuthState build() {
    Future.microtask(() => initialize());
    return const AuthState(status: AuthStatus.unknown);
  }

  AuthState get debugState => state;

  Future<void> initialize() async {
    String? token = await _storage.read(key: 'firebase_id_token');
    String? userId = await _storage.read(key: 'user_id');
    final roleName = await _storage.read(key: 'account_role');
    var role = AccountRole.values.cast<AccountRole?>().firstWhere(
      (value) => value?.name == roleName,
      orElse: () => null,
    );

    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      token ??= await fbUser.getIdToken();
      userId ??= fbUser.uid;
      role ??= AccountRole.community;
    }

    final isAuthenticated = (token != null && token.isNotEmpty) || fbUser != null;

    state = AuthState(
      status: isAuthenticated
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      uid: userId ?? fbUser?.uid,
      role: role ?? AccountRole.community,
    );
  }

  Future<void> signIn({required String uid, AccountRole? role}) async {
    await _storage.write(key: 'firebase_id_token', value: 'placeholder-token');
    await _storage.write(key: 'user_id', value: uid);
    if (role != null) {
      await _storage.write(key: 'account_role', value: role.name);
    }
    state = AuthState(status: AuthStatus.authenticated, uid: uid, role: role);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
    required AccountRole role,
  }) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw const AuthException('Account was not found.');

      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw const AuthException('Could not verify your session.');
      }

      final api = _api ?? ApiClient(config: AppConfig.fromEnvironment());
      api.setIdToken(token);
      Map<String, dynamic> profile;
      try {
        profile = await api.getMe();
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) {
          await FirebaseAuth.instance.signOut();
          await GoogleSignIn().signOut();
          throw AuthException(
            'No ${role.label.toLowerCase()} account found for this Google account. Please sign up.',
          );
        }
        rethrow;
      }
      final backendRole = profile['role'];
      final backendRoleName = backendRole is Map<String, dynamic>
          ? backendRole['name']?.toString()
          : null;
      if (backendRoleName != null &&
          backendRoleName != role.backendAccountType &&
          !(role == AccountRole.space && backendRoleName == 'SPACE_PARTNER')) {
        await FirebaseAuth.instance.signOut();
        throw AuthException('This account is not a ${role.label} account.');
      }

      await _storage.write(key: 'firebase_id_token', value: token);
      await _storage.write(key: 'user_id', value: user.uid);
      await _storage.write(key: 'account_role', value: role.name);
      state = AuthState(
        status: AuthStatus.authenticated,
        uid: user.uid,
        role: role,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error.code));
    }
  }

  Future<void> signInWithGoogle({required AccountRole role}) async {
    try {
      print('=== GOOGLE SIGNIN START ===');
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ Google Sign-In returned null (user cancelled)');
        return;
      }
      print('✅ Google user: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      print('✅ Google auth obtained');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      print('✅ Credential created');
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      print('✅ Firebase auth successful');
      final user = result.user;
      if (user == null) throw const AuthException('Google account not found.');
      print('✅ Firebase user: ${user.email}');

      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw const AuthException('Could not verify your Google session.');
      }
      print('✅ ID token obtained (${token.length} chars)');

      final api = _api ?? ApiClient(config: AppConfig.fromEnvironment());
      api.setIdToken(token);
      print('✅ API client token set');

      // Try to get existing profile
      Map<String, dynamic> profile;
      try {
        print('🔍 Fetching existing profile...');
        profile = await api.getMe();
        print('✅ Profile found');
      } catch (e) {
        print('❌ Profile fetch error: $e');
        // User doesn't exist yet, register them
        if (e.toString().contains('404')) {
          final names = (user.displayName ?? '').split(' ');
          final firstName = names.isNotEmpty ? names[0] : 'User';
          final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

          final registerData = {
            'firstName': firstName,
            'lastName': lastName,
          };

          // Add role-specific required fields
          if (role == AccountRole.brand) {
            registerData['accountType'] = 'BRAND';
            registerData['brandName'] = user.displayName ?? 'Brand';
          } else if (role == AccountRole.community) {
            registerData['accountType'] = 'HOST';
            registerData['hostType'] = 'INDIVIDUAL'; // Default host type
            registerData['communityName'] = user.displayName ?? 'Community';
          } else {
            registerData['accountType'] = 'USER';
          }

          print('=== AUTH REGISTER DEBUG ===');
          print('Token: ${token.substring(0, 50)}...');
          print('Register Data: $registerData');
          print('Base URL: ${api.dio.options.baseUrl}');
          print('Full URL: ${api.dio.options.baseUrl}/auth/register');

          final response = await api.dio.post(
            '/auth/register',
            data: registerData,
            options: Options(
              headers: {'Authorization': 'Bearer $token'},
              contentType: 'application/json',
            ),
          );

          print('Register Response Status: ${response.statusCode}');
          print('Register Response: ${response.data}');

          if (response.statusCode != 201 && response.statusCode != 200) {
            throw Exception('Registration failed: ${response.statusMessage}');
          }

          // Now get the profile after registration
          profile = await api.getMe();
        } else {
          rethrow;
        }
      }

      if (!_hasRoleAccess(profile, role)) {
        await FirebaseAuth.instance.signOut();
        await _googleSignIn.signOut();
        throw AuthException(
          'No ${role.label.toLowerCase()} account found for this Google account. Please sign up.',
        );
      }

      await _persistAuthenticatedUser(user.uid, token, role);
      print('✅ SIGNIN COMPLETE - User authenticated');
    } on FirebaseAuthException catch (error) {
      print('❌ FirebaseAuthException: ${error.code} - ${error.message}');
      throw AuthException(_firebaseMessage(error.code));
    } catch (error) {
      print('❌ SIGNIN FAILED - $error');
      rethrow;
    }
  }

  bool _hasRoleAccess(Map<String, dynamic> profile, AccountRole role) {
    final accessKey = switch (role) {
      AccountRole.brand => 'hasBrandAccess',
      AccountRole.community => 'hasHostAccess',
      AccountRole.space => 'hasSpaceAccess',
    };
    if (profile[accessKey] == true) return true;

    final backendRole = profile['role'];
    final roleName = backendRole is Map<String, dynamic>
        ? backendRole['name']?.toString()
        : null;
    return roleName == role.backendAccountType ||
        (role == AccountRole.space && roleName == 'SPACE_PARTNER');
  }

  Future<void> _persistAuthenticatedUser(
    String uid,
    String token,
    AccountRole role,
  ) async {
    await _storage.write(key: 'firebase_id_token', value: token);
    await _storage.write(key: 'user_id', value: uid);
    await _storage.write(key: 'account_role', value: role.name);
    state = AuthState(status: AuthStatus.authenticated, uid: uid, role: role);
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'firebase_id_token');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'account_role');
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);
