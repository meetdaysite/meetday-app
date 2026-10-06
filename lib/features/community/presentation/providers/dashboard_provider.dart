import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/account_role.dart';
import '../../../auth/state/auth_provider.dart';

// Helper function to check if event date has passed
bool _isEventCompleted(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return false;
  try {
    final d = DateTime.parse(dateStr);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    return d.isBefore(todayStart);
  } catch (_) {
    return false;
  }
}

String _formatDateRange(String? start, String? end) {
  if (start == null || start.isEmpty) return 'Date TBD';
  try {
    final s = DateTime.parse(start);
    final sStr = '${s.day} ${_monthName(s.month)} ${s.year}';
    if (end == null || end.isEmpty || end == start) return sStr;
    final e = DateTime.parse(end);
    final eStr = '${e.day} ${_monthName(e.month)} ${e.year}';
    if (sStr == eStr) return sStr;
    return '$sStr - $eStr';
  } catch (_) {
    return 'Date TBD';
  }
}

Map<String, dynamic> _mapProposalItem(Map item) {
  final name =
      (item['name'] ??
              item['title'] ??
              item['briefTitle'] ??
              'Untitled Proposal')
          .toString();
  final about = (item['about'] ?? '').toString();
  final imageUrl = item['imageUrl'] as String?;
  final eventDate = item['eventDate']?.toString();
  final eventEndDate = item['eventEndDate']?.toString();
  final dateLabel = _formatDateRange(eventDate, eventEndDate);

  final venues =
      (item['venues'] as List?)?.map((e) => e.toString()).toList() ??
      <String>[];
  final venueCities =
      (item['venueCities'] as List?)?.map((e) => e.toString()).toList() ??
      <String>[];
  final venue =
      item['venue']?.toString() ?? (venues.isNotEmpty ? venues.first : '');
  final city =
      item['city']?.toString() ??
      (venueCities.isNotEmpty ? venueCities.first : '');

  final guestCount = (item['guestCount'] ?? '').toString();
  final ageGroup = (item['ageGroup'] ?? '').toString();
  final videoUrl = item['videoUrl'] as String?;
  final docUrl = item['docUrl'] as String?;
  final docName = item['docName'] as String?;
  final docType = item['docType'] as String?;
  final docSize = item['docSize'] as int?;

  final rawStatus = (item['status'] ?? 'PUBLISHED').toString().toUpperCase();
  final isCompleted = _isEventCompleted(eventEndDate ?? eventDate);
  final effectiveStatus = isCompleted ? 'COMPLETED' : rawStatus;

  final sponsorshipType = (item['sponsorshipType'] ?? 'CASH')
      .toString()
      .toUpperCase();
  final hasCash = sponsorshipType == 'CASH' || sponsorshipType == 'BOTH';
  final hasBarter = sponsorshipType == 'BARTER' || sponsorshipType == 'BOTH';

  final sponsorTiers =
      (item['sponsorTiers'] as List?)
          ?.whereType<Map>()
          .map(
            (t) => {
              'name': (t['name'] ?? '').toString(),
              'price': (t['price'] ?? '').toString(),
            },
          )
          .toList() ??
      <Map<String, dynamic>>[];

  final hostProfile = item['hostProfile'] is Map
      ? item['hostProfile'] as Map
      : null;
  final hostName =
      (hostProfile?['displayName'] ??
              item['hostName'] ??
              item['communityName'] ??
              '')
          .toString();
  final hostProfileId = (item['hostProfileId'] ?? hostProfile?['id'] ?? '')
      .toString();
  final communityId =
      (item['communityId'] ?? hostProfile?['communityProfile']?['id'] ?? '')
          .toString();

  return <String, dynamic>{
    'id': (item['id'] ?? '').toString(),
    'name': name,
    'title': name,
    'about': about,
    'imageUrl': imageUrl,
    'imageKey': item['imageKey'],
    'eventDate': eventDate,
    'eventEndDate': eventEndDate,
    'dateLabel': dateLabel,
    'venue': venue,
    'venues': venues,
    'city': city,
    'venueCities': venueCities,
    'guestCount': guestCount,
    'ageGroup': ageGroup,
    'audienceProfile':
        (item['audienceProfile'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[],
    'videoUrl': videoUrl,
    'docUrl': docUrl,
    'docKey': item['docKey'],
    'docName': docName,
    'docType': docType,
    'docSize': docSize,
    'status': effectiveStatus,
    'rawStatus': rawStatus,
    'isCompleted': isCompleted,
    'adminRejectionRemark': item['adminRejectionRemark'] as String?,
    'sponsorshipType': sponsorshipType,
    'hasCash': hasCash,
    'hasBarter': hasBarter,
    'sponsorTiers': sponsorTiers,
    'hostName': hostName,
    'hostProfileId': hostProfileId,
    'communityId': communityId,
  };
}

// The proposal tab shows the authenticated account's own proposals.
final dashboardProposalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final authState = ref.watch(authControllerProvider);
      final role = authState.role ?? AccountRole.community;
      final List<Map<String, dynamic>> myProposals = [];
      try {
        final response = await api.dio.get<dynamic>(
          '/sponsorships/me',
          queryParameters: {'actorType': role.backendAccountType},
        );
        if (response.statusCode == 200) {
          final responseData = response.data;
          List<dynamic> list = [];
          if (responseData is Map && responseData.containsKey('data')) {
            final inner = responseData['data'];
            if (inner is Map && inner.containsKey('proposals')) {
              list = inner['proposals'] ?? [];
            } else if (inner is List) {
              list = inner;
            }
          }
          for (final p in list.whereType<Map>()) {
            myProposals.add(_mapProposalItem(p));
          }
        }
      } catch (e) {
        debugPrint('Could not fetch /sponsorships/me: $e');
      }

      return myProposals;
    });

