import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  factory FCMService() {
    return _instance;
  }

  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late FlutterLocalNotificationsPlugin _localNotifications;

  // Getters
  Stream<NotificationPayload> get notificationStream => _notificationStreamController.stream;

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
      // TODO: Send this token to the backend to save for this user
      // This is needed so the backend can send push notifications to this device
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }

    // Listen for token refresh (when the token is regenerated)
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      // TODO: Update the token on the backend
    });
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
    // Extract notification type and route accordingly
    final notificationType = data['type'] ?? 'unknown';

    debugPrint('Navigating to: $notificationType with data: $data');

    // TODO: Implement navigation based on notification type
    // Example:
    // if (notificationType == 'chat') {
    //   final threadId = data['threadId'];
    //   appRouter.go('/chat/$threadId');
    // } else if (notificationType == 'deal') {
    //   final interestId = data['interestId'];
    //   appRouter.go('/deals/$interestId');
    // }
  }

  /// Encode payload for local notification
  static String _encodePayload(Map<String, dynamic> data) {
    return Uri.encodeComponent(data.toString());
  }

  /// Decode payload from local notification
  static Map<String, dynamic> _decodePayload(String payload) {
    try {
      Uri.decodeComponent(payload);
      // Parse the map string - this is a simplified version
      // TODO: Implement proper payload decoding
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
