import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetday_app/features/auth/state/auth_provider.dart';
import 'package:meetday_app/features/community/presentation/community_dashboard_screen.dart';

void main() {
  testWidgets('community dashboard shows the main web tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
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

    await tester.pump();

    // Open the drawer to reveal the mobile navigation items matching meetday-frontend
    final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Experience Proposals'), findsOneWidget);
    expect(find.text('Community Hubs'), findsOneWidget);
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Communities')), findsOneWidget);
    expect(find.text('Locked Deals'), findsOneWidget);
    expect(find.text('Support Chat'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
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
