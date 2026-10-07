import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/account_role.dart';
import '../../../auth/state/auth_provider.dart';

String _spaceAccountRole(AccountRole? role) {
  if (role == AccountRole.brand) return 'BRAND';
  if (role == AccountRole.space) return 'SPACE';
  return 'COMMUNITY';
}

// ─── Data Models ─────────────────────────────────────────────────────────────

enum ChatRole { community, brand, space }

class UnifiedRequestItem {
  const UnifiedRequestItem({
    required this.id,
    required this.category,
    required this.kind,
    required this.direction,
    required this.status,
    required this.counterpartName,
    this.counterpartAvatarUrl,
    this.counterpartType,
    required this.title,
    this.subtitle,
    this.description,
    this.createdAt,
    this.lastMessagePreview,
    required this.isIncoming,
    this.rawItem = const {},
  });

  final String id;
  final String category; // 'sponsorships', 'spaces', 'communities', 'brands'
  final String
  kind; // 'SPONSORSHIP', 'CAMPAIGN', 'SPACE_INTEREST', 'SPACE_HOST', 'COMMUNITY_COLLAB'
  final String direction; // 'INCOMING', 'OUTGOING'
  final String status; // 'REQUESTED', 'ACCEPTED', 'DECLINED'
  final String counterpartName;
  final String? counterpartAvatarUrl;
  final String? counterpartType;
  final String title;
  final String? subtitle;
  final String? description;
  final String? createdAt;
  final String? lastMessagePreview;
  final bool isIncoming;
  final Map<String, dynamic> rawItem;
}

class UnifiedActiveThread {
  const UnifiedActiveThread({
    required this.id,
    required this.category,
    required this.kind,
    required this.counterpartName,
    this.counterpartAvatarUrl,
    this.counterpartType,
    required this.title,
    this.subtitle,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.createdAt,
    this.unreadCount = 0,
    this.hasUnreadMention = false,
    this.isDealLocked = false,
    this.isDealClosed = false,
    this.rawThread = const {},
  });

  final String id;
  final String category;
  final String kind;
  final String counterpartName;
  final String? counterpartAvatarUrl;
  final String? counterpartType;
  final String title;
  final String? subtitle;
  final String? lastMessagePreview;
  final String? lastMessageAt;
  final String? createdAt;
  final int unreadCount;
  final bool hasUnreadMention;
  final bool isDealLocked;
  final bool isDealClosed;
  final Map<String, dynamic> rawThread;

  bool get isBrandCommunityCollaboration =>
      kind == 'COMMUNITY_COLLAB' &&
      (rawThread['collaborationType'] == 'BRAND_COMMUNITY' ||
          rawThread['requesterBrandId'] != null);
}

class UnifiedChatMessage {
  const UnifiedChatMessage({
    required this.id,
    required this.content,
    required this.senderType,
    required this.isMe,
    this.mediaUrl,
    this.messageType = 'TEXT',
    this.createdAt,
    this.deletedAt,
    this.editedAt,
    this.replyTo,
    this.raw = const {},
  });

  final String id;
  final String content;
  final String senderType;
  final bool isMe;
  final String? mediaUrl;
  final String messageType; // 'TEXT', 'IMAGE', 'SYSTEM'
  final DateTime? createdAt;
  final DateTime? deletedAt;
  final DateTime? editedAt;
  final UnifiedChatMessage? replyTo;
  final Map<String, dynamic> raw;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get isAdmin =>
      senderType == 'ADMIN' || senderType == 'BOT' || senderType == 'SYSTEM';
  bool get isSystem =>
      messageType == 'SYSTEM' ||
      content.toLowerCase().contains('[system]') ||
      isSystemMessage(raw);

  static bool isSystemMessage(Map<String, dynamic> m) {
    if ((m['messageType'] ?? '').toString().toUpperCase() == 'SYSTEM') {
      return true;
    }
    final content = (m['content'] ?? '').toString().toLowerCase();
    if (content.contains('[system]')) return true;
    if (content.contains('deal is locked') ||
        content.contains('deal is closed') ||
        content.contains('deal confirmed') ||
        content.contains('report approved') ||
        content.contains('deliverables report was submitted') ||
        content.contains('deliverables report') ||
        content.contains('payment completed')) {
      return true;
    }
    return false;
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    try {
      return DateTime.parse(val.toString());
    } catch (_) {
      return null;
    }
  }

  static UnifiedChatMessage? _parseReplyTo(dynamic val) {
    if (val is Map) {
      final r = Map<String, dynamic>.from(val);
      final sType = (r['senderType'] ?? '').toString().toUpperCase();
      return UnifiedChatMessage(
        id: (r['id'] ?? '').toString(),
        content: (r['content'] ?? '').toString(),
        senderType: sType,
        isMe: sType == 'HOST' || sType == 'COMMUNITY',
      );
    }
    return null;
  }

