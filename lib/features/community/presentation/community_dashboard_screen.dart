import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/meetday_colors.dart';
import '../../auth/domain/account_role.dart';
import '../../auth/state/auth_provider.dart';
import 'chat/community_chat_hub.dart';
import 'community_detail_screen.dart';
import 'profile/profile_screen.dart';
import 'proposal_components.dart';
import 'providers/dashboard_provider.dart';
import 'providers/profile_provider.dart';
import 'support/community_support_chat_view.dart';

enum CommunityDashboardTab {
  dashboard,
  proposals,
  hubs,
  communities,
  deals,
  support,
  notifications,
}

extension CommunityDashboardTabX on CommunityDashboardTab {
  String get label {
    switch (this) {
      case CommunityDashboardTab.dashboard:
        return 'Dashboard';
      case CommunityDashboardTab.proposals:
        return 'Experience Proposals';
      case CommunityDashboardTab.hubs:
        return 'Community Hubs';
      case CommunityDashboardTab.communities:
        return 'Communities';
      case CommunityDashboardTab.deals:
        return 'Locked Deals';
      case CommunityDashboardTab.support:
        return 'Support Chat';
      case CommunityDashboardTab.notifications:
        return 'Notifications';
    }
  }

  IconData get icon {
    switch (this) {
      case CommunityDashboardTab.dashboard:
        return Icons.dashboard_rounded;
      case CommunityDashboardTab.proposals:
        return Icons.description_rounded;
      case CommunityDashboardTab.hubs:
        return Icons.calendar_today_rounded;
      case CommunityDashboardTab.communities:
        return Icons.groups_rounded;
      case CommunityDashboardTab.deals:
        return Icons.lock_rounded;
      case CommunityDashboardTab.support:
        return Icons.headset_mic_rounded;
      case CommunityDashboardTab.notifications:
        return Icons.notifications_rounded;
    }
  }
}

class CommunityDashboardScreen extends ConsumerStatefulWidget {
  const CommunityDashboardScreen({
    super.key,
    this.profileFuture,
    this.roleOverride,
  });

  final Future<Map<String, dynamic>>? profileFuture;
  final AccountRole? roleOverride;

  static const List<CommunityDashboardTab> tabs = [
    CommunityDashboardTab.dashboard,
    CommunityDashboardTab.proposals,
    CommunityDashboardTab.hubs,
    CommunityDashboardTab.communities,
    CommunityDashboardTab.deals,
    CommunityDashboardTab.support,
    CommunityDashboardTab.notifications,
  ];

  @override
  ConsumerState<CommunityDashboardScreen> createState() =>
      _CommunityDashboardScreenState();
}

