import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// إعدادات Firebase للمشروع المربوط
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDpjvk1w1MvT7iy9Pgsh7-9QEoHWiLAD9k',
    appId: '1:562034251468:web:5b9f55755906bc9152d469',
    messagingSenderId: '562034251468',
    projectId: 'game-hub-a674f',
    authDomain: 'game-hub-a674f.firebaseapp.com',
    storageBucket: 'game-hub-a674f.firebasestorage.app',
    measurementId: 'G-S5YL3W6L92',
  );
}
