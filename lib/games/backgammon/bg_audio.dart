import 'package:audioplayers/audioplayers.dart';
import '../../utils/haptics.dart';
import '../chess/chess_audio.dart';

/// مؤثرات الطاولي — نرد وضرب ووضع حجر وانفتاح اللوح + فقاعة الدردشة
class BgAudio {
  static void _play(String name, {double volume = 1.0}) {
    if (!ChessAudio.soundEnabled) return;
    try {
      final p = AudioPlayer()
        ..setPlayerMode(PlayerMode.lowLatency)
        ..setVolume(ChessAudio.sfxVolume * volume);
      p.play(AssetSource('audio/backgammon/$name.wav'));
      p.onPlayerComplete.first.then((_) => p.dispose());
    } catch (_) {}
  }

  static void dice() {
    AppHaptics.light();
    _play('dice', volume: 0.9);
  }

  static void place({double volume = 0.8}) {
    AppHaptics.light();
    _play('place', volume: volume);
  }

  static void hit() {
    AppHaptics.heavy();
    _play('hit');
  }

  static void open() {
    AppHaptics.medium();
    _play('open');
  }

  static void pop() => _play('pop', volume: 0.5);

  static void pick() => ChessAudio.select();
  static void illegal() => ChessAudio.illegal();
  static void bearOff() => _play('place', volume: 0.6);
  static void win() => ChessAudio.win();
  static void lose() => ChessAudio.lose();
}
