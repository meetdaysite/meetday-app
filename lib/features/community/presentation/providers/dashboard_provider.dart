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

      final result = (spaces as List)
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

      final result = (communities as List)
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

// Dashboard Deals/Locked Deals (from /sponsorships/billing - authenticated endpoint)
final dashboardDealsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/sponsorships/billing');
    print('=== SPONSORSHIPS/BILLING RESPONSE ===');
    print('Status: ${response.statusCode}');
    print('Response: ${response.data}');

    if (response.statusCode == 200) {
      // Response is { success: true, data: [...] }
      final responseData = response.data;
      List<dynamic> deals = [];

      if (responseData is Map && responseData.containsKey('data')) {
        final innerData = responseData['data'];
        print('Inner data type: ${innerData.runtimeType}');
        if (innerData is List) {
          deals = innerData;
        }
      }

      print('Deals count: ${deals.length}');

      if (deals.isEmpty) return [];

      final result = (deals as List)
          .whereType<Map>()
          .map((item) => {
                'id': item['id'] ?? '',
                'brandName': item['brandName'] ?? item['communityName'] ?? 'Unknown',
                'projectName': item['projectName'] ?? item['briefTitle'] ?? 'Project',
                'amount': _formatAmount(item['amount'] ?? item['payoutAmount']),
                'paid': item['status'] == 'completed' || item['paymentStatus'] == 'paid',
              })
          .toList();
      print('Final deals: $result');
      return result;
    }
    return [];
  } catch (e) {
    print('Error fetching deals: $e');
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

      final result = (chats as List)
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

      return (chats as List)
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

// Notifications (can use analytics or create a dedicated endpoint)
final notificationsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/analytics');
    if (response.statusCode == 200) {
      return [
        {
          'id': '1',
          'title': 'New sponsorship proposal received',
          'description': 'Aster Labs posted a new sponsorship brief',
          'type': 'proposal',
          'timestamp': DateTime.now().toIso8601String(),
          'read': false,
        },
        {
          'id': '2',
          'title': 'Event reminder',
          'description': 'The Block Party starts in 2 days',
          'type': 'event',
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'read': false,
        },
        {
          'id': '3',
          'title': 'New member joined',
          'description': '5 new members joined your community',
          'type': 'member',
          'timestamp': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
          'read': true,
        },
      ];
    }
    return [];
  } catch (e) {
    print('Error fetching notifications: $e');
    return [];
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
