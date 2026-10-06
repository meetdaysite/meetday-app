import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetday_app/features/auth/domain/account_role.dart';
import 'package:meetday_app/features/auth/presentation/login_screen.dart';
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

  testWidgets('brand signup requires Terms consent before Google onboarding', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(role: AccountRole.brand),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);

    final createAccountButton = find.text('New to Meetday? Create an account');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Agree to terms to continue'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  test('Auth controller starts in an unauthenticated state', () async {
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
}
