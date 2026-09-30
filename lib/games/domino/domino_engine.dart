import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../l10n/app_lang.dart';
import 'domino_audio.dart';

/// حجر دومينو — a جهة يسرى، b جهة يمنى (0..6)
class DominoTile {
  final int a;
  final int b;
  const DominoTile(this.a, this.b);

  bool get isDouble => a == b;
  int get pips => a + b;

  @override
  bool operator ==(Object other) =>
      other is DominoTile && other.a == a && other.b == b;

  @override
  int get hashCode => a * 7 + b;

  @override
  String toString() => '[$a|$b]';
}

/// حجر موضوع على الطاولة بتوجيه فعلي (left يوصل لليسار، right لليمين)
class PlacedDomino {
  final DominoTile tile;
  final int left;
  final int right;
  const PlacedDomino(this.tile, this.left, this.right);
}

/// محرك الدومينو — مجموعة دبل-6 (28 حجراً)، لاعبان، سحب من البونيارد،
/// انتهاء الجولة بإفراغ اليد أو البلوك، نقاط تتراكم حتى 50
class DominoEngine extends ChangeNotifier {
  DominoEngine({
    this.vsAI = true,
    this.botDelay = const Duration(milliseconds: 850),
    this.target = 50,
  }) {
    _newMatch();
  }

  final bool vsAI;
  final Duration botDelay;
  final int target;

  final math.Random _random = math.Random();
  Timer? _botTimer;

  /// أيدي اللاعبين
  final List<List<DominoTile>> hands = [[], []];

  /// بونيارد (السحب)
  final List<DominoTile> boneyard = [];

  /// السلسلة على الطاولة بالترتيب من الطرف الأيسر للأيمن
  final List<PlacedDomino> chain = [];

  /// الطرفان المفتوحان (-1 إذا السلسلة فارغة)
  int leftEnd = -1;
  int rightEnd = -1;

  int currentPlayer = 0;
  final List<int> scores = [0, 0];
  int round = 1;
  int consecutivePasses = 0;

  /// الفائز بالجولة الأخيرة (-1 تعادل بالبلوك، null جارية)
  int? roundWinner;
  int roundPoints = 0;

  /// الفائز بالمباراة
  int? matchWinner;

  /// توقفة نهاية جولة (تُعرض لافتة ثم يبدأ التوزيع)
  bool betweenRounds = false;

  /// حجر يُنقل للطاولة حالياً (لأنيميشن الطيران)
  DominoTile? flyingTile;
  int flyingPlayer = -1;

  final List<String> names = ['أنت', 'روبوت 🤖'];

  void Function(String message)? onNotice;

  bool get busy => betweenRounds || matchWinner != null;
  bool get humanTurn => !vsAI || currentPlayer == 0;

  void _notice(String msg) => onNotice?.call(msg);

  // ─────────────────────────────────────────────
  //  التوزيع
  // ─────────────────────────────────────────────
  void _newMatch() {
    scores[0] = 0;
    scores[1] = 0;
    round = 1;
    matchWinner = null;
    _deal();
  }

  void _deal() {
    final deck = <DominoTile>[
      for (var i = 0; i <= 6; i++)
        for (var j = i; j <= 6; j++) DominoTile(i, j),
    ]..shuffle(_random);

    hands[0] = deck.sublist(0, 7);
    hands[1] = deck.sublist(7, 14);
    boneyard
      ..clear()
      ..addAll(deck.sublist(14));
    chain.clear();
    leftEnd = -1;
    rightEnd = -1;
    consecutivePasses = 0;
    roundWinner = null;
    betweenRounds = false;
    flyingTile = null;
    currentPlayer = _firstPlayer();
    DominoAudio.shuffle();
    notifyListeners();
    _maybeBot();
  }

