import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/home/presentation/home_shell.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // This is a placeholder redirect logic.
      // The real auth guard will be wired after Firebase is configured.
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
      router.go('/login');
    }
  });

  return router;
});
