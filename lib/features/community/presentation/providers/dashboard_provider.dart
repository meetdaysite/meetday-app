import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

dynamic _unwrapData(dynamic response) {
  if (response is Map) {
    // Check for success/data envelope
    if (response.containsKey('data')) {
      return response['data'];
    }
    // Check for direct array response
    if (response is List) {
      return response;
    }
  }
  return response;
}

dynamic _safeList(dynamic data) {
  if (data is List) return data;

  // Handle nested data envelopes: { data: { data: [...] } }
  if (data is Map && data.containsKey('data')) {
    var inner = data['data'];

    // If inner is a list, return it
    if (inner is List) return inner;

    // If inner is a map with another 'data' key, unwrap again
    if (inner is Map && inner.containsKey('data') && inner['data'] is List) {
      return inner['data'];
    }
  }
  return [];
}

// Dashboard Proposals (from campaigns endpoint)
final dashboardProposalsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/campaigns?limit=10');
    if (response.statusCode == 200) {
      final data = _safeList(response.data);
      return data
          .whereType<Map>()
          .map((item) => {
                'id': item['id'] ?? '',
                'title': item['title'] ?? item['brandName'] ?? 'Untitled',
                'dateLabel': _formatDate(item['deadline']),
                'hasCash': (item['budget'] ?? 0) > 0,
                'hasBarter': item['category'] != null,
              })
          .toList();
    }
    return [];
  } catch (e) {
    print('Error fetching proposals: $e');
    return [];
  }
});

// Dashboard Hubs/Spaces
final dashboardHubsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/spaces?limit=10');
    if (response.statusCode == 200) {
      final data = _safeList(response.data);
      if (data.isEmpty) return [];

      return (data as List)
          .whereType<Map>()
          .map((item) => {
                'id': item['id'] ?? '',
                'title': item['name'] ?? 'Untitled Space',
                'memberCount': (item['capacity'] ?? 0).toString(),
              })
          .toList();
    }
    return [];
  } catch (e) {
    print('Error fetching hubs: $e');
    return [];
  }
});

// Dashboard Communities
final dashboardCommunitiesProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/communities');

    if (response.statusCode == 200) {
      // Response is { success: true, data: { data: [...], total: number, page: 1, limit: 20 } }
      final data = _safeList(response.data);
      if (data.isEmpty) return [];

      return (data as List)
          .whereType<Map>()
          .map((item) => {
                'id': item['id'] ?? '',
                'title': item['name'] ?? item['displayName'] ?? 'Community',
                'memberCount': (item['memberCount'] ?? 0).toString(),
              })
          .toList();
    }
    return [];
  } catch (e) {
    print('Error fetching communities: $e');
    return [];
  }
});

// Dashboard Deals/Locked Deals (using payouts endpoint)
final dashboardDealsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/payouts?limit=10');
    if (response.statusCode == 200) {
      final data = _safeList(response.data);
      if (data.isEmpty) return [];

      return (data as List)
          .whereType<Map>()
          .map((item) => {
                'id': item['id'] ?? '',
                'brandName': item['dealName']?.split(' - ')[0] ?? 'Unknown Brand',
                'projectName': item['dealName'] ?? 'Project',
                'amount': _formatAmount(item['amount']),
                'paid': item['status'] == 'completed',
              })
          .toList();
    }
    return [];
  } catch (e) {
    print('Error fetching deals: $e');
    return [];
  }
});

// Support Conversations
final supportConversationsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/conversations?type=support&limit=50');
    if (response.statusCode == 200) {
      final data = _safeList(response.data);
      if (data.isEmpty) return [];

      return (data as List)
          .whereType<Map>()
          .where((item) => item['type'] == 'support')
          .map((item) => {
                'id': item['id'] ?? '',
                'participantName': item['participantName'] ?? 'Support',
                'lastMessage': item['lastMessage'] ?? '',
                'lastMessageTime': item['lastMessageTime'] ?? '',
                'unreadCount': item['unreadCount'] ?? 0,
              })
          .toList();
    }
    return [];
  } catch (e) {
    print('Error fetching support conversations: $e');
    return [];
  }
});

// All Conversations (for messaging)
final allConversationsProvider = FutureProvider.autoDispose((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.dio.get<dynamic>('/conversations?limit=50');
    if (response.statusCode == 200) {
      final data = _safeList(response.data);
      if (data.isEmpty) return [];

      return (data as List)
          .whereType<Map>()
          .map((item) => {
                'id': item['id'] ?? '',
                'participantName': item['participantName'] ?? 'Unknown',
                'lastMessage': item['lastMessage'] ?? '',
                'lastMessageTime': item['lastMessageTime'] ?? '',
                'unreadCount': item['unreadCount'] ?? 0,
                'type': item['type'] ?? 'brand',
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

// Helper function to format dates
String _formatDate(dynamic date) {
  if (date == null) return 'TBD';
  try {
    final parsed = DateTime.parse(date.toString());
    final now = DateTime.now();
    final diff = parsed.difference(now);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Tomorrow';
    } else if (diff.inDays < 7) {
      return 'In ${diff.inDays} days';
    } else {
      return '${parsed.day} ${_monthName(parsed.month)}';
    }
  } catch (e) {
    return 'Soon';
  }
}

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