  /// صاحب أعلى دبل يبدأ — وإلا أعلى حجر
  int _firstPlayer() {
    var best = -1;
    var bestP = 0;
    var bestDouble = false;
    for (var p = 0; p < 2; p++) {
      for (final t in hands[p]) {
        final isBetter = (t.isDouble && !bestDouble) ||
            (t.isDouble == bestDouble && t.pips > best);
        if (isBetter) {
          best = t.pips;
          bestDouble = t.isDouble;
          bestP = p;
        }
      }
    }
    return bestP;
  }

  // ─────────────────────────────────────────────
  //  القواعد
  // ─────────────────────────────────────────────
  /// جوانب لعب حجر: 0=يسار، 1=يمين، قد يكونا معاً
  List<int> legalSides(DominoTile t) {
    if (chain.isEmpty) return const [0, 1];
    final out = <int>[];
    if (t.a == leftEnd || t.b == leftEnd) out.add(0);
    if (t.a == rightEnd || t.b == rightEnd) out.add(1);
    return out;
  }

  bool get hasEmptyChain => chain.isEmpty;

  /// أحجار اللاعب القابلة للعب
  List<int> legalHandIndices(int player) {
    final out = <int>[];
    for (var i = 0; i < hands[player].length; i++) {
      if (legalSides(hands[player][i]).isNotEmpty) out.add(i);
    }
    return out;
  }

  bool get mustDraw =>
      boneyard.isNotEmpty && legalHandIndices(currentPlayer).isEmpty;

  bool get mustPass =>
      boneyard.isEmpty && legalHandIndices(currentPlayer).isEmpty;

  int handPips(int player) => hands[player].fold(0, (sum, t) => sum + t.pips);

