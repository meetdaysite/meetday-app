import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/campaign_model.dart';
import '../../../../core/network/api_client.dart';

final campaignsProvider = FutureProvider.autoDispose<List<Campaign>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/campaigns');
    return (response as List).map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Failed to fetch campaigns: $e');
  }
});

final spacesProvider = FutureProvider.autoDispose<List<Space>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/spaces');
    return (response as List).map((e) => Space.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Failed to fetch spaces: $e');
  }
});

final payoutsProvider = FutureProvider.autoDispose<List<Payout>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/payouts');
    return (response as List).map((e) => Payout.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Failed to fetch payouts: $e');
  }
});

final conversationsProvider = FutureProvider.autoDispose<List<Conversation>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/conversations');
    return (response as List).map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Failed to fetch conversations: $e');
  }
});

final applyCampaignProvider = FutureProvider.autoDispose.family<Campaign, String>((ref, campaignId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.postRequest('/campaigns/$campaignId/apply', {});
    ref.invalidate(campaignsProvider);
    return Campaign.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Failed to apply for campaign: $e');
  }
});

final createSpaceProvider = FutureProvider.autoDispose.family<Space, Map<String, dynamic>>((ref, data) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.postRequest('/spaces', data);
    ref.invalidate(spacesProvider);
    return Space.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Failed to create space: $e');
  }
});

final requestWithdrawalProvider = FutureProvider.autoDispose.family<Payout, double>((ref, amount) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.postRequest('/payouts/withdraw', {'amount': amount});
    ref.invalidate(payoutsProvider);
    return Payout.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Failed to request withdrawal: $e');
  }
});