class _CommunityDashboardScreenState
    extends ConsumerState<CommunityDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: CommunityDashboardScreen.tabs.length,
      vsync: this,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _currentTabIndex) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentTabIndex = index;
    });
    _tabController.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiClientProvider);
    final authState = ref.watch(authControllerProvider);
    final effectiveRole = widget.roleOverride ?? authState.role ?? AccountRole.community;

    return FutureBuilder<Map<String, dynamic>>(
      future: widget.profileFuture ??
          (() async {
            final token = await const FlutterSecureStorage().read(
              key: 'firebase_id_token',
            );
            api.setIdToken(token);
            if (effectiveRole == AccountRole.brand) {
              return await api.getMe();
            }
            return await api.getHostCommunityProfile();
          })(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        final profileName = (profile['name'] as String?) ??
            (profile['communityName'] as String?) ??
            (profile['brandName'] as String?) ??
            (profile['displayName'] as String?) ??
            (effectiveRole == AccountRole.brand ? 'My Brand' : 'My Community');
        final displayName = (profile['displayName'] as String?) ??
            (profile['firstName'] as String?) ??
            (profile['name'] as String?) ??
            (effectiveRole == AccountRole.brand ? 'Brand' : 'Host');
        final approvalStatus = (profile['approvalStatus'] as String?) ??
            (profile['status'] as String?) ??
            'APPROVED';
        final hostData = ref.watch(hostProfileProvider).asData?.value;
        final commData = ref.watch(communityProfileProvider).asData?.value;
        final unreadCount = ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;
        final avatarUrl = (hostData?['avatarUrl'] ?? profile['avatarUrl']) as String?;

        return Scaffold(
          backgroundColor: const Color(0xFFFFFDFC),
          appBar: AppBar(
            backgroundColor: MeetdayColors.primaryRed,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            centerTitle: true,
            automaticallyImplyLeading: false,
            leadingWidth: 64,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            // Notifications icon on the top left corner
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: GestureDetector(
                  onTap: () => _onTabSelected(6),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _currentTabIndex == 6
                          ? MeetdayColors.accentYellow
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          _currentTabIndex == 6
                              ? Icons.notifications_rounded
                              : Icons.notifications_none_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: MeetdayColors.primaryRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: GestureDetector(
              onTap: () => _onTabSelected(0),
              behavior: HitTestBehavior.opaque,
              child: SvgPicture.asset(
                'assets/logo/meetday-white.svg',
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            actions: [
              // Profile icon on top right corner (redirects to profile page)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileScreen(
                            onSelectTab: _onTabSelected,
                            currentTabIndex: _currentTabIndex,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: avatarUrl != null && avatarUrl.isNotEmpty
                            ? Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person_rounded,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(
                    color: MeetdayColors.primaryRed,
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _DashboardTabBody(
                      displayName: displayName,
                      profileName: profileName,
                      approvalStatus: approvalStatus,
                      role: effectiveRole,
                      onNavigateToTab: _onTabSelected,
                    ),
                    _ProposalTabBody(role: effectiveRole),
                    const _HubTabBody(),
                    const _CommunityTabBody(),
                    const CommunityChatHubScreen(),
                    const _SupportTabBody(),
                    const _NotificationsTabBody(),
                  ],
                ),
          bottomNavigationBar: _MeetdayMobileBottomBar(
            currentIndex: _currentTabIndex,
            onTap: _onTabSelected,
          ),
        );
      },
    );
  }
}

class _DashboardTabBody extends ConsumerWidget {
  const _DashboardTabBody({
    required this.displayName,
    required this.profileName,
    required this.approvalStatus,
    required this.role,
    required this.onNavigateToTab,
  });

  final String displayName;
  final String profileName;
  final String approvalStatus;
  final AccountRole role;
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBrand = role == AccountRole.brand;

    // Fetch data from backend
    final proposalsAsync = ref.watch(dashboardProposalsProvider);
    final hubsAsync = ref.watch(dashboardHubsProvider);
    final communitiesAsync = ref.watch(dashboardCommunitiesProvider);
    final dealsAsync = ref.watch(dashboardDealsProvider);
    final publishedAsync = ref.watch(publishedProposalsProvider);

    // Build proposal cards from data
    final proposalCards = proposalsAsync.when(
      data: (proposals) => proposals
          .map((p) => _ProposalCardPreview(
                title: (p['name'] ?? p['title'] ?? 'Untitled Proposal').toString(),
                dateLabel: (p['dateLabel'] ?? 'TBD').toString(),
                imageUrl: p['imageUrl'] as String?,
                status: p['status'] as String?,
                hasCash: p['hasCash'] == true,
                hasBarter: p['hasBarter'] == true,
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => ProposalDetailDialog(
                      proposal: p,
                      onSubmitApproval: () async {
                        Navigator.of(ctx).pop();
                        final id = p['id'];
                        if (id != null) {
                          try {
                            final api = ref.read(apiClientProvider);
                            await api.dio.post<dynamic>('/sponsorships/$id/submit');
                            ref.invalidate(dashboardProposalsProvider);
                          } catch (_) {}
                        }
                      },
                    ),
                  );
                },
              ))
          .toList(),
      loading: () => [_LoadingCard()],
      error: (err, stack) => [
        _ErrorCard(
          onRetry: () => ref.refresh(dashboardProposalsProvider),
        ),
      ],
    );

    // Build hub cards from data
    final hubCards = hubsAsync.when(
      data: (hubs) => hubs
          .map((h) => _CommunityHubCardPreview(
                title: h['title'] ?? 'Hub',
                memberCount: h['memberCount'] ?? '0',
                onTap: () => onNavigateToTab(2),
              ))
          .toList(),
      loading: () => [_LoadingCard()],
      error: (err, stack) => [
        _ErrorCard(
          onRetry: () => ref.refresh(dashboardHubsProvider),
        ),
      ],
    );

    final publishedProposals = (publishedAsync.asData?.value ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    // Build community cards from data
    final communityCards = communitiesAsync.when(
      data: (communities) => communities.isNotEmpty
          ? communities
              .map((c) => _CommunityCardPreview(
                    title: (c['title'] ?? c['name'] ?? 'Community').toString(),
                    memberCount: (c['memberCount'] ?? c['size'] ?? '0').toString(),
                    imageUrl: c['logoUrl'] as String?,
                    onTap: () {
                      final matching = getCommunityMatchingProposals(c, publishedProposals);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CommunityDetailScreen(
                            community: c,
                            activeProposals: matching,
                          ),
                        ),
                      );
                    },
                  ))
              .toList()
          : [
              _CommunityCardPreview(
                title: 'Meetday Social Circle',
                memberCount: '1,240',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CommunityDetailScreen(
                        community: {
                          'name': 'Meetday Social Circle',
                          'size': '1,240',
                          'about': 'A curated social circle bringing together founders, creators, and artists for weekly offline meetups.',
                          'operatingCities': ['Delhi NCR', 'Bengaluru'],
                          'avgGuestCount': '60-80',
                          'experiencesPerYear': '24',
                        },
                      ),
                    ),
                  );
                },
              ),
              _CommunityCardPreview(
                title: 'Creative Hosts Network',
                memberCount: '760',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CommunityDetailScreen(
                        community: {
                          'name': 'Creative Hosts Network',
                          'size': '760',
                          'about': 'Independent community organizers and event hosts curating intimate music, design, and culture popups.',
                          'operatingCities': ['Mumbai'],
                          'avgGuestCount': '45',
                          'experiencesPerYear': '12',
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
      loading: () => [_LoadingCard()],
      error: (err, stack) => [
        _ErrorCard(
          onRetry: () => ref.refresh(dashboardCommunitiesProvider),
        ),
      ],
    );

    // Build deal cards from data
    final dealCards = dealsAsync.when(
      data: (deals) => deals
          .map((d) => _DealCardPreview(
                brandName: (d['brandName'] ?? 'Brand').toString(),
                brandLogo: d['brandLogo'] as String?,
                projectName: (d['projectName'] ?? 'Project').toString(),
                amount: (d['amount'] ?? '₹0').toString(),
                paid: d['paid'] == true,
                hasReport: d['hasReport'] == true,
                onTap: () => onNavigateToTab(4),
              ))
          .toList(),
      loading: () => [_LoadingCard()],
      error: (err, stack) => [
        _ErrorCard(
          onRetry: () => ref.refresh(dashboardDealsProvider),
        ),
      ],
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        const SizedBox(height: 4),

        // Hero headline
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.4,
              color: const Color(0xFF111111),
            ),
            children: [
              TextSpan(text: 'Hey $displayName, '),
              TextSpan(
                text: isBrand
                    ? 'what are we sponsoring today?'
                    : 'what are we building today?',
                style: const TextStyle(color: MeetdayColors.primaryRed),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        Center(
          child: Text(
            isBrand
                ? 'Browse sponsorship opportunities or check out communities!'
                : 'Start something new or pick up where you left off!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF667085),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Two Hero Action Cards (Stacked vertically for mobile phone screens, exactly like frontend)
        _ActionCard(
          title: isBrand ? 'Curated Experiences' : 'Raise Sponsorship',
          badge: 'LIVE',
          body: isBrand
              ? 'Browse hand-picked, curated experiences from top communities and secure offline marketing opportunities.'
              : 'Build custom proposals, pitch relevant brand sponsors, and secure brand backing to scale your upcoming experiences.',
          buttonLabel: isBrand ? 'START EXPLORING ➔' : 'CREATE PROPOSAL ➔',
          accent: MeetdayColors.accentYellow,
          onTap: () => onNavigateToTab(1),
        ),

        const SizedBox(height: 12),

        _ActionCard(
          title: isBrand ? 'Launch a Campaign' : 'Explore Campaigns',
          badge: isBrand ? 'LIVE' : 'SOON',
          body: isBrand
              ? 'Share your offline marketing requirements with active communities and get matched instantly.'
              : 'Browse active marketing and sponsorship campaign briefs posted by brands, review requirements, and contact them to collaborate.',
          buttonLabel: isBrand ? 'POST A BRIEF ➔' : 'EXPLORE CAMPAIGNS Soon',
          accent: isBrand ? MeetdayColors.accentYellow : const Color(0xFFE5E7EB),
          disabled: !isBrand,
          onTap: isBrand ? () => onNavigateToTab(1) : null,
        ),

        const SizedBox(height: 20),
        const Divider(height: 1, color: Color(0x1F000000), thickness: 1.5),
        const SizedBox(height: 18),

        // Section 1: Proposals
        _SectionHeaderRow(
          title: isBrand ? 'Curated Proposals' : 'Sponsorship Proposals',
          subtitle: isBrand
              ? 'Approved community event sponsorship proposals.'
              : 'View your approved proposals.',
          actionLabel: 'View All Proposals >',
          onActionTap: () => onNavigateToTab(1),
        ),
        const SizedBox(height: 10),
        proposalCards.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(2.5, 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.note_add_outlined, size: 32, color: Colors.black54),
                    const SizedBox(height: 8),
                    Text(
                      'No proposals created yet',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your first proposal to get sponsored by top brands.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => onNavigateToTab(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: MeetdayColors.primaryRed,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 1.8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          '+ CREATE PROPOSAL',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: proposalCards.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => proposalCards[index],
                ),
              ),

        const SizedBox(height: 22),

        // Section 2: Active Community Hubs
        _SectionHeaderRow(
          title: 'Active Community Hubs',
          subtitle:
              'Discover venues and hubs for offline activations and community events.',
          actionLabel: 'View All Hubs >',
          onActionTap: () => onNavigateToTab(2),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: hubCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => hubCards[index],
          ),
        ),

        const SizedBox(height: 22),

        // Section 3: Active Communities
        _SectionHeaderRow(
          title: 'Active Communities',
          subtitle:
              'Discover verified creator and host communities on Meetday.',
          actionLabel: 'View All Communities >',
          onActionTap: () => onNavigateToTab(3),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: communityCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => communityCards[index],
          ),
        ),

        const SizedBox(height: 22),

        // Section 4: Locked Deals & Reports
        _SectionHeaderRow(
          title: 'Locked Deals & Reports',
          subtitle:
              'View locked deal terms and submitted deliverables reports.',
          actionLabel: 'Go to Chats >',
          onActionTap: () => onNavigateToTab(4),
        ),
        const SizedBox(height: 10),
        dealsAsync.when(
          data: (deals) {
            if (deals.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(2.5, 2.5),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 32, color: Colors.black54),
                    const SizedBox(height: 8),
                    Text(
                      'No locked deals yet',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lock terms with a brand sponsor in your chat dashboard to start earning.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              );
            }
            return SizedBox(
              height: 155,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: dealCards.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) => dealCards[index],
              ),
            );
          },
          loading: () => SizedBox(
            height: 155,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [_LoadingCard()],
            ),
          ),
          error: (err, stack) => _ErrorCard(
            onRetry: () => ref.refresh(dashboardDealsProvider),
          ),
        ),
      ],
    );
  }
}

