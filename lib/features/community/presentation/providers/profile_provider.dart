import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

/// Fetches the authenticated host's own profile (the Community Representative profile: /hosts/me)
final hostProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    return await api.getHostProfile();
  } catch (e) {
    // If hosts/me fails or is empty, return empty map so UI can gracefully display placeholders
    return <String, dynamic>{};
  }
});

/// Fetches the host's community profile (the Community itself: /hosts/community)
final communityProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    return await api.getHostCommunityProfile();
  } catch (e) {
    return <String, dynamic>{};
  }
});

/// Fetches the team members of the host's community (/hosts/community/members)
final teamMembersProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    return await api.getHostTeamMembers();
  } catch (e) {
    return <String, dynamic>{
      'members': <dynamic>[],
      'viewerCanManage': false,
      'viewerIsOwner': false,
    };
  }
});

/// Mutation to update the host profile
final updateHostProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, Map<String, dynamic>>((ref, data) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.updateHostProfile(data);
  ref.invalidate(hostProfileProvider);
  return response;
});
