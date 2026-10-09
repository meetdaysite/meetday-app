import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, staging, prod }

const _androidGooglePlacesApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY_ANDROID',
  defaultValue: 'AIzaSyDziwuIRL1u6KMuckQI5kcRBira2M6qK08',
);
const _iosGooglePlacesApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_API_KEY_IOS',
  defaultValue: 'AIzaSyDziwuIRL1u6KMuckQI5kcRBira2M6qK08',
);

String get googleMapsApiKey => switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidGooglePlacesApiKey,
      TargetPlatform.iOS => _iosGooglePlacesApiKey,
      _ => 'AIzaSyDziwuIRL1u6KMuckQI5kcRBira2M6qK08',
    };

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.baseUrl,
    required this.socketUrl,
    required this.useDebugLogs,
  });

  final AppEnvironment environment;
  final String baseUrl;
  final String socketUrl;
  final bool useDebugLogs;

  String get name => environment.name;

  factory AppConfig.fromEnvironment() {
    const envName = String.fromEnvironment('APP_ENV', defaultValue: 'prod');
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue:
          'https://meetday-backend-371293689986.asia-south1.run.app/api/v1',
    );
    const socketUrl = String.fromEnvironment(
      'SOCKET_BASE_URL',
      defaultValue: 'https://meetday-backend-371293689986.asia-south1.run.app',
    );

    final environment = switch (envName) {
      'prod' => AppEnvironment.prod,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.dev,
    };

    return AppConfig(
      environment: environment,
      baseUrl: baseUrl,
      socketUrl: socketUrl,
      useDebugLogs: environment != AppEnvironment.prod,
    );
  }
}
