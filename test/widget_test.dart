import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetday_app/core/theme/app_theme.dart';
import 'package:meetday_app/core/network/api_client.dart';
import 'package:meetday_app/config/environment.dart';
import 'package:meetday_app/features/auth/domain/account_role.dart';
import 'package:meetday_app/features/auth/presentation/login_screen.dart';
import 'package:meetday_app/features/auth/state/auth_provider.dart';
import 'package:meetday_app/features/community/presentation/campaigns/campaigns_screen.dart';
import 'package:meetday_app/features/community/presentation/campaigns/brand_campaigns_screen.dart';
import 'package:meetday_app/features/community/presentation/providers/chat_provider.dart';
import 'package:meetday_app/features/community/presentation/providers/dashboard_provider.dart';
import 'package:meetday_app/features/community/presentation/providers/support_chat_provider.dart';
import 'package:meetday_app/features/community/presentation/spaces/space_dashboard_screen.dart';
import 'package:meetday_app/features/community/presentation/spaces/space_community_listing_form.dart';
import 'package:meetday_app/features/community/presentation/proposal/proposal_form_screen.dart';
import 'package:meetday_app/features/community/presentation/community_detail_screen.dart';
import 'package:meetday_app/features/community/presentation/chat/community_chat_hub.dart';
import 'package:meetday_app/features/community/presentation/events/create_event_screen.dart';
import 'package:meetday_app/features/community/presentation/events/events_list_screen.dart';
import 'package:meetday_app/features/community/presentation/attendees/attendees_screen.dart';
import 'package:meetday_app/features/community/presentation/attendees/qr_scanner_screen.dart';
import 'package:meetday_app/features/community/presentation/payouts/payouts_screen.dart';
import 'package:meetday_app/features/community/presentation/analytics/analytics_screen.dart';
import 'package:meetday_app/features/community/presentation/providers/profile_provider.dart';
import 'package:meetday_app/features/home/presentation/home_screen.dart';
import 'package:meetday_app/features/home/presentation/home_shell.dart';

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

class FakeSpaceAccountAuthController extends AuthController {
  FakeSpaceAccountAuthController() : super(storage: FakeSecureStorage());

  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    uid: 'space-user',
    role: AccountRole.space,
  );
}

class FakeBrandAccountAuthController extends AuthController {
  FakeBrandAccountAuthController() : super(storage: FakeSecureStorage());

  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    uid: 'brand-user',
    role: AccountRole.brand,
  );
}