class _SectionHeaderRow extends StatelessWidget {
  const _SectionHeaderRow({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionTap,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
            ),
            GestureDetector(
              onTap: onActionTap,
              child: Text(
                actionLabel,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF6C32D1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.badge,
    required this.body,
    required this.buttonLabel,
    required this.accent,
    this.disabled = false,
    this.onTap,
  });

  final String title;
  final String badge;
  final String body;
  final String buttonLabel;
  final Color accent;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.poppins(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF525252),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: disabled ? null : onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: disabled ? const Color(0x12000000) : accent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: disabled ? const Color(0x33000000) : Colors.black,
                  width: disabled ? 1.5 : 2,
                ),
                boxShadow: disabled
                    ? null
                    : const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: disabled ? const Color(0x66000000) : Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProposalCardPreview extends StatelessWidget {
  const _ProposalCardPreview({
    required this.title,
    required this.dateLabel,
    this.imageUrl,
    this.status,
    this.hasCash = false,
    this.hasBarter = false,
    this.onTap,
  });

  final String title;
  final String dateLabel;
  final String? imageUrl;
  final String? status;
  final bool hasCash;
  final bool hasBarter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1:1 Image
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (imageUrl != null && imageUrl!.isNotEmpty)
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _fallbackThumbnail(),
                            )
                          : _fallbackThumbnail(),

