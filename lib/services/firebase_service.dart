import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool isInitialized = false;
  FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  /// تهيئة Firebase عند بدء تشغيل التطبيق
  Future<void> initialize() async {
    if (isInitialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firestore = FirebaseFirestore.instance;
      isInitialized = true;
      debugPrint('Firebase initialized successfully!');
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
    }
  }

  /// جلب بيانات اللاعب من Firestore أو إنشاء ملف تعريف جديد إذا لم يكن موجوداً
  Future<Map<String, dynamic>> getOrCreatePlayerProfile({
    required String playerId,
    String defaultName = 'Alex K.',
    int defaultChips = 1250,
    int defaultRating = 1358,
    int defaultLevel = 24,
  }) async {
    if (!isInitialized) {
      return {
        'name': defaultName,
        'chips': defaultChips,
        'rating': defaultRating,
        'level': defaultLevel,
        'wins': 0,
        'losses': 0,
      };
    }

    try {
      final docRef = firestore.collection('players').doc(playerId);
      final snapshot = await docRef.get();

      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data()!;
      } else {
        final initialData = {
          'id': playerId,
          'name': defaultName,
          'chips': defaultChips,
          'rating': defaultRating,
          'level': defaultLevel,
          'wins': 0,
          'losses': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await docRef.set(initialData);
        return initialData;
      }
    } catch (e) {
      debugPrint('Error fetching player profile: $e');
      return {
        'name': defaultName,
        'chips': defaultChips,
        'rating': defaultRating,
        'level': defaultLevel,
        'wins': 0,
        'losses': 0,
      };
    }
  }

  /// تحديث رصيد اللاعب وتقييمه في قاعدة البيانات بعد انتهاء الجولة
  Future<void> updatePlayerScore({
    required String playerId,
    required int chips,
    required int rating,
    bool isWin = false,
  }) async {
    if (!isInitialized) return;
    try {
      await firestore.collection('players').doc(playerId).update({
        'chips': chips,
        'rating': rating,
        if (isWin) 'wins': FieldValue.increment(1) else 'losses': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Player $playerId stats updated in Firestore!');
    } catch (e) {
      debugPrint('Error updating player stats: $e');
    }
  }

  /// حفظ نتيجة الجولة في سجل المباريات
  Future<void> logGameResult({
    required String winnerName,
    required String winType,
    required int roundDurationSeconds,
  }) async {
    if (!isInitialized) return;
    try {
      await firestore.collection('game_history').add({
        'game': 'Turkish Okey',
        'winner': winnerName,
        'winType': winType,
        'durationSeconds': roundDurationSeconds,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error logging game result: $e');
    }
  }
}
