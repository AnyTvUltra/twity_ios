import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_service.dart';

/// إعدادات السيرفر الحيّة — تُدار من لوحة الأدمن (config/game_settings)
/// وتصل لكل الأجهزة لحظياً دون إعادة تشغيل التطبيق.
class GameSettingsService extends ChangeNotifier {
  static final GameSettingsService _instance = GameSettingsService._internal();
  factory GameSettingsService() => _instance;
  GameSettingsService._internal();

  bool _initialized = false;
  StreamSubscription<DocumentSnapshot>? _sub;

  bool maintenanceMode = false;
  String announcement = '';
  int defaultTurnTimer = 72;
  int startingChips = 1250;
  String botDifficulty = 'medium';

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    final fb = FirebaseService();
    if (!fb.isInitialized) return;
    _sub = fb.firestore
        .collection('config')
        .doc('game_settings')
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      maintenanceMode = data['maintenanceMode'] == true;
      announcement = (data['announcement'] ?? '').toString();
      defaultTurnTimer =
          (data['defaultTurnTimer'] as num?)?.toInt() ?? defaultTurnTimer;
      startingChips = (data['startingChips'] as num?)?.toInt() ?? startingChips;
      botDifficulty = (data['botDifficulty'] ?? 'medium').toString();
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('GameSettings stream error: $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
