import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/account_role.dart';
import '../features/auth/presentation/brand_onboarding_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/role_selection_screen.dart';
import '../features/auth/presentation/space_onboarding_screen.dart';
import '../features/auth/state/auth_provider.dart';
import '../features/community/presentation/community_dashboard_screen.dart';
import '../features/community/presentation/brand_data_room_screen.dart';
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
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
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
          return LoginScreen(
            role: role,
            redirectTo: state.uri.queryParameters['redirectTo'],
          );
        },
      ),
      GoRoute(
        path: '/brand-onboarding',
        builder: (context, state) => const BrandOnboardingScreen(),
      ),
      GoRoute(
        path: '/space-onboarding',
        builder: (context, state) => const SpaceOnboardingScreen(),
      ),
      GoRoute(
        path: '/brand/data-room',
        builder: (context, state) => const BrandDataRoomScreen(),
      ),
      GoRoute(
        path: '/brand/proposal/:id',
        builder: (context, state) =>
            BrandDataRoomScreen(proposalId: state.pathParameters['id']),
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
    if (next.status == AuthStatus.onboarding &&
        next.role == AccountRole.brand) {
      router.go('/brand-onboarding');
    } else if (next.status == AuthStatus.onboarding &&
        next.role == AccountRole.space) {
      router.go('/space-onboarding');
    } else if (next.status == AuthStatus.authenticated) {
      final brandRedirect = next.role == AccountRole.brand
          ? ref.read(pendingBrandRedirectProvider)
          : null;
      final destination =
          brandRedirect ??
          (next.role == AccountRole.community
              ? '/community-dashboard'
              : '/dashboard');
      if (brandRedirect != null) {
        ref.read(pendingBrandRedirectProvider.notifier).set(null);
      }
      router.go(destination);
    } else if (next.status == AuthStatus.unauthenticated) {
      router.go('/');
    }
  });

  return router;
});
