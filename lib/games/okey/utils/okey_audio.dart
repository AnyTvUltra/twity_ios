import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:game_hub/utils/haptics.dart';

/// نظام المؤثرات الصوتية للأوكي — مشغّل audioplayers بجلسة مشتركة.
///
/// كان يستخدم SystemSound الذي يمر عبر AudioServicesPlaySystemSound في iOS
/// فيخفض صوت الراديو ثم يعيده (ducking) مع كل حركة. الآن تُشغَّل المؤثرات
/// عبر AudioPlayer بنفس سياق الراديو بالضبط (playback + mixWithOthers في iOS
/// وبدون طلب audio focus في أندرويد) فلا يتأثر صوت الراديو إطلاقاً.
class OkeyAudio {
  static bool soundEnabled = true;
  static bool musicEnabled = true;
  static double sfxVolume = 0.8;

  /// مجموعة مشغّلات صغيرة للأصوات المتداخلة (سحب سريع متتالٍ مثلاً)
  static final List<AudioPlayer> _pool = [];
  static int _cursor = 0;
  static bool _initTried = false;

  /// نفس سياق الراديو حرفياً: جلسة واحدة مشتركة بلا أي تبديل يخفض الصوت
  static final AudioContext _ctx = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
    android: const AudioContextAndroid(
      audioFocus: AndroidAudioFocus.none,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
    ),
  );

  static void _ensurePool() {
    if (_initTried) return;
    _initTried = true;
    try {
      for (var i = 0; i < 3; i++) {
        final p = AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop)
          ..setAudioContext(_ctx);
        _pool.add(p);
      }
    } catch (_) {}
  }

  /// في بيئة اختبارات Flutter لا توجد قنوات منصة — نتخطّى الصوت بصمت
  /// (اكتشاف عبر اسم نوع الـ binding — بلا dart:io حتى لا يكسر الويب)
  static bool get _isTestEnv {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  static void _play(String file, double volume) {
    if (!soundEnabled || _isTestEnv) return;
    try {
      _ensurePool();
      if (_pool.isEmpty) return;
      final p = _pool[_cursor++ % _pool.length];
      p.stop();
      p.setVolume((volume * sfxVolume).clamp(0.0, 1.0));
      p.play(AssetSource('audio/okey/$file'));
    } catch (_) {}
  }

  // أصوات حقيقية مسجّلة (Kenney Casino Audio — CC0): طقطقة قطع بلاستيكية
  // صلبة قريبة جداً من أحجار الأوكي. عدة نسخ لكل حركة تُختار بالتناوب
  // حتى لا تتكرر الحركات المتتالية بنفس الصوت حرفياً
  static final _rng = math.Random();
  static String _pick(List<String> files) => files[_rng.nextInt(files.length)];

  static const _pickFiles = ['pick_1.m4a', 'pick_2.m4a', 'pick_3.m4a'];
  static const _placeFiles = ['place_1.m4a', 'place_2.m4a', 'place_3.m4a'];
  static const _sortFiles = ['sort_2.m4a', 'sort_3.m4a'];

  /// صوت رفع الحجر
  static void playTilePickup() {
    if (!soundEnabled) return;
    AppHaptics.selection();
    _play(_pick(_pickFiles), 0.6);
  }

  /// صوت رمي الحجر على الطاولة
  static void playTileDiscard() {
    if (!soundEnabled) return;
    AppHaptics.medium();
    _play(_pick(_placeFiles), 0.85);
  }

  /// صوت سحب حجر جديد من الرزمة
  static void playTileDraw() {
    if (!soundEnabled) return;
    AppHaptics.light();
    _play('draw_1.m4a', 0.7);
  }

  /// صوت ضغط زر
  static void playButtonClick() {
    if (!soundEnabled) return;
    AppHaptics.light();
    _play('click_1.m4a', 0.45);
  }

  /// صوت تنبيه الدور
  static void playTurnNotification() {
    if (!soundEnabled) return;
    AppHaptics.heavy();
    _play('turn.wav', 0.8);
  }

  /// صوت الفوز
  static void playWin() {
    if (!soundEnabled) return;
    AppHaptics.heavy();
    _play('win.wav', 0.9);
  }

  /// صوت الترتيب
  static void playSort() {
    if (!soundEnabled) return;
    AppHaptics.selection();
    _play(_pick(_sortFiles), 0.6);
  }
}
