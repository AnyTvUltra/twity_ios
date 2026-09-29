import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// إعدادات Firebase للمشروع المربوط
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
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

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAol0j4IqOu_FoAETnEoyfBJZ-yipjNsLc',
    appId: '1:882641594444:ios:8775d9c0e0d5f7e0886ce9',
    messagingSenderId: '882641594444',
    projectId: 'game-651a3',
    storageBucket: 'game-651a3.firebasestorage.app',
    iosBundleId: 'com.yallayari.game',
  );
}
