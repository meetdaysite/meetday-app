// Generated for the Meetday Firebase project: meetday-dev.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Firebase is not configured for this platform.',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDus0szV6X9E1QlS4qCr3eceDRcgaaEo8',
    appId: '1:371293689986:android:568bac6292fae3bf36bc9b',
    messagingSenderId: '371293689986',
    projectId: 'meetday-dev',
    storageBucket: 'meetday-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBhrTh0Tbnr__XYRWlRcOuu2oOhTnrKP_4',
    appId: '1:371293689986:ios:48bac044eb9b330b36bc9b',
    messagingSenderId: '371293689986',
    projectId: 'meetday-dev',
    storageBucket: 'meetday-dev.firebasestorage.app',
    iosBundleId: 'com.meetday.app.meetdayApp',
    iosClientId:
        '371293689986-o2amnb5kq7u8t0p6on88u25lm9smg9t9.apps.googleusercontent.com',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCPu05LYns29JbRjlWZB3SoniyV3V71e1s',
    appId: '1:371293689986:web:5698e58b60ecd8ee36bc9b',
    messagingSenderId: '371293689986',
    projectId: 'meetday-dev',
    authDomain: 'meetday-dev.firebaseapp.com',
    storageBucket: 'meetday-dev.firebasestorage.app',
  );
}
