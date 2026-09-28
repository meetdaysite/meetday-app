import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

final analyticsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/analytics');
    return response as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Failed to fetch analytics: $e');
  }
});

final revenueBreakdownProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/analytics/revenue');
    return response as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Failed to fetch revenue breakdown: $e');
  }
});

final engagementMetricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/analytics/engagement');
    return response as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Failed to fetch engagement metrics: $e');
  }
});

final attendanceTrendProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, period) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/analytics/attendance?period=$period');
    return (response as List).cast<Map<String, dynamic>>();
  } catch (e) {
    throw Exception('Failed to fetch attendance trend: $e');
  }
});

final exportAnalyticsProvider = FutureProvider.autoDispose<String>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.postRequest('/analytics/export', {});
    return response['url'] as String;
  } catch (e) {
    throw Exception('Failed to export analytics: $e');
  }
});