  // ─────────────────────────────────────────────
  //  اللعب
  // ─────────────────────────────────────────────
  /// لعب حجر على طرف: side 0=يسار، 1=يمين، -1=تلقائي (وحيد ممكن)
  Future<void> playTile(int player, int handIndex, int side) async {
    if (busy || player != currentPlayer) return;
    if (handIndex < 0 || handIndex >= hands[player].length) return;
    final tile = hands[player][handIndex];
    final sides = legalSides(tile);
    if (sides.isEmpty) return;
    if (side == -1) side = sides.first;
    if (!sides.contains(side)) return;

    // أنيميشن الطيران ثم الوضع
    hands[player].removeAt(handIndex);
    flyingTile = tile;
    flyingPlayer = player;
    DominoAudio.place();
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 380));

    if (chain.isEmpty) {
      chain.add(PlacedDomino(tile, tile.a, tile.b));
      leftEnd = tile.a;
      rightEnd = tile.b;
    } else if (side == 0) {
      final placed = tile.a == leftEnd
          ? PlacedDomino(tile, tile.b, tile.a)
          : PlacedDomino(tile, tile.a, tile.b);
      chain.insert(0, placed);
      leftEnd = placed.left;
    } else {
      final placed = tile.b == rightEnd
          ? PlacedDomino(tile, tile.b, tile.a)
          : PlacedDomino(tile, tile.a, tile.b);
      chain.add(placed);
      rightEnd = placed.right;
    }
    flyingTile = null;
    consecutivePasses = 0;
    notifyListeners();

    // نهاية الجولة بإفراغ اليد
    if (hands[player].isEmpty) {
      _endRound(player, blocked: false);
      return;
    }
    _nextTurn();
  }

  /// سحب حجر من البونيارد
  Future<void> drawTile(int player) async {
    if (busy || player != currentPlayer) return;
    if (!mustDraw) return;
    final t = boneyard.removeLast();
    hands[player].add(t);
    DominoAudio.draw();
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    // إذا بقي بلا حركة والبونيارد فرغ → مرّر تلقائياً
    if (mustPass) pass(player);
    notifyListeners();
  }

  /// تمرير عند استحالة اللعب والسحب
  void pass(int player) {
    if (busy || player != currentPlayer || !mustPass) return;
    consecutivePasses++;
    _notice('🚫 {} يمرّ — لا حركة'.trp([names[player]]));
    if (consecutivePasses >= 2) {
      _endRound(null, blocked: true);
      return;
    }
    _nextTurn();
  }

  void _nextTurn() {
    currentPlayer = 1 - currentPlayer;
    notifyListeners();
    _maybeBot();
  }

  void _maybeBot() {
    if (vsAI && currentPlayer == 1 && matchWinner == null && !betweenRounds) {
      _botTimer?.cancel();
      _botTimer = Timer(botDelay, _botMove);
    }
  }

  // ─────────────────────────────────────────────
  //  نهاية الجولة والمباراة
  // ─────────────────────────────────────────────
  Future<void> _endRound(int? winner, {required bool blocked}) async {
    betweenRounds = true;
    int pts;
    if (blocked) {
      // البلوك: الأقل نقاطاً في اليد يفوز بالفرق
      final p0 = handPips(0), p1 = handPips(1);
      if (p0 == p1) {
        winner = null;
        pts = 0;
      } else {
        winner = p0 < p1 ? 0 : 1;
        pts = (p0 - p1).abs();
      }
    } else {
      final loser = 1 - winner!;
      pts = handPips(loser);
    }

    roundWinner = winner;
    roundPoints = pts;
    if (winner != null) scores[winner] += pts;
    DominoAudio.roundEnd();
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 2600));
    if (matchWinner != null) return;

    // فوز بالمباراة؟
    final targetHit =
        scores.indexWhere((s) => s >= target); // الأكبر أولاً عند التعادل
    if (targetHit != -1) {
      var m = 0;
      if (scores[1] > scores[0]) m = 1;
      matchWinner = m;
      (m == 0 || !vsAI) ? DominoAudio.win() : DominoAudio.lose();
      notifyListeners();
      return;
    }

    // جولة جديدة
    round++;
    _deal();
  }

  /// استسلام — خسارة فورية
  void resign(int player) {
    matchWinner = 1 - player;
    notifyListeners();
  }

  /// إعادة مباراة من الصفر
  void reset() {
    _botTimer?.cancel();
    _newMatch();
  }

  // ─────────────────────────────────────────────
  //  البوت
  // ─────────────────────────────────────────────
  Future<void> _botMove() async {
    if (busy || !vsAI || currentPlayer != 1) return;
    final legal = legalHandIndices(1);

    if (legal.isEmpty) {
      if (boneyard.isNotEmpty) {
        await drawTile(1);
        _botTimer = Timer(const Duration(milliseconds: 450), _botMove);
      } else {
        pass(1);
      }
      return;
    }

    // اختيار: أعلى نقاط + يفضّل إبقاء الطرفين بأرقام نملكها
    var bestIdx = legal.first;
    var bestSide = -1;
    var bestScore = -1;
    for (final i in legal) {
      final t = hands[1][i];
      for (final side in legalSides(t)) {
        var s = t.pips * 10;
        if (t.isDouble) s += 12;
        // الطرف الناتج الجديد: افضّل رقم نملكه كثيراً في اليد
        final newEnds = <int>[];
        if (chain.isEmpty) {
          newEnds.addAll([t.a, t.b]);
        } else {
          final nl = side == 0 ? (t.a == leftEnd ? t.b : t.a) : leftEnd;
          final nr = side == 1 ? (t.a == rightEnd ? t.b : t.a) : rightEnd;
          newEnds.addAll([nl, nr]);
        }
        for (var j = 0; j < hands[1].length; j++) {
          if (j == i) continue;
          final o = hands[1][j];
          if (newEnds.contains(o.a) || newEnds.contains(o.b)) s += 3;
        }
        if (s > bestScore) {
          bestScore = s;
          bestIdx = i;
          bestSide = side;
        }
      }
    }
    await playTile(1, bestIdx, bestSide);
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    super.dispose();
  }
}
