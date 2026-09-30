import 'package:audioplayers/audioplayers.dart';

import '../../utils/haptics.dart';

/// مؤثرات الحية والدرج — يعيد استخدام ملفات الصوت الموجودة
class SnakeAudio {
  SnakeAudio._();

  static bool soundEnabled = true;
  static double sfxVolume = 0.85;

  static void _play(String path, {double volume = 1.0}) {
    if (!soundEnabled) return;
    try {
      final p = AudioPlayer()
        ..setPlayerMode(PlayerMode.lowLatency)
        ..setVolume(sfxVolume * volume);
      p.play(AssetSource('audio/$path.wav'));
      p.onPlayerComplete.first.then((_) => p.dispose());
    } catch (_) {}
  }

  /// دحرجة النرد
  static void dice() {
    AppHaptics.medium();
    _play('backgammon/dice', volume: 0.95);
  }

  /// قفزة حجر — خانة واحدة
  static void step() {
    _play('backgammon/pop', volume: 0.35);
  }

  /// صعود الدرج
  static void ladder() {
    AppHaptics.light();
    _play('backgammon/place', volume: 0.9);
  }

  /// عضة الحية / الهبوط
  static void snake() {
    AppHaptics.heavy();
    _play('backgammon/hit', volume: 0.7);
  }

  static void win() {
    AppHaptics.heavy();
    _play('chess/win');
  }

  static void lose() {
    _play('chess/lose', volume: 0.8);
  }
}
