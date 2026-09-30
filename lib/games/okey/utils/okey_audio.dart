import 'package:flutter/services.dart';
import 'package:game_hub/utils/haptics.dart';

/// نظام المؤثرات الصوتية للأوكي - haptics + SystemSound
class OkeyAudio {
  static bool soundEnabled = true;
  static bool musicEnabled = true;
  static double sfxVolume = 0.8;

  /// صوت رفع الحجر
  static void playTilePickup() {
    if (!soundEnabled) return;
    AppHaptics.selection();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// صوت رمي الحجر
  static void playTileDiscard() {
    if (!soundEnabled) return;
    AppHaptics.medium();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// صوت سحب حجر جديد
  static void playTileDraw() {
    if (!soundEnabled) return;
    AppHaptics.light();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// صوت ضغط زر
  static void playButtonClick() {
    if (!soundEnabled) return;
    AppHaptics.light();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// صوت تنبيه الدور
  static void playTurnNotification() {
    if (!soundEnabled) return;
    AppHaptics.heavy();
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// صوت الفوز
  static void playWin() {
    if (!soundEnabled) return;
    AppHaptics.heavy();
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// صوت الترتيب
  static void playSort() {
    if (!soundEnabled) return;
    AppHaptics.selection();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
