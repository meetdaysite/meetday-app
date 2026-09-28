import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/account_role.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/role_selection_screen.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/community/presentation/community_dashboard_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/home/presentation/home_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // This is a placeholder redirect logic.
      // The real auth guard will be wired after Firebase is configured.
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
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
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const HomeShell(),
      ),
      GoRoute(
        path: '/community-dashboard',
        builder: (context, state) => const CommunityDashboardScreen(),
      ),
    ],
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = AppRouter.router;

  ref.listen<AuthState>(authControllerProvider, (_, next) {
    if (next.status == AuthStatus.authenticated) {
      final destination = next.role == AccountRole.community
          ? '/community-dashboard'
          : '/dashboard';
      router.go(destination);
    } else if (next.status == AuthStatus.unauthenticated) {
      router.go('/');
    }
  });

  return router;
});
