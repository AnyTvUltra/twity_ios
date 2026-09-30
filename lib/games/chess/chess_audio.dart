import 'package:audioplayers/audioplayers.dart';
import 'package:game_hub/utils/haptics.dart';

/// نظام المؤثرات الصوتية للشطرنج — ملفات WAV حقيقية + haptics
class ChessAudio {
  static bool soundEnabled = true;
  static double sfxVolume = 0.9;

  static const _dir = 'audio/chess';

  static void _play(String name,
      {double volume = 1.0, void Function()? haptic}) {
    haptic?.call();
    if (!soundEnabled) return;
    try {
      // player جديد لكل صوت — يسمح بتداخل المؤثرات (حركة + كش)
      final p = AudioPlayer()
        ..setPlayerMode(PlayerMode.lowLatency)
        ..setVolume(sfxVolume * volume);
      p.play(AssetSource('$_dir/$name.wav'));
      p.onPlayerComplete.first.then((_) => p.dispose());
    } catch (_) {}
  }

  /// تحديد قطعة
  static void select() =>
      _play('select', volume: 0.6, haptic: AppHaptics.selection);

  /// حركة عادية — طرقة خشبية
  static void move() => _play('move', haptic: AppHaptics.light);

  /// أخذ قطعة — ثud أثقل
  static void capture() => _play('capture', haptic: AppHaptics.medium);

  /// تبييت — طرقتان
  static void castle() => _play('castle', haptic: AppHaptics.medium);

  /// ترقية بيدق
  static void promote() => _play('promote', haptic: AppHaptics.medium);

  /// كش — رنّة تحذيرية
  static void check() => _play('check', haptic: AppHaptics.heavy);

  /// حركة غير قانونية / ضغطة مرفوضة
  static void illegal() =>
      _play('illegal', volume: 0.5, haptic: AppHaptics.light);

  /// بداية مباراة جديدة
  static void gameStart() => _play('game_start', haptic: AppHaptics.medium);

  /// فوز
  static void win() => _play('win', haptic: AppHaptics.heavy);

  /// خسارة
  static void lose() => _play('lose', haptic: AppHaptics.heavy);

  /// تعادل
  static void draw() => _play('draw', volume: 0.8, haptic: AppHaptics.medium);

  /// نبضة وقت منخفض
  static void lowTime() => _play('low_time', volume: 0.45);

  /// ضغطة زر واجهة
  static void tap() => _play('select', volume: 0.45, haptic: AppHaptics.light);
}
