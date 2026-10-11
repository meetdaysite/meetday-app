import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/event_model.dart';
import '../../../../core/network/api_client.dart';

final communityOwnedEventsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, page) async {
  final response = await ref.watch(apiClientProvider).dio.get<dynamic>('/events/me',
    queryParameters: {'page': page, 'limit': 20});
  final body = response.data is Map ? response.data['data'] ?? response.data : null;
  if (body is! Map) throw const FormatException('Invalid event list response.');
  return Map<String, dynamic>.from(body);
});

final communityOwnedEventProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, id) async {
  final response = await ref.watch(apiClientProvider).getRequest('/events/me/${Uri.encodeComponent(id)}');
  if (response is! Map) throw const FormatException('Invalid event detail response.');
  return Map<String, dynamic>.from(response);
});

final communityEventAttendeesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (String, int)>((ref, query) async {
  final response = await ref.watch(apiClientProvider).dio.get<dynamic>(
    '/events/me/${Uri.encodeComponent(query.$1)}/attendees', queryParameters: {'page': query.$2, 'limit': 50});
  final body = response.data is Map ? response.data['data'] ?? response.data : null;
  if (body is! Map) throw const FormatException('Invalid attendee response.');
  return Map<String, dynamic>.from(body);
});

final eventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/events');
    return (response as List).map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Failed to fetch events: $e');
  }
});

final eventDetailsProvider = FutureProvider.autoDispose.family<Event, String>((ref, eventId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/events/$eventId');
    return Event.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Failed to fetch event details: $e');
  }
});

final eventAttendeesProvider = FutureProvider.autoDispose.family<List<Attendee>, String>((ref, eventId) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/events/$eventId/attendees');
    return (response as List).map((e) => Attendee.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    throw Exception('Failed to fetch attendees: $e');
  }
});

final eventStatsProvider = FutureProvider.autoDispose<EventStats>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.getRequest('/events/stats');
    return EventStats.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Failed to fetch event stats: $e');
  }
});

final createEventProvider = FutureProvider.autoDispose.family<Event, Map<String, dynamic>>((ref, data) async {
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.postRequest('/events', data);
    ref.invalidate(eventsProvider);
    return Event.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Failed to create event: $e');
  }
});

final updateEventProvider = FutureProvider.autoDispose.family<Event, (String, Map<String, dynamic>)>((ref, args) async {
  final (eventId, data) = args;
  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.putRequest('/events/$eventId', data);
    ref.invalidate(eventsProvider);
    ref.invalidate(eventDetailsProvider(eventId));
    return Event.fromJson(response as Map<String, dynamic>);
  } catch (e) {
    throw Exception('Failed to update event: $e');
  }
});
