import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/meetday_colors.dart';
import '../proposal/proposal_form_screen.dart';
import '../providers/chat_provider.dart';
import '../providers/dashboard_provider.dart';
import 'space_community_listing_form.dart';

final spaceCommunityProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
      final api = ref.watch(apiClientProvider);
      final response = await api.dio.get<dynamic>('/spaces/community');
      final payload = response.data;
      final data = payload is Map ? (payload['data'] ?? payload) : null;
      return data is Map ? Map<String, dynamic>.from(data) : null;
    });

class SpaceProposalsScreen extends ConsumerWidget {
  const SpaceProposalsScreen({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? proposal,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProposalFormScreen(
          initialProposal: proposal,
          onSuccess: () => ref.invalidate(dashboardProposalsProvider),
        ),
      ),
    );
    ref.invalidate(dashboardProposalsProvider);
  }

  Future<void> _deleteProposal(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> proposal,
  ) async {
    final id = (proposal['id'] ?? '').toString();
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete proposal?'),
        content: const Text('This draft will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteProposal(id);
      ref.invalidate(dashboardProposalsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete proposal: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(dashboardProposalsProvider);
    final communityAsync = ref.watch(spaceCommunityProfileProvider);

    return proposalsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (error, _) => _SpaceErrorState(
        title: 'Could not load proposals',
        onRetry: () => ref.invalidate(dashboardProposalsProvider),
      ),
      data: (proposals) {
        final approved =
            communityAsync.asData?.value?['approvalStatus'] == 'APPROVED';
        return RefreshIndicator(
          color: MeetdayColors.primaryRed,
          onRefresh: () async {
            ref.invalidate(dashboardProposalsProvider);
            ref.invalidate(spaceCommunityProfileProvider);
            await ref.read(dashboardProposalsProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _SpacePageHeading(
                title: 'Experience Proposals',
                subtitle: 'Create and manage your sponsorship proposals.',
              ),
              const SizedBox(height: 14),
              if (communityAsync.isLoading)
                const LinearProgressIndicator(color: MeetdayColors.primaryRed)
              else if (!approved)
                const _SpaceNotice(
                  text:
                      'Your Community Hubs listing must be approved before you can create or submit proposals.',
                ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: approved ? () => _openForm(context, ref) : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create proposal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.black, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
              const SizedBox(height: 14),
              if (proposals.isEmpty)
                const _SpaceEmptyState(
                  icon: Icons.description_outlined,
                  title: 'No proposals yet',
                  subtitle: 'Your Hub proposals will appear here.',
                )
              else
                ...proposals.map(
                  (proposal) => _SpaceProposalTile(
                    proposal: proposal,
                    onEdit: () => _openForm(context, ref, proposal: proposal),
                    onDelete:
                        const {'DRAFT', 'REJECTED'}.contains(
                          (proposal['status'] ?? '').toString().toUpperCase(),
                        )
                        ? () => _deleteProposal(context, ref, proposal)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SpaceCommunitiesScreen extends ConsumerStatefulWidget {
  const SpaceCommunitiesScreen({super.key, required this.onOpenChats});

  final VoidCallback onOpenChats;

  @override
  ConsumerState<SpaceCommunitiesScreen> createState() =>
      _SpaceCommunitiesScreenState();
}

class _SpaceCommunitiesScreenState
    extends ConsumerState<SpaceCommunitiesScreen> {
  final Set<String> _sendingIds = {};

  Future<void> _sendInterest(Map<String, dynamic> community) async {
    final hostProfileId = (community['hostProfileId'] ?? '').toString();
    if (hostProfileId.isEmpty || _sendingIds.contains(hostProfileId)) return;
    setState(() => _sendingIds.add(hostProfileId));
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .post<dynamic>(
            '/space-host/communities/$hostProfileId/interest',
            data: const <String, dynamic>{},
          );
      ref.invalidate(chatHubProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interest sent to the community.')),
        );
        widget.onOpenChats();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send interest: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingIds.remove(hostProfileId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final communitiesAsync = ref.watch(dashboardCommunitiesProvider);
    return communitiesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (error, _) => _SpaceErrorState(
        title: 'Could not load communities',
        onRetry: () => ref.invalidate(dashboardCommunitiesProvider),
      ),
      data: (rawCommunities) {
        final communities = rawCommunities
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList();
        return RefreshIndicator(
          color: MeetdayColors.primaryRed,
          onRefresh: () async => ref.invalidate(dashboardCommunitiesProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _SpacePageHeading(
                title: 'Communities',
                subtitle: 'Find communities open to Hub partnerships.',
              ),
              const SizedBox(height: 14),
              if (communities.isEmpty)
                const _SpaceEmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No communities available',
                  subtitle: 'Approved communities will appear here.',
                )
              else
                ...communities.map((community) {
                  final hostProfileId = (community['hostProfileId'] ?? '')
                      .toString();
                  final locations =
                      (community['operatingCities'] as List?)?.join(', ') ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black, width: 2),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black,
                          offset: Offset(2, 2),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (community['name'] ?? 'Community').toString(),
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if ((community['about'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            community['about'].toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 11),
                          ),
                        ],
                        if (locations.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            locations,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF525252),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                hostProfileId.isEmpty ||
                                    _sendingIds.contains(hostProfileId)
                                ? null
                                : () => _sendInterest(community),
                            icon: const Icon(Icons.handshake_outlined),
                            label: Text(
                              _sendingIds.contains(hostProfileId)
                                  ? 'Sending…'
                                  : 'Express interest',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MeetdayColors.accentYellow,
                              foregroundColor: Colors.black,
                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class SpaceDealsScreen extends ConsumerWidget {
  const SpaceDealsScreen({super.key, required this.onOpenThread});

  final ValueChanged<UnifiedActiveThread> onOpenThread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatHubProvider);
    return chatAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (error, _) => _SpaceErrorState(
        title: 'Could not load deals',
        onRetry: () => ref.invalidate(chatHubProvider),
      ),
      data: (chatData) {
        final threads = (chatData.activeThreadsByCategory['spaces'] ?? [])
            .where((thread) => thread.isDealLocked)
            .toList();
        return RefreshIndicator(
          color: MeetdayColors.primaryRed,
          onRefresh: () async => ref.invalidate(chatHubProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const _SpacePageHeading(
                title: 'Locked Deals',
                subtitle: 'Approved Hub agreements and their chat threads.',
              ),
              const SizedBox(height: 14),
              if (threads.isEmpty)
                const _SpaceEmptyState(
                  icon: Icons.lock_outline_rounded,
                  title: 'No locked deals yet',
                  subtitle: 'Approved deal terms will appear here.',
                )
              else
                ...threads.map(
                  (thread) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: Text(thread.counterpartName),
                    subtitle: Text(thread.title),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded),
                    onTap: () => onOpenThread(thread),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class SpaceNotificationsScreen extends ConsumerWidget {
  const SpaceNotificationsScreen({super.key, required this.onOpenChat});

  final ValueChanged<ChatHubInitialTarget> onOpenChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final api = ref.read(apiClientProvider);
    return notificationsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: MeetdayColors.primaryRed),
      ),
      error: (error, _) => _SpaceErrorState(
        title: 'Could not load notifications',
        onRetry: () => ref.invalidate(notificationsProvider),
      ),
      data: (notifications) => RefreshIndicator(
        color: MeetdayColors.primaryRed,
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SpacePageHeading(
                    title: 'Notifications',
                    subtitle: 'Messages and account updates.',
                  ),
                ),
                if (notifications.any((item) => item['isRead'] != true))
                  TextButton(
                    onPressed: () async {
                      await api.markAllNotificationsRead();
                      ref.invalidate(notificationsProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                    },
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (notifications.isEmpty)
              const _SpaceEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'All caught up',
                subtitle: 'New updates will appear here.',
              )
            else
              ...notifications.map((notification) {
                final id = (notification['id'] ?? '').toString();
                final isRead = notification['isRead'] == true;
                final metadata = notification['metadata'] is Map
                    ? Map<String, dynamic>.from(notification['metadata'] as Map)
                    : <String, dynamic>{};
                final threadId =
                    (metadata['spaceThreadId'] ??
                            metadata['threadId'] ??
                            metadata['thread_id'] ??
                            metadata['interestId'] ??
                            metadata['interest_id'] ??
                            metadata['chatId'] ??
                            metadata['chat_id'])
                        ?.toString();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  leading: Icon(
                    isRead
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_rounded,
                    color: isRead ? Colors.black45 : MeetdayColors.primaryRed,
                  ),
                  title: Text((notification['title'] ?? 'Update').toString()),
                  subtitle: Text((notification['body'] ?? '').toString()),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: isRead ? Colors.black26 : Colors.black,
                      width: isRead ? 1 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: id.isEmpty && threadId == null
                      ? null
                      : () async {
                          if (id.isNotEmpty && !isRead) {
                            await api.markNotificationRead(id);
                            ref.invalidate(notificationsProvider);
                            ref.invalidate(unreadNotificationsCountProvider);
                          }
                          if (threadId != null && threadId.isNotEmpty) {
                            onOpenChat(
                              ChatHubInitialTarget(
                                category: (metadata['category'] ?? 'spaces')
                                    .toString(),
                                threadId: threadId,
                              ),
                            );
                          }
                        },
                );
              }),
          ],
        ),
      ),
    );
  }
}

class SpaceAccountProfileScreen extends ConsumerStatefulWidget {
  const SpaceAccountProfileScreen({super.key, required this.onPreviewListing});

  final ValueChanged<Map<String, dynamic>> onPreviewListing;

  @override
  ConsumerState<SpaceAccountProfileScreen> createState() =>
      _SpaceAccountProfileScreenState();
}

class _SpaceAccountProfileScreenState
    extends ConsumerState<SpaceAccountProfileScreen> {
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _citiesController = TextEditingController();
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<Map<String, dynamic>?> _communityFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _communityFuture = _loadCommunity();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    final profile = await ref.read(apiClientProvider).getSpaceProfile();
    _businessNameController.text = (profile['businessName'] ?? '').toString();
    _phoneController.text = (profile['phone'] ?? '').toString();
    final cities = profile['operatingCities'];
    _citiesController.text = cities is List ? cities.join(', ') : '';
    return profile;
  }

  Future<Map<String, dynamic>?> _loadCommunity() async {
    final response = await ref
        .read(apiClientProvider)
        .dio
        .get<dynamic>('/spaces/community');
    final body = response.data;
    final data = body is Map ? (body['data'] ?? body) : null;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> _openListingEditor() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SpaceCommunityListingForm(),
      ),
    );
    if (mounted) setState(() => _communityFuture = _loadCommunity());
  }

  Future<void> _save() async {
    final businessName = _businessNameController.text.trim();
    if (businessName.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .patch<dynamic>(
            '/spaces/me',
            data: {
              'businessName': businessName,
              'phone': _phoneController.text.trim(),
              'operatingCities': _citiesController.text
                  .split(',')
                  .map((city) => city.trim())
                  .where((city) => city.isNotEmpty)
                  .toList(),
            },
          );
      setState(() => _profileFuture = _loadProfile());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Hub profile updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _citiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SpacePageHeading(
          title: 'My Profile',
          subtitle: 'Manage your Hub Partner account and public listing.',
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _SpaceErrorState(
                title: 'Could not load Hub profile',
                onRetry: () => setState(() => _profileFuture = _loadProfile()),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: MeetdayColors.primaryRed,
                ),
              );
            }
            return Column(
              children: [
                TextField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _citiesController,
                  decoration: const InputDecoration(
                    labelText: 'Operating cities',
                    hintText: 'Separate cities with commas',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving…' : 'Save profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MeetdayColors.accentYellow,
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        FutureBuilder<Map<String, dynamic>?>(
          future: _communityFuture,
          builder: (context, snapshot) {
            final community = snapshot.data;
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator(
                color: MeetdayColors.primaryRed,
              );
            }
            if (community == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SpaceNotice(
                    text:
                        'Activate a public Community Hubs listing to publish your venues and sponsorship offers.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _openListingEditor,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Activate public listing'),
                  ),
                ],
              );
            }
            final status = (community['approvalStatus'] ?? 'PENDING')
                .toString()
                .toUpperCase();
            return Column(
              children: [
                Card(
                  child: ListTile(
                    title: Text(
                      (community['name'] ?? 'Community Hubs Profile')
                          .toString(),
                    ),
                    subtitle: Text('Listing status: $status'),
                    trailing: const Icon(Icons.visibility_outlined),
                    onTap: () => widget.onPreviewListing(community),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openListingEditor,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit listing'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onPreviewListing(community),
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Preview'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class SpaceProfilePreviewScreen extends StatelessWidget {
  const SpaceProfilePreviewScreen({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final locations =
        (profile['activeLocations'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Hub listing preview')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            (profile['name'] ?? 'Community Hub').toString(),
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text((profile['about'] ?? '').toString()),
          const SizedBox(height: 16),
          _PreviewFact(label: 'Locations', value: locations.join(', ')),
          _PreviewFact(
            label: 'Venues',
            value: (profile['numberOfVenues'] ?? '—').toString(),
          ),
          _PreviewFact(
            label: 'Venue capacity',
            value: (profile['venueCapacity'] ?? '—').toString(),
          ),
          _PreviewFact(
            label: 'Community size',
            value: (profile['communitySize'] ?? '—').toString(),
          ),
          _PreviewFact(
            label: 'Experiences per year',
            value: (profile['experiencesPerYear'] ?? '—').toString(),
          ),
        ],
      ),
    );
  }
}

class SpaceMoreScreen extends StatelessWidget {
  const SpaceMoreScreen({super.key, required this.onSelect});

  final ValueChanged<int> onSelect;

  static const _destinations = [
    (4, Icons.description_outlined, 'Experience Proposals'),
    (5, Icons.groups_outlined, 'Communities'),
    (6, Icons.lock_outline_rounded, 'Locked Deals'),
    (7, Icons.notifications_none_rounded, 'Notifications'),
    (8, Icons.person_outline_rounded, 'My Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SpacePageHeading(
          title: 'More',
          subtitle: 'Manage the rest of your Hub workspace.',
        ),
        const SizedBox(height: 12),
        ..._destinations.map(
          (item) => Card(
            child: ListTile(
              leading: Icon(item.$2),
              title: Text(item.$3),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => onSelect(item.$1),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpaceProposalTile extends StatelessWidget {
  const _SpaceProposalTile({
    required this.proposal,
    required this.onEdit,
    this.onDelete,
  });

  final Map<String, dynamic> proposal;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final status = (proposal['status'] ?? 'DRAFT').toString().toUpperCase();
    return Card(
      child: ListTile(
        title: Text((proposal['name'] ?? 'Untitled proposal').toString()),
        subtitle: Text(status.replaceAll('_', ' ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit proposal',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete proposal',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpacePageHeading extends StatelessWidget {
  const _SpacePageHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54),
        ),
      ],
    );
  }
}

class _SpaceEmptyState extends StatelessWidget {
  const _SpaceEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.black45),
          const SizedBox(height: 8),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SpaceNotice extends StatelessWidget {
  const _SpaceNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F3),
        border: Border.all(color: Colors.black, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 11)),
    );
  }
}

class _SpaceErrorState extends StatelessWidget {
  const _SpaceErrorState({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewFact extends StatelessWidget {
  const _PreviewFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: GoogleFonts.poppins(fontSize: 10)),
      subtitle: Text(value.isEmpty ? '—' : value),
    );
  }
}
