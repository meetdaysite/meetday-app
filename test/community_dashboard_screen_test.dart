import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meetday_app/features/auth/state/auth_provider.dart';
import 'package:meetday_app/features/auth/domain/account_role.dart';
import 'package:meetday_app/features/community/presentation/community_dashboard_screen.dart';
import 'package:meetday_app/features/community/presentation/messages/messages_screen.dart';
import 'package:meetday_app/features/community/presentation/proposal_components.dart';
import 'package:meetday_app/features/community/presentation/widgets/google_venue_autocomplete_field.dart';

import 'package:meetday_app/features/community/presentation/providers/dashboard_provider.dart';
import 'package:meetday_app/features/community/presentation/providers/profile_provider.dart';

void main() {
  testWidgets('Brand proposal detail loads its approved community profile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [publishedProposalDetailProvider.overrideWith((ref, id) async => {
        'id': id, 'name': 'Developer Meetup', 'status': 'PUBLISHED',
        'alreadyInterested': true,
        'community': {'id': 'community-1', 'name': 'Developer Community',
          'about': 'Local founders and developers',
          'categories': [{'id': 'tech', 'name': 'Technology'}]},
      })],
      child: MaterialApp(home: Builder(builder: (context) => Scaffold(
        body: TextButton(onPressed: () => showDialog<void>(context: context,
          builder: (_) => const ProposalDetailDialog(proposal: {'id': 'proposal-1'}, isBrand: true)),
          child: const Text('Open proposal')),
      ))),
    ));
    await tester.tap(find.text('Open proposal'));
    await tester.pumpAndSettle();
    expect(find.text('Developer Community'), findsOneWidget);
    expect(find.text('Technology'), findsOneWidget);
    expect(find.text('Developer Meetup'), findsWidgets);
    await tester.ensureVisible(find.text('INTEREST SENT'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Brand curated experiences filter by category and search', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        dashboardProposalsProvider.overrideWith((ref) async => []),
        dashboardHubsProvider.overrideWith((ref) async => []),
        dashboardCommunitiesProvider.overrideWith((ref) async => []),
        communityCollaborationCommunitiesProvider.overrideWith((ref) async => []),
        dashboardDealsProvider.overrideWith((ref) async => []),
        brandCampaignsProvider.overrideWith((ref) async => []),
        publishedProposalsProvider.overrideWith((ref) async => [
          {'id': 'tech', 'name': 'Developer Meetup', 'sponsorshipType': 'CASH',
            'categories': [{'id': 'tech-category', 'name': 'Technology'}]},
          {'id': 'food', 'name': 'Food Festival', 'sponsorshipType': 'BARTER',
            'categories': [{'id': 'food-category', 'name': 'Food'}]},
        ]),
        exploreSubViewProvider.overrideWith(() => _ExperiencesSubView()),
      ],
      child: MaterialApp(home: CommunityDashboardScreen(
        roleOverride: AccountRole.brand,
        profileFuture: Future.value({'brandName': 'Test Brand', 'approvalStatus': 'APPROVED'}),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byIcon(Icons.explore_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownMenu<String>), findsOneWidget);
    await tester.tap(find.byType(DropdownMenu<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Technology').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ProposalListItemCard, 'Developer Meetup'), findsOneWidget);
    expect(find.widgetWithText(ProposalListItemCard, 'Food Festival'), findsNothing);
    final search = find.byWidgetPredicate((widget) => widget is TextField &&
        widget.decoration?.hintText == 'Search experiences, communities or cities');
    await tester.enterText(search, 'unmatched');
    await tester.pumpAndSettle();
    expect(find.text('No curated experiences found'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('message conversation rows fit a phone-width viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(overrides: [
      hostProfileProvider.overrideWith((ref) async => {'approvalStatus': 'APPROVED'}),
      communityProfileProvider.overrideWith((ref) async => {'name': 'Test Community', 'approvalStatus': 'PENDING'}),
      dashboardProposalsProvider.overrideWith((ref) async => [
        {'id': 'proposal', 'name': 'Local meetup', 'status': 'REJECTED', 'adminRejectionRemark': 'Update dates'},
      ]),
      notificationsProvider.overrideWith((ref) async => [
        {'id': 'notification', 'title': 'New activity', 'body': 'Your application was received', 'isRead': false},
      ]),
    ], child: const MaterialApp(home: Scaffold(body: MessagesScreen()))));
    await tester.pumpAndSettle();

    expect(find.text('Local meetup - REJECTED'), findsOneWidget);
    expect(find.text('New activity'), findsOneWidget);
    expect(find.text('Aster Labs'), findsNothing);
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

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify AppBar exists
    expect(find.byType(AppBar), findsOneWidget);

    // Verify Notifications and Profile icons in the top bar actions
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Explore, Create, Deals, and Support are the visible icon-based dock destinations.
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MeetdayMobileBottomBar),
        matching: find.byIcon(Icons.description_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
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
    await tester.pump(const Duration(milliseconds: 300));
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

class _ExperiencesSubView extends ExploreSubViewNotifier {
  @override
  String build() => 'experiences';
}
