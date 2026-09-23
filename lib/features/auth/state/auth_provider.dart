import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  const AuthState({required this.status, this.uid});

  final AuthStatus status;
  final String? uid;

  AuthState copyWith({AuthStatus? status, String? uid}) {
    return AuthState(status: status ?? this.status, uid: uid ?? this.uid);
  }
}

class AuthController extends Notifier<AuthState> {
  AuthController({AppSecureStorage? storage})
    : _storage = storage ?? FlutterSecureStorageAdapter();

  final AppSecureStorage _storage;

  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unknown);
  }

  AuthState get debugState => state;

  Future<void> initialize() async {
    final token = await _storage.read(key: 'firebase_id_token');
    final userId = await _storage.read(key: 'user_id');

    state = AuthState(
      status: token != null && token.isNotEmpty
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
      uid: userId,
    );
  }

  Future<void> signIn({required String uid}) async {
    await _storage.write(key: 'firebase_id_token', value: 'placeholder-token');
    await _storage.write(key: 'user_id', value: uid);
    state = AuthState(status: AuthStatus.authenticated, uid: uid);
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'firebase_id_token');
    await _storage.delete(key: 'user_id');
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);
