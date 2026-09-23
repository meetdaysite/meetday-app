import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetday_app/features/auth/state/auth_provider.dart';

class FakeSecureStorage implements AppSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController', () {
    test('initializes as unauthenticated by default', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => AuthController(storage: FakeSecureStorage()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.initialize();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    test('signIn sets authenticated state', () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => AuthController(storage: FakeSecureStorage()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authControllerProvider.notifier);
      await notifier.signIn(uid: 'user-123');

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(container.read(authControllerProvider).uid, 'user-123');
    });
  });
}
