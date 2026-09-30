import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../l10n/app_lang.dart';
import 'snake_audio.dart';

/// محرك لعبة الحية والدرج — لاعبان على لوحة 10×10
/// اللاعب 0 = أنت، اللاعب 1 = بوت (أونلاين/ذكاء اصطناعي) أو صديق على نفس الجهاز
class SnakeEngine extends ChangeNotifier {
  SnakeEngine({
    this.vsAI = true,
    this.botDelay = const Duration(milliseconds: 950),
  });

  /// ضد ذكاء اصطناعي (true) أم لاعب ثانٍ على نفس الجهاز (false)
  final bool vsAI;
  final Duration botDelay;

  final math.Random _random = math.Random();
  Timer? _botTimer;

  /// خريطة الدرجات: أسفل الدرج → أعلى الدرج
  static const Map<int, int> ladders = {
    2: 38,
    4: 14,
    9: 31,
    21: 42,
    28: 84,
    36: 44,
    51: 67,
    71: 91,
    80: 100,
  };

  /// خريطة الحيات: الرأس → الذيل (الهبوط)
  static const Map<int, int> snakes = {
    16: 6,
    47: 26,
    49: 11,
    56: 53,
    62: 19,
    64: 60,
    87: 24,
    93: 73,
    95: 75,
    98: 78,
  };

  /// مواقع اللاعبين (0 = خارج اللوحة قبل البداية، 100 = الفوز)
  final List<int> positions = [0, 0];

  /// أسماء اللاعبين — تُضبط من الشاشة
  final List<String> names = ['أنت', 'روبوت 🤖'];

  int currentPlayer = 0;
  int dice = 6;
  bool rolling = false;
  bool moving = false;
  int? winner;

  /// انزلاق جارٍ على حية (للأنيميشن المقوّس على جسمها)
  int? slidingPlayer;
  int slideFrom = 0;
  int slideTo = 0;

  /// تسلّق جارٍ على درج (للأنيميشن الصاعد)
  int? climbingPlayer;
  int climbFrom = 0;
  int climbTo = 0;

  /// إشعار نصي للواجهة
  void Function(String message)? onNotice;

  bool get humanTurn => !vsAI || currentPlayer == 0;
  bool get busy => rolling || moving || winner != null;

  /// اسم اللاعب صاحب الدور الحالي
  String get turnName => names[currentPlayer];

  void _notice(String msg) => onNotice?.call(msg);

  /// زر الرمي — البشري فقط (البوت يدير دوره ذاتياً)
  Future<void> roll() async {
    if (busy) return;
    if (vsAI && currentPlayer != 0) return;
    await _doRoll();
  }

  Future<void> _doRoll() async {
    if (winner != null || rolling || moving) return;
    rolling = true;
    SnakeAudio.dice();
    notifyListeners();

    // دحرجة النرد — الوجه يتبدل بصرياً في الواجهة ثم يستقر
    await Future<void>.delayed(const Duration(milliseconds: 620));
    dice = 1 + _random.nextInt(6);
    rolling = false;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (winner != null) return;
    await _advance();
  }

  /// تحريك الحجر خطوة خطوة ثم حسم المصير (درج/حية/فوز)
  Future<void> _advance() async {
    final p = currentPlayer;
    moving = true;

    final start = positions[p];
    final raw = start + dice;
    // قاعدة الارتداد: تجاوز 100 يرتد للخلف
    final target = raw > 100 ? 100 - (raw - 100) : raw;

    // مسار الخطوات: صعود إلى 100 ثم رجوع عند الارتداد
    final path = <int>[];
    for (var s = start + 1; s <= math.min(raw, 100); s++) {
      path.add(s);
    }
    for (var s = 99; s > target; s--) {
      path.add(s);
    }

    for (final s in path) {
      positions[p] = s;
      SnakeAudio.step();
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 165));
    }

    // درج؟
    final ladderTop = ladders[positions[p]];
    if (ladderTop != null && winner == null) {
      climbingPlayer = p;
      climbFrom = positions[p];
      climbTo = ladderTop;
      SnakeAudio.ladder();
      _notice('🪜 {} صعد الدرج! {} → {}'.trp([names[p], climbFrom, ladderTop]));
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      positions[p] = ladderTop;
      climbingPlayer = null;
      notifyListeners();
    }

    // حية؟
    final snakeTail = snakes[positions[p]];
    if (snakeTail != null && winner == null) {
      slidingPlayer = p;
      slideFrom = positions[p];
      slideTo = snakeTail;
      SnakeAudio.snake();
      _notice('🐍 {} عضته حية! {} → {}'.trp([names[p], slideFrom, snakeTail]));
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      positions[p] = snakeTail;
      slidingPlayer = null;
      notifyListeners();
    }

    // فوز؟
    if (positions[p] == 100) {
      winner = p;
      moving = false;
      (p == 0 || !vsAI) ? SnakeAudio.win() : SnakeAudio.lose();
      notifyListeners();
      return;
    }

    // ستة = رمية إضافية
    final extra = dice == 6;
    if (!extra) currentPlayer = 1 - currentPlayer;
    moving = false;
    notifyListeners();

    if (extra) {
      _notice('🎲 {} رمى 6 — رمية إضافية!'.trp([names[p]]));
    }

    // دور البوت
    if (winner == null && vsAI && currentPlayer == 1) {
      _botTimer?.cancel();
      _botTimer = Timer(botDelay, _doRoll);
    }
  }

  /// إعادة مباراة
  void reset() {
    _botTimer?.cancel();
    positions[0] = 0;
    positions[1] = 0;
    currentPlayer = 0;
    dice = 6;
    rolling = false;
    moving = false;
    winner = null;
    slidingPlayer = null;
    climbingPlayer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