// Published proposals across all communities on Meetday (from /sponsorships/published)
// Used when viewing any particular community profile to show proposals created by THAT specific community.
final publishedProposalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final List<Map<String, dynamic>> publishedList = [];

      try {
        final response = await api.dio.get<dynamic>('/sponsorships/published');
        if (response.statusCode == 200) {
          final responseData = response.data;
          List<dynamic> list = [];
          if (responseData is Map && responseData.containsKey('data')) {
            final inner = responseData['data'];
            if (inner is Map && inner.containsKey('proposals')) {
              list = inner['proposals'] ?? [];
            } else if (inner is List) {
              list = inner;
            }
          }
          for (final p in list.whereType<Map>()) {
            publishedList.add(_mapProposalItem(p));
          }
        }
      } catch (e) {
        debugPrint('Error fetching /sponsorships/published: $e');
      }

      return publishedList;
    });

// Helper function to filter proposals created by a specific community
List<Map<String, dynamic>> getCommunityMatchingProposals(
  Map<String, dynamic> community,
  List<Map<String, dynamic>> proposals,
) {
  final cId = (community['id'] ?? '').toString();
  final cHostId = (community['hostProfileId'] ?? '').toString();
  final cName = (community['name'] ?? community['title'] ?? '')
      .toString()
      .toLowerCase()
      .trim();

  return proposals.where((p) {
    // 1. Match by community profile ID
    final pCommId = (p['communityId'] ?? '').toString();
    if (cId.isNotEmpty && pCommId.isNotEmpty && pCommId == cId) return true;

    // 2. Match by host profile ID
    final pHostId = (p['hostProfileId'] ?? '').toString();
    if (cHostId.isNotEmpty && pHostId.isNotEmpty && pHostId == cHostId)
      return true;
    if (cId.isNotEmpty && pHostId.isNotEmpty && pHostId == cId) return true;

    // 3. Match by host displayName / community name
    final pHostName = (p['hostName'] ?? p['displayName'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    if (cName.isNotEmpty && pHostName.isNotEmpty) {
      if (cName == pHostName) return true;
      if (cName.length >= 4 &&
          (pHostName.contains(cName) || cName.contains(pHostName)))
        return true;
    }

    return false;
  }).toList();
}

// Dashboard Hubs/Spaces (from /spaces/community/browse - authenticated endpoint)
final dashboardHubsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/spaces/community/browse');

    if (response.statusCode == 200 && response.data != null) {
      final responseData = response.data;
      List<dynamic> spaces = [];

      if (responseData is List) {
        spaces = responseData;
      } else if (responseData is Map) {
        if (responseData.containsKey('data')) {
          final innerData = responseData['data'];
          if (innerData is List) {
            spaces = innerData;
          } else if (innerData is Map && innerData.containsKey('spaces')) {
            final sp = innerData['spaces'];
            if (sp is List) spaces = sp;
          }
        } else if (responseData.containsKey('spaces')) {
          final sp = responseData['spaces'];
          if (sp is List) spaces = sp;
        }
      }

      if (spaces.isEmpty) return <Map<String, dynamic>>[];

      final result = spaces
          .whereType<Map>()
          .map((item) {
            final m = Map<String, dynamic>.from(item);
            final locations = (m['activeLocations'] as List?)?.map((e) => e.toString()).toList()
                ?? (m['operatingCities'] as List?)?.map((e) => e.toString()).toList()
                ?? <String>[];
            final capacity = m['venueCapacity'] ?? m['capacity'] ?? m['communitySize'] ?? m['memberCount'] ?? '0';
            return <String, dynamic>{
              'id': (m['id'] ?? '').toString(),
              'title': (m['name'] ?? m['businessName'] ?? m['spaceName'] ?? 'Untitled Hub').toString(),
              'businessName': (m['businessName'] ?? '').toString(),
              'memberCount': capacity.toString(),
              'venueCapacity': capacity.toString(),
              'numberOfVenues': (m['numberOfVenues'] ?? '1').toString(),
              'logoUrl': m['logoUrl'] ?? m['posterUrl'] as String?,
              'locations': locations,
              'operatingCities': locations,
              'about': (m['about'] ?? '').toString(),
              'raw': m,
            };
          })
          .toList();
      return result;
    }
    return <Map<String, dynamic>>[];
  } catch (e) {
    debugPrint('Error fetching hubs from /spaces/community/browse: $e');
    return <Map<String, dynamic>>[];
  }
});

final communityCollaborationCommunitiesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/community-collaboration/communities');
    dynamic payload = response.data;
    if (payload is Map && payload['data'] != null) payload = payload['data'];
    final rawCommunities = payload is Map ? payload['communities'] : payload;
    if (rawCommunities is! List) return <Map<String, dynamic>>[];
    return rawCommunities
        .whereType<Map>()
        .map((community) => Map<String, dynamic>.from(community))
        .toList();
  } catch (e) {
    debugPrint('Error fetching collaboration communities: $e');
    return <Map<String, dynamic>>[];
  }
});

// Dashboard Communities (from /sponsorships/communities - authenticated endpoint with real data)
final dashboardCommunitiesProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/sponsorships/communities');

    print('=== SPONSORSHIPS/COMMUNITIES RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Response type: ${response.data.runtimeType}');
    print('Response: ${response.data}');

    if (response.statusCode == 200) {
      // Response is { success: true, data: { communities: [...], total: number } }
      final responseData = response.data;
      List<dynamic> communities = [];

      if (responseData is Map && responseData.containsKey('data')) {
        final innerData = responseData['data'];
        print('Inner data type: ${innerData.runtimeType}');
        print('Inner data: $innerData');

        if (innerData is Map && innerData.containsKey('communities')) {
          communities = innerData['communities'] ?? [];
        }
      }

      print('Communities count: ${communities.length}');

      if (communities.isEmpty) return [];

      final result = communities
          .whereType<Map>()
          .map((item) {
            final name = (item['name'] ?? item['displayName'] ?? 'Community').toString();
            final memberCount = (item['memberCount'] ?? item['size'] ?? 0).toString();
            final logoUrl = item['logoUrl'] as String?;
            final secondaryImageUrl = item['secondaryImageUrl'] as String?;
            final about = (item['about'] ?? '').toString();
            final avgGuestCount = (item['avgGuestCount'] ?? '').toString();
            final experiencesPerYear = (item['experiencesPerYear'] ?? '').toString();
        final operatingCities =
            (item['operatingCities'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];

        final socialLinks = item['socialLinks'] is Map
            ? item['socialLinks'] as Map
            : null;

        final categories =
            (item['categories'] as List?)
                ?.whereType<Map>()
                .map(
                  (cat) => {
                    'id': (cat['id'] ?? '').toString(),
                    'name': (cat['name'] ?? '').toString(),
                  },
                )
                .toList() ??
            <Map<String, String>>[];

        final pastEvents =
            (item['pastEvents'] as List?)
                ?.whereType<Map>()
                .map(
                  (pe) => {
                    'name': (pe['name'] ?? '').toString(),
                    'description': (pe['description'] ?? '').toString(),
                    'imageUrls':
                        (pe['imageUrls'] as List?)
                            ?.map((u) => u.toString())
                            .toList() ??
                        <String>[],
                  },
                )
                .toList() ??
            <Map<String, dynamic>>[];

        final brandsWorkedWith =
            (item['brandsWorkedWith'] as List?)
                ?.whereType<Map>()
                .map(
                  (b) => {
                    'name': (b['brandName'] ?? b['name'] ?? '').toString(),
                    'logoUrl': (b['logoUrl'] ?? '').toString(),
                    'url': (b['url'] ?? '').toString(),
                  },
                )
                .toList() ??
            <Map<String, dynamic>>[];

        return <String, dynamic>{
          'id': (item['id'] ?? '').toString(),
          'hostProfileId': (item['hostProfileId'] ?? '').toString(),
          'title': name,
          'name': name,
          'memberCount': memberCount,
          'size': memberCount,
          'logoUrl': logoUrl,
          'imageUrl': logoUrl,
          'secondaryImageUrl': secondaryImageUrl,
          'about': about,
          'avgGuestCount': avgGuestCount,
          'experiencesPerYear': experiencesPerYear,
          'operatingCities': operatingCities,
          'socialLinks': socialLinks,
          'categories': categories,
          'pastEvents': pastEvents,
          'brandsWorkedWith': brandsWorkedWith,
        };
      }).toList();
      print('Final communities: $result');
      return result;
    }
    return [];
  } catch (e) {
    print('Error fetching communities: $e');
    return [];
  }
});

