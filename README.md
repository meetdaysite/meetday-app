# Meetday App

Flutter mobile client for the Meetday Brand, Community, and Space portals.

## Run locally

The app defaults to the deployed Meetday backend at
`https://meetday-backend-371293689986.asia-south1.run.app/api/v1`.

```bash
flutter pub get
flutter run
```

For local backend development on an Android emulator, point at the host machine with `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For staging or production, provide both `APP_ENV` and `API_BASE_URL` at build/run time. Firebase platform configuration files are required before using real login on a device.

## Firebase

The Flutter app uses the same `meetday-dev` Firebase project as the web frontend. Android, iOS, and web apps are registered in that Firebase project. The generated Android and iOS registration files are included in the project.

```bash
flutterfire configure --project=meetday-dev --platforms=android,ios,web
```

This regenerates `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist` if the Firebase project configuration changes.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
