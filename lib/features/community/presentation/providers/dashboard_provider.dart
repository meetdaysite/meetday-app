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
  final name = (item['name'] ?? item['title'] ?? item['briefTitle'] ?? 'Untitled Proposal').toString();
  final about = (item['about'] ?? '').toString();
  final imageUrl = item['imageUrl'] as String?;
  final eventDate = item['eventDate']?.toString();
  final eventEndDate = item['eventEndDate']?.toString();
  final dateLabel = _formatDateRange(eventDate, eventEndDate);

  final venues = (item['venues'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
  final venueCities = (item['venueCities'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
  final venue = item['venue']?.toString() ?? (venues.isNotEmpty ? venues.first : '');
  final city = item['city']?.toString() ?? (venueCities.isNotEmpty ? venueCities.first : '');

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

  final sponsorshipType = (item['sponsorshipType'] ?? 'CASH').toString().toUpperCase();
  final hasCash = sponsorshipType == 'CASH' || sponsorshipType == 'BOTH';
  final hasBarter = sponsorshipType == 'BARTER' || sponsorshipType == 'BOTH';

  final sponsorTiers = (item['sponsorTiers'] as List?)
          ?.whereType<Map>()
          .map((t) => {
                'name': (t['name'] ?? '').toString(),
                'price': (t['price'] ?? '').toString(),
              })
          .toList() ??
      <Map<String, dynamic>>[];

  final hostProfile = item['hostProfile'] is Map ? item['hostProfile'] as Map : null;
  final hostName = (hostProfile?['displayName'] ?? item['hostName'] ?? item['communityName'] ?? '').toString();
  final hostProfileId = (item['hostProfileId'] ?? hostProfile?['id'] ?? '').toString();
  final communityId = (item['communityId'] ?? hostProfile?['communityProfile']?['id'] ?? '').toString();

  return <String, dynamic>{
    'id': (item['id'] ?? '').toString(),
    'name': name,
    'title': name,
    'about': about,
    'imageUrl': imageUrl,
    'eventDate': eventDate,
    'eventEndDate': eventEndDate,
    'dateLabel': dateLabel,
    'venue': venue,
    'venues': venues,
    'city': city,
    'venueCities': venueCities,
    'guestCount': guestCount,
    'ageGroup': ageGroup,
    'audienceProfile': (item['audienceProfile'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
    'videoUrl': videoUrl,
    'docUrl': docUrl,
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

// Host's Own Proposals (fetches strictly from /sponsorships/me for host/community accounts)
// Brands discover all approved proposals from /sponsorships/published.
final dashboardProposalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final authState = ref.watch(authControllerProvider);
  final isBrand = authState.role == AccountRole.brand;

  if (isBrand) {
    // Brands discover all published proposals across communities
    try {
      final pubResponse = await api.dio.get<dynamic>('/sponsorships/published');
      if (pubResponse.statusCode == 200) {
        final pubData = pubResponse.data;
        List<dynamic> pubList = [];
        if (pubData is Map && pubData.containsKey('data')) {
          final inner = pubData['data'];
          if (inner is Map && inner.containsKey('proposals')) {
            pubList = inner['proposals'] ?? [];
          } else if (inner is List) {
            pubList = inner;
          }
        }
        return pubList.whereType<Map>().map(_mapProposalItem).toList();
      }
    } catch (e) {
      debugPrint('Error fetching brand published proposals: $e');
    }
    return [];
  }

  // Community Hosts: strictly fetch ONLY the host's own proposals from /sponsorships/me
  final List<Map<String, dynamic>> myProposals = [];
  try {
    final response = await api.dio.get<dynamic>('/sponsorships/me');
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
final publishedProposalsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
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
  final cName = (community['name'] ?? community['title'] ?? '').toString().toLowerCase().trim();

  return proposals.where((p) {
    // 1. Match by community profile ID
    final pCommId = (p['communityId'] ?? '').toString();
    if (cId.isNotEmpty && pCommId.isNotEmpty && pCommId == cId) return true;

    // 2. Match by host profile ID
    final pHostId = (p['hostProfileId'] ?? '').toString();
    if (cHostId.isNotEmpty && pHostId.isNotEmpty && pHostId == cHostId) return true;
    if (cId.isNotEmpty && pHostId.isNotEmpty && pHostId == cId) return true;

    // 3. Match by host displayName / community name
    final pHostName = (p['hostName'] ?? p['displayName'] ?? '').toString().toLowerCase().trim();
    if (cName.isNotEmpty && pHostName.isNotEmpty) {
      if (cName == pHostName) return true;
      if (cName.length >= 4 && (pHostName.contains(cName) || cName.contains(pHostName))) return true;
    }

    return false;
  }).toList();
}

// Dashboard Hubs/Spaces (from /spaces/community/browse - authenticated endpoint)
final dashboardHubsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/spaces/community/browse');
    print('=== SPACES/COMMUNITY/BROWSE RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Response: ${response.data}');

    if (response.statusCode == 200) {
      // Response is { success: true, data: { spaces: [...], total: number } }
      final responseData = response.data;
      List<dynamic> spaces = [];

      if (responseData is Map && responseData.containsKey('data')) {
        final innerData = responseData['data'];
        print('Inner data type: ${innerData.runtimeType}');
        if (innerData is Map && innerData.containsKey('spaces')) {
          spaces = innerData['spaces'] ?? [];
        }
      }

      print('Spaces/Hubs count: ${spaces.length}');

      if (spaces.isEmpty) return [];

      final result = spaces
          .whereType<Map>()
          .map((item) => {
                'id': item['id'] ?? '',
                'title': item['name'] ?? item['spaceName'] ?? 'Untitled Space',
                'memberCount': (item['capacity'] ?? item['memberCount'] ?? 0).toString(),
              })
          .toList();
      print('Final hubs: $result');
      return result;
    }
    return [];
  } catch (e) {
    print('Error fetching hubs: $e');
    return [];
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

            final operatingCities = (item['operatingCities'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];

            final socialLinks = item['socialLinks'] is Map ? item['socialLinks'] as Map : null;

            final categories = (item['categories'] as List?)
                    ?.whereType<Map>()
                    .map((cat) => {
                          'id': (cat['id'] ?? '').toString(),
                          'name': (cat['name'] ?? '').toString(),
                        })
                    .toList() ??
                <Map<String, String>>[];

            final pastEvents = (item['pastEvents'] as List?)
                    ?.whereType<Map>()
                    .map((pe) => {
                          'name': (pe['name'] ?? '').toString(),
                          'description': (pe['description'] ?? '').toString(),
                          'imageUrls': (pe['imageUrls'] as List?)
                                  ?.map((u) => u.toString())
                                  .toList() ??
                              <String>[],
                        })
                    .toList() ??
                <Map<String, dynamic>>[];

            final brandsWorkedWith = (item['brandsWorkedWith'] as List?)
                    ?.whereType<Map>()
                    .map((b) => {
                          'name': (b['brandName'] ?? b['name'] ?? '').toString(),
                          'logoUrl': (b['logoUrl'] ?? '').toString(),
                          'url': (b['url'] ?? '').toString(),
                        })
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
          })
          .toList();
      print('Final communities: $result');
      return result;
    }
    return [];
  } catch (e) {
    print('Error fetching communities: $e');
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
          .map((item) => {
                'id': item['id'] ?? '',
                'participantName': item['counterpartName'] ?? item['participantName'] ?? 'Support',
                'lastMessage': item['lastMessage'] ?? item['lastMessageText'] ?? '',
                'lastMessageTime': item['lastMessageTime'] ?? item['lastMessageAt'] ?? '',
                'unreadCount': item['unreadCount'] ?? 0,
              })
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
          .map((item) => {
                'id': item['id'] ?? '',
                'participantName': item['counterpartName'] ?? item['participantName'] ?? 'Unknown',
                'lastMessage': item['lastMessage'] ?? item['lastMessageText'] ?? '',
                'lastMessageTime': item['lastMessageTime'] ?? item['lastMessageAt'] ?? '',
                'unreadCount': item['unreadCount'] ?? 0,
                'type': item['type'] ?? 'sponsorship',
              })
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
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
