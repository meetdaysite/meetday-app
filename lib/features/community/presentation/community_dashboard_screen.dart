import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/api_client.dart';

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
}

class CommunityDashboardScreen extends ConsumerWidget {
  const CommunityDashboardScreen({super.key, this.profileFuture});

  final Future<Map<String, dynamic>>? profileFuture;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);

    return FutureBuilder<Map<String, dynamic>>(
      future:
          profileFuture ??
          (() async {
            final token = await const FlutterSecureStorage().read(
              key: 'firebase_id_token',
            );
            api.setIdToken(token);
            return await api.getHostCommunityProfile();
          })(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const <String, dynamic>{};
        final profileName =
            (profile['name'] as String?) ??
            (profile['communityName'] as String?) ??
            (profile['displayName'] as String?) ??
            'Your Community';
        final displayName =
            (profile['displayName'] as String?) ??
            (profile['name'] as String?) ??
            'Host';
        final approvalStatus =
            (profile['approvalStatus'] as String?) ??
            (profile['status'] as String?) ??
            'PENDING';

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: const Color(0xFFF7F7F6),
            appBar: AppBar(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF101828),
              title: Text(profileName),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(58),
                child: Container(
                  color: Colors.white,
                  child: TabBar(
                    isScrollable: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    labelColor: const Color(0xFF101828),
                    unselectedLabelColor: const Color(0xFF667085),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFFFFF2C8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: tabs
                        .map(
                          (tab) => Tab(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: Text(tab.label),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
            body: snapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _DashboardTabBody(
                        displayName: displayName,
                        profileName: profileName,
                        approvalStatus: approvalStatus,
                      ),
                      const _ProposalTabBody(),
                      const _HubTabBody(),
                      const _CommunityTabBody(),
                      const _DealsTabBody(),
                      const _SupportTabBody(),
                      const _NotificationsTabBody(),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _DashboardTabBody extends StatelessWidget {
  const _DashboardTabBody({
    required this.displayName,
    required this.profileName,
    required this.approvalStatus,
  });

  final String displayName;
  final String profileName;
  final String approvalStatus;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = approvalStatus.toUpperCase();
    final isApproved = normalizedStatus == 'APPROVED';
    final statusPill = isApproved ? 'Live' : 'Pending';

    final proposalCards = [
      _ProposalCardPreview(
        title: 'The Block Party',
        city: 'Mumbai',
        venue: 'Marine Drive',
        description:
            'A weekend music and food festival for creators and growing communities.',
        dateLabel: '12–14 Oct',
        guestLabel: '1200 Guests',
      ),
      _ProposalCardPreview(
        title: 'Creator Night',
        city: 'Bengaluru',
        venue: 'Arena Hall',
        description:
            'An intimate creator-led networking night with live performances and sponsor booths.',
        dateLabel: '24 Oct',
        guestLabel: '650 Guests',
        badge: 'Cash',
        badgeColor: const Color(0xFFDCFCE7),
      ),
      _ProposalCardPreview(
        title: 'Weekend Pop-Up',
        city: 'Hyderabad',
        venue: 'Skyline Courtyard',
        description:
            'A premium community pop-up bringing brands, creators, and local audiences together.',
        dateLabel: '9 Nov',
        guestLabel: '850 Guests',
        badge: 'Barter',
        badgeColor: const Color(0xFFFFF3BF),
      ),
    ];

    final hubCards = [
      _CommunityHubCardPreview(
        title: 'Design & Culture Hub',
        subtitle: '3 spaces · 12 active members',
      ),
      _CommunityHubCardPreview(
        title: 'Startup Circle',
        subtitle: '2 spaces · 8 active members',
      ),
      _CommunityHubCardPreview(
        title: 'Wellness Club',
        subtitle: '4 spaces · 15 active members',
      ),
    ];

    final dealCards = [
      _DealCardPreview(
        brandName: 'Aster Labs',
        projectName: 'Launch Week',
        amount: '₹1,80,000',
        paid: true,
      ),
      _DealCardPreview(
        brandName: 'Urban Mint',
        projectName: 'Weekend Fest',
        amount: '₹2,35,000',
        paid: false,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: Color(0xFF111111),
            ),
            children: [
              const TextSpan(text: 'Hey '),
              TextSpan(
                text: displayName,
                style: const TextStyle(color: Color(0xFF111111)),
              ),
              const TextSpan(text: ', '),
              TextSpan(
                text: 'what are we building today?',
                style: const TextStyle(color: Color(0xFFEE2C2C)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Start something new or pick up where you left off!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isApproved
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFE0F2FE),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Community status: $statusPill',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                title: 'Raise Sponsorship',
                badge: 'LIVE',
                body:
                    'Build custom proposals, pitch relevant brand sponsors, and secure brand backing to scale your upcoming experiences.',
                buttonLabel: 'CREATE PROPOSAL',
                accent: const Color(0xFFFFC940),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ActionCard(
                title: 'Explore Campaigns',
                badge: 'SOON',
                body:
                    'Browse active marketing and sponsorship campaign briefs posted by brands, review requirements, and contact them to collaborate.',
                buttonLabel: 'EXPLORE CAMPAIGNS',
                accent: const Color(0xFFE5E7EB),
                disabled: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(height: 1, color: Color(0x1A000000)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Sponsorship Proposals',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View your approved proposals.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
            const Text(
              'View All Proposals >',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6C32D1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: proposalCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) => proposalCards[index],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Active Community Hubs',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Discover venues and hubs for offline activations and community events.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
            const Text(
              'View All Hubs >',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6C32D1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hubCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) => hubCards[index],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Locked Deals & Reports',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'View locked deal terms and submitted deliverables reports.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
            const Text(
              'Go to Chats >',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6C32D1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: dealCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) => dealCards[index],
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
  });

  final String title;
  final String badge;
  final String body;
  final String buttonLabel;
  final Color accent;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(5, 5), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4A5565),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: disabled ? const Color(0xFFEBEBEB) : accent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Center(
              child: Text(
                buttonLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: disabled ? const Color(0xFF7A7A7A) : Colors.black,
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
    required this.city,
    required this.venue,
    required this.description,
    required this.dateLabel,
    required this.guestLabel,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final String city;
  final String venue;
  final String description;
  final String dateLabel;
  final String guestLabel;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(17),
                bottomLeft: Radius.circular(17),
              ),
              border: Border.all(color: Colors.black, width: 0),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
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
                  ),
                ),
                Center(
                  child: Text(
                    title.substring(0, 2).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.black54,
                    ),
                  ),
                ),
                if (badge != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? const Color(0xFFDCFCE7),
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$city • $venue',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4A5565),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _miniTag(
                        dateLabel,
                        const Color(0xFF6C32D1),
                        Colors.white,
                      ),
                      _miniTag(
                        guestLabel,
                        const Color(0xFFEE2C2C),
                        Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityHubCardPreview extends StatelessWidget {
  const _CommunityHubCardPreview({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFC7D2FE),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: const Icon(Icons.location_city_rounded, size: 28),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
        ],
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
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 3),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Center(
                  child: Text(
                    brandName.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  brandName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              if (paid)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF86EFAC),
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'PAID',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Project: $projectName',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667085),
            ),
          ),
          const Spacer(),
          const Divider(color: Color(0x14000000), thickness: 2),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC940),
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Locked Deal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      'Report',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _miniTag(String text, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black, width: 1.5),
      boxShadow: const [
        BoxShadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
      ],
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: fg),
    ),
  );
}

class _ProposalTabBody extends StatelessWidget {
  const _ProposalTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Experience Proposals'),
        const SizedBox(height: 8),
        _ListCard(
          title: 'Weekend Night Market',
          subtitle: 'Under review · submitted 2 days ago',
          status: 'Reviewing',
          accent: const Color(0xFFF0A12B),
        ),
        _ListCard(
          title: 'Founders Mixer',
          subtitle: 'Published · visible to brands',
          status: 'Live',
          accent: const Color(0xFF12B76A),
        ),
        _ListCard(
          title: 'Creative Workshop',
          subtitle: 'Draft · waiting for edits',
          status: 'Draft',
          accent: const Color(0xFF98A2B3),
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
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Community Hubs'),
        const SizedBox(height: 8),
        _ListCard(
          title: 'Design & Culture Hub',
          subtitle: '3 spaces · 12 active members',
          status: 'Open',
          accent: const Color(0xFF2673E8),
        ),
        _ListCard(
          title: 'Startup Circle',
          subtitle: '2 spaces · 8 active members',
          status: 'Open',
          accent: const Color(0xFF12B76A),
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
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Communities'),
        const SizedBox(height: 8),
        _ListCard(
          title: 'Meetday Social Circle',
          subtitle: 'Member count · 1,240',
          status: 'Approved',
          accent: const Color(0xFF12B76A),
        ),
        _ListCard(
          title: 'Creative Hosts Network',
          subtitle: 'Member count · 760',
          status: 'Pending',
          accent: const Color(0xFFF0A12B),
        ),
      ],
    );
  }
}

class _DealsTabBody extends StatelessWidget {
  const _DealsTabBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Locked Deals'),
        const SizedBox(height: 8),
        _ListCard(
          title: 'Brand partnership agreement',
          subtitle: 'Signed yesterday · payout pending',
          status: 'Locked',
          accent: const Color(0xFF2673E8),
        ),
        _ListCard(
          title: 'Venue add-on package',
          subtitle: 'Awaiting final approval',
          status: 'Review',
          accent: const Color(0xFFF0A12B),
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
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Support Chat'),
        const SizedBox(height: 8),
        _ListCard(
          title: 'Meetday support',
          subtitle: 'Last reply 14 minutes ago',
          status: 'Active',
          accent: const Color(0xFF12B76A),
        ),
        _ListCard(
          title: 'KYC verification',
          subtitle: 'Document follow-up needed',
          status: 'Waiting',
          accent: const Color(0xFFF0A12B),
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
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Notifications'),
        const SizedBox(height: 8),
        _ListCard(
          title: 'New sponsorship interest',
          subtitle: 'A brand has shown interest in your event.',
          status: 'New',
          accent: const Color(0xFFE5484D),
        ),
        _ListCard(
          title: 'Community profile approved',
          subtitle: 'Your profile is now visible in the directory.',
          status: 'Seen',
          accent: const Color(0xFF98A2B3),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF101828),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
