import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetday_app/features/auth/state/auth_provider.dart';
import 'package:meetday_app/features/community/presentation/community_dashboard_screen.dart';

import 'package:meetday_app/features/community/presentation/providers/dashboard_provider.dart';

void main() {
  testWidgets('community dashboard shows centered logo, profile and notification icons, and dock navigation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProposalsProvider.overrideWith((ref) => Future.value([])),
          dashboardHubsProvider.overrideWith((ref) => Future.value([])),
          dashboardCommunitiesProvider.overrideWith((ref) => Future.value([])),
          dashboardDealsProvider.overrideWith((ref) => Future.value([])),
          publishedProposalsProvider.overrideWith((ref) => Future.value([])),
        ],
        child: MaterialApp(
          home: CommunityDashboardScreen(
            profileFuture: Future.value({
              'name': 'Night Market Community',
              'approvalStatus': 'APPROVED',
            }),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify AppBar exists
    expect(find.byType(AppBar), findsOneWidget);

    // Verify Notifications and Profile icons in the top bar actions
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Verify bottom navigation dock icons
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    expect(find.byIcon(Icons.headset_mic_rounded), findsOneWidget);
  });

  test('auth error formatter surfaces the actual Firebase retry message', () {
    final formatted = AuthController.formatLoginError(
      FirebaseAuthException(
        code: 'too-many-requests',
        message: 'Too many attempts',
      ),
    );

    expect(formatted, 'Too many attempts. Please try again later.');
  });
}