class FakeBrandApiClient extends ApiClient {
  FakeBrandApiClient({this.proposals, this.respondToChats = false, this.responses = const {}}) : super(config: const AppConfig(
    environment: AppEnvironment.dev,
    baseUrl: 'http://localhost/api/v1',
    socketUrl: 'http://localhost',
    useDebugLogs: false,
  )) {
    _testDio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      final responseKey = '${request.method} ${request.path}';
      if (responses.containsKey(responseKey)) {
        handler.resolve(Response(requestOptions: request, statusCode: 200,
          data: {'data': responses[responseKey]}));
        return;
      }
      if (respondToChats && request.path.contains('/chats')) {
        handler.resolve(Response(requestOptions: request, statusCode: 200, data: {'data': []}));
        return;
      }
      if (proposals != null && request.path == '/sponsorships/published') {
        handler.resolve(Response(requestOptions: request, statusCode: 200,
          data: {'data': {'proposals': proposals}}));
      } else {
        handler.reject(DioException(requestOptions: request,
          type: DioExceptionType.connectionError, error: 'offline'));
      }
    }));
  }

  final List<Map<String, dynamic>>? proposals;
  final bool respondToChats;
  final Map<String, dynamic> responses;
  final List<RequestOptions> requests = [];
  final Dio _testDio = Dio();

  @override
  Dio get dio => _testDio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Community insights use actual earnings instead of fixed trends', (tester) async {
    final now = DateTime.now().toIso8601String();
    final api = FakeBrandApiClient(responses: {'GET /host/earnings/events': [
      {'status': 'COMPLETED', 'netPayoutAmount': '321', 'completedAt': now,
        'event': {'title': 'Actual event', 'eventDate': now}},
    ]});
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      communityProfileProvider.overrideWith((ref) async => {'size': '250'}),
      dashboardProposalsProvider.overrideWith((ref) async => []),
    ], child: MaterialApp(theme: AppTheme.lightTheme(), home: const AnalyticsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Actual event'), findsOneWidget);
    expect(find.text('INR 321.00'), findsWidgets);
    expect(find.text('+24%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community payout screen parses nested live payouts', (tester) async {
    final api = FakeBrandApiClient(responses: {
      'GET /host/earnings': {'totalEarned': '1200', 'totalPending': '50', 'totalTdsDeducted': '10'},
      'GET /host/payouts': {'data': [{'id': 'payout', 'event': {'title': 'Paid meetup'},
        'status': 'COMPLETED', 'netPayoutAmount': '1200'}], 'total': 1},
    });
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: const PayoutsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Paid meetup'), findsOneWidget);
    expect(find.text('INR 1200.00'), findsWidgets);
    expect(find.text('HDFC Bank'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community scanner invite uses verified staff payload', (tester) async {
    final api = FakeBrandApiClient(responses: {'GET /events/event/scanner-sessions': [],
      'POST /events/event/scanner-sessions': {'id': 'session'}});
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: const StaffScannerScreen(eventId: 'event'))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Gate Staff');
    await tester.enterText(find.byType(TextField).at(1), 'staff@example.com');
    await tester.tap(find.text('Invite scanner staff'));
    await tester.pumpAndSettle();
    final request = api.requests.singleWhere((request) => request.method == 'POST');
    expect(request.path, '/events/event/scanner-sessions');
    expect(request.data, {'name': 'Gate Staff', 'email': 'staff@example.com'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community events list reads owned events rather than public demo data', (tester) async {
    final api = FakeBrandApiClient(responses: {'GET /events/me': {
      'events': [{'id': 'event', 'title': 'Real meetup', 'status': 'DRAFT'}], 'total': 1,
    }});
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: const EventsListScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Real meetup'), findsOneWidget);
    expect(api.requests.first.path, '/events/me');
    expect(find.text('The Block Party'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community event draft save sends backend ticket and refund fields', (tester) async {
    final api = FakeBrandApiClient(responses: {'GET /categories': [], 'POST /events': {'id': 'event'}});
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: const CreateEventScreen())));
    await tester.pumpAndSettle();
    final title = find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.labelText == 'Event title');
    await tester.ensureVisible(title);
    await tester.enterText(title, 'Local gathering');
    await tester.scrollUntilVisible(find.text('Save draft'), 450, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    final payload = api.requests.singleWhere((request) => request.method == 'POST').data as Map;
    expect(payload['title'], 'Local gathering');
    expect(payload['refundPolicy'], {'type': 'NO_REFUND', 'refundTo': 'ORIGINAL_PAYMENT'});
    expect(payload['tickets'], []);
    expect(payload.containsKey('status'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community attendees load the owned-event endpoint and real check-in state', (tester) async {
    final api = FakeBrandApiClient(responses: {'GET /events/me/event/attendees': {'attendees': [
      {'firstName': 'Real', 'lastName': 'Attendee', 'bookingId': 'BK1', 'ticketType': 'General', 'isCheckedIn': true},
    ], 'total': 1}});
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: const AttendeesScreen(eventId: 'event'))));
    await tester.pumpAndSettle();
    expect(find.text('Real Attendee'), findsOneWidget);
    expect(api.requests.any((request) => request.path == '/events/me/event/attendees'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Community public profile saves its own DTO instead of Hub fields', (tester) async {
    const categoryId = '123e4567-e89b-42d3-a456-426614174000';
    final profile = {'name': 'City Community', 'about': 'Founders and creators', 'logoKey': 'logo.jpg',
      'size': '250', 'avgGuestCount': '60', 'experiencesPerYear': '12',
      'categories': [{'id': categoryId, 'name': 'Technology'}]};
    final api = FakeBrandApiClient(responses: {
      'GET /hosts/community': profile,
      'GET /categories': [{'id': categoryId, 'name': 'Technology'}],
      'POST /hosts/community': profile,
    });
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: const SpaceCommunityListingForm(isCommunity: true))));
    await tester.pumpAndSettle();
    expect(find.text('Average guest count'), findsOneWidget);
    expect(find.text('Number of venues'), findsNothing);
    await tester.scrollUntilVisible(find.text('Submit for approval'), 400,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();
    final request = api.requests.singleWhere((request) => request.method == 'POST');
    expect(request.path, '/hosts/community');
    final payload = request.data as Map;
    expect(payload['size'], '250');
    expect(payload['avgGuestCount'], '60');
    expect(payload['categoryIds'], [categoryId]);
    expect(payload.containsKey('numberOfVenues'), isFalse);
    expect(payload.containsKey('communitySize'), isFalse);
    expect(tester.takeException(), isNull);
  });

  test('Hub deal and report permissions match Space ownership', () {
    UnifiedActiveThread thread(String kind) => UnifiedActiveThread(id: kind, category: 'spaces',
      kind: kind, counterpartName: 'Partner', counterpartType: 'COMMUNITY', title: 'Agreement');
    expect(canCreateThreadDeal(thread('SPONSORSHIP'), AccountRole.space), isTrue);
    expect(canReviewThreadDeal(thread('CAMPAIGN'), AccountRole.space), isTrue);
    expect(canSubmitThreadReport(thread('CAMPAIGN'), AccountRole.space), isTrue);
    expect(canCreateThreadDeal(thread('SPACE_HOST'), AccountRole.space), isTrue);
    expect(canReviewThreadDeal(thread('SPACE_HOST'), AccountRole.space), isFalse);
    expect(canReviewThreadDeal(thread('SPACE_HOST'), AccountRole.community), isTrue);
    expect(canSubmitThreadReport(thread('SPACE_HOST'), AccountRole.space), isTrue);
    expect(canReviewThreadReport(thread('SPACE_HOST'), AccountRole.community), isTrue);
    expect(canReviewThreadReport(thread('SPACE_HOST'), AccountRole.space), isFalse);
  });

  test('Hub Space-host partnership requests are outgoing', () async {
    final api = FakeBrandApiClient(respondToChats: true, responses: {
      'GET /space-host/chats': [{'id': 'request', 'chatStatus': 'REQUESTED', 'counterpartName': 'Community'}],
    });
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(FakeSpaceAccountAuthController.new),
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    final chats = await container.read(chatHubProvider.future);
    final request = chats.allRequests.single;
    expect(request.direction, 'OUTGOING');
    expect(request.isIncoming, isFalse);
    expect(request.counterpartType, 'COMMUNITY');
  });

  testWidgets('Hub community collaboration calls Space-host interest and opens chats', (tester) async {
    final api = FakeBrandApiClient(responses: {
      'POST /space-host/communities/host-profile/interest': {'alreadyInterested': false},
    });
    int? selectedTab;
    await tester.pumpWidget(ProviderScope(overrides: [
      apiClientProvider.overrideWithValue(api),
      authControllerProvider.overrideWith(FakeSpaceAccountAuthController.new),
      chatHubProvider.overrideWith((ref) async => const ChatHubData(categories: [],
        activeThreadsByCategory: {}, allRequests: [], incomingCount: 0, sentCount: 0)),
    ], child: MaterialApp(theme: AppTheme.lightTheme(), home: Builder(builder: (context) => Scaffold(
      body: TextButton(child: const Text('Open community'), onPressed: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => CommunityDetailScreen(
          community: const {'id': 'community', 'hostProfileId': 'host-profile', 'name': 'City Community'},
          onSelectTab: (tab) => selectedTab = tab,
        )),
      )),
    )))));
    await tester.tap(find.text('Open community'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('COLLABORATE'));
    await tester.tap(find.text('COLLABORATE'));
    await tester.pumpAndSettle();
    expect(api.requests.any((request) => request.path == '/space-host/communities/host-profile/interest'), isTrue);
    expect(selectedTab, 9);
    expect(tester.takeException(), isNull);
  });

  test('Hub notifications route exact threads and non-chat destinations', () {
    final target = hubNotificationChatTarget({'type': 'space_chat_message',
      'metadata': {'spaceInterestId': 'hub-thread'}});
    expect(target?.threadId, 'hub-thread');
    expect(target?.category, 'spaces');
    expect(hubNotificationChatTarget({'type': 'host_interested_in_campaign',
      'metadata': {'campaignId': 'campaign', 'sponsorshipInterestId': 'campaign-thread'}})?.category, 'campaigns');
    expect(hubNotificationDestination({'type': 'meetday_chat_message'}), 6);
    expect(hubNotificationDestination({'type': 'space_profile_approved'}), -1);
    expect(hubNotificationDestination({'type': 'sponsorship_approved', 'metadata': {'proposalId': 'proposal'}}), 1);
    expect(hubNotificationChatTarget({'type': 'meetday_chat_message', 'metadata': {'threadId': 'support'}}), isNull);
  });

  test('Hub Space-host message ownership uses SPACE identity', () {
    expect(UnifiedChatMessage.fromSpaceHost({'id': 'mine', 'senderType': 'SPACE'}, currentRole: 'SPACE').isMe, isTrue);
    expect(UnifiedChatMessage.fromSpaceHost({'id': 'theirs', 'senderType': 'HOST'}, currentRole: 'SPACE').isMe, isFalse);
  });

  testWidgets('Hub proposal editor loads Hub approval and pending revision', (tester) async {
    final api = FakeBrandApiClient(responses: {'GET /spaces/community': {
      'name': 'Central Hub', 'approvalStatus': 'APPROVED',
    }});
    await tester.pumpWidget(ProviderScope(overrides: [
      authControllerProvider.overrideWith(FakeSpaceAccountAuthController.new),
      apiClientProvider.overrideWithValue(api),
    ], child: MaterialApp(home: ProposalFormScreen(initialProposal: {
      'id': 'proposal', 'name': 'Live title', 'pendingRevision': {'name': 'Revised title'},
    }, onSuccess: () {}))));
    await tester.pumpAndSettle();
    expect(api.requests.any((request) => request.path == '/spaces/community'), isTrue);
    expect(api.requests.any((request) => request.path == '/hosts/community'), isFalse);
    expect(find.text('Revised title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hub listing submits complete DTO fields and preserves history', (tester) async {
    const categoryId = '123e4567-e89b-42d3-a456-426614174000';
    final listing = <String, dynamic>{
      'name': 'Central Hub', 'about': 'Coworking and community events', 'logoKey': 'logo.jpg',
      'numberOfVenues': '2', 'venueCapacity': '100', 'communitySize': '250',
      'experiencesPerYear': '12', 'activeLocations': ['Pune'],
      'categories': [{'id': categoryId, 'name': 'Coworking'}],
      'posterKey': 'poster.jpg', 'centreShowcaseImageKeys': ['photo.jpg'],
      'pastEvents': [{'name': 'Meetup', 'description': 'Local founders', 'imageKeys': ['event.jpg']}],
      'brandsWorkedWith': [{'brandName': 'Acme', 'url': 'https://example.com', 'logoKey': 'acme.jpg'}],
    };
    final api = FakeBrandApiClient(responses: {
      'GET /spaces/community': listing,
      'GET /categories': [{'id': categoryId, 'name': 'Coworking'}],
      'POST /spaces/community': listing,
    });
    await tester.pumpWidget(ProviderScope(overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp(theme: AppTheme.lightTheme(), home: const SpaceCommunityListingForm())));
    await tester.pumpAndSettle();
    expect(find.text('Listing name'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Submit for approval'), 450,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Submit for approval'));
    await tester.pumpAndSettle();
    final payload = api.requests.singleWhere((request) => request.method == 'POST').data as Map;
    expect(payload['numberOfVenues'], '2');
    expect(payload['communitySize'], '250');
    expect(payload['categoryIds'], [categoryId]);
    expect(payload['activeLocations'], ['Pune']);
    expect(payload['pastEvents'], listing['pastEvents']);
    expect(payload['brandsWorkedWith'], listing['brandsWorkedWith']);
    expect(payload.containsKey('venueCount'), isFalse);
    expect(payload.containsKey('operatingCities'), isFalse);
    expect(tester.takeException(), isNull);
  });

  test('Hub chat listings and message reads use SPACE, not HOST', () async {
    final api = FakeBrandApiClient(respondToChats: true);
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(FakeSpaceAccountAuthController.new),
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    await container.read(chatHubProvider.future);
    for (final request in api.requests.where((request) =>
        request.path == '/sponsorships/chats' || request.path == '/space-host/chats')) {
      expect(request.queryParameters['role'], 'SPACE');
    }
    for (final kind in ['CAMPAIGN', 'SPACE_HOST']) {
      final thread = UnifiedActiveThread(id: 'thread-1', category: 'spaces', kind: kind,
        counterpartName: 'Partner', counterpartType: 'BRAND', title: 'Test');
      await container.read(chatMessagesProvider(thread).future);
      expect(api.requests.last.queryParameters['role'], 'SPACE');
    }
    expect(sponsorshipChatRole(AccountRole.brand), 'BRAND');
    expect(sponsorshipChatRole(AccountRole.community), 'HOST');
  });

  test('Brand proposal and chat failures remain errors, not empty lists', () async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(FakeBrandAccountAuthController.new),
      apiClientProvider.overrideWithValue(FakeBrandApiClient()),
    ]);
    addTearDown(container.dispose);
    await expectLater(container.read(dashboardProposalsProvider.future), throwsA(isA<DioException>()));
    await expectLater(container.read(publishedProposalsProvider.future), throwsA(isA<DioException>()));
    await expectLater(container.read(chatHubProvider.future), throwsA(isA<DioException>()));
  });

  test('Published proposal mapping retains website categories', () async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(FakeBrandAccountAuthController.new),
      apiClientProvider.overrideWithValue(FakeBrandApiClient(proposals: [
        {'id': 'proposal-1', 'name': 'Meetup', 'hostProfile': {
          'categories': [{'id': 'tech', 'name': 'Technology'}],
        }},
      ])),
    ]);
    addTearDown(container.dispose);
    final proposals = await container.read(publishedProposalsProvider.future);
    expect(proposals.single['categories'], [{'id': 'tech', 'name': 'Technology'}]);
  });

  testWidgets('brand signup requires Terms consent before Google onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen(role: AccountRole.brand)),
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

  testWidgets('Hub login exposes Hub Partner signup and consent gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen(role: AccountRole.space)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hub Partner Login'), findsOneWidget);
    final signupButton = find.text('New to Meetday? Create an account');
    await tester.ensureVisible(signupButton);
    await tester.tap(signupButton);
    await tester.pumpAndSettle();

    expect(find.text('Create Hub Partner Account'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.text('Agree to terms to continue'), findsOneWidget);
  });

  testWidgets('Space accounts land on the live Hub dashboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            FakeSpaceAccountAuthController.new,
          ),
          apiClientProvider.overrideWithValue(FakeBrandApiClient(respondToChats: true)),
          spaceCommunityProfileProvider.overrideWith((ref) async => null),
          spaceLockedDealsProvider.overrideWith((ref) async => []),
          publishedProposalsProvider.overrideWith((ref) async => []),
          dashboardCommunitiesProvider.overrideWith((ref) async => []),
          notificationsProvider.overrideWith((ref) async => []),
          unreadNotificationsCountProvider.overrideWith((ref) async => 0),
          spaceDashboardProfileProvider.overrideWith(
            (ref) async => {
              'businessName': 'Northside Hall',
              'operatingCities': ['Pune'],
            },
          ),
          dashboardProposalsProvider.overrideWith(
            (ref) async => [
              {'name': 'Launch Night', 'status': 'UNDER_REVIEW'},
            ],
          ),
          dashboardCampaignsProvider.overrideWith(
            (ref) async => [
              {'name': 'Summer Pop-up'},
            ],
          ),
          chatHubProvider.overrideWith(
            (ref) async => const ChatHubData(
              categories: [],
              activeThreadsByCategory: {},
              allRequests: [],
              incomingCount: 0,
              sentCount: 0,
            ),
          ),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Hey Northside Hall,'), findsOneWidget);
    expect(find.text('Raise Sponsorship'), findsOneWidget);
    expect(find.text('Explore Campaigns'), findsOneWidget);
    expect(find.text('My Proposals'), findsOneWidget);
    expect(find.text('Brand Campaigns'), findsOneWidget);
    expect(find.text('Summer Pop-up'), findsOneWidget);

    await tester.tap(find.text('My Proposals'));
    await tester.pumpAndSettle();
    expect(find.text('Experiences'), findsOneWidget);
    expect(find.text('Launch Night'), findsOneWidget);
  });

  testWidgets('Hub dashboard opens Support and surfaces load failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          spaceDashboardProfileProvider.overrideWith(
            (ref) async => throw StateError('profile offline'),
          ),
          dashboardProposalsProvider.overrideWith((ref) async => []),
          dashboardCampaignsProvider.overrideWith((ref) async => []),
          chatHubProvider.overrideWith(
            (ref) async => const ChatHubData(
              categories: [],
              activeThreadsByCategory: {},
              allRequests: [],
              incomingCount: 0,
              sentCount: 0,
            ),
          ),
          supportChatMessagesProvider.overrideWith(
            (ref, role) async => throw StateError('offline'),
          ),
        ],
        child: MaterialApp(theme: AppTheme.lightTheme(), home: const SpaceDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.headset_mic_rounded).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Support Chat'), findsOneWidget);
    expect(find.text('Unable to load support chat'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Brand campaign fetch failures show a retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          brandCampaignsProvider.overrideWith(
            (ref) async => throw StateError('offline'),
          ),
        ],
        child: const MaterialApp(home: BrandCampaignsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to load campaigns'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Brand campaign modal renders and scrolls on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [brandCampaignsProvider.overrideWith((ref) async => [])],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const BrandCampaignsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE CAMPAIGN'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Campaign Name *'), findsOneWidget);
    expect(find.text('Description *'), findsOneWidget);

    await tester.tap(find.text('Draft with AI'));
    await tester.pumpAndSettle();
    expect(find.text('Start Cooking ✨'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final formScroll = find.ancestor(
      of: find.text('Campaign Name *'),
      matching: find.byType(SingleChildScrollView),
    );
    final locationField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText ==
          'Search city or region (e.g. Bangalore)',
    );
    await tester.ensureVisible(locationField);
    await tester.enterText(locationField, 'Delhi');
    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Delhi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.drag(formScroll, const Offset(0, -1600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SUBMIT FOR REVIEW'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Campaign Name *'));
    await tester.pumpAndSettle();
    final nameField = find.byType(TextField).at(1);
    await tester.ensureVisible(nameField);
    await tester.tap(nameField);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(nameField, 'Phone campaign');
    expect(find.text('Phone campaign'), findsOneWidget);
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

  test('brand return paths accept internal brand routes only', () {
    expect(
      validatedBrandReturnPath('/brand/proposal/proposal-123'),
      '/brand/proposal/proposal-123',
    );
    expect(validatedBrandReturnPath('/community-dashboard'), isNull);
    expect(
      validatedBrandReturnPath('https://example.com/brand/proposal/123'),
      isNull,
    );
    expect(
      validatedBrandReturnPath('//example.com/brand/proposal/123'),
      isNull,
    );
  });

  test('campaign interest uses backend roles for Community and Hub', () {
    expect(campaignInterestBackendRole(AccountRole.community), 'HOST');
    expect(campaignInterestBackendRole(AccountRole.space), 'SPACE');
  });

  testWidgets('HomeScreen renders with centered logo and cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SvgPicture), findsWidgets);
    expect(find.text('Community'), findsWidgets);
    expect(find.text('RAISE SPONSORSHIP'), findsOneWidget);
  });
}
