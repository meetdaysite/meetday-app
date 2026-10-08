import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/account_role.dart';
import '../../auth/state/auth_provider.dart';
import '../../community/presentation/community_dashboard_screen.dart';
import '../../community/presentation/spaces/space_dashboard_screen.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.role == AccountRole.space) {
      return const SpaceDashboardScreen();
    }

    return CommunityDashboardScreen(roleOverride: authState.role);
  }
}
