import 'package:audioplayers/audioplayers.dart';

import '../../utils/haptics.dart';

/// مؤثرات السوليتر — يعيد استخدام ملفات الصوت الموجودة
class SolAudio {
  SolAudio._();

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

  /// خلط وتوزيع اللعبة
  static void shuffle() {
    AppHaptics.light();
    _play('backgammon/dice', volume: 0.55);
  }

  /// سحب بطاقة من المخزون
  static void draw() {
    _play('backgammon/pop', volume: 0.5);
  }

  /// وضع بطاقة على الأساس
  static void place() {
    _play('backgammon/place', volume: 0.9);
  }

  /// كشف بطاقة مقلوبة
  static void flip() {
    AppHaptics.light();
    _play('backgammon/open', volume: 0.7);
  }

  static void win() {
    AppHaptics.heavy();
    _play('chess/win');
  }

  static void lose() {
    _play('chess/lose', volume: 0.8);
  }
}
