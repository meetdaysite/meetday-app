import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/environment.dart';
import 'core/services/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/fcm_notification_banner.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase options are supplied per platform during app integration.
  }

  // Initialize FCM for push notifications
  try {
    await FCMService().initialize();
  } catch (e) {
    debugPrint('Error initializing FCM: $e');
  }

  final appConfig = AppConfig.fromEnvironment();

  runApp(ProviderScope(child: MeetdayApp(config: appConfig)));
}

class MeetdayApp extends ConsumerWidget {
  const MeetdayApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Set router for FCM notification navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FCMService.setRouter(router);
    });

    return MaterialApp.router(
      title: 'Meetday',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const FCMNotificationBanner(),
          ],
        );
      },
    );
  }
}
