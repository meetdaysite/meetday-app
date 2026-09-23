import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';

import '../../../config/environment.dart';
import '../../../data/network/api_client.dart';
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
      _api = api;

  final AppSecureStorage _storage;
  final ApiClient? _api;

  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unknown);
  }

  AuthState get debugState => state;

  Future<void> initialize() async {
    final token = await _storage.read(key: 'firebase_id_token');
    final userId = await _storage.read(key: 'user_id');
    final roleName = await _storage.read(key: 'account_role');
    final role = AccountRole.values.cast<AccountRole?>().firstWhere(
      (value) => value?.name == roleName,
      orElse: () => null,
    );

    state = AuthState(
      status: token != null && token.isNotEmpty
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      uid: userId,
      role: role,
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
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = result.user;
      if (user == null) throw const AuthException('Google account not found.');

      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw const AuthException('Could not verify your Google session.');
      }

      final api = _api ?? ApiClient(config: AppConfig.fromEnvironment());
      api.setIdToken(token);
      final profile = await api.getMe();
      if (!_hasRoleAccess(profile, role)) {
        await FirebaseAuth.instance.signOut();
        await GoogleSignIn().signOut();
        throw AuthException(
          'No ${role.label.toLowerCase()} account found for this Google account. Please sign up.',
        );
      }

      await _persistAuthenticatedUser(user.uid, token, role);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_firebaseMessage(error.code));
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
    await GoogleSignIn().signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _firebaseMessage(String code) => switch (code) {
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => 'Email or password is incorrect.',
    'user-disabled' => 'This account has been disabled.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    _ => 'Unable to sign in with these details.',
  };
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);
