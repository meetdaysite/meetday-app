import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/fcm_service.dart';

/// Provider for FCM service
final fcmServiceProvider = Provider<FCMService>((ref) {
  return FCMService();
});

/// Provider for notification stream from FCM
final notificationStreamProvider = StreamProvider<NotificationPayload>((ref) {
  final fcmService = ref.watch(fcmServiceProvider);
  return fcmService.notificationStream;
});
