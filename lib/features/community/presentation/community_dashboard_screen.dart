import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/meetday_colors.dart';
import '../../auth/domain/account_role.dart';
import '../../auth/state/auth_provider.dart';
import '../../dashboard/presentation/meetday_sidebar_drawer.dart';
import 'providers/dashboard_provider.dart';

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
        final avatarUrl = profile['avatarUrl'] as String?;

        return Scaffold(
          backgroundColor: const Color(0xFFFFFDFC),
          drawer: MeetdaySidebarDrawer(
            currentTabIndex: _currentTabIndex,
            onSelectTab: _onTabSelected,
            communityName: profileName,
            avatarUrl: avatarUrl,
            role: effectiveRole,
          ),
          appBar: AppBar(
            backgroundColor: MeetdayColors.primaryRed,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            centerTitle: false,
            automaticallyImplyLeading: false,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            titleSpacing: 16,
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
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    child: const Icon(Icons.menu_rounded, color: Colors.black, size: 20),
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
                    const _ChatsTabBody(),
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

    // Build proposal cards from data
    final proposalCards = proposalsAsync.when(
      data: (proposals) => proposals
          .map((p) => _ProposalCardPreview(
                title: p['title'] ?? 'Untitled',
                dateLabel: p['dateLabel'] ?? 'TBD',
                hasCash: p['hasCash'] ?? false,
                hasBarter: p['hasBarter'] ?? false,
                onTap: () => onNavigateToTab(1),
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

    // Build community cards from data
    final communityCards = communitiesAsync.when(
      data: (communities) => communities.isNotEmpty
          ? communities
              .map((c) => _CommunityCardPreview(
                    title: c['title'] ?? 'Community',
                    memberCount: c['memberCount'] ?? '0',
                    onTap: () => onNavigateToTab(3),
                  ))
              .toList()
          : [
              _CommunityCardPreview(
                title: 'Meetday Social Circle',
                memberCount: '1,240',
                onTap: () => onNavigateToTab(3),
              ),
              _CommunityCardPreview(
                title: 'Creative Hosts Network',
                memberCount: '760',
                onTap: () => onNavigateToTab(3),
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
                brandName: d['brandName'] ?? 'Brand',
                projectName: d['projectName'] ?? 'Project',
                amount: d['amount'] ?? '₹0',
                paid: d['paid'] ?? false,
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
        SizedBox(
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
        SizedBox(
          height: 155,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: dealCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) => dealCards[index],
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
    this.hasCash = false,
    this.hasBarter = false,
    this.onTap,
  });

  final String title;
  final String dateLabel;
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
                    _fallbackThumbnail(),

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
  });

  final String brandName;
  final String projectName;
  final String amount;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(10),
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
                child: Center(
                  child: Text(
                    brandName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
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
    );
  }
}

// ── Other Tabs Implementation ─────────────────────────────────────────────

class _ProposalTabBody extends StatelessWidget {
  const _ProposalTabBody({required this.role});

  final AccountRole role;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Text(
          role == AccountRole.brand ? 'Curated Experiences' : 'Experience Proposals',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          role == AccountRole.brand
              ? 'Discover and back vetted experiences hosted by communities.'
              : 'Submit and manage your sponsorship proposals for upcoming events.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 12),
        _NeoListCard(
          title: 'Weekend Night Market',
          subtitle: 'Under review · submitted 2 days ago',
          status: 'Reviewing',
          statusColor: const Color(0xFFFEF3C7),
        ),
        _NeoListCard(
          title: 'Founders Mixer',
          subtitle: 'Published · visible to brands',
          status: 'Live',
          statusColor: const Color(0xFFDCFCE7),
        ),
        _NeoListCard(
          title: 'Creative Workshop',
          subtitle: 'Draft · waiting for edits',
          status: 'Draft',
          statusColor: const Color(0xFFE5E7EB),
        ),
      ],
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

class _CommunityTabBody extends StatelessWidget {
  const _CommunityTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Text(
          'Communities',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Browse registered communities and host collectives on Meetday.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 12),
        _NeoListCard(
          title: 'Meetday Social Circle',
          subtitle: 'Member count · 1,240 members',
          status: 'Approved',
          statusColor: const Color(0xFFDCFCE7),
        ),
        _NeoListCard(
          title: 'Creative Hosts Network',
          subtitle: 'Member count · 760 members',
          status: 'Pending',
          statusColor: const Color(0xFFFEF3C7),
        ),
      ],
    );
  }
}

class _ChatsTabBody extends StatelessWidget {
  const _ChatsTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Text(
          'Chats & Messages',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Direct conversations with brand sponsors, hosts, and collaborators.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 12),
        _NeoListCard(
          title: 'Aster Labs Partnership',
          subtitle: 'Active chat · Last message: "Contract looks good!"',
          status: 'Online',
          statusColor: const Color(0xFFDCFCE7),
        ),
        _NeoListCard(
          title: 'Urban Mint Activation',
          subtitle: 'Awaiting response · Proposal sent',
          status: '1 Unread',
          statusColor: const Color(0xFFFEF3C7),
        ),
        _NeoListCard(
          title: 'Meetday Support Concierge',
          subtitle: 'Always here to assist with verification & payouts',
          status: '24/7 Support',
          statusColor: const Color(0xFFDBEAFE),
        ),
      ],
    );
  }
}

class _SupportTabBody extends StatelessWidget {
  const _SupportTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Text(
          'Support Chat',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Need assistance? Message Meetday concierge support anytime.',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 12),
        _NeoListCard(
          title: 'Meetday Concierge Support',
          subtitle: 'Active support thread · last reply 14m ago',
          status: 'Active',
          statusColor: const Color(0xFFDCFCE7),
        ),
        _NeoListCard(
          title: 'KYC & Payout Helpdesk',
          subtitle: 'Bank account validation inquiry',
          status: 'Open',
          statusColor: const Color(0xFFDBEAFE),
        ),
      ],
    );
  }
}

class _NotificationsTabBody extends StatelessWidget {
  const _NotificationsTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Text(
          'Notifications',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 18,
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
        const SizedBox(height: 12),
        _NeoListCard(
          title: 'New Sponsorship Interest',
          subtitle: 'A brand sponsor initiated collaboration on your event.',
          status: 'New',
          statusColor: MeetdayColors.primaryRed,
          statusTextColor: Colors.white,
        ),
        _NeoListCard(
          title: 'Profile Approved',
          subtitle: 'Your community workspace is verified and live.',
          status: 'Approved',
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
    this.statusTextColor = Colors.black,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final Color statusTextColor;

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
                color: statusTextColor,
              ),
            ),
          ),
        ],
      ),
    );
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
      (3, Icons.groups_rounded, 'Communities'),
      (2, Icons.calendar_today_rounded, 'Hubs'),
      (1, Icons.description_rounded, 'Proposals'),
      (4, Icons.chat_bubble_rounded, 'Chats'),
      (5, Icons.headset_mic_rounded, 'Support'),
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
            final label = item.$3;
            final isSelected = currentIndex == index;

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
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? Colors.black : Colors.white,
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

