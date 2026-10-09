import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../../../auth/domain/account_role.dart';
import '../../../auth/state/auth_provider.dart';
import '../campaigns/campaigns_screen.dart';
import '../chat/community_chat_hub.dart';
import '../community_detail_screen.dart';
import '../deals/brand_deals_screen.dart';
import '../profile/profile_screen.dart';
import '../proposal/proposal_form_screen.dart';
import '../proposal_components.dart';
import '../providers/chat_provider.dart';
import '../providers/dashboard_provider.dart';
import '../support/community_support_chat_view.dart';

/// Provider for authenticated space partner's account profile
final spaceDashboardProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final token = await const FlutterSecureStorage().read(
        key: 'firebase_id_token',
      );
      if (token != null && token.isNotEmpty) {
        api.setIdToken(token);
      }
      return api.getSpaceProfile();
    });

/// Provider for authenticated space partner's public community space listing
final spaceCommunityProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final api = ref.watch(apiClientProvider);
      try {
        final profile = await api.getSpaceCommunityProfile();
        return profile.isNotEmpty ? profile : null;
      } catch (_) {
        return null;
      }
    });

/// Provider for locked deals for space partner
final spaceLockedDealsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = ref.watch(apiClientProvider);
      try {
        final response = await api.dio.get<dynamic>(
          '/spaces/chats',
          queryParameters: {'role': 'SPACE', 'status': 'ACCEPTED'},
        );
        dynamic raw = response.data;
        if (raw is Map && raw['data'] != null) raw = raw['data'];
        final threads = raw is List
            ? raw
                .whereType<Map>()
                .map((t) => Map<String, dynamic>.from(t))
                .toList()
            : <Map<String, dynamic>>[];

        final deals = await Future.wait(
          threads.map((thread) async {
            final threadId = thread['id']?.toString();
            if (threadId == null || threadId.isEmpty) return null;
            try {
              final deal = await api.getSpaceDeal(threadId);
              if (deal != null &&
                  ((deal['status'] ?? '').toString().toUpperCase() ==
                          'APPROVED' ||
                      deal['isDealLocked'] == true)) {
                bool hasReport = false;
                try {
                  final rep = await api.getSpaceDealReport(threadId, 'SPACE');
                  if (rep != null) hasReport = true;
                } catch (_) {}
                return <String, dynamic>{
                  ...deal,
                  'id': deal['id'] ?? threadId,
                  'spaceInterestId': threadId,
                  'counterpartName':
                      thread['counterpartName'] ?? 'Partner',
                  'counterpartAvatarUrl': thread['counterpartAvatarUrl'],
                  'requesterType': thread['requesterType'] ?? 'COMMUNITY',
                  'thread': thread,
                  'hasReport': hasReport,
                };
              }
            } catch (_) {}
            return null;
          }),
        );
        return deals.whereType<Map<String, dynamic>>().toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    });

class SpaceDashboardScreen extends ConsumerStatefulWidget {
  const SpaceDashboardScreen({super.key});

  @override
  ConsumerState<SpaceDashboardScreen> createState() =>
      _SpaceDashboardScreenState();
}

class _SpaceDashboardScreenState extends ConsumerState<SpaceDashboardScreen> {
  // Current active tab index matching CommunityDashboardScreen tab indexes:
  // 0: Dashboard, 1: Proposals, 2: Explore, 5: Deals, 6: Support, 7: Notifications, 9: Chats
  int _currentTabIndex = 0;
  String _exploreSubView = 'menu'; // 'menu', 'campaigns', or 'communities'

  void _onTabSelected(int index, {String? exploreSubView}) {
    setState(() {
      _currentTabIndex = index;
      if (exploreSubView != null) {
        _exploreSubView = exploreSubView;
      }
    });
  }