// Published Brand Campaigns (from /campaigns/published)
final dashboardCampaignsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/campaigns/published');
    if (response.statusCode == 200 && response.data != null) {
      final responseData = response.data;
      List<dynamic> list = [];
      if (responseData is List) {
        list = responseData;
      } else if (responseData is Map && responseData.containsKey('data')) {
        final inner = responseData['data'];
        if (inner is List) {
          list = inner;
        } else if (inner is Map && inner.containsKey('campaigns')) {
          list = inner['campaigns'] ?? [];
        }
      }
      return list.whereType<Map>().map((item) {
        final m = Map<String, dynamic>.from(item);
        final bp = m['brandProfile'] is Map ? Map<String, dynamic>.from(m['brandProfile'] as Map) : null;
        return <String, dynamic>{
          'id': (m['id'] ?? '').toString(),
          'name': (m['name'] ?? 'Brand Campaign').toString(),
          'goal': (m['goal'] ?? '').toString(),
          'locations': (m['locations'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
          'audience': (m['audience'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
          'startDate': (m['startDate'] ?? '').toString(),
          'endDate': (m['endDate'] ?? '').toString(),
          'offerType': (m['offerType'] ?? 'CASH').toString().toUpperCase(),
          'budgetAmount': m['budgetAmount'] ?? 0,
          'budgetCurrency': (m['budgetCurrency'] ?? '₹').toString(),
          'barterElements': m['barterElements'] as String?,
          'description': m['description'] as String?,
          'status': (m['status'] ?? 'PUBLISHED').toString(),
          'brandName': (bp?['brandName'] ?? 'Brand').toString(),
          'brandLogo': bp?['logoUrl'] as String?,
          'brandProfile': bp,
        };
      }).toList();
    }
    return [];
  } catch (e) {
    debugPrint('Error fetching /campaigns/published: $e');
    return [];
  }
});

/// Authenticated Brand's Own Campaigns (from /campaigns via getMyCampaigns())
final brandCampaignsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final list = await api.getMyCampaigns();
    return list.whereType<Map>().map((item) {
      final m = Map<String, dynamic>.from(item);
      final bp = m['brandProfile'] is Map ? Map<String, dynamic>.from(m['brandProfile'] as Map) : null;
      return <String, dynamic>{
        'id': (m['id'] ?? '').toString(),
        'name': (m['name'] ?? 'Campaign').toString(),
        'goal': (m['goal'] ?? '').toString(),
        'locations': (m['locations'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
        'audience': (m['audience'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
        'startDate': (m['startDate'] ?? '').toString(),
        'endDate': (m['endDate'] ?? '').toString(),
        'offerType': (m['offerType'] ?? 'CASH').toString().toUpperCase(),
        'budgetAmount': m['budgetAmount'] ?? 0,
        'budgetCurrency': (m['budgetCurrency'] ?? '₹').toString(),
        'barterElements': m['barterElements'] as String?,
        'description': m['description'] as String?,
        'status': (m['status'] ?? 'DRAFT').toString().toUpperCase(),
        'brandName': (bp?['brandName'] ?? 'My Brand').toString(),
        'brandLogo': bp?['logoUrl'] as String?,
        'brandProfile': bp,
      };
    }).toList();
  } catch (e) {
    debugPrint('Error fetching /campaigns: $e');
    return [];
  }
});

// Dashboard Deals/Locked Deals & Reports (authenticated real data)
final dashboardDealsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    // 1. Try brand billing if user is brand
    try {
      final brandRes = await api.dio.get<dynamic>('/sponsorships/billing');
      if (brandRes.statusCode == 200 && brandRes.data != null) {
        final raw = brandRes.data is Map ? (brandRes.data['data'] ?? brandRes.data) : null;
        if (raw is List && raw.isNotEmpty) {
          return raw.whereType<Map>().map((d) {
            final rawAmount = d['totalAmount'] ?? d['sponsorshipAmount'] ?? d['amount'] ?? d['payoutAmount'];
            final paymentStatus = (d['paymentStatus'] ?? d['status'] ?? '').toString().toUpperCase();
            return <String, dynamic>{
              'id': d['id']?.toString() ?? '',
              'brandName': d['brandName']?.toString() ?? d['communityName']?.toString() ?? 'Brand Sponsor',
              'brandLogo': d['brandLogo']?.toString() ?? d['counterpartAvatarUrl']?.toString(),
              'projectName': d['projectName']?.toString() ?? d['briefTitle']?.toString() ?? 'Sponsorship Deal',
              'amount': _formatAmount(rawAmount),
              'paid': paymentStatus == 'PAID' || paymentStatus == 'COMPLETED',
              'hasReport': d['hasReport'] == true || d['reportSubmitted'] == true,
              'sponsorshipInterestId': d['sponsorshipInterestId']?.toString() ?? d['id']?.toString() ?? '',
            };
          }).toList();
        }
      }
    } catch (_) {
      // Not brand or /sponsorships/billing 403, fall through to host/community chats
    }

    // 2. Fetch accepted sponsorship chats for host/community
    final chatRes = await api.dio.get<dynamic>(
      '/sponsorships/chats',
      queryParameters: {'status': 'ACCEPTED', 'role': 'HOST'},
    );
    final rawChats = chatRes.data is Map ? (chatRes.data['data'] ?? chatRes.data) : null;
    final List<dynamic> threads = rawChats is List ? rawChats : [];

    if (threads.isEmpty) return [];

    final dealsPromises = threads.whereType<Map>().map((thread) async {
      final interestId = thread['id']?.toString();
      if (interestId == null || interestId.isEmpty) return null;
      try {
        final dealRes = await api.dio.get<dynamic>('/sponsorships/chats/$interestId/deal');
        final dealData = dealRes.data is Map ? (dealRes.data['data'] ?? dealRes.data) : null;
        if (dealData is Map) {
          final status = (dealData['status'] ?? '').toString().toUpperCase();
          if (status == 'APPROVED' || status == 'LOCKED') {
            bool hasReport = false;
            try {
              final repRes = await api.dio.get<dynamic>('/sponsorships/chats/$interestId/deal/report');
              final repData = repRes.data is Map ? (repRes.data['data'] ?? repRes.data) : null;
              if (repData is Map && repData.isNotEmpty) {
                hasReport = true;
              }
            } catch (_) {}

            final rawAmount = dealData['sponsorshipAmount'] ?? dealData['totalAmount'] ?? 0;
            final paymentStatus = (dealData['paymentStatus'] ?? '').toString().toUpperCase();
            return <String, dynamic>{
              'id': dealData['id']?.toString() ?? interestId,
              'brandName': thread['counterpartName']?.toString() ?? 'Brand Sponsor',
              'brandLogo': thread['counterpartAvatarUrl']?.toString(),
              'projectName': dealData['projectName']?.toString() ?? thread['proposalName']?.toString() ?? 'Sponsorship Deal',
              'amount': _formatAmount(rawAmount),
              'paid': paymentStatus == 'PAID',
              'hasReport': hasReport,
              'sponsorshipInterestId': interestId,
            };
          }
        }
      } catch (_) {}
      return null;
    });

    final resolved = await Future.wait(dealsPromises);
    return resolved.whereType<Map<String, dynamic>>().toList();
  } catch (e) {
    debugPrint('Error fetching deals: $e');
    return [];
  }
});

