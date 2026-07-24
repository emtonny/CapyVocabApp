// File cấu hình Firebase Options mặc định cho Capy Vocab App
// Sinh bởi FlutterFire CLI (mock options template để dự án sẵn sàng kết nối Firebase real API)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCapyVocabWebApiKeyMock123456789',
    appId: '1:123456789000:web:capyvocab123456',
    messagingSenderId: '123456789000',
    projectId: 'capy-vocab-app',
    authDomain: 'capy-vocab-app.firebaseapp.com',
    storageBucket: 'capy-vocab-app.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCapyVocabAndroidApiKeyMock12345',
    appId: '1:123456789000:android:capyvocab123456',
    messagingSenderId: '123456789000',
    projectId: 'capy-vocab-app',
    storageBucket: 'capy-vocab-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCapyVocabIosApiKeyMock1234567',
    appId: '1:123456789000:ios:capyvocab123456',
    messagingSenderId: '123456789000',
    projectId: 'capy-vocab-app',
    storageBucket: 'capy-vocab-app.appspot.com',
    iosBundleId: 'com.capyvocab.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCapyVocabMacosApiKeyMock1234567',
    appId: '1:123456789000:ios:capyvocab123456',
    messagingSenderId: '123456789000',
    projectId: 'capy-vocab-app',
    storageBucket: 'capy-vocab-app.appspot.com',
    iosBundleId: 'com.capyvocab.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCapyVocabWindowsApiKeyMock12345',
    appId: '1:123456789000:web:capyvocab123456',
    messagingSenderId: '123456789000',
    projectId: 'capy-vocab-app',
    authDomain: 'capy-vocab-app.firebaseapp.com',
    storageBucket: 'capy-vocab-app.appspot.com',
  );
}
