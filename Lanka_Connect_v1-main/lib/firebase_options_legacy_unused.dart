// Legacy generated Firebase config kept only as a historical fallback.
// Do not import this file. Use firebase_options_selector.dart instead.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class LegacyUnusedFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'LegacyUnusedFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'LegacyUnusedFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'LegacyUnusedFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'LegacyUnusedFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDINe-eLTdgg2L8B0g59rE9rMrkq-O41us',
    appId: '1:262402675622:web:b24c551fdf3a98dd67b567',
    messagingSenderId: '262402675622',
    projectId: 'lankaconnect-app',
    authDomain: 'lankaconnect-app.firebaseapp.com',
    storageBucket: 'lankaconnect-app.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBcinz104MNv8RjdZQX32w5acmreKhJ5Qw',
    appId: '1:262402675622:android:543534587e6f734467b567',
    messagingSenderId: '262402675622',
    projectId: 'lankaconnect-app',
    storageBucket: 'lankaconnect-app.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDjDrm_kbvjmpZdvOO0U2wWN9AAWqFrfRU',
    appId: '1:262402675622:ios:58958d1ce12a6fb367b567',
    messagingSenderId: '262402675622',
    projectId: 'lankaconnect-app',
    storageBucket: 'lankaconnect-app.firebasestorage.app',
    iosClientId: '262402675622-54uj3qjcbs22580nscvvmo89d3737pqb.apps.googleusercontent.com',
    iosBundleId: 'com.example.lankaConnect',
  );

}