// Support Conversations (from /sponsorships/chats - real sponsorship chats)
final supportConversationsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/sponsorships/chats');
    print('=== SPONSORSHIPS/CHATS RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Response: ${response.data}');

    if (response.statusCode == 200) {
      final responseData = response.data;
      List<dynamic> chats = [];

      if (responseData is Map && responseData.containsKey('data')) {
        chats = responseData['data'] ?? [];
      }

      print('Chats count: ${chats.length}');

      if (chats.isEmpty) return [];

      final result = chats
          .whereType<Map>()
          .map(
            (item) => {
              'id': item['id'] ?? '',
              'participantName':
                  item['counterpartName'] ??
                  item['participantName'] ??
                  'Support',
              'lastMessage':
                  item['lastMessage'] ?? item['lastMessageText'] ?? '',
              'lastMessageTime':
                  item['lastMessageTime'] ?? item['lastMessageAt'] ?? '',
              'unreadCount': item['unreadCount'] ?? 0,
            },
          )
          .toList();
      print('Final chats: $result');
      return result;
    }
    return [];
  } catch (e) {
    print('Error fetching support conversations: $e');
    return [];
  }
});

// All Conversations (from /sponsorships/chats - real sponsorship chats/conversations)
final allConversationsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/sponsorships/chats');
    if (response.statusCode == 200) {
      final responseData = response.data;
      List<dynamic> chats = [];

      if (responseData is Map && responseData.containsKey('data')) {
        chats = responseData['data'] ?? [];
      }

      if (chats.isEmpty) return [];

      return chats
          .whereType<Map>()
          .map(
            (item) => {
              'id': item['id'] ?? '',
              'participantName':
                  item['counterpartName'] ??
                  item['participantName'] ??
                  'Unknown',
              'lastMessage':
                  item['lastMessage'] ?? item['lastMessageText'] ?? '',
              'lastMessageTime':
                  item['lastMessageTime'] ?? item['lastMessageAt'] ?? '',
              'unreadCount': item['unreadCount'] ?? 0,
              'type': item['type'] ?? 'sponsorship',
            },
          )
          .toList();
    }
    return [];
  } catch (e) {
    print('Error fetching conversations: $e');
    return [];
  }
});

// Notifications (fetches real user notifications from /notifications)
final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getNotifications(limit: 50);
    final raw = response['notifications'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return <Map<String, dynamic>>[];
  } catch (e) {
    debugPrint('Error fetching notifications: $e');
    return <Map<String, dynamic>>[];
  }
});

// Unread notification count for top bar badge
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    return await api.getUnreadNotificationCount();
  } catch (_) {
    return 0;
  }
});

String _monthName(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}

// Helper function to format amounts
String _formatAmount(dynamic amount) {
  if (amount == null) return '₹0';
  try {
    final value = double.parse(amount.toString());
    if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(2)}K';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  } catch (e) {
    return '₹0';
  }
}
