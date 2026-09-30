import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../l10n/app_lang.dart';
import 'ludo_audio.dart';

/// محرك اللودو — لاعبان (أنت أزرق أسفل-يسار، الخصم أخضر أعلى-يمين)
/// 4 أحجار لكل لاعب على مسار 52 خانة + عمود بيت من 5 خانات
class LudoEngine extends ChangeNotifier {
  LudoEngine({
    this.vsAI = true,
    this.botDelay = const Duration(milliseconds: 900),
  });

  final bool vsAI;
  final Duration botDelay;

  final math.Random _random = math.Random();
  Timer? _botTimer;

  /// المسار الرئيسي 52 خانة بترتيب السير (صف, عمود) على شبكة 15×15
  static const List<(int, int)> track = [
    (6, 1), (6, 2), (6, 3), (6, 4), (6, 5), // 0-4   يمين من انطلاق الأحمر
    (5, 6), (4, 6), (3, 6), (2, 6), (1, 6), (0, 6), // 5-10  أعلى
    (0, 7), (0, 8), // 11-12
    (1, 8), (2, 8), (3, 8), (4, 8), (5, 8), // 13-17 أسفل (13=انطلاق الأخضر)
    (6, 9), (6, 10), (6, 11), (6, 12), (6, 13), (6, 14), // 18-23 يمين
    (7, 14), (8, 14), // 24-25
    (8, 13), (8, 12), (8, 11), (8, 10), (8, 9), // 26-30 يسار (26=انطلاق الأصفر)
    (9, 8), (10, 8), (11, 8), (12, 8), (13, 8), (14, 8), // 31-36 أسفل
    (14, 7), (14, 6), // 37-38
    (13, 6), (12, 6), (11, 6), (10, 6), (9, 6), // 39-43 أعلى (39=انطلاق الأزرق)
    (8, 5), (8, 4), (8, 3), (8, 2), (8, 1), (8, 0), // 44-49 يسار
    (7, 0), (6, 0), // 50-51 → يعود للبداية
  ];

  /// خانة الانطلاق على المسار العالمي لكل لاعب
  static const startGlobal = {0: 39, 1: 13}; // أزرق / أخضر

