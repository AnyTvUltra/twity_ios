import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// إعدادات Firebase للمشروع المربوط
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBZ1GzN3LUvWxmSf1ZRVC9wDstNNzgJpmw',
    appId: '1:882641594444:web:177374244ae0d874886ce9',
    messagingSenderId: '882641594444',
    projectId: 'game-651a3',
    authDomain: 'game-651a3.firebaseapp.com',
    storageBucket: 'game-651a3.firebasestorage.app',
    measurementId: 'G-BJ3SDN2NBK',
  );
}
