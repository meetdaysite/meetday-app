import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meetday_app/features/auth/domain/account_role.dart';
import 'package:meetday_app/features/auth/presentation/login_screen.dart';
import 'package:meetday_app/features/auth/state/auth_provider.dart';
import 'package:meetday_app/features/community/presentation/campaigns/campaigns_screen.dart';
import 'package:meetday_app/features/community/presentation/campaigns/brand_campaigns_screen.dart';
import 'package:meetday_app/features/community/presentation/providers/chat_provider.dart';
import 'package:meetday_app/features/community/presentation/providers/dashboard_provider.dart';
import 'package:meetday_app/features/community/presentation/providers/support_chat_provider.dart';
import 'package:meetday_app/features/community/presentation/spaces/space_dashboard_screen.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
            (ref) async => {
              'businessName': 'Northside Hall',
              'operatingCities': ['Pune'],
            },
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
            (ref) async => throw StateError('offline'),
          ),
        ],
        child: const MaterialApp(home: SpaceDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Support'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Support Chat'), findsOneWidget);
    expect(find.text('Unable to load support chat'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
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
