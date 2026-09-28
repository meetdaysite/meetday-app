import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

final communityProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/profile');
    return response as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Failed to fetch profile: $e');
  }
});

final updateProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, Map<String, dynamic>>((ref, data) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.putRequest('/profile', data);
    ref.invalidate(communityProfileProvider);
    return response as Map<String, dynamic>;
  } catch (e) {
    throw Exception('Failed to update profile: $e');
  }
});

final uploadProfileImageProvider = FutureProvider.autoDispose.family<String, String>((ref, imagePath) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.uploadFile('/profile/image', imagePath);
    ref.invalidate(communityProfileProvider);
    return response['url'] as String;
  } catch (e) {
    throw Exception('Failed to upload profile image: $e');
  }
});