  /// خانات عمود البيت (5 خانات قبل المركز) لكل لاعب
  static const homeCells = {
    0: [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)], // أزرق ↑
    1: [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)], // أخضر ↓
  };

  /// الخانات الآمنة (نجوم + خانات الانطلاق) — لا يُؤكل عليها
  static const safeGlobals = {0, 8, 13, 21, 26, 34, 39, 47};

  /// تقدّم كل حجر: -1 قاعدة، 0..51 مسار، 52..56 عمود البيت، 57 وصل
  final List<List<int>> tokens = [
    List.filled(4, -1),
    List.filled(4, -1),
  ];

  final List<String> names = ['أنت', 'روبوت 🤖'];

  int currentPlayer = 0;
  int dice = 6;
  bool rolling = false;
  bool moving = false;
  int? winner;
  int sixesInRow = 0;

  /// حجر يعود للقاعدة بعد أُكله (لأنيميشن القفزة)
  int? capturedPlayer;
  int capturedToken = -1;
  (int, int)? capturedFrom;

  /// إشعار نصي للواجهة
  void Function(String message)? onNotice;

  bool get busy => rolling || moving || winner != null;

  /// الموقع العالمي على المسار لحجر تقدّمه p — فقط لـ 0..51
  static int globalOf(int player, int p) => (startGlobal[player]! + p) % 52;

  /// الأحجار القانونية للحركة بالنرد الحالي
  List<int> legalTokens(int player) {
    if (winner != null) return const [];
    final out = <int>[];
    for (var t = 0; t < 4; t++) {
      final p = tokens[player][t];
      if (p == 57) continue;
      if (p == -1) {
        if (dice == 6) out.add(t);
      } else if (p + dice <= 57) {
        out.add(t);
      }
    }
    return out;
  }

  bool get humanTurn => !vsAI || currentPlayer == 0;

  void _notice(String msg) => onNotice?.call(msg);

  /// زر الرمي — البشري فقط
  Future<void> roll() async {
    if (busy) return;
    if (vsAI && currentPlayer != 0) return;
    await _doRoll();
  }

  Future<void> _doRoll() async {
    if (winner != null || rolling || moving) return;
    rolling = true;
    LudoAudio.dice();
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 620));
    dice = 1 + _random.nextInt(6);
    rolling = false;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (winner != null) return;

    final legal = legalTokens(currentPlayer);
    if (legal.isEmpty) {
      _notice(
          '🚫 لا حركة ممكنة لـ {} — تخطّي الدور'.trp([names[currentPlayer]]));
      await Future<void>.delayed(const Duration(milliseconds: 700));
      _endTurn(extra: false);
      return;
    }

    if (!humanTurn) {
      // البوت يختار ويحرك
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (winner != null) return;
      await _doMove(currentPlayer, _botPick(currentPlayer, legal));
    } else if (legal.length == 1) {
      // خيار واحد — تحريك تلقائي سريع
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (winner != null) return;
      await _doMove(currentPlayer, legal.first);
    }
    // عدة خيارات: ننتظر لمس اللاعب لحجره
    notifyListeners();
  }

  /// اللاعب يلمس حجراً من أحجاره القانونية
  Future<void> moveToken(int token) async {
    if (winner != null || rolling || moving) return;
    if (!humanTurn) return;
    if (!legalTokens(currentPlayer).contains(token)) return;
    await _doMove(currentPlayer, token);
  }

  /// تحريك حجر خطوة-خطوة ثم حسم الأكل/الوصول/الدور
  Future<void> _doMove(int player, int token) async {
    moving = true;
    notifyListeners();

    var p = tokens[player][token];
    if (p == -1) {
      // الخروج من القاعدة إلى خانة الانطلاق
      tokens[player][token] = 0;
      LudoAudio.step();
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } else {
      final target = p + dice;
      for (var s = p + 1; s <= target; s++) {
        tokens[player][token] = s;
        LudoAudio.step();
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 160));
      }
    }

    var extra = dice == 6;

    // الأكل — فقط على المسار الرئيسي وخارج الآمنة
    final landed = tokens[player][token];
    if (landed <= 51) {
      final g = globalOf(player, landed);
      if (!safeGlobals.contains(g)) {
        final opp = 1 - player;
        var ate = false;
        for (var t = 0; t < 4; t++) {
          final op = tokens[opp][t];
          if (op >= 0 && op <= 51 && globalOf(opp, op) == g) {
            capturedPlayer = opp;
            capturedToken = t;
            capturedFrom = track[g];
            notifyListeners();
            await Future<void>.delayed(const Duration(milliseconds: 620));
            tokens[opp][t] = -1;
            capturedPlayer = null;
            capturedToken = -1;
            capturedFrom = null;
            ate = true;
          }
        }
        if (ate) {
          LudoAudio.capture();
          _notice('⚔️ {} أكل حجر {}!'.trp([names[player], names[opp]]));
          extra = true;
          notifyListeners();
        }
      }
    }

    // وصول للمركز
    if (tokens[player][token] == 57) {
      LudoAudio.tokenHome();
      _notice('🏠 حجر {} وصل البيت!'.trp([names[player]]));
      extra = true;
    }

    // فوز: الأربعة كلها في البيت
    if (tokens[player].every((p) => p == 57)) {
      winner = player;
      moving = false;
      (player == 0 || !vsAI) ? LudoAudio.win() : LudoAudio.lose();
      notifyListeners();
      return;
    }

    // ثلاث ستات متتالية = إلغاء الدور
    if (dice == 6) {
      sixesInRow++;
      if (sixesInRow >= 3) {
        _notice('🎲 {} رمى 6 ثلاث مرات — يفقد الدور!'.trp([names[player]]));
        extra = false;
        sixesInRow = 0;
      }
    } else {
      sixesInRow = 0;
    }

    _endTurn(extra: extra);
  }

  void _endTurn({required bool extra}) {
    moving = false;
    if (!extra) {
      currentPlayer = 1 - currentPlayer;
      sixesInRow = 0;
    } else if (extra && dice == 6) {
      // الرمية الإضافية بنفس اللاعب
      _notice('🎲 {} رمى 6 — رمية إضافية!'.trp([names[currentPlayer]]));
    }
    notifyListeners();

    if (winner == null && vsAI && currentPlayer == 1) {
      _botTimer?.cancel();
      _botTimer = Timer(botDelay, _doRoll);
    } else if (winner == null && !vsAI) {
      notifyListeners();
    }
  }

  /// اختيار البوت: أكل > خروج بستة > إيصال للبيت > أبعد حجر
  int _botPick(int player, List<int> legal) {
    int score(int t) {
      final p = tokens[player][t];
      if (p == -1) return 500; // خروج من القاعدة
      final np = p + dice;
      var s = np; // يفضّل الحجر الأكثر تقدماً
      if (np == 57) s += 400; // وصول للبيت
      if (np >= 52) s += 150; // دخول عمود البيت (أمان)
      if (np <= 51) {
        final g = globalOf(player, np);
        if (!safeGlobals.contains(g)) {
          final opp = 1 - player;
          for (var t2 = 0; t2 < 4; t2++) {
            final op = tokens[opp][t2];
            if (op >= 0 && op <= 51 && globalOf(opp, op) == g) s += 1000;
          }
        } else {
          s += 80; // خانة آمنة
        }
      }
      return s;
    }

    var best = legal.first;
    var bestS = -1;
    for (final t in legal) {
      final s = score(t);
      if (s > bestS) {
        bestS = s;
        best = t;
      }
    }
    return best;
  }

  /// هل الحجر عند تقدّم p قابل للمس الآن (للواجهة)
  bool awaitingHumanPick() =>
      humanTurn &&
      !rolling &&
      !moving &&
      winner == null &&
      legalTokens(currentPlayer).length > 1;

  void reset() {
    _botTimer?.cancel();
    for (final t in tokens) {
      t.fillRange(0, 4, -1);
    }
    currentPlayer = 0;
    dice = 6;
    rolling = false;
    moving = false;
    winner = null;
    sixesInRow = 0;
    capturedPlayer = null;
    capturedToken = -1;
    capturedFrom = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
