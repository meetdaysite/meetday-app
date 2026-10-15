import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../network/api_client.dart';

/// Global notification stream controller for foreground notifications
final _notificationStreamController = StreamController<NotificationPayload>.broadcast();

class NotificationPayload {
  const NotificationPayload({
    required this.title,
    required this.body,
    required this.data,
    this.imageUrl,
  });

  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String? imageUrl;
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  static GoRouter? _router;

  factory FCMService() {
    return _instance;
  }

  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Getters
  Stream<NotificationPayload> get notificationStream => _notificationStreamController.stream;

  /// Set router for navigation (call after app initialization)
  static void setRouter(GoRouter router) {
    _router = router;
  }

  Future<void> initialize() async {
    _localNotifications = FlutterLocalNotificationsPlugin();

    // Request notification permissions
    await _requestNotificationPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message (when app is terminated)
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // Handle notification tap when app is in background or terminated
    FirebaseMessaging.instance.getInitialMessage().then(_handleNotificationTap);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Get and log FCM token
    await _refreshFCMToken();
  }

  /// Request notification permissions from user
  Future<void> _requestNotificationPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permissions');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional notification permissions');
    } else {
      debugPrint('User declined or has not yet granted notification permissions');
    }
  }

  /// Initialize flutter_local_notifications for displaying lock screen notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: _handleLocalNotificationTap,
    );
  }

  /// Get FCM token and refresh it if needed
  Future<void> _refreshFCMToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Listen for token refresh (when the token is regenerated)
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _sendTokenToBackend(newToken);
    });
  }

  /// Send FCM token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiClient.instance.dio.post<dynamic>(
        '/users/fcm-token',
        data: {'fcmToken': token},
      );
      debugPrint('FCM token sent to backend');
    } catch (e) {
      debugPrint('Error sending FCM token to backend: $e');
    }
  }

  /// Handle messages received when app is in foreground
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.notification?.title}');

    // Show local notification (this will display as a banner and lock screen notification)
    await _showLocalNotification(
      message.notification?.title ?? 'Meetday',
      message.notification?.body ?? '',
      message.data,
      message.notification?.android?.imageUrl ??
          message.notification?.apple?.imageUrl,
    );

    // Also emit to stream for in-app UI banners
    _notificationStreamController.add(
      NotificationPayload(
        title: message.notification?.title ?? 'Meetday',
        body: message.notification?.body ?? '',
        data: message.data,
        imageUrl: message.notification?.android?.imageUrl ??
            message.notification?.apple?.imageUrl,
      ),
    );
  }

  /// Show local notification (displays on lock screen and notification center)
  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
    String? imageUrl,
  ) async {
    const androidDetails = AndroidNotificationDetails(
      'meetday_notifications',
      'Meetday Notifications',
      channelDescription: 'Notifications from Meetday',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: _encodePayload(data),
    );
  }

  /// Handle notification tap from local notification
  static void _handleLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final data = _decodePayload(response.payload!);
      _handleNotificationNavigation(data);
    }
  }

  /// Handle notification tap when app is in background/terminated
  static Future<void> _handleNotificationTap(RemoteMessage? message) async {
    if (message != null) {
      debugPrint('Notification tap: ${message.notification?.title}');
      _handleNotificationNavigation(message.data);
    }
  }

  /// Navigate based on notification data
  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    if (_router == null) {
      debugPrint('Router not initialized for notification navigation');
      return;
    }

    final notificationType = data['type'] ?? '';
    final threadId = data['threadId'];
    final interestId = data['interestId'];

    debugPrint('Navigating to: $notificationType with data: $data');

    switch (notificationType) {
      // Chat notifications
      case 'chat':
      case 'sponsorship_chat':
      case 'space_chat':
      case 'community_chat':
      case 'brand_community_chat':
        if (threadId != null) {
          _router!.push('/chat/$threadId');
          debugPrint('Navigated to chat: $threadId');
        }
        break;

      // Deal notifications
      case 'deal':
      case 'sponsorship_deal':
      case 'space_deal':
        if (interestId != null) {
          _router!.push('/deals/$interestId');
          debugPrint('Navigated to deal: $interestId');
        }
        break;

      // Proposal notifications
      case 'proposal':
      case 'sponsorship_proposal':
        if (interestId != null) {
          _router!.push('/proposals/$interestId');
          debugPrint('Navigated to proposal: $interestId');
        }
        break;

      // Support chat
      case 'support':
        _router!.push('/support');
        debugPrint('Navigated to support');
        break;

      // Campaign notifications
      case 'campaign':
        if (data['campaignId'] != null) {
          _router!.push('/campaigns/${data['campaignId']}');
          debugPrint('Navigated to campaign');
        }
        break;

      default:
        debugPrint('Unknown notification type: $notificationType');
    }
  }

  /// Encode payload for local notification
  static String _encodePayload(Map<String, dynamic> data) {
    // Pass as JSON string via payload
    return Uri.encodeComponent(data.toString());
  }

  /// Decode payload from local notification
  static Map<String, dynamic> _decodePayload(String payload) {
    try {
      Uri.decodeComponent(payload);
      // Data comes from RemoteMessage.data directly
      // This is a fallback - most navigation data comes from FCM payload
      return {};
    } catch (e) {
      debugPrint('Error decoding payload: $e');
      return {};
    }
  }

  Future<void> dispose() async {
    await _notificationStreamController.close();
  }
}

/// Background message handler (must be a top-level function)
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
  // Handle the message - typically just log it or store it
  // The notification will be handled by FCM automatically when app is killed
}