                      // Status badge on TOP LEFT
                      if (status != null && status!.isNotEmpty)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: _statusBadge(status!),
                        ),

                      // Cash / Barter badge on the TOP RIGHT
                      if (hasCash || hasBarter)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasCash)
                                Container(
                                  margin: EdgeInsets.only(bottom: hasBarter ? 3 : 0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    border: Border.all(color: Colors.black, width: 1.2),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(1, 1),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'CASH',
                                    style: GoogleFonts.poppins(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              if (hasBarter)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MeetdayColors.accentYellow,
                                    border: Border.all(color: Colors.black, width: 1.2),
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(1, 1),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'BARTER',
                                    style: GoogleFonts.poppins(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Below 1:1 image: Title + Date
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: Color(0xFF667085),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackThumbnail() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade200,
            Colors.orange.shade100,
            Colors.yellow.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          title.substring(0, title.length > 2 ? 2 : title.length).toUpperCase(),
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg = const Color(0xFF4ADE80);
    Color fg = Colors.black;
    String label = status;

    if (status == 'PUBLISHED') {
      bg = const Color(0xFF4ADE80);
      label = 'LIVE';
    } else if (status == 'UNDER_REVIEW') {
      bg = const Color(0xFFFFC940);
      label = 'REVIEW';
    } else if (status == 'DRAFT') {
      bg = const Color(0xFFF1F5F9);
      label = 'DRAFT';
    } else if (status == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'REJECTED';
    } else if (status == 'COMPLETED') {
      bg = const Color(0xFF1E293B);
      fg = Colors.white;
      label = 'DONE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: Colors.black, width: 1.1),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(1, 1),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 7.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _CommunityHubCardPreview extends StatelessWidget {
  const _CommunityHubCardPreview({
    required this.title,
    required this.memberCount,
    this.onTap,
  });

  final String title;
  final String memberCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1:1 Image
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: _fallbackThumbnail(),
                ),
              ),

              // Below 1:1 image: Name + Members
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5C343),
                            border: Border.all(color: Colors.black, width: 1.1),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                            memberCount,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Members',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0x80000000),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFDBEAFE),
            Color(0xFFC7D2FE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black,
                offset: Offset(1.5, 1.5),
                blurRadius: 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.location_city_rounded,
            size: 22,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _CommunityCardPreview extends StatelessWidget {
  const _CommunityCardPreview({
    required this.title,
    required this.memberCount,
    this.imageUrl,
    this.width = 148,
    this.onTap,
  });

  final String title;
  final String memberCount;
  final String? imageUrl;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1:1 Image
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? Image.network(
                          imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _fallbackThumbnail(),
                        )
                      : _fallbackThumbnail(),
                ),
              ),

              // Below 1:1 image: Name + Members
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5C343),
                            border: Border.all(color: Colors.black, width: 1.1),
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black,
                                offset: Offset(1, 1),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Text(
                            memberCount,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Members',
                          style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0x80000000),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackThumbnail() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFCE29),
      ),
      child: Center(
        child: Text(
          title.substring(0, title.length > 2 ? 2 : title.length).toUpperCase(),
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}


class _DealCardPreview extends StatelessWidget {
  const _DealCardPreview({
    required this.brandName,
    required this.projectName,
    required this.amount,
    required this.paid,
    this.brandLogo,
    this.hasReport = false,
    this.onTap,
  });

  final String brandName;
  final String projectName;
  final String amount;
  final bool paid;
  final String? brandLogo;
  final bool hasReport;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(2.5, 2.5),
              blurRadius: 0,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13.5),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: ClipOval(
                        child: (brandLogo != null && brandLogo!.isNotEmpty)
                            ? Image.network(
                                brandLogo!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Center(
                                  child: Text(
                                    brandName.isNotEmpty
                                        ? brandName.substring(0, 1).toUpperCase()
                                        : 'B',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  brandName.isNotEmpty
                                      ? brandName.substring(0, 1).toUpperCase()
                                      : 'B',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        brandName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                        border: Border.all(color: Colors.black, width: 1.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        paid ? 'PAID' : 'PENDING',
                        style: GoogleFonts.poppins(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (hasReport) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          border: Border.all(color: Colors.black, width: 1.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'REPORT',
                          style: GoogleFonts.poppins(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MeetdayColors.accentYellow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 1.2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Deal Value',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        amount,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Other Tabs Implementation ─────────────────────────────────────────────

class _ProposalTabBody extends ConsumerStatefulWidget {
  const _ProposalTabBody({required this.role});

  final AccountRole role;

  @override
  ConsumerState<_ProposalTabBody> createState() => _ProposalTabBodyState();
}

class _ProposalTabBodyState extends ConsumerState<_ProposalTabBody> {
  String _selectedSegment = 'ALL';

  void _openCreateProposalModal([Map<String, dynamic>? initialProposal]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => ProposalFormScreen(
          initialProposal: initialProposal,
          onSuccess: () {
            ref.invalidate(dashboardProposalsProvider);
          },
        ),
      ),
    );
  }

  void _openProposalDetail(Map<String, dynamic> proposal) {
    showDialog<void>(
      context: context,
      builder: (ctx) => ProposalDetailDialog(
        proposal: proposal,
        onEdit: () {
          _openCreateProposalModal(proposal);
        },
        onSubmitApproval: () async {
          Navigator.of(ctx).pop();
          final id = proposal['id'];
          if (id != null) {
            try {
              final api = ref.read(apiClientProvider);
              await api.dio.patch<dynamic>('/sponsorships/$id/submit');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Proposal submitted for admin approval!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
              ref.invalidate(dashboardProposalsProvider);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to submit proposal: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposalsAsync = ref.watch(dashboardProposalsProvider);

    return proposalsAsync.when(
      data: (proposals) {
        final allCount = proposals.length;
        final publishedCount = proposals.where((p) => p['status'] == 'PUBLISHED').length;
        final underReviewCount = proposals.where((p) => p['status'] == 'UNDER_REVIEW').length;
        final draftCount = proposals.where((p) => p['status'] == 'DRAFT').length;
        final completedCount = proposals.where((p) => p['status'] == 'COMPLETED').length;
        final rejectedCount = proposals.where((p) => p['status'] == 'REJECTED').length;

        final filtered = proposals.where((p) {
          if (_selectedSegment == 'ALL') return true;
          return p['status'] == _selectedSegment;
        }).toList();

        final segments = [
          {'key': 'ALL', 'label': 'ALL ($allCount)'},
          {'key': 'PUBLISHED', 'label': 'PUBLISHED ($publishedCount)'},
          {'key': 'UNDER_REVIEW', 'label': 'UNDER REVIEW ($underReviewCount)'},
          {'key': 'DRAFT', 'label': 'DRAFT ($draftCount)'},
          {'key': 'COMPLETED', 'label': 'COMPLETED ($completedCount)'},
          {'key': 'REJECTED', 'label': 'REJECTED ($rejectedCount)'},
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          children: [
            // Header with Title and + CREATE PROPOSAL button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.role == AccountRole.brand
                            ? 'Curated Experiences'
                            : 'My Sponsorships',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.role == AccountRole.brand
                            ? 'Discover and back vetted experiences hosted by communities.'
                            : 'For all your proposals',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openCreateProposalModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: MeetdayColors.primaryRed,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'CREATE NEW',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Horizontal segment bar (tabs)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: segments.map((seg) {
                  final isSelected = _selectedSegment == seg['key'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSegment = seg['key']!;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.black, width: 1.8),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(
                                  color: Colors.black,
                                  offset: Offset(1.5, 1.5),
                                  blurRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        seg['label']!,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF525252),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Proposal cards list or Empty State
            if (filtered.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black38,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined, size: 44, color: Colors.black38),
                    const SizedBox(height: 10),
                    Text(
                      'No proposals found',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No proposals in "$_selectedSegment" category yet.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _openCreateProposalModal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: MeetdayColors.accentYellow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          '+ CREATE PROPOSAL',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map((p) => ProposalListItemCard(
                    proposal: p,
                    onTap: () => _openProposalDetail(p),
                  )),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (err, stack) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Text(
            widget.role == AccountRole.brand ? 'Curated Experiences' : 'My Sponsorships',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 14),
          _ErrorCard(onRetry: () => ref.refresh(dashboardProposalsProvider)),
        ],
      ),
    );
  }
}

class _HubTabBody extends StatelessWidget {
  const _HubTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Text(
          'Community Hubs',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Discover offline partner venues and physical spaces for events.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 12),
        _NeoListCard(
          title: 'Design & Culture Hub',
          subtitle: '3 spaces · 12 active members',
          status: 'Open',
          statusColor: const Color(0xFFDBEAFE),
        ),
        _NeoListCard(
          title: 'Startup Circle Hub',
          subtitle: '2 spaces · 8 active members',
          status: 'Open',
          statusColor: const Color(0xFFDCFCE7),
        ),
      ],
    );
  }
}

class _NeoListCard extends StatelessWidget {
  const _NeoListCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(2.5, 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF667085),
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: statusColor,
              border: Border.all(color: Colors.black, width: 1.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityTabBody extends ConsumerWidget {
  const _CommunityTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(dashboardCommunitiesProvider);
    final publishedAsync = ref.watch(publishedProposalsProvider);
    final publishedProposals = (publishedAsync.asData?.value ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList();

    return communitiesAsync.when(
      data: (communities) {
        final list = communities.isNotEmpty
            ? communities
            : [
                <String, dynamic>{
                  'id': 'demo-1',
                  'name': 'Meetday Social Circle',
                  'size': '1,240',
                  'memberCount': '1,240',
                  'about':
                      'A curated social circle bringing together founders, creators, and artists for weekly offline meetups.',
                  'operatingCities': ['Delhi NCR', 'Bengaluru'],
                  'avgGuestCount': '60-80',
                  'experiencesPerYear': '24',
                },
                <String, dynamic>{
                  'id': 'demo-2',
                  'name': 'Creative Hosts Network',
                  'size': '760',
                  'memberCount': '760',
                  'about':
                      'Independent community organizers and event hosts curating intimate music, design, and culture popups.',
                  'operatingCities': ['Mumbai'],
                  'avgGuestCount': '45',
                  'experiencesPerYear': '12',
                },
              ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            Text(
              'Communities',
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Communities onboarded on Meetday, available for sponsorship.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final c = list[index];
                final name = (c['name'] ?? c['title'] ?? 'Community').toString();
                final members = (c['memberCount'] ?? c['size'] ?? '0').toString();
                final imageUrl = c['logoUrl'] as String?;

                return _CommunityCardPreview(
                  title: name,
                  memberCount: members,
                  imageUrl: imageUrl,
                  width: null,
                  onTap: () {
                    final matchingProposals = getCommunityMatchingProposals(c, publishedProposals);

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CommunityDetailScreen(
                          community: c,
                          activeProposals: matchingProposals,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: MeetdayColors.primaryRed,
        ),
      ),
      error: (err, stack) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          Text(
            'Communities',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 12),
          _ErrorCard(
            onRetry: () => ref.refresh(dashboardCommunitiesProvider),
          ),
        ],
      ),
    );
  }
}


class _SupportTabBody extends StatelessWidget {
  const _SupportTabBody();

  @override
  Widget build(BuildContext context) {
    return const CommunitySupportChatView();
  }
}

class _NotificationsTabBody extends ConsumerWidget {
  const _NotificationsTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final api = ref.watch(apiClientProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Stay updated on proposals, chats, deals, and community activity.',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                try {
                  await api.markAllNotificationsRead();
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadNotificationsCountProvider);
                } catch (_) {}
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(1.5, 1.5), blurRadius: 0),
                  ],
                ),
                child: Text(
                  'MARK ALL READ',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black,
                      offset: Offset(3, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 28,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No notifications yet',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You're all caught up! When you receive proposals, deal updates, or messages, they will appear here.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: notifications.map((notif) {
                final id = notif['id']?.toString() ?? '';
                final title = (notif['title'] ?? 'Notification').toString();
                final body = (notif['body'] ?? notif['message'] ?? notif['description'] ?? '').toString();
                final type = notif['type']?.toString();
                final isRead = notif['isRead'] == true || notif['read'] == true;
                final createdAt = notif['createdAt']?.toString() ?? notif['timestamp']?.toString();
                String timeLabel = '';
                if (createdAt != null && createdAt.isNotEmpty) {
                  try {
                    final dt = DateTime.parse(createdAt).toLocal();
                    final diff = DateTime.now().difference(dt);
                    if (diff.inMinutes < 1) {
                      timeLabel = 'Just now';
                    } else if (diff.inHours < 1) {
                      timeLabel = '${diff.inMinutes}m ago';
                    } else if (diff.inDays < 1) {
                      timeLabel = '${diff.inHours}h ago';
                    } else if (diff.inDays < 7) {
                      timeLabel = '${diff.inDays}d ago';
                    } else {
                      timeLabel = '${dt.day}/${dt.month}/${dt.year}';
                    }
                  } catch (_) {
                    timeLabel = '';
                  }
                }

                return GestureDetector(
                  onTap: () async {
                    if (!isRead && id.isNotEmpty) {
                      try {
                        await api.markNotificationRead(id);
                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadNotificationsCountProvider);
                      } catch (_) {}
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2.5, 2.5),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: isRead ? const Color(0xFFF1F5F9) : MeetdayColors.primaryRed,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black, width: 1.5),
                          ),
                          child: Icon(
                            _getNotificationIcon(type),
                            size: 18,
                            color: isRead ? Colors.black87 : Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: GoogleFonts.bricolageGrotesque(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF111111),
                                      ),
                                    ),
                                  ),
                                  if (!isRead) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: MeetdayColors.primaryRed,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: Colors.black, width: 1),
                                      ),
                                      child: Text(
                                        'NEW',
                                        style: GoogleFonts.poppins(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  body,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: const Color(0xFF525252),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (timeLabel.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  timeLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
            ),
          ),
          error: (err, stack) => _ErrorCard(
            onRetry: () => ref.refresh(notificationsProvider),
          ),
        ),
      ],
    );
  }

  static IconData _getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'sponsorship':
      case 'proposal':
        return Icons.handshake_rounded;
      case 'chat':
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'deal':
        return Icons.lock_rounded;
      case 'host_approved':
      case 'approved':
        return Icons.check_circle_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}


class _MeetdayMobileBottomBar extends StatelessWidget {
  const _MeetdayMobileBottomBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // 5 primary dock destinations: Communities (3), Hubs (2), Proposals (1 - Center), Chats (4), Support (5)
    final items = [
      (3, Icons.groups_rounded, null, null, 'Communities'),
      (2, Icons.calendar_today_rounded, null, null, 'Hubs'),
      (1, Icons.description_rounded, null, null, 'Proposals'),
      (4, null, 'assets/icons/chat.svg', 'assets/icons/chat-filled.svg', 'Chats'),
      (5, Icons.headset_mic_rounded, null, null, 'Support'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: MeetdayColors.primaryRed,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final index = item.$1;
            final icon = item.$2;
            final svgOutlined = item.$3;
            final svgFilled = item.$4;
            final label = item.$5;
            final isSelected = currentIndex == index;
            final itemColor = isSelected ? Colors.black : Colors.white;

            return GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(
                  horizontal: isSelected ? 12 : 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? MeetdayColors.accentYellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 2)
                      : null,
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (svgOutlined != null)
                      SvgPicture.asset(
                        (isSelected && svgFilled != null) ? svgFilled : svgOutlined,
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          itemColor,
                          BlendMode.srcIn,
                        ),
                      )
                    else if (icon != null)
                      Icon(
                        icon,
                        size: 20,
                        color: itemColor,
                      ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(MeetdayColors.primaryRed),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: MeetdayColors.primaryRed),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MeetdayColors.primaryRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