  Future<void> _refreshAll() async {
    ref.invalidate(spaceDashboardProfileProvider);
    ref.invalidate(spaceCommunityProfileProvider);
    ref.invalidate(dashboardProposalsProvider);
    ref.invalidate(dashboardCampaignsProvider);
    ref.invalidate(communityCollaborationCommunitiesProvider);
    ref.invalidate(spaceLockedDealsProvider);
    ref.invalidate(chatHubProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
    await ref.read(spaceDashboardProfileProvider.future);
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        title: Text(
          'Sign out?',
          style: GoogleFonts.bricolageGrotesque(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        content: Text(
          'You can sign back in anytime to manage your Hub Partner account.',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: MeetdayColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.black, width: 1.5),
              ),
            ),
            child: Text(
              'Sign out',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (shouldSignOut == true && mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  void _openHubProfileModal(
    BuildContext context,
    Map<String, dynamic> profile,
    Map<String, dynamic>? community,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HubProfileSheet(
        profile: profile,
        community: community,
        onSignOut: _confirmSignOut,
        onProfileUpdated: () {
          ref.invalidate(spaceDashboardProfileProvider);
          ref.invalidate(spaceCommunityProfileProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(spaceDashboardProfileProvider);
    final communityAsync = ref.watch(spaceCommunityProfileProvider);
    final unreadChatCount = ref.watch(totalChatUnreadNotificationCountProvider);
    final unreadNotifCount =
        ref.watch(unreadNotificationsCountProvider).asData?.value ?? 0;

    final profile = profileAsync.asData?.value ?? const <String, dynamic>{};
    final community = communityAsync.asData?.value;
    final userMap = profile['user'] is Map ? profile['user'] as Map : const {};
    final avatarUrl =
        (community?['logoUrl'] ??
                profile['avatarUrl'] ??
                userMap['avatarUrl'])
            as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      // ── Neo-Brutalist Top Bar (identical to CommunityDashboardScreen) ──────────
      appBar: AppBar(
        backgroundColor: MeetdayColors.primaryRed,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leadingWidth: 64,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
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
                            Icons.storefront_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                        )
                      : const Icon(
                          Icons.storefront_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: GestureDetector(
                onTap: () => _onTabSelected(7),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _currentTabIndex == 7
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
                        _currentTabIndex == 7
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      if (unreadNotifCount > 0)
                        Positioned(
                          top: 7,
                          right: 7,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: MeetdayColors.primaryRed,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // ── Main Body with Tabs ────────────────────────────────────────────────
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
        ),
        error: (err, _) => _ProfileLoadError(onRetry: _refreshAll),
        data: (profileData) {
          switch (_currentTabIndex) {
            case 1:
              return _SpaceProposalsTabBody(
                onBack: () => _onTabSelected(0),
                onNavigateToTab: _onTabSelected,
              );
            case 2:
              return _SpaceExploreTabBody(
                subView: _exploreSubView,
                onSubViewChanged: (v) => setState(() => _exploreSubView = v),
                onNavigateToTab: _onTabSelected,
              );
            case 5:
              return const BrandDealsScreen(role: AccountRole.space);
            case 6:
              return const CommunitySupportChatView(role: AccountRole.space);
            case 7:
              return _SpaceNotificationsTabBody(
                onOpenChat: (target) {
                  _onTabSelected(9);
                },
                onOpenDestination: (idx) {
                  _onTabSelected(idx);
                },
              );
            case 9:
              return const CommunityChatHubScreen(initialCategory: null);
            case 0:
            default:
              return _SpaceDashboardTabBody(
                profile: profileData,
                community: community,
                onNavigateToTab: _onTabSelected,
                onOpenCampaigns: () =>
                    _onTabSelected(2, exploreSubView: 'campaigns'),
                onOpenCommunities: () =>
                    _onTabSelected(2, exploreSubView: 'communities'),
                onOpenChats: () => _onTabSelected(9),
                onOpenDeals: () => _onTabSelected(5),
                onOpenProposals: () => _onTabSelected(1),
                onRefresh: _refreshAll,
              );
          }
        },
      ),

      // ── Neo-Brutalist Floating Bottom Bar ─────────────────────────────────
      bottomNavigationBar: _SpaceBottomBar(
        currentTabIndex: _currentTabIndex,
        unreadChatCount: unreadChatCount,
        onTap: (idx) => _onTabSelected(
          idx,
          exploreSubView: idx == 2 ? 'menu' : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEO-BRUTALIST BOTTOM BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SpaceBottomBar extends StatelessWidget {
  const _SpaceBottomBar({
    required this.currentTabIndex,
    required this.unreadChatCount,
    required this.onTap,
  });

  final int currentTabIndex;
  final int unreadChatCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      return const SizedBox.shrink();
    }

    final items = [
      (1, Icons.description_rounded, null, null, 'Proposals'),
      (2, Icons.explore_rounded, null, null, 'Explore'),
      (
        9,
        null,
        'assets/icons/chat.svg',
        'assets/icons/chat-filled.svg',
        'Chats',
      ),
      (5, Icons.lock_rounded, null, null, 'Deals'),
      (6, Icons.headset_mic_rounded, null, null, 'Support'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: MeetdayColors.primaryRed,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
            final isSelected = currentTabIndex == index;
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
                  color: isSelected
                      ? MeetdayColors.accentYellow
                      : Colors.transparent,
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (svgOutlined != null)
                          SvgPicture.asset(
                            (isSelected && svgFilled != null)
                                ? svgFilled
                                : svgOutlined,
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              itemColor,
                              BlendMode.srcIn,
                            ),
                          )
                        else if (icon != null)
                          Icon(icon, size: 20, color: itemColor),
                        if (label == 'Chats' && unreadChatCount > 0)
                          Positioned(
                            top: -6,
                            right: -8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 15,
                                minHeight: 15,
                              ),
                              decoration: BoxDecoration(
                                color: MeetdayColors.accentYellow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black,
                                    offset: Offset(1, 1),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  unreadChatCount > 9
                                      ? '9+'
                                      : '$unreadChatCount',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// 0. SPACE DASHBOARD TAB BODY (Matches Community & Frontend Dashboard)
// ─────────────────────────────────────────────────────────────────────────────

class _SpaceDashboardTabBody extends ConsumerWidget {
  const _SpaceDashboardTabBody({
    required this.profile,
    required this.community,
    required this.onNavigateToTab,
    required this.onOpenCampaigns,
    required this.onOpenCommunities,
    required this.onOpenChats,
    required this.onOpenDeals,
    required this.onOpenProposals,
    required this.onRefresh,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic>? community;
  final ValueChanged<int> onNavigateToTab;
  final VoidCallback onOpenCampaigns;
  final VoidCallback onOpenCommunities;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenDeals;
  final VoidCallback onOpenProposals;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessName = (profile['businessName'] ?? 'Space Partner')
        .toString();

    final campaignsAsync = ref.watch(dashboardCampaignsProvider);
    final communitiesAsync = ref.watch(dashboardCommunitiesProvider);
    final dealsAsync = ref.watch(spaceLockedDealsProvider);
    final publishedAsync = ref.watch(publishedProposalsProvider);

    final publishedProposals =
        (publishedAsync.asData?.value ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();

    // Build campaign cards
    final campaignCards = campaignsAsync.when(
      data: (campaigns) => campaigns
          .map(
            (c) => _CampaignCardPreview(
              campaign: c,
              onTap: () {
                showCampaignDetailModal(
                  context,
                  c,
                  onInterestSent: onRefresh,
                );
              },
            ),
          )
          .toList(),
      loading: () => const [_LoadingCard()],
      error: (err, stack) => [
        _ErrorCard(onRetry: () => ref.refresh(dashboardCampaignsProvider)),
      ],
    );

    // Build community cards
    final communityCards = communitiesAsync.when(
      data: (communities) => communities
          .map(
            (c) => _CommunityCardPreview(
              title: (c['name'] ?? c['title'] ?? 'Community').toString(),
              memberCount: (c['memberCount'] ?? c['size'] ?? '0').toString(),
              imageUrl: c['logoUrl'] as String?,
              onTap: () {
                final matching = getCommunityMatchingProposals(
                  c,
                  publishedProposals,
                );
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CommunityDetailScreen(
                      community: c,
                      activeProposals: matching,
                      isBrandPreview: false,
                      isHub: false,
                    ),
                  ),
                );
              },
            ),
          )
          .toList(),
      loading: () => const [_LoadingCard()],
      error: (err, stack) => [
        _ErrorCard(onRetry: () => ref.refresh(dashboardCommunitiesProvider)),
      ],
    );

    // Build deal cards
    final dealCards = dealsAsync.when(
      data: (deals) => deals
          .map(
            (d) => _DealCardPreview(
              brandName: (d['counterpartName'] ?? d['brandName'] ?? 'Brand').toString(),
              brandLogo: (d['counterpartAvatarUrl'] ?? d['brandLogo']) as String?,
              projectName: (d['projectName'] ?? d['proposalName'] ?? 'Project').toString(),
              amount: '₹${d['sponsorshipAmount'] ?? d['amount'] ?? 0}',
              paid: d['paid'] == true || d['isDealClosed'] == true,
              hasReport: d['hasReport'] == true,
              onTap: onOpenDeals,
            ),
          )
          .toList(),
      loading: () => const [_LoadingCard()],
      error: (err, stack) => [
        _ErrorCard(onRetry: () => ref.refresh(spaceLockedDealsProvider)),
      ],
    );

    return RefreshIndicator(
      color: MeetdayColors.primaryRed,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          const SizedBox(height: 4),

          // Centered Hero Headline (matching Community exactly)
          Text.rich(
            TextSpan(
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                height: 1.2,
                letterSpacing: -0.4,
                color: const Color(0xFF111111),
              ),
              children: [
                TextSpan(text: 'Hey $businessName, '),
                const TextSpan(
                  text: 'what are we building today?',
                  style: TextStyle(color: MeetdayColors.primaryRed),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 6),

          Center(
            child: Text(
              'Start something new or pick up where you left off!',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Two Hero Action Cards (Stacked vertically, full width, matching Community)
          _ActionCard(
            title: 'Raise Sponsorship',
            badge: 'LIVE',
            body:
                'Build custom proposals, pitch relevant brand sponsors, and secure brand backing to scale your upcoming experiences.',
            buttonLabel: 'CREATE PROPOSAL ➔',
            accent: MeetdayColors.accentYellow,
            onTap: onOpenProposals,
          ),

          const SizedBox(height: 12),

          _ActionCard(
            title: 'Explore Campaigns',
            badge: 'LIVE',
            body:
                'Browse active marketing and sponsorship campaign briefs posted by brands, review requirements, and contact them to collaborate.',
            buttonLabel: 'EXPLORE CAMPAIGNS ➔',
            accent: MeetdayColors.accentYellow,
            disabled: false,
            onTap: onOpenCampaigns,
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0x1F000000), thickness: 1.5),
          const SizedBox(height: 18),

          // Full-width red button: My Proposals
          GestureDetector(
            onTap: onOpenProposals,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: MeetdayColors.primaryRed,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.description_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'My Proposals',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          // Section 1: Brand Campaigns
          _SectionHeaderRow(
            title: 'Brand Campaigns',
            subtitle:
                'Active brand briefs seeking community partnerships & sponsorships.',
            actionLabel: 'View All Campaigns >',
            onActionTap: onOpenCampaigns,
          ),
          const SizedBox(height: 10),
          campaignCards.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
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
                      const Icon(
                        Icons.rocket_launch_outlined,
                        size: 32,
                        color: Colors.black54,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No active brand campaigns yet',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Brand campaigns and sponsorship briefs will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  height: 215,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: campaignCards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => campaignCards[index],
                  ),
                ),

          const SizedBox(height: 22),

          // Section 2: Active Communities
          _SectionHeaderRow(
            title: 'Active Communities',
            subtitle:
                'Discover verified creator and host communities on Meetday.',
            actionLabel: 'View All Communities >',
            onActionTap: onOpenCommunities,
          ),
          const SizedBox(height: 10),
          communityCards.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
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
                      const Icon(
                        Icons.groups_outlined,
                        size: 32,
                        color: Colors.black54,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No active communities yet',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Partner communities will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF667085),
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
                    itemCount: communityCards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => communityCards[index],
                  ),
                ),

          const SizedBox(height: 22),

          // Section 3: Locked Deals & Reports
          _SectionHeaderRow(
            title: 'Locked Deals & Reports',
            subtitle:
                'View locked deal terms and submitted deliverables reports.',
            actionLabel: 'View All Deals >',
            onActionTap: onOpenDeals,
          ),
          const SizedBox(height: 10),
          dealCards.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 32,
                        color: Colors.black54,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No locked deals yet',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Once a deal is locked in chat with a brand or community, it will appear here.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: dealCards.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => dealCards[index],
                  ),
                ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SPACE PROPOSALS TAB BODY
// ─────────────────────────────────────────────────────────────────────────────

class _SpaceProposalsTabBody extends ConsumerStatefulWidget {
  const _SpaceProposalsTabBody({
    required this.onBack,
    required this.onNavigateToTab,
  });

  final VoidCallback onBack;
  final ValueChanged<int> onNavigateToTab;

  @override
  ConsumerState<_SpaceProposalsTabBody> createState() =>
      _SpaceProposalsTabBodyState();
}

class _SpaceProposalsTabBodyState
    extends ConsumerState<_SpaceProposalsTabBody> {
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
        isBrand: false,
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
        onDelete: () async {
          final id = proposal['id'];
          if (id != null) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dCtx) => AlertDialog(
                title: const Text('Delete Proposal?'),
                content: const Text(
                  'Are you sure you want to delete this proposal? This cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dCtx).pop(false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dCtx).pop(true),
                    child: const Text(
                      'DELETE',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              try {
                final api = ref.read(apiClientProvider);
                await api.deleteProposal(id.toString());
                ref.invalidate(dashboardProposalsProvider);
              } catch (_) {}
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
        final publishedCount = proposals
            .where((p) => p['status'] == 'PUBLISHED')
            .length;
        final underReviewCount = proposals
            .where((p) => p['status'] == 'UNDER_REVIEW')
            .length;
        final draftCount = proposals
            .where((p) => p['status'] == 'DRAFT')
            .length;
        final completedCount = proposals
            .where((p) => p['status'] == 'COMPLETED')
            .length;
        final rejectedCount = proposals
            .where((p) => p['status'] == 'REJECTED')
            .length;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Experiences',
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'For all your experiences and proposals',
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
                  onTap: () => _openCreateProposalModal(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                        const Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF525252),
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
                  border: Border.all(color: Colors.black38, width: 2),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.note_add_outlined,
                      size: 44,
                      color: Colors.black38,
                    ),
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
                      onTap: () => _openCreateProposalModal(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                        child: Text(
                          '+ CREATE PROPOSAL',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...filtered.map(
                (p) => ProposalListItemCard(
                  proposal: p,
                  onTap: () => _openProposalDetail(p),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 36,
                color: MeetdayColors.primaryRed,
              ),
              const SizedBox(height: 8),
              Text(
                'Could not load proposals',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.refresh(dashboardProposalsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SPACE EXPLORE TAB BODY (Brand Campaigns & Communities)
// ─────────────────────────────────────────────────────────────────────────────

class _SpaceExploreTabBody extends ConsumerWidget {
  const _SpaceExploreTabBody({
    required this.subView,
    required this.onSubViewChanged,
    required this.onNavigateToTab,
  });

  final String subView;
  final ValueChanged<String> onSubViewChanged;
  final ValueChanged<int> onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subView == 'campaigns') {
      return CampaignsScreen(
        onBack: () => onSubViewChanged('menu'),
        onInterestSent: () => onNavigateToTab(9),
      );
    }
    if (subView == 'communities') {
      return _SpaceCommunityTabBody(
        onBack: () => onSubViewChanged('menu'),
        onNavigateToTab: onNavigateToTab,
      );
    }

    // Default 'menu' with 2 Option Cards: Brand Campaigns and Communities
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Explore Header
        Text(
          'Explore',
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: const Color(0xFF111111),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Discover active brand campaigns and partner communities.',
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 18),

        // Card 1: Brand Campaigns
        _buildExploreCard(
          icon: Icons.rocket_launch_rounded,
          iconBg: MeetdayColors.primaryRed,
          iconColor: Colors.white,
          title: 'Campaigns',
          description:
              'Browse active brand campaigns, apply with your space, and secure deals.',
          onTap: () => onSubViewChanged('campaigns'),
        ),
        const SizedBox(height: 14),

        // Card 2: Communities
        _buildExploreCard(
          icon: Icons.groups_rounded,
          iconBg: MeetdayColors.accentYellow,
          iconColor: Colors.black,
          title: 'Communities',
          description:
              'Browse and partner with verified creator & host communities.',
          onTap: () => onSubViewChanged('communities'),
        ),
      ],
    );
  }

  Widget _buildExploreCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color cardBg = Colors.white,
    Color textColor = const Color(0xFF111111),
    Color descColor = const Color(0xFF667085),
    Color arrowBg = const Color(0xFFF3F4F6),
    Color arrowColor = Colors.black,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(2, 2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(child: Icon(icon, color: iconColor, size: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: descColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: arrowBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(1.5, 1.5),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: arrowColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. SPACE COMMUNITY TAB BODY (2-column GridView of Communities)
// ─────────────────────────────────────────────────────────────────────────────

class _SpaceCommunityTabBody extends ConsumerWidget {
  const _SpaceCommunityTabBody({this.onBack, this.onNavigateToTab});

  final VoidCallback? onBack;
  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communitiesAsync = ref.watch(dashboardCommunitiesProvider);
    final publishedAsync = ref.watch(publishedProposalsProvider);
    final publishedProposals =
        (publishedAsync.asData?.value ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();

    return communitiesAsync.when(
      data: (communities) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            if (onBack != null) ...[
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 13,
                      color: Color(0x99000000),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Back to Explore',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0x99000000),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
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
              'Browse approved communities and start a collaboration.',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 16),
            if (communities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No communities are available yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: communities.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                itemBuilder: (context, index) {
                  final c = communities[index];
                  final name =
                      (c['name'] ?? c['title'] ?? 'Community').toString();
                  final members =
                      (c['memberCount'] ?? c['size'] ?? '0').toString();
                  final imageUrl = c['logoUrl'] as String?;

                  return _CommunityCardPreview(
                    title: name,
                    memberCount: members,
                    imageUrl: imageUrl,
                    width: null,
                    onTap: () {
                      final matchingProposals = getCommunityMatchingProposals(
                        c,
                        publishedProposals,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CommunityDetailScreen(
                            community: c,
                            activeProposals: matchingProposals,
                            isBrandPreview: false,
                            isHub: false,
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
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 36,
                color: MeetdayColors.primaryRed,
              ),
              const SizedBox(height: 8),
              Text(
                'Could not load communities',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.refresh(dashboardCommunitiesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. SPACE NOTIFICATIONS TAB BODY
// ─────────────────────────────────────────────────────────────────────────────

class _SpaceNotificationsTabBody extends ConsumerWidget {
  const _SpaceNotificationsTabBody({
    required this.onOpenChat,
    required this.onOpenDestination,
  });

  final ValueChanged<ChatHubInitialTarget> onOpenChat;
  final ValueChanged<int> onOpenDestination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final api = ref.watch(apiClientProvider);

    return RefreshIndicator(
      color: MeetdayColors.primaryRed,
      onRefresh: () async => ref.refresh(notificationsProvider),
      child: ListView(
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
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stay updated on bookings, deals, and activity.',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  try {
                    await api.markAllNotificationsRead();
                    ref.invalidate(notificationsProvider);
                    ref.invalidate(unreadNotificationsCountProvider);
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(1.5, 1.5),
                        blurRadius: 0,
                      ),
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
                return _EmptyPanelCard(
                  title: 'No notifications yet',
                  subtitle: "You're all caught up! Bookings, deals, and messages will appear here.",
                  icon: Icons.notifications_none_rounded,
                );
              }

              return Column(
                children: notifications.map((notif) {
                  final id = notif['id']?.toString() ?? '';
                  final title = (notif['title'] ?? 'Notification').toString();
                  final body = (notif['body'] ??
                          notif['message'] ??
                          notif['description'] ??
                          '')
                      .toString();
                  final isRead =
                      notif['isRead'] == true || notif['read'] == true;
                  final createdAt = notif['createdAt']?.toString() ??
                      notif['timestamp']?.toString();

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
                      } else {
                        timeLabel = '${dt.day}/${dt.month}';
                      }
                    } catch (_) {}
                  }

                  return GestureDetector(
                    onTap: () async {
                      if (id.isNotEmpty) {
                        try {
                          await api.markNotificationRead(id);
                        } catch (_) {}
                      }
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                      onOpenDestination(9); // Open chats tab
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
                              color: isRead
                                  ? const Color(0xFFF1F5F9)
                                  : MeetdayColors.primaryRed,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.notifications_rounded,
                              size: 18,
                              color: isRead ? Colors.black87 : Colors.white,
                            ),
                          ),
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
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    body,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF525252),
                                    ),
                                  ),
                                ],
                                if (timeLabel.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    timeLabel,
                                    style: GoogleFonts.poppins(
                                      fontSize: 9.5,
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
            error: (err, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HUB PROFILE BOTTOM SHEET & MODAL (View & Edit Hub Profile)
// ─────────────────────────────────────────────────────────────────────────────

class HubProfileSheet extends StatefulWidget {
  const HubProfileSheet({
    required this.profile,
    required this.community,
    required this.onSignOut,
    required this.onProfileUpdated,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic>? community;
  final VoidCallback onSignOut;
  final VoidCallback onProfileUpdated;

  @override
  State<HubProfileSheet> createState() => _HubProfileSheetState();
}

class _HubProfileSheetState extends State<HubProfileSheet> {
  void _openEditProfileForm() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditHubProfileDialog(
        profile: widget.profile,
        community: widget.community,
        onSaved: () {
          widget.onProfileUpdated();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessName = (widget.profile['businessName'] ?? 'Hub Partner')
        .toString();
    final cities = (widget.profile['operatingCities'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final userMap = widget.profile['user'] is Map
        ? widget.profile['user'] as Map
        : const {};
    final fullName = [
      userMap['firstName'],
      userMap['lastName'],
    ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    final email = (userMap['email'] ?? '').toString();
    final phone = (widget.profile['phone'] ?? userMap['phone'] ?? '').toString();
    final approvalStatus = (widget.community?['approvalStatus'] ??
            widget.profile['approvalStatus'] ??
            'APPROVED')
        .toString()
        .toUpperCase();

    final capacity = (widget.community?['venueCapacity'] ??
            widget.community?['capacity'] ??
            '50-200')
        .toString();
    final venuesCount = (widget.community?['venueCount'] ??
            widget.community?['venues'] ??
            '1')
        .toString();
    final expPerYear = (widget.community?['experiencesPerYear'] ?? '12')
        .toString();
    final showcaseUrls = (widget.community?['centreShowcaseUrls'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final pastEvents = (widget.community?['pastEvents'] as List?)
            ?.whereType<Map>()
            .toList() ??
        const <Map>[];
    final brandsWorkedWith = (widget.community?['brandsWorkedWith'] as List?)
            ?.whereType<Map>()
            .toList() ??
        const <Map>[];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.black, width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Title row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hub Partner Profile',
                    style: GoogleFonts.bricolageGrotesque(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Approval status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: approvalStatus == 'APPROVED'
                      ? const Color(0xFFDDF5E8)
                      : approvalStatus == 'REJECTED'
                          ? const Color(0xFFFFD2D2)
                          : const Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: approvalStatus == 'APPROVED'
                        ? const Color(0xFF10B981)
                        : approvalStatus == 'REJECTED'
                            ? MeetdayColors.primaryRed
                            : const Color(0xFFF59E0B),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      approvalStatus == 'APPROVED'
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: approvalStatus == 'APPROVED'
                          ? const Color(0xFF047857)
                          : Colors.black87,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        approvalStatus == 'APPROVED'
                            ? 'Live to Communities & Brands.'
                            : approvalStatus == 'REJECTED'
                                ? 'Profile rejected by admin. Update and resubmit.'
                                : 'Profile under review — awaiting admin approval.',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Yellow Profile Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MeetdayColors.accentYellow,
                  border: Border.all(color: Colors.black, width: 2.5),
                  borderRadius: BorderRadius.circular(20),
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
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black, width: 2),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            size: 26,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                businessName,
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black,
                                ),
                              ),
                              if (fullName.isNotEmpty)
                                Text(
                                  fullName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (email.isNotEmpty)
                      Text(
                        'Email: $email',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    if (phone.isNotEmpty)
                      Text(
                        'Phone: $phone',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    if (cities.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: cities
                            .map(
                              (c) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  c,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Community Space Specs
              Text(
                'Venue Space Details',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SpecCard(
                      label: 'Venue Capacity',
                      value: capacity,
                      icon: Icons.people_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SpecCard(
                      label: 'Venues',
                      value: venuesCount,
                      icon: Icons.location_city_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SpecCard(
                      label: 'Exp / Year',
                      value: expPerYear,
                      icon: Icons.auto_awesome_rounded,
                    ),
                  ),
                ],
              ),

              if (showcaseUrls.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Showcase Photos',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: showcaseUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) => Container(
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.network(
                        showcaseUrls[idx],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.image),
                      ),
                    ),
                  ),
                ),
              ],

              if (pastEvents.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Past Experiences',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...pastEvents.map((pe) {
                  final name = (pe['name'] ?? 'Event').toString();
                  final desc = (pe['description'] ?? '').toString();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8F3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (desc.isNotEmpty)
                                Text(
                                  desc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    color: Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              if (brandsWorkedWith.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Brands Worked With',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: brandsWorkedWith.map((b) {
                    final bName =
                        (b['brandName'] ?? b['name'] ?? 'Brand').toString();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Text(
                        bName,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons: Edit Hub Profile & Sign Out
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _openEditProfileForm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: MeetdayColors.accentYellow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'EDIT PROFILE',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onSignOut();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            size: 16,
                            color: MeetdayColors.primaryRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sign out',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: MeetdayColors.primaryRed,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  const _SpecCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.black),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 8.5, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _EditHubProfileDialog extends ConsumerStatefulWidget {
  const _EditHubProfileDialog({
    required this.profile,
    required this.community,
    required this.onSaved,
  });

  final Map<String, dynamic> profile;
  final Map<String, dynamic>? community;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditHubProfileDialog> createState() =>
      _EditHubProfileDialogState();
}

class _EditHubProfileDialogState extends ConsumerState<_EditHubProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _citiesController;
  late final TextEditingController _capacityController;
  late final TextEditingController _venuesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: (widget.profile['businessName'] ?? '').toString(),
    );
    _phoneController = TextEditingController(
      text: (widget.profile['phone'] ?? '').toString(),
    );
    final cities = (widget.profile['operatingCities'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '';
    _citiesController = TextEditingController(text: cities);
    _capacityController = TextEditingController(
      text: (widget.community?['venueCapacity'] ??
              widget.community?['capacity'] ??
              '')
          .toString(),
    );
    _venuesController = TextEditingController(
      text: (widget.community?['venueCount'] ??
              widget.community?['venues'] ??
              '')
          .toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _citiesController.dispose();
    _capacityController.dispose();
    _venuesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final citiesList = _citiesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await api.updateSpaceProfile({
        'businessName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'operatingCities': citiesList,
      });

      if (_capacityController.text.isNotEmpty ||
          _venuesController.text.isNotEmpty) {
        await api.activateSpaceCommunityProfile({
          'name': _nameController.text.trim(),
          'venueCapacity': _capacityController.text.trim(),
          'venueCount': int.tryParse(_venuesController.text.trim()) ?? 1,
          'operatingCities': citiesList,
        });
      }

      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: MeetdayColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.black, width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Hub Profile',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _field('Business Name', _nameController),
              const SizedBox(height: 8),
              _field('Phone Number', _phoneController),
              const SizedBox(height: 8),
              _field('Operating Cities (comma separated)', _citiesController),
              const SizedBox(height: 8),
              _field('Venue Capacity (e.g. 100)', _capacityController),
              const SizedBox(height: 8),
              _field('Number of Venues', _venuesController),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: MeetdayColors.accentYellow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'SAVE CHANGES',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: GoogleFonts.poppins(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            filled: true,
            fillColor: const Color(0xFFFFF8F3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.black, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: MeetdayColors.primaryRed,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE DASHBOARD CARDS & HELPERS
// ─────────────────────────────────────────────────────────────────────────────

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
          BoxShadow(color: Colors.black, offset: Offset(4, 4), blurRadius: 0),
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
                  width: 2,
                ),
                boxShadow: disabled
                    ? null
                    : const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  buttonLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: disabled ? Colors.black38 : Colors.black,
                    letterSpacing: 0.5,
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

class _CampaignCardPreview extends StatelessWidget {
  const _CampaignCardPreview({required this.campaign, this.onTap});

  final Map<String, dynamic> campaign;
  final VoidCallback? onTap;

  Widget _fallbackMonogram(String brandName) {
    final letter = brandName.trim().isNotEmpty
        ? brandName.trim().substring(0, 1).toUpperCase()
        : 'B';
    return Center(
      child: Text(
        letter,
        style: GoogleFonts.bricolageGrotesque(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          color: MeetdayColors.primaryRed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        (campaign['name'] ?? campaign['title'] ?? 'Brand Campaign').toString();
    final brandName = (campaign['brandName'] ?? 'Brand').toString();
    final brandLogo =
        (campaign['brandLogo'] ?? campaign['imageUrl']) as String?;
    final offerType =
        (campaign['offerType'] ?? 'CASH').toString().toUpperCase();
    final hasCash = offerType == 'CASH' || offerType == 'BOTH';
    final hasBarter = offerType == 'BARTER' || offerType == 'BOTH';
    final budgetAmount =
        campaign['budgetAmount'] ?? campaign['budget'] ?? campaign['amount'];
    final budgetCurrency = (campaign['budgetCurrency'] ?? '₹').toString();

    String budgetText = '';
    if (budgetAmount != null &&
        budgetAmount != 0 &&
        budgetAmount.toString().isNotEmpty) {
      budgetText = '$budgetCurrency$budgetAmount';
    } else if (hasBarter) {
      budgetText = 'Barter';
    } else {
      budgetText = 'Brand Brief';
    }

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
              // 1:1 Image / Monogram
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF1F2),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (brandLogo != null && brandLogo.isNotEmpty)
                        Image.network(
                          brandLogo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _fallbackMonogram(brandName),
                        )
                      else
                        _fallbackMonogram(brandName),

                      // Status badge on TOP LEFT
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: MeetdayColors.primaryRed,
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
                            'CAMPAIGN',
                            style: GoogleFonts.poppins(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      // CASH / BARTER badge on TOP RIGHT
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
                                  margin: EdgeInsets.only(
                                    bottom: hasBarter ? 3 : 0,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
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
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.2,
                                    ),
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

              // Below 1:1 image: Title + Brand & Budget
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
                          Icons.business_outlined,
                          size: 11,
                          color: Color(0xFF667085),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$brandName • $budgetText',
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

  Widget _fallbackThumbnail() {
    return const Center(
      child: Icon(Icons.groups_rounded, size: 36, color: Colors.black45),
    );
  }

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
                          errorBuilder: (context, error, stackTrace) =>
                              _fallbackThumbnail(),
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
                                        ? brandName
                                            .substring(0, 1)
                                            .toUpperCase()
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: paid
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFFEF3C7),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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

class _EmptyPanelCard extends StatelessWidget {
  const _EmptyPanelCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black38, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    color: const Color(0xFF667085),
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

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 34,
              color: MeetdayColors.primaryRed,
            ),
            const SizedBox(height: 10),
            Text(
              'Could not load your Hub profile',
              textAlign: TextAlign.center,
              style: GoogleFonts.bricolageGrotesque(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF525252),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
