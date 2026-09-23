import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/role_selection_screen.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/home/presentation/home_shell.dart';
import '../features/auth/domain/account_role.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/roles',
    redirect: (context, state) {
      // This is a placeholder redirect logic.
      // The real auth guard will be wired after Firebase is configured.
      return null;
    },
    routes: [
      GoRoute(
        path: '/roles',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/login/:role',
        builder: (context, state) {
          final roleName =
              state.pathParameters['role'] ?? AccountRole.brand.name;
          final role = AccountRole.values.firstWhere(
            (value) => value.name == roleName,
            orElse: () => AccountRole.brand,
          );
          return LoginScreen(role: role);
        },
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
    ],
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = AppRouter.router;

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    if (next.status == AuthStatus.authenticated) {
      router.go('/home');
    } else if (next.status == AuthStatus.unauthenticated) {
      router.go('/roles');
    }
  });

  return router;
});
