import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/network/api_client.dart';
import '../chat/community_chat_hub.dart';
import '../profile/profile_screen.dart';
import '../proposal_components.dart';
import '../providers/chat_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/profile_provider.dart';
import '../support/community_support_chat_view.dart';

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  void _profile(BuildContext context) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => const ProfileScreen(initialOpenPanel: 'community'),
    ));
  }

  void _proposal(BuildContext context, WidgetRef ref, Map<String, dynamic> proposal) {
    showDialog<void>(context: context, builder: (dialogContext) => ProposalDetailDialog(
      proposal: proposal,
      onEdit: () {
        Navigator.pop(dialogContext);
        Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => ProposalFormScreen(
          initialProposal: proposal, onSuccess: () => ref.invalidate(dashboardProposalsProvider),
        )));
      },
    ));
  }

  Future<void> _notification(BuildContext context, WidgetRef ref, Map<String, dynamic> notification) async {
    try {
      final id = notification['id']?.toString();
      if (id != null) await ref.read(apiClientProvider).markNotificationRead(id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark notification as read.')),
      );
    }
    if (!context.mounted) return;
    final metadata = notification['metadata'] is Map ? notification['metadata'] as Map : const {};
    final type = (notification['type'] ?? '').toString();
    if (type.contains('meetday_chat') || metadata['threadId'] == 'support') {
      Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => const Scaffold(body: CommunitySupportChatView()),
      ));
      return;
    }
    final thread = (metadata['sponsorshipInterestId'] ?? metadata['spaceInterestId'] ??
        metadata['spaceHostInterestId'] ?? metadata['communityCollaborationInterestId'] ??
        metadata['interestId'] ?? metadata['chatId'] ?? metadata['threadId'])?.toString();
    if (thread != null) {
      final category = type.contains('campaign') || metadata['campaignId'] != null ? 'campaigns'
          : type.startsWith('space_') ? 'spaces' : type.contains('collaboration') ? 'communities' : 'sponsorships';
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => Scaffold(body: CommunityChatHubScreen(
        initialTarget: ChatHubInitialTarget(category: category, threadId: thread),
      ))));
      return;
    }
    final proposalId = (metadata['proposalId'] ?? metadata['sponsorshipProposalId'])?.toString();
    if (proposalId != null) {
      try {
        final proposals = await ref.read(dashboardProposalsProvider.future);
        final proposal = proposals.where((proposal) => proposal['id']?.toString() == proposalId).firstOrNull;
        if (context.mounted && proposal != null) _proposal(context, ref, proposal);
      } catch (_) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load proposal. Please retry.')),
        );
      }
    } else if (type.contains('profile') || type.contains('verification')) {
      _profile(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(hostProfileProvider);
    final community = ref.watch(communityProfileProvider);
    final proposals = ref.watch(dashboardProposalsProvider);
    final notifications = ref.watch(notificationsProvider);
    return RefreshIndicator(onRefresh: () async {
      ref.invalidate(hostProfileProvider);
      ref.invalidate(communityProfileProvider);
      ref.invalidate(dashboardProposalsProvider);
      ref.invalidate(notificationsProvider);
      await ref.read(notificationsProvider.future);
    }, child: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text('Notifications', style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800))),
        IconButton(tooltip: 'Mark all read', icon: const Icon(Icons.done_all_rounded), onPressed: () async {
          try {
            await ref.read(apiClientProvider).markAllNotificationsRead();
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadNotificationsCountProvider);
          } catch (_) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not mark notifications as read.')),
            );
          }
        }),
      ]),
      const Divider(),
      for (final entry in [host.asData?.value, community.asData?.value])
        if (entry != null && ['REJECTED', 'PENDING'].contains(entry['approvalStatus']))
          ListTile(leading: const Icon(Icons.pending_actions_rounded),
            title: Text('${entry['name'] ?? entry['displayName'] ?? 'Profile'}: ${entry['approvalStatus']}'),
            subtitle: Text((entry['adminRejectionRemark'] ?? entry['rejectionReason'] ?? 'Awaiting review.').toString()),
            trailing: const Icon(Icons.chevron_right_rounded), onTap: () => _profile(context)),
      if (proposals.hasError || host.hasError || community.hasError)
        ListTile(title: const Text('Could not load status alerts'), trailing: TextButton(onPressed: () {
          ref.invalidate(dashboardProposalsProvider); ref.invalidate(hostProfileProvider); ref.invalidate(communityProfileProvider);
        }, child: const Text('Retry'))),
      for (final proposal in proposals.asData?.value ?? <Map<String, dynamic>>[])
        if (['REJECTED', 'UNDER_REVIEW', 'PUBLISHED'].contains(proposal['rawStatus'] ?? proposal['status']))
          ListTile(leading: const Icon(Icons.description_outlined),
            title: Text('${proposal['name']} - ${proposal['rawStatus'] ?? proposal['status']}'),
            subtitle: Text((proposal['adminRejectionRemark'] ?? 'Review proposal status.').toString()),
            trailing: const Icon(Icons.chevron_right_rounded), onTap: () => _proposal(context, ref, proposal)),
      const Divider(),
      if (notifications.isLoading) const Center(child: CircularProgressIndicator()),
      if (notifications.hasError) ListTile(title: const Text('Could not load notifications'), trailing: TextButton(
        onPressed: () => ref.invalidate(notificationsProvider), child: const Text('Retry'))),
      if (notifications.asData?.value.isEmpty == true) const ListTile(title: Text('No notifications yet')),
      for (final notification in notifications.asData?.value ?? <Map<String, dynamic>>[])
        ListTile(leading: Icon(notification['isRead'] == true ? Icons.notifications_none_rounded : Icons.notifications_active_rounded),
          title: Text((notification['title'] ?? 'Notification').toString()),
          subtitle: Text((notification['body'] ?? notification['message'] ?? '').toString()),
          onTap: () => _notification(context, ref, notification)),
    ]));
  }
}