import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../../../auth/state/auth_provider.dart';
import '../campaigns/campaigns_screen.dart';
import '../chat/community_chat_hub.dart';
import '../providers/chat_provider.dart';
import '../providers/dashboard_provider.dart';

final spaceDashboardProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final token = await const FlutterSecureStorage().read(
        key: 'firebase_id_token',
      );
      api.setIdToken(token);
      return api.getSpaceProfile();
    });

class SpaceDashboardScreen extends ConsumerStatefulWidget {
  const SpaceDashboardScreen({super.key});

  @override
  ConsumerState<SpaceDashboardScreen> createState() =>
      _SpaceDashboardScreenState();
}

class _SpaceDashboardScreenState extends ConsumerState<SpaceDashboardScreen> {
  int _selectedIndex = 0;

  static const _pageTitles = ['Hub dashboard', 'Brand campaigns', 'Chats'];

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        title: Text(
          'Sign out?',
          style: GoogleFonts.bricolageGrotesque(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'You can sign back in to manage your Hub Partner account.',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: MeetdayColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut == true && mounted) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(totalChatUnreadNotificationCountProvider);
    final pages = [
      _SpaceOverviewPage(
        onOpenCampaigns: () => setState(() => _selectedIndex = 1),
        onOpenChats: () => setState(() => _selectedIndex = 2),
      ),
      const CampaignsScreen(),
      const CommunityChatHubScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFC),
      appBar: AppBar(
        backgroundColor: MeetdayColors.primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _pageTitles[_selectedIndex],
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: _SpaceNavigationBar(
        selectedIndex: _selectedIndex,
        unreadCount: unreadCount,
        onSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _SpaceOverviewPage extends ConsumerWidget {
  const _SpaceOverviewPage({
    required this.onOpenCampaigns,
    required this.onOpenChats,
  });

  final VoidCallback onOpenCampaigns;
  final VoidCallback onOpenChats;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(spaceDashboardProfileProvider);
    ref.invalidate(dashboardProposalsProvider);
    ref.invalidate(dashboardCampaignsProvider);
    ref.invalidate(chatHubProvider);
    await ref.read(spaceDashboardProfileProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(spaceDashboardProfileProvider);
    final proposalsAsync = ref.watch(dashboardProposalsProvider);
    final campaignsAsync = ref.watch(dashboardCampaignsProvider);
    final chatHubAsync = ref.watch(chatHubProvider);
    final chatCount = ref.watch(totalChatUnreadNotificationCountProvider);

    return profileAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (error, _) => _ProfileLoadError(
        onRetry: () => ref.invalidate(spaceDashboardProfileProvider),
      ),
      data: (profile) {
        final businessName = (profile['businessName'] ?? 'Space Partner')
            .toString();
        final cities =
            (profile['operatingCities'] as List?)
                ?.map((city) => city.toString())
                .where((city) => city.isNotEmpty)
                .toList() ??
            const <String>[];
        final proposals =
            proposalsAsync.asData?.value ?? const <Map<String, dynamic>>[];
        final campaigns =
            campaignsAsync.asData?.value ?? const <Map<String, dynamic>>[];
        final activeThreads =
            chatHubAsync.asData?.value.activeThreadsByCategory['spaces'] ??
            const <UnifiedActiveThread>[];
        final lockedDeals = activeThreads
            .where((thread) => thread.isDealLocked)
            .length;

        return RefreshIndicator(
          color: MeetdayColors.primaryRed,
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            children: [
              Text(
                'Hey $businessName,',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 26,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'What are we building today?',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: MeetdayColors.primaryRed,
                ),
              ),
              if (cities.isNotEmpty) ...[
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: cities
                      .map((city) => _CityChip(city: city))
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),
              _PrimaryAction(
                icon: Icons.campaign_rounded,
                title: 'Explore brand campaigns',
                subtitle: 'Find briefs that fit your spaces and audience.',
                onTap: onOpenCampaigns,
              ),
              const SizedBox(height: 12),
              _SecondaryAction(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Open partner chats',
                trailing: chatCount > 0 ? '$chatCount new' : null,
                onTap: onOpenChats,
              ),
              const SizedBox(height: 24),
              Text(
                'Your overview',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 11),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _OverviewMetric(
                        width: cardWidth,
                        label: 'My proposals',
                        value: proposals.length.toString(),
                        icon: Icons.description_outlined,
                      ),
                      _OverviewMetric(
                        width: cardWidth,
                        label: 'Brand campaigns',
                        value: campaigns.length.toString(),
                        icon: Icons.campaign_outlined,
                      ),
                      _OverviewMetric(
                        width: cardWidth,
                        label: 'Active collaborations',
                        value: activeThreads.length.toString(),
                        icon: Icons.handshake_outlined,
                      ),
                      _OverviewMetric(
                        width: cardWidth,
                        label: 'Locked deals',
                        value: lockedDeals.toString(),
                        icon: Icons.lock_outline_rounded,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Active collaborations',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 10),
              if (chatHubAsync.isLoading && activeThreads.isEmpty)
                const _LoadingPanel()
              else if (activeThreads.isEmpty)
                const _EmptyPanel(
                  icon: Icons.handshake_outlined,
                  title: 'No active collaborations yet',
                  subtitle:
                      'Accepted partner chats and deals will show up here.',
                )
              else
                ...activeThreads
                    .take(3)
                    .map(
                      (thread) => _CollaborationSummary(
                        thread: thread,
                        onTap: onOpenChats,
                      ),
                    ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recent proposals',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                  if (proposals.isNotEmpty)
                    Text(
                      '${proposals.length} total',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF667085),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (proposalsAsync.isLoading && proposals.isEmpty)
                const _LoadingPanel()
              else if (proposals.isEmpty)
                const _EmptyPanel(
                  icon: Icons.description_outlined,
                  title: 'No proposals yet',
                  subtitle: 'Your Hub proposals will appear here once created.',
                )
              else
                ...proposals
                    .take(3)
                    .map((proposal) => _ProposalSummary(proposal: proposal)),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _SpaceNavigationBar extends StatelessWidget {
  const _SpaceNavigationBar({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.dashboard_rounded, 'Dashboard'),
    (Icons.campaign_rounded, 'Campaigns'),
    (Icons.chat_bubble_rounded, 'Chats'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = selectedIndex == index;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.$2,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? MeetdayColors.accentYellow
                            : Colors.white,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.transparent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(item.$1, size: 20, color: Colors.black),
                              if (index == 2 && unreadCount > 0)
                                Positioned(
                                  right: -9,
                                  top: -7,
                                  child: _UnreadDot(count: unreadCount),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.$2,
                            maxLines: 1,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: MeetdayColors.primaryRed,
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 8,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  const _CityChip({required this.city});

  final String city;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        city,
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MeetdayColors.accentYellow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
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
          child: Row(
            children: [
              Icon(icon, size: 24, color: Colors.black),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: MeetdayColors.primaryRed,
                  ),
                ),
              const SizedBox(width: 5),
              const Icon(Icons.arrow_forward_ios_rounded, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MeetdayColors.primaryRed),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
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

class _ProposalSummary extends StatelessWidget {
  const _ProposalSummary({required this.proposal});

  final Map<String, dynamic> proposal;

  @override
  Widget build(BuildContext context) {
    final title = (proposal['name'] ?? proposal['title'] ?? 'Untitled proposal')
        .toString();
    final status = (proposal['status'] ?? 'DRAFT').toString().toUpperCase();
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 110),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'PUBLISHED' || status == 'APPROVED'
                  ? const Color(0xFFDDF5E8)
                  : MeetdayColors.accentYellow,
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.replaceAll('_', ' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollaborationSummary extends StatelessWidget {
  const _CollaborationSummary({required this.thread, required this.onTap});

  final UnifiedActiveThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final counterpart = thread.counterpartName.trim().isEmpty
        ? 'Partner'
        : thread.counterpartName;
    final status = thread.isDealClosed
        ? 'CLOSED'
        : thread.isDealLocked
        ? 'LOCKED'
        : 'ACTIVE';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: MeetdayColors.accentYellow,
                foregroundColor: Colors.black,
                child: Text(
                  counterpart[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counterpart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: const Color(0xFF525252),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: thread.isDealLocked
                      ? MeetdayColors.accentYellow
                      : const Color(0xFFDDF5E8),
                  border: Border.all(color: Colors.black, width: 1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.poppins(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 80,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: MeetdayColors.primaryRed,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: const Color(0xFF525252),
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

  final VoidCallback onRetry;

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
