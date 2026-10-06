import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetday_app/features/auth/state/auth_provider.dart';
import 'package:meetday_app/features/community/presentation/community_dashboard_screen.dart';
import 'package:meetday_app/features/community/presentation/messages/messages_screen.dart';
import 'package:meetday_app/features/community/presentation/proposal_components.dart';
import 'package:meetday_app/features/community/presentation/widgets/google_venue_autocomplete_field.dart';

import 'package:meetday_app/features/community/presentation/providers/dashboard_provider.dart';

void main() {
  testWidgets('message conversation rows fit a phone-width viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('community dashboard shows profile, notifications, and updated dock navigation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProposalsProvider.overrideWith((ref) => Future.value([])),
          dashboardHubsProvider.overrideWith((ref) => Future.value([])),
          communityCollaborationCommunitiesProvider.overrideWith((ref) => Future.value([])),
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

    // Explore, Proposals, and Support are the visible icon-based dock destinations.
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    expect(find.byIcon(Icons.description_rounded), findsOneWidget);
    expect(find.byIcon(Icons.headset_mic_rounded), findsOneWidget);
  });

  testWidgets('proposal editor exposes website fields and Copilot controls', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CreateProposalModal(onSuccess: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProposalFormScreen), findsOneWidget);
    expect(find.byType(GoogleVenueAutocompleteField), findsOneWidget);

    await tester.tap(find.text('Meetday AI Copilot').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Describe your event idea'), findsOneWidget);
    expect(find.text('Generate Draft'), findsOneWidget);
  });

  testWidgets('Google venue field remains manually editable without a Places key', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleVenueAutocompleteField(
            value: controller.text,
            onChanged: (value) => controller.text = value,
            onCitySelected: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Indie Community Hub');
    expect(controller.text, 'Indie Community Hub');
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