  factory UnifiedChatMessage.fromSponsorship(
    Map<String, dynamic> m, {
    String currentRole = 'HOST',
    String? currentUserId,
  }) {
    final senderType = (m['senderType'] ?? 'HOST').toString().toUpperCase();
    final senderId = m['senderId']?.toString();
    final isMe =
        (currentUserId != null &&
            senderId != null &&
            senderId == currentUserId) ||
        (senderType == currentRole.toUpperCase());
    final isSys = isSystemMessage(m);
    final msgType = isSys
        ? 'SYSTEM'
        : (m['mediaKey'] != null ? 'IMAGE' : (m['messageType'] ?? 'TEXT'))
              .toString()
              .toUpperCase();

    return UnifiedChatMessage(
      id: (m['id'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      senderType: senderType,
      isMe: isMe,
      mediaUrl: m['mediaUrl'] as String?,
      messageType: msgType,
      createdAt: _parseDate(m['createdAt']),
      deletedAt: _parseDate(m['deletedAt']),
      editedAt: _parseDate(m['editedAt']),
      replyTo: _parseReplyTo(m['replyTo']),
      raw: m,
    );
  }

  factory UnifiedChatMessage.fromSpace(
    Map<String, dynamic> m, {
    String currentRole = 'COMMUNITY',
    String? currentUserId,
  }) {
    final senderType = (m['senderType'] ?? 'COMMUNITY')
        .toString()
        .toUpperCase();
    final senderId = m['senderId']?.toString();
    final isMe =
        (currentUserId != null &&
            senderId != null &&
            senderId == currentUserId) ||
        (senderType == currentRole.toUpperCase());
    final isSys = isSystemMessage(m);
    final msgType = isSys
        ? 'SYSTEM'
        : (m['mediaKey'] != null ? 'IMAGE' : (m['messageType'] ?? 'TEXT'))
              .toString()
              .toUpperCase();

    return UnifiedChatMessage(
      id: (m['id'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      senderType: senderType,
      isMe: isMe,
      mediaUrl: m['mediaUrl'] as String?,
      messageType: msgType,
      createdAt: _parseDate(m['createdAt']),
      deletedAt: _parseDate(m['deletedAt']),
      editedAt: _parseDate(m['editedAt']),
      replyTo: _parseReplyTo(m['replyTo']),
      raw: m,
    );
  }

  factory UnifiedChatMessage.fromSpaceHost(
    Map<String, dynamic> m, {
    String? currentUserId,
  }) {
    final senderType = (m['senderType'] ?? 'HOST').toString().toUpperCase();
    final senderId = m['senderId']?.toString();
    final isMe =
        (currentUserId != null &&
            senderId != null &&
            senderId == currentUserId) ||
        (senderType == 'HOST');
    final isSys = isSystemMessage(m);
    final msgType = isSys
        ? 'SYSTEM'
        : (m['mediaKey'] != null ? 'IMAGE' : (m['messageType'] ?? 'TEXT'))
              .toString()
              .toUpperCase();

    return UnifiedChatMessage(
      id: (m['id'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      senderType: senderType,
      isMe: isMe,
      mediaUrl: m['mediaUrl'] as String?,
      messageType: msgType,
      createdAt: _parseDate(m['createdAt']),
      deletedAt: _parseDate(m['deletedAt']),
      editedAt: _parseDate(m['editedAt']),
      replyTo: _parseReplyTo(m['replyTo']),
      raw: m,
    );
  }

  factory UnifiedChatMessage.fromCommunityCollab(
    Map<String, dynamic> m,
    String mySenderType, {
    String? currentUserId,
  }) {
    final senderType = (m['senderType'] ?? 'REQUESTER')
        .toString()
        .toUpperCase();
    final senderId = m['senderId']?.toString();
    final isMe =
        (currentUserId != null &&
            senderId != null &&
            senderId == currentUserId) ||
        (senderType == mySenderType.toUpperCase());
    final isSys = isSystemMessage(m);
    final msgType = isSys
        ? 'SYSTEM'
        : (m['mediaKey'] != null ? 'IMAGE' : (m['messageType'] ?? 'TEXT'))
              .toString()
              .toUpperCase();

    return UnifiedChatMessage(
      id: (m['id'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      senderType: senderType,
      isMe: isMe,
      mediaUrl: m['mediaUrl'] as String?,
      messageType: msgType,
      createdAt: _parseDate(m['createdAt']),
      deletedAt: _parseDate(m['deletedAt']),
      editedAt: _parseDate(m['editedAt']),
      replyTo: _parseReplyTo(m['replyTo']),
      raw: m,
    );
  }

  factory UnifiedChatMessage.fromBrandCommunity(
    Map<String, dynamic> m, {
    String currentRole = 'COMMUNITY',
    String? mySenderType,
    String? currentUserId,
  }) {
    final senderType = (m['senderType'] ?? '').toString().toUpperCase();
    final senderId = m['senderId']?.toString();
    final isBrand = currentRole.toUpperCase() == 'BRAND';
    final expectedSender = isBrand ? 'REQUESTER' : 'TARGET';
    final isMe =
        (currentUserId != null &&
            senderId != null &&
            senderId == currentUserId) ||
        (mySenderType != null && senderType == mySenderType.toUpperCase()) ||
        (senderType == expectedSender) ||
        (isBrand && senderType == 'BRAND') ||
        (!isBrand && senderType == 'COMMUNITY');
    final isSys = isSystemMessage(m);
    final msgType = isSys
        ? 'SYSTEM'
        : (m['mediaKey'] != null ? 'IMAGE' : (m['messageType'] ?? 'TEXT'))
              .toString()
              .toUpperCase();

    return UnifiedChatMessage(
      id: (m['id'] ?? '').toString(),
      content: (m['content'] ?? '').toString(),
      senderType: senderType,
      isMe: isMe,
      mediaUrl: m['mediaUrl'] as String?,
      messageType: msgType,
      createdAt: _parseDate(m['createdAt']),
      deletedAt: _parseDate(m['deletedAt']),
      editedAt: _parseDate(m['editedAt']),
      replyTo: _parseReplyTo(m['replyTo']),
      raw: m,
    );
  }
}

class CategoryDefinition {
  const CategoryDefinition({
    required this.key,
    required this.label,
    required this.description,
    this.badgeCount = 0,
    this.activeCount = 0,
    this.pendingRequestsCount = 0,
  });

  final String key; // 'sponsorships', 'spaces', 'communities', 'brands'
  final String label;
  final String description;
  final int badgeCount;
  final int activeCount;
  final int pendingRequestsCount;
}

class ChatHubData {
  const ChatHubData({
    required this.categories,
    required this.activeThreadsByCategory,
    required this.allRequests,
    required this.incomingCount,
    required this.sentCount,
  });

  final List<CategoryDefinition> categories;
  final Map<String, List<UnifiedActiveThread>> activeThreadsByCategory;
  final List<UnifiedRequestItem> allRequests;
  final int incomingCount;
  final int sentCount;
}

class ChatHubInitialTarget {
  const ChatHubInitialTarget({
    required this.category,
    this.threadId,
    this.queue,
  });

  final String category;
  final String? threadId;
  final String? queue;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _extractList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (data is Map) {
    // Check direct keys first
    for (final k in ['threads', 'chats', 'messages', 'items']) {
      if (data[k] is List) {
        return (data[k] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    if (data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (data['data'] is Map) {
      final inner = data['data'];
      for (final k in ['threads', 'chats', 'messages', 'items']) {
        if (inner[k] is List) {
          return (inner[k] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
  }
  return [];
}

// ─── Chat Hub Provider ───────────────────────────────────────────────────────

final chatHubProvider = FutureProvider.autoDispose<ChatHubData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final accountRole = ref.watch(authControllerProvider).role;
  final sponsorshipRole = accountRole == AccountRole.brand ? 'BRAND' : 'HOST';
  final spaceRole = _spaceAccountRole(accountRole);

  // 1. Fetch raw data across all 5 endpoints in parallel
  List<Map<String, dynamic>> sponsorshipAccepted = [];
  List<Map<String, dynamic>> sponsorshipRequested = [];
  List<Map<String, dynamic>> spaceThreads = [];
  List<Map<String, dynamic>> spaceHostThreads = [];
  List<Map<String, dynamic>> communityCollabThreads = [];
  List<Map<String, dynamic>> brandCommunityThreads = [];

  try {
    Future<dynamic> safeGet(String path, [Map<String, dynamic>? params]) async {
      try {
        final res = await api.dio.get<dynamic>(path, queryParameters: params);
        return res.data;
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safeGet('/sponsorships/chats', {
        'status': 'ACCEPTED',
        'role': sponsorshipRole,
      }),
      safeGet('/sponsorships/chats', {
        'status': 'REQUESTED',
        'role': sponsorshipRole,
      }),
      safeGet('/spaces/chats', {'role': spaceRole}),
      safeGet('/space-host/chats', {'role': 'HOST'}),
      safeGet('/community-collaboration/chats'),
      safeGet('/brand-community-collaboration/chats', {
        'asRole': accountRole == AccountRole.brand ? 'BRAND' : 'COMMUNITY',
      }),
    ]);

    if (results[0] != null) sponsorshipAccepted = _extractList(results[0]);
    if (results[1] != null) sponsorshipRequested = _extractList(results[1]);
    if (results[2] != null) spaceThreads = _extractList(results[2]);
    if (results[3] != null) spaceHostThreads = _extractList(results[3]);
    if (results[4] != null) communityCollabThreads = _extractList(results[4]);
    if (results[5] != null) brandCommunityThreads = _extractList(results[5]);
  } catch (e) {
    debugPrint('Error fetching chat data: $e');
  }

  // 2. Aggregate Active Threads
  final activeMap = <String, List<UnifiedActiveThread>>{
    'sponsorships': [],
    'campaigns': [],
    'spaces': [],
    'communities': [],
    'brands': [],
  };

  // Sponsorships & Campaigns Accepted
  for (final t in sponsorshipAccepted) {
    final isCampaign = t['campaignId'] != null;
    final catKey = isCampaign ? 'campaigns' : 'sponsorships';
    final deal = t['deal'] is Map ? (t['deal'] as Map) : null;
    final dealStatus = (t['dealStatus'] ?? deal?['status'] ?? '')
        .toString()
        .toUpperCase();
    final paymentStatus = (t['paymentStatus'] ?? deal?['paymentStatus'] ?? '')
        .toString()
        .toUpperCase();

    final isLocked =
        t['isDealLocked'] == true ||
        t['dealLocked'] == true ||
        dealStatus == 'APPROVED' ||
        dealStatus == 'LOCKED';
    final isClosed =
        t['isDealClosed'] == true ||
        t['dealClosed'] == true ||
        dealStatus == 'CLOSED' ||
        (dealStatus == 'APPROVED' && paymentStatus == 'PAID');

    final isBrand = accountRole == AccountRole.brand;
    final defaultCounterpartName = isBrand ? 'Community' : 'Brand';
    final defaultCounterpartType = isBrand ? 'COMMUNITY' : 'BRAND';

    activeMap[catKey]!.add(
      UnifiedActiveThread(
        id: (t['id'] ?? '').toString(),
        category: catKey,
        kind: isCampaign ? 'CAMPAIGN' : 'SPONSORSHIP',
        counterpartName: (t['counterpartName'] ?? defaultCounterpartName)
            .toString(),
        counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
        counterpartType: (t['counterpartType'] ?? defaultCounterpartType)
            .toString(),
        title:
            (t['proposalName'] ??
                    (isCampaign ? 'Brand Campaign' : 'Sponsorship Proposal'))
                .toString(),
        subtitle: (t['counterpartName'] ?? '').toString(),
        lastMessagePreview: t['lastMessagePreview'] as String?,
        lastMessageAt: t['lastMessageAt'] as String?,
        createdAt: t['createdAt'] as String?,
        unreadCount: (t['unreadCount'] is num)
            ? (t['unreadCount'] as num).toInt()
            : 0,
        hasUnreadMention: t['hasUnreadMention'] == true,
        isDealLocked: isLocked,
        isDealClosed: isClosed,
        rawThread: t,
      ),
    );
  }

  // Space Threads (from /spaces/chats)
  for (final t in spaceThreads) {
    if (t['chatStatus'] == 'ACCEPTED') {
      final deal = t['deal'] is Map ? (t['deal'] as Map) : null;
      final dealStatus = (t['dealStatus'] ?? deal?['status'] ?? '')
          .toString()
          .toUpperCase();
      final paymentStatus = (t['paymentStatus'] ?? deal?['paymentStatus'] ?? '')
          .toString()
          .toUpperCase();

      final isLocked =
          t['isDealLocked'] == true ||
          t['dealLocked'] == true ||
          dealStatus == 'APPROVED' ||
          dealStatus == 'LOCKED';
      final isClosed =
          t['isDealClosed'] == true ||
          t['dealClosed'] == true ||
          dealStatus == 'CLOSED' ||
          (dealStatus == 'APPROVED' && paymentStatus == 'PAID');

      activeMap['spaces']!.add(
        UnifiedActiveThread(
          id: (t['id'] ?? '').toString(),
          category: 'spaces',
          kind: 'SPACE_INTEREST',
          counterpartName: (t['counterpartName'] ?? 'Hub Partner').toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: 'SPACE',
          title: (t['counterpartName'] ?? 'Hub Booking').toString(),
          subtitle: (t['counterpartName'] ?? '').toString(),
          lastMessagePreview: t['lastMessagePreview'] as String?,
          lastMessageAt: t['lastMessageAt'] as String?,
          createdAt: t['createdAt'] as String?,
          unreadCount: (t['unreadCount'] is num)
              ? (t['unreadCount'] as num).toInt()
              : 0,
          isDealLocked: isLocked,
          isDealClosed: isClosed,
          rawThread: t,
        ),
      );
    }
  }

  // Space Host Threads (from /space-host/chats)
  for (final t in spaceHostThreads) {
    if (t['chatStatus'] == 'ACCEPTED') {
      final deal = t['deal'] is Map ? (t['deal'] as Map) : null;
      final dealStatus = (t['dealStatus'] ?? deal?['status'] ?? '')
          .toString()
          .toUpperCase();
      final paymentStatus = (t['paymentStatus'] ?? deal?['paymentStatus'] ?? '')
          .toString()
          .toUpperCase();

      final isLocked =
          t['isDealLocked'] == true ||
          t['dealLocked'] == true ||
          dealStatus == 'APPROVED' ||
          dealStatus == 'LOCKED';
      final isClosed =
          t['isDealClosed'] == true ||
          t['dealClosed'] == true ||
          dealStatus == 'CLOSED' ||
          (dealStatus == 'APPROVED' && paymentStatus == 'PAID');

      activeMap['spaces']!.add(
        UnifiedActiveThread(
          id: (t['id'] ?? '').toString(),
          category: 'spaces',
          kind: 'SPACE_HOST',
          counterpartName: (t['counterpartName'] ?? 'Hub Partner').toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: 'SPACE',
          title: (t['counterpartName'] ?? 'Hub Partnership').toString(),
          subtitle: (t['counterpartName'] ?? '').toString(),
          lastMessagePreview: t['lastMessagePreview'] as String?,
          lastMessageAt: t['lastMessageAt'] as String?,
          createdAt: t['createdAt'] as String?,
          unreadCount: (t['unreadCount'] is num)
              ? (t['unreadCount'] as num).toInt()
              : 0,
          isDealLocked: isLocked,
          isDealClosed: isClosed,
          rawThread: t,
        ),
      );
    }
  }

  // Community Collaboration Threads
  for (final t in communityCollabThreads) {
    if (t['chatStatus'] == 'ACCEPTED') {
      activeMap['communities']!.add(
        UnifiedActiveThread(
          id: (t['id'] ?? '').toString(),
          category: 'communities',
          kind: 'COMMUNITY_COLLAB',
          counterpartName: (t['counterpartName'] ?? 'Community').toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: 'COMMUNITY',
          title: 'Community Collaboration',
          subtitle: (t['counterpartName'] ?? '').toString(),
          lastMessagePreview: t['lastMessagePreview'] as String?,
          lastMessageAt: t['lastMessageAt'] as String?,
          createdAt: t['createdAt'] as String?,
          unreadCount: (t['unreadCount'] is num)
              ? (t['unreadCount'] as num).toInt()
              : 0,
          rawThread: t,
        ),
      );
    }
  }

  // Brand Community Threads
  final isBrandCommunityRole = accountRole == AccountRole.brand;
  for (final t in brandCommunityThreads) {
    if (t['chatStatus'] == 'ACCEPTED') {
      final isBrandUser = accountRole == AccountRole.brand;
      final categoryKey = isBrandUser ? 'communities' : 'brands';
      activeMap[categoryKey]!.add(
        UnifiedActiveThread(
          id: (t['id'] ?? '').toString(),
          category: categoryKey,
          kind: 'COMMUNITY_COLLAB',
          counterpartName:
              (t['counterpartName'] ?? (isBrandUser ? 'Community' : 'Brand'))
                  .toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: isBrandCommunityRole ? 'COMMUNITY' : 'BRAND',
          title: isBrandUser
              ? 'Community Collaboration'
              : 'Brand Collaboration',
          lastMessagePreview: t['lastMessagePreview'] as String?,
          lastMessageAt: t['lastMessageAt'] as String?,
          unreadCount: (t['unreadCount'] is num)
              ? (t['unreadCount'] as num).toInt()
              : 0,
          rawThread: t,
        ),
      );
    }
  }

  // 3. Aggregate Unified Requests (Incoming & Sent)
  final requests = <UnifiedRequestItem>[];

  // Sponsorship Requests
  for (final t in sponsorshipRequested) {
    final isCampaign = t['campaignId'] != null;
    final isBrandUser = accountRole == AccountRole.brand;
    if (isBrandUser) {
      if (isCampaign) {
        // Incoming: Community applied to Brand campaign
        requests.add(
          UnifiedRequestItem(
            id: (t['id'] ?? '').toString(),
            category: 'campaigns',
            kind: 'CAMPAIGN',
            direction: 'INCOMING',
            status: 'REQUESTED',
            counterpartName: (t['counterpartName'] ?? 'Community').toString(),
            counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
            counterpartType: 'COMMUNITY',
            title: (t['proposalName'] ?? 'Campaign Application').toString(),
            description: 'This community applied to your campaign.',
            createdAt: t['createdAt'] as String?,
            lastMessagePreview: t['lastMessagePreview'] as String?,
            isIncoming: true,
            rawItem: t,
          ),
        );
      } else {
        // Outgoing: Brand requested sponsorship from community proposal
        requests.add(
          UnifiedRequestItem(
            id: (t['id'] ?? '').toString(),
            category: 'sponsorships',
            kind: 'SPONSORSHIP',
            direction: 'OUTGOING',
            status: 'REQUESTED',
            counterpartName: (t['counterpartName'] ?? 'Community').toString(),
            counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
            counterpartType: t['counterpartType'] == 'SPACE'
                ? 'SPACE'
                : 'COMMUNITY',
            title: (t['proposalName'] ?? 'Sponsorship Interest').toString(),
            description:
                'You expressed interest in this proposal. Awaiting community acceptance.',
            createdAt: t['createdAt'] as String?,
            lastMessagePreview: t['lastMessagePreview'] as String?,
            isIncoming: false,
            rawItem: t,
          ),
        );
      }
    } else {
      if (!isCampaign) {
        // Incoming: Brand interested in Host proposal
        requests.add(
          UnifiedRequestItem(
            id: (t['id'] ?? '').toString(),
            category: 'sponsorships',
            kind: 'SPONSORSHIP',
            direction: 'INCOMING',
            status: 'REQUESTED',
            counterpartName: (t['counterpartName'] ?? 'Brand').toString(),
            counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
            counterpartType: 'BRAND',
            title: (t['proposalName'] ?? 'Sponsorship Proposal').toString(),
            description: 'This brand is interested in your proposal.',
            createdAt: t['createdAt'] as String?,
            lastMessagePreview: t['lastMessagePreview'] as String?,
            isIncoming: true,
            rawItem: t,
          ),
        );
      } else {
        // Outgoing: Host applied to campaign
        requests.add(
          UnifiedRequestItem(
            id: (t['id'] ?? '').toString(),
            category: 'campaigns',
            kind: 'CAMPAIGN',
            direction: 'OUTGOING',
            status: 'REQUESTED',
            counterpartName: (t['counterpartName'] ?? 'Brand').toString(),
            counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
            counterpartType: 'BRAND',
            title: (t['proposalName'] ?? 'Brand Campaign').toString(),
            description:
                'You showed interest in this campaign. Awaiting brand approval.',
            createdAt: t['createdAt'] as String?,
            lastMessagePreview: t['lastMessagePreview'] as String?,
            isIncoming: false,
            rawItem: t,
          ),
        );
      }
    }
  }

  // Space Requests
  final isSpacePartner = accountRole == AccountRole.space;
  for (final t in spaceThreads) {
    if (t['chatStatus'] == 'REQUESTED') {
      requests.add(
        UnifiedRequestItem(
          id: (t['id'] ?? '').toString(),
          category: 'spaces',
          kind: 'SPACE_INTEREST',
          direction: isSpacePartner ? 'INCOMING' : 'OUTGOING',
          status: 'REQUESTED',
          counterpartName: (t['counterpartName'] ?? 'Hub Partner').toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: 'SPACE',
          title: (t['counterpartName'] ?? 'Hub Booking').toString(),
          description: isSpacePartner
              ? 'This community sent a booking inquiry to your hub.'
              : 'You sent a booking inquiry to this hub.',
          createdAt: t['createdAt'] as String?,
          lastMessagePreview: t['lastMessagePreview'] as String?,
          isIncoming: isSpacePartner,
          rawItem: t,
        ),
      );
    }
  }

  for (final t in spaceHostThreads) {
    if (t['chatStatus'] == 'REQUESTED') {
      requests.add(
        UnifiedRequestItem(
          id: (t['id'] ?? '').toString(),
          category: 'spaces',
          kind: 'SPACE_HOST',
          direction: 'INCOMING',
          status: 'REQUESTED',
          counterpartName: (t['counterpartName'] ?? 'Hub Partner').toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: 'SPACE',
          title: (t['counterpartName'] ?? 'Hub Partnership').toString(),
          description: 'This hub partner wants to host your community events.',
          createdAt: t['createdAt'] as String?,
          lastMessagePreview: t['lastMessagePreview'] as String?,
          isIncoming: true,
          rawItem: t,
        ),
      );
    }
  }

  // Community Collab Requests
  for (final t in communityCollabThreads) {
    if (t['chatStatus'] == 'REQUESTED') {
      final isIncoming = t['direction'] == 'INCOMING';
      requests.add(
        UnifiedRequestItem(
          id: (t['id'] ?? '').toString(),
          category: 'communities',
          kind: 'COMMUNITY_COLLAB',
          direction: isIncoming ? 'INCOMING' : 'OUTGOING',
          status: 'REQUESTED',
          counterpartName: (t['counterpartName'] ?? 'Community').toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: 'COMMUNITY',
          title: 'Community Collaboration',
          description: isIncoming
              ? 'This community sent you a collaboration request.'
              : 'You sent a collaboration request to this community.',
          createdAt: t['createdAt'] as String?,
          lastMessagePreview: t['lastMessagePreview'] as String?,
          isIncoming: isIncoming,
          rawItem: t,
        ),
      );
    }
  }

  // Brand Community Requests
  for (final t in brandCommunityThreads) {
    if (t['chatStatus'] == 'REQUESTED') {
      requests.add(
        UnifiedRequestItem(
          id: (t['id'] ?? '').toString(),
          category: 'brands',
          kind: 'COMMUNITY_COLLAB',
          direction: isBrandCommunityRole ? 'OUTGOING' : 'INCOMING',
          status: 'REQUESTED',
          counterpartName: (t['counterpartName'] ?? 'Brand').toString(),
          counterpartAvatarUrl: t['counterpartAvatarUrl'] as String?,
          counterpartType: isBrandCommunityRole ? 'COMMUNITY' : 'BRAND',
          title: isBrandCommunityRole
              ? 'Community Collaboration'
              : 'Brand Collaboration',
          description: isBrandCommunityRole
              ? 'You sent this community a collaboration request.'
              : 'This brand wants to collaborate with your community.',
          createdAt: t['createdAt'] as String?,
          lastMessagePreview: t['lastMessagePreview'] as String?,
          isIncoming: !isBrandCommunityRole,
          rawItem: t,
        ),
      );
    }
  }

  // Sort requests by newest first
  requests.sort((a, b) {
    final tA = a.createdAt != null
        ? DateTime.tryParse(a.createdAt!)?.millisecondsSinceEpoch ?? 0
        : 0;
    final tB = b.createdAt != null
        ? DateTime.tryParse(b.createdAt!)?.millisecondsSinceEpoch ?? 0
        : 0;
    return tB.compareTo(tA);
  });

  // Calculate unread & pending counts per category
  final spUnread = activeMap['sponsorships']!.fold<int>(
    0,
    (s, t) => s + t.unreadCount,
  );
  final campUnread = activeMap['campaigns']!.fold<int>(
    0,
    (s, t) => s + t.unreadCount,
  );
  final spcUnread = activeMap['spaces']!.fold<int>(
    0,
    (s, t) => s + t.unreadCount,
  );
  final comUnread = activeMap['communities']!.fold<int>(
    0,
    (s, t) => s + t.unreadCount,
  );
  final brUnread = activeMap['brands']!.fold<int>(
    0,
    (s, t) => s + t.unreadCount,
  );

  final spPending = requests
      .where((r) => r.category == 'sponsorships' && r.direction == 'INCOMING')
      .length;
  final campPending = requests.where((r) => r.category == 'campaigns').length;
  final spcPending = requests
      .where((r) => r.category == 'spaces' && r.direction == 'INCOMING')
      .length;
  final comPending = requests
      .where((r) => r.category == 'communities' && r.direction == 'INCOMING')
      .length;
  final brPending = requests
      .where((r) => r.category == 'brands' && r.direction == 'INCOMING')
      .length;

  final categories = [
    CategoryDefinition(
      key: 'sponsorships',
      label: 'Sponsorships',
      description: 'Talk to brands interested in your experience proposals.',
      badgeCount: spUnread,
      activeCount: activeMap['sponsorships']!.length,
      pendingRequestsCount: spPending,
    ),
    CategoryDefinition(
      key: 'campaigns',
      label: 'Campaigns',
      description: 'Collaborate with brands on active campaign briefs.',
      badgeCount: campUnread,
      activeCount: activeMap['campaigns']!.length,
      pendingRequestsCount: campPending,
    ),
    CategoryDefinition(
      key: 'spaces',
      label: 'Hubs',
      description: 'Collaborate with community hubs & venues for events.',
      badgeCount: spcUnread,
      activeCount: activeMap['spaces']!.length,
      pendingRequestsCount: spcPending,
    ),
    CategoryDefinition(
      key: 'communities',
      label: 'Communities',
      description:
          'Partner, cross-promote, and co-host with other communities.',
      badgeCount: comUnread,
      activeCount: activeMap['communities']!.length,
      pendingRequestsCount: comPending,
    ),
    CategoryDefinition(
      key: 'brands',
      label: 'Brands',
      description: 'Manage collaboration requests from brands.',
      badgeCount: brUnread,
      activeCount: activeMap['brands']!.length,
      pendingRequestsCount: brPending,
    ),
  ];

  final incomingCount = requests.where((r) => r.direction == 'INCOMING').length;
  final sentCount = requests.where((r) => r.direction == 'OUTGOING').length;

  return ChatHubData(
    categories: categories,
    activeThreadsByCategory: activeMap,
    allRequests: requests,
    incomingCount: incomingCount,
    sentCount: sentCount,
  );
});

// ─── Thread Messages Provider ────────────────────────────────────────────────

final chatMessagesProvider = FutureProvider.autoDispose
    .family<List<UnifiedChatMessage>, UnifiedActiveThread>((ref, thread) async {
      final api = ref.watch(apiClientProvider);
      final authState = ref.watch(authControllerProvider);
      final accountRole = authState.role;
      final currentUserId = authState.uid;
      final sponsorshipRole = accountRole == AccountRole.brand
          ? 'BRAND'
          : 'HOST';
      final id = thread.id;

      try {
        switch (thread.kind) {
          case 'SPONSORSHIP':
          case 'CAMPAIGN':
            final res = await api.dio.get<dynamic>(
              '/sponsorships/chats/$id/messages',
              queryParameters: {'role': sponsorshipRole},
            );
            final list = _extractList(res.data);
            return list
                .map(
                  (m) => UnifiedChatMessage.fromSponsorship(
                    m,
                    currentRole: sponsorshipRole,
                    currentUserId: currentUserId,
                  ),
                )
                .toList();
          case 'SPACE_INTEREST':
            final res = await api.dio.get<dynamic>(
              '/spaces/chats/$id/messages',
              queryParameters: {'role': _spaceAccountRole(accountRole)},
            );
            final list = _extractList(res.data);
            final spaceRole = _spaceAccountRole(accountRole);
            return list
                .map(
                  (m) => UnifiedChatMessage.fromSpace(
                    m,
                    currentRole: spaceRole,
                    currentUserId: currentUserId,
                  ),
                )
                .toList();
          case 'SPACE_HOST':
            final res = await api.dio.get<dynamic>(
              '/space-host/chats/$id/messages',
              queryParameters: {'role': 'HOST'},
            );
            final list = _extractList(res.data);
            return list
                .map(
                  (m) => UnifiedChatMessage.fromSpaceHost(
                    m,
                    currentUserId: currentUserId,
                  ),
                )
                .toList();
          case 'COMMUNITY_COLLAB':
            if (thread.isBrandCommunityCollaboration) {
              final brandCollabRole = accountRole == AccountRole.brand
                  ? 'BRAND'
                  : 'COMMUNITY';
              final res = await api.dio.get<dynamic>(
                '/brand-community-collaboration/chats/$id/messages',
                queryParameters: {'asRole': brandCollabRole},
              );
              final data = res.data is Map
                  ? (res.data['data'] ?? res.data)
                  : res.data;
              final mySenderType = data is Map
                  ? data['mySenderType']?.toString()
                  : null;
              final list = _extractList(res.data);
              return list
                  .map(
                    (m) => UnifiedChatMessage.fromBrandCommunity(
                      m,
                      currentRole: brandCollabRole,
                      mySenderType: mySenderType,
                      currentUserId: currentUserId,
                    ),
                  )
                  .toList();
            } else {
              final res = await api.dio.get<dynamic>(
                '/community-collaboration/chats/$id/messages',
              );
              final data = res.data is Map
                  ? (res.data['data'] ?? res.data)
                  : res.data;
              final mySenderType = data is Map
                  ? (data['mySenderType'] ?? 'REQUESTER').toString()
                  : 'REQUESTER';
              final list = _extractList(res.data);
              return list
                  .map(
                    (m) => UnifiedChatMessage.fromCommunityCollab(
                      m,
                      mySenderType,
                      currentUserId: currentUserId,
                    ),
                  )
                  .toList();
            }
          default:
            return [];
        }
      } catch (e) {
        debugPrint('Error fetching chat messages: $e');
        return [];
      }
    });

// ─── Thread Deal & Report Providers ──────────────────────────────────────────

final threadDealProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, UnifiedActiveThread>((ref, thread) async {
      final api = ref.watch(apiClientProvider);
      final id = thread.id;

      try {
        if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
          final res = await api.dio.get<dynamic>(
            '/sponsorships/chats/$id/deal',
          );
          final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
          if (data is Map<String, dynamic>) return data;
          if (data is Map) return Map<String, dynamic>.from(data);
        } else if (thread.kind == 'SPACE_INTEREST') {
          final res = await api.dio.get<dynamic>('/spaces/chats/$id/deal');
          final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
          if (data is Map<String, dynamic>) return data;
          if (data is Map) return Map<String, dynamic>.from(data);
        } else if (thread.kind == 'SPACE_HOST') {
          final res = await api.dio.get<dynamic>('/space-host/chats/$id/deal');
          final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
          if (data is Map<String, dynamic>) return data;
          if (data is Map) return Map<String, dynamic>.from(data);
        }
      } catch (e) {
        debugPrint('Error fetching deal: $e');
      }
      return null;
    });

final threadReportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, UnifiedActiveThread>((ref, thread) async {
      final api = ref.watch(apiClientProvider);
      final accountRole = ref.watch(authControllerProvider).role;
      final id = thread.id;

      try {
        if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
          final res = await api.dio.get<dynamic>(
            '/sponsorships/chats/$id/deal/report',
          );
          final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
          if (data is Map<String, dynamic>) return data;
          if (data is Map) return Map<String, dynamic>.from(data);
        } else if (thread.kind == 'SPACE_INTEREST') {
          final res = await api.dio.get<dynamic>(
            '/spaces/chats/$id/deal/report',
            queryParameters: {'role': _spaceAccountRole(accountRole)},
          );
          final data = res.data is Map ? (res.data['data'] ?? res.data) : null;
          if (data is Map<String, dynamic>) return data;
          if (data is Map) return Map<String, dynamic>.from(data);
        }
      } catch (e) {
        debugPrint('Error fetching report: $e');
      }
      return null;
    });

// ─── Chat Actions API Helpers ────────────────────────────────────────────────

Future<void> editChatMessageApi(
  ApiClient api,
  UnifiedActiveThread thread,
  String messageId,
  String newContent,
) async {
  final id = thread.id;
  if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
    await api.dio.patch<dynamic>(
      '/sponsorships/chats/$id/messages/$messageId',
      data: {'content': newContent},
    );
  } else if (thread.kind == 'SPACE_INTEREST') {
    await api.dio.patch<dynamic>(
      '/spaces/chats/$id/messages/$messageId',
      data: {'content': newContent},
    );
  } else if (thread.kind == 'SPACE_HOST') {
    await api.dio.patch<dynamic>(
      '/space-host/chats/$id/messages/$messageId',
      data: {'content': newContent},
    );
  }
}

Future<void> deleteChatMessageApi(
  ApiClient api,
  UnifiedActiveThread thread,
  String messageId,
) async {
  final id = thread.id;
  if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
    await api.dio.delete<dynamic>(
      '/sponsorships/chats/$id/messages/$messageId',
    );
  } else if (thread.kind == 'SPACE_INTEREST') {
    await api.dio.delete<dynamic>('/spaces/chats/$id/messages/$messageId');
  } else if (thread.kind == 'SPACE_HOST') {
    await api.dio.delete<dynamic>('/space-host/chats/$id/messages/$messageId');
  }
}

Future<void> saveDealApi(
  ApiClient api,
  UnifiedActiveThread thread,
  Map<String, dynamic> payload, {
  bool isUpdate = false,
  AccountRole? role,
}) async {
  final id = thread.id;
  if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
    if (isUpdate) {
      await api.dio.patch<dynamic>(
        '/sponsorships/chats/$id/deal',
        data: payload,
      );
    } else {
      await api.dio.post<dynamic>(
        '/sponsorships/chats/$id/deal',
        data: payload,
      );
    }
  } else if (thread.kind == 'SPACE_INTEREST') {
    if (isUpdate) {
      await api.dio.put<dynamic>(
        '/spaces/chats/$id/deal',
        data: {...payload, 'asRole': _spaceAccountRole(role)},
      );
    } else {
      await api.dio.post<dynamic>(
        '/spaces/chats/$id/deal',
        data: {...payload, 'asRole': _spaceAccountRole(role)},
      );
    }
  } else if (thread.kind == 'SPACE_HOST') {
    if (isUpdate) {
      await api.dio.put<dynamic>('/space-host/chats/$id/deal', data: payload);
    } else {
      await api.dio.post<dynamic>('/space-host/chats/$id/deal', data: payload);
    }
  }
}

Future<void> saveReportApi(
  ApiClient api,
  UnifiedActiveThread thread,
  Map<String, dynamic> payload, {
  AccountRole? role,
}) async {
  final id = thread.id;
  if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
    await api.dio.put<dynamic>(
      '/sponsorships/chats/$id/deal/report',
      data: payload,
    );
  } else if (thread.kind == 'SPACE_INTEREST') {
    await api.dio.put<dynamic>(
      '/spaces/chats/$id/deal/report',
      data: {...payload, 'asRole': _spaceAccountRole(role)},
    );
  } else if (thread.kind == 'SPACE_HOST') {
    await api.dio.put<dynamic>(
      '/space-host/chats/$id/deal/report',
      data: payload,
    );
  }
}

Future<void> approveDealApi(
  ApiClient api,
  UnifiedActiveThread thread, {
  AccountRole? role,
}) async {
  final id = thread.id;
  if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
    await api.dio.post<dynamic>('/sponsorships/chats/$id/deal/approve');
  } else if (thread.kind == 'SPACE_INTEREST') {
    await api.dio.post<dynamic>(
      '/spaces/chats/$id/deal/approve',
      queryParameters: {'role': _spaceAccountRole(role)},
    );
  } else if (thread.kind == 'SPACE_HOST') {
    await api.dio.post<dynamic>('/space-host/chats/$id/deal/approve');
  }
}

Future<void> requestDealChangesApi(
  ApiClient api,
  UnifiedActiveThread thread, {
  String? note,
  AccountRole? role,
}) async {
  final id = thread.id;
  final body = note != null && note.trim().isNotEmpty
      ? {'note': note.trim()}
      : <String, dynamic>{};
  if (thread.kind == 'SPONSORSHIP' || thread.kind == 'CAMPAIGN') {
    await api.dio.post<dynamic>(
      '/sponsorships/chats/$id/deal/request-changes',
      data: body,
    );
  } else if (thread.kind == 'SPACE_INTEREST') {
    await api.dio.post<dynamic>(
      '/spaces/chats/$id/deal/request-changes',
      data: {...body, 'asRole': _spaceAccountRole(role)},
    );
  } else if (thread.kind == 'SPACE_HOST') {
    await api.dio.post<dynamic>(
      '/space-host/chats/$id/deal/request-changes',
      data: body,
    );
  }
}
