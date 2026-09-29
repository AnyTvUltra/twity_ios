import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// حركة واحدة في الطاولي
/// [from]: ‎-1 = البار، 0..23 = الخانة
/// [to]: 0..23 = الخانة، 24 = إخراج (Bear off)
class BgMove {
  static const int bar = -1;
  static const int off = 24;

  final int from;
  final int to;
  final int die;
  final bool hit;

  const BgMove(this.from, this.to, this.die, {this.hit = false});

  @override
  bool operator ==(Object other) =>
      other is BgMove &&
      other.from == from &&
      other.to == to &&
      other.die == die;

  @override
  int get hashCode => Object.hash(from, to, die);

  @override
  String toString() => 'BgMove($from→$to d$die${hit ? ' hit' : ''})';
}

/// حالة اللوح
/// [pts]: موجب = اللاعب 0 (يتحرك 23→0، بيته 0..5)
///        سالب = اللاعب 1 (يتحرك 0→23، بيته 18..23)
class BgState {
  final List<int> pts;
  final List<int> bar;
  final List<int> off;

  BgState(this.pts, this.bar, this.off);

  factory BgState.initial() {
    final p = List<int>.filled(24, 0);
    p[23] = 2;
    p[12] = 5;
    p[7] = 3;
    p[5] = 5;
    p[0] = -2;
    p[11] = -5;
    p[16] = -3;
    p[18] = -5;
    return BgState(p, [0, 0], [0, 0]);
  }

  BgState copy() => BgState(List.of(pts), List.of(bar), List.of(off));

  int countAt(int i, int side) {
    final v = pts[i];
    if (side == 0) return v > 0 ? v : 0;
    return v < 0 ? -v : 0;
  }

  int oppCountAt(int i, int side) => countAt(i, 1 - side);

  /// عدد النقاط المتبقية (Pip count)
  int pip(int side) {
    int sum = bar[side] * 25;
    for (int i = 0; i < 24; i++) {
      final c = countAt(i, side);
      if (c > 0) sum += c * (side == 0 ? i + 1 : 24 - i);
    }
    return sum;
  }

  String get key => '${pts.join(',')}|${bar.join(',')}|${off.join(',')}';
}

/// مستوى صعوبة البوت
enum BgBotLevel { easy, medium, hard }

/// محرك الطاولي — قوانين كاملة + ذكاء اصطناعي
class BackgammonEngine extends ChangeNotifier {
  BackgammonEngine({math.Random? rng}) : _rng = rng ?? math.Random();

  final math.Random _rng;

  BgState state = BgState.initial();

  /// صاحب الدور (0 = أنت، 1 = الخصم)
  int turn = 0;

  /// النرد المرمي هذا الدور (للعرض)
  List<int> rolled = [];

  /// النرد المتبقي للاستخدام
  List<int> dice = [];

  int? winner;

  /// سجل الدور الحالي للتراجع
  final List<(BgState, List<int>)> _undo = [];

  bool get hasRolled => rolled.isNotEmpty;
  bool get canUndo => _undo.isNotEmpty && winner == null;

  void reset() {
    state = BgState.initial();
    turn = 0;
    rolled = [];
    dice = [];
    winner = null;
    _undo.clear();
    notifyListeners();
  }

  int rollDie() => _rng.nextInt(6) + 1;

  /// رمية الافتتاح: كل لاعب نرداً — الأعلى يبدأ ويلعب بالنردين
  (int, int) rollOpening() {
    int a, b;
    do {
      a = rollDie();
      b = rollDie();
    } while (a == b);
    turn = a > b ? 0 : 1;
    setDice(a, b);
    return (a, b);
  }

  /// رمي النرد للدور الحالي
  (int, int) roll() {
    final a = rollDie(), b = rollDie();
    setDice(a, b);
    return (a, b);
  }

  void setDice(int a, int b) {
    rolled = [a, b];
    dice = a == b ? [a, a, a, a] : [a, b];
    _undo.clear();
    notifyListeners();
  }

  void endTurn() {
    turn = 1 - turn;
    rolled = [];
    dice = [];
    _undo.clear();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════
  // القوانين
  // ══════════════════════════════════════════════════════

  static int _dir(int side) => side == 0 ? -1 : 1;

  static bool _allHome(BgState s, int side) {
    if (s.bar[side] > 0) return false;
    for (int i = 0; i < 24; i++) {
      if (s.countAt(i, side) == 0) continue;
      if (side == 0 && i > 5) return false;
      if (side == 1 && i < 18) return false;
    }
    return true;
  }

  /// هل يوجد حجر للاعب أبعد عن الإخراج من الخانة [i]؟
  static bool _hasFarther(BgState s, int side, int i) {
    if (side == 0) {
      for (int j = i + 1; j <= 5; j++) {
        if (s.countAt(j, 0) > 0) return true;
      }
    } else {
      for (int j = 18; j < i; j++) {
        if (s.countAt(j, 1) > 0) return true;
      }
    }
    return false;
  }

  /// كل الحركات المفردة الممكنة (بدون قاعدة استخدام أقصى عدد من النرد)
  static List<BgMove> _singles(BgState s, int side, List<int> dice) {
    final out = <BgMove>[];
    final seen = <int>{};
    for (final d in dice) {
      if (!seen.add(d)) continue;
      if (s.bar[side] > 0) {
        final to = side == 0 ? 24 - d : d - 1;
        final opp = s.oppCountAt(to, side);
        if (opp < 2) out.add(BgMove(BgMove.bar, to, d, hit: opp == 1));
        continue;
      }
      final home = _allHome(s, side);
      for (int i = 0; i < 24; i++) {
        if (s.countAt(i, side) == 0) continue;
        final to = i + _dir(side) * d;
        if (to >= 0 && to <= 23) {
          final opp = s.oppCountAt(to, side);
          if (opp < 2) out.add(BgMove(i, to, d, hit: opp == 1));
        } else if (home) {
          final dist = side == 0 ? i + 1 : 24 - i;
          if (d == dist || (d > dist && !_hasFarther(s, side, i))) {
            out.add(BgMove(i, BgMove.off, d));
          }
        }
      }
    }
    return out;
  }

  /// تطبيق حركة على نسخة جديدة من الحالة
  static BgState applyTo(BgState s, int side, BgMove m) {
    final n = s.copy();
    final sign = side == 0 ? 1 : -1;
    if (m.from == BgMove.bar) {
      n.bar[side]--;
    } else {
      n.pts[m.from] -= sign;
    }
    if (m.to == BgMove.off) {
      n.off[side]++;
    } else {
      if (n.oppCountAt(m.to, side) == 1) {
        n.pts[m.to] = 0;
        n.bar[1 - side]++;
      }
      n.pts[m.to] += sign;
    }
    return n;
  }

  static List<int> _without(List<int> dice, int d) {
    final l = List.of(dice);
    l.remove(d);
    return l;
  }

  static int _maxLen(BgState s, int side, List<int> dice,
      [Map<String, int>? memo]) {
    if (dice.isEmpty) return 0;
    memo ??= {};
    final k = '${s.key}#${dice.join()}';
    final cached = memo[k];
    if (cached != null) return cached;
    int best = 0;
    for (final m in _singles(s, side, dice)) {
      final l =
          1 + _maxLen(applyTo(s, side, m), side, _without(dice, m.die), memo);
      if (l > best) best = l;
      if (best == dice.length) break;
    }
    memo[k] = best;
    return best;
  }

  /// الحركات القانونية الآن — تطبّق قاعدة "استخدم أكبر عدد من النرد"
  /// و"إن أمكن نرد واحد فقط فالأكبر إلزامي"
  static List<BgMove> legalFor(BgState s, int side, List<int> dice) {
    if (dice.isEmpty) return const [];
    final singles = _singles(s, side, dice);
    if (singles.isEmpty) return const [];
    final memo = <String, int>{};
    final max = _maxLen(s, side, dice, memo);
    var legal = singles
        .where((m) =>
            1 +
                _maxLen(
                    applyTo(s, side, m), side, _without(dice, m.die), memo) ==
            max)
        .toList();
    if (max == 1 && dice.length == 2 && dice[0] != dice[1]) {
      final hi = math.max(dice[0], dice[1]);
      final big = legal.where((m) => m.die == hi).toList();
      if (big.isNotEmpty) legal = big;
    }
    return legal;
  }

  List<BgMove> legalMoves() =>
      winner != null ? const [] : legalFor(state, turn, dice);

  /// الخانات التي يمكن تحريك حجر منها الآن
  Set<int> movableSources() => legalMoves().map((m) => m.from).toSet();

  /// الوجهات الممكنة لحجر واحد (خطوة أو عدة خطوات متتالية بنفس الحجر)
  /// المفتاح = الوجهة، القيمة = مسار الحركات
  Map<int, List<BgMove>> pathsFrom(int from) {
    final res = <int, List<BgMove>>{};
    void dfs(BgState s, List<int> d, int cur, List<BgMove> path) {
      for (final m in legalFor(s, turn, d)) {
        if (m.from != cur) continue;
        final p = [...path, m];
        final existing = res[m.to];
        if (existing == null || existing.length > p.length) res[m.to] = p;
        if (m.to != BgMove.off) {
          dfs(applyTo(s, turn, m), _without(d, m.die), m.to, p);
        }
      }
    }

    if (winner == null) dfs(state, dice, from, const []);
    return res;
  }

  /// تنفيذ حركة قانونية
  void applyMove(BgMove m) {
    _undo.add((state.copy(), List.of(dice)));
    state = applyTo(state, turn, m);
    dice = _without(dice, m.die);
    if (state.off[turn] == 15) winner = turn;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    final (s, d) = _undo.removeLast();
    state = s;
    dice = d;
    notifyListeners();
  }

  /// مضاعف الفوز: 1 عادي، 2 مارس (Gammon)، 3 مارس مضاعف (Backgammon)
  int get winMultiplier {
    final w = winner;
    if (w == null) return 0;
    final l = 1 - w;
    if (state.off[l] > 0) return 1;
    if (state.bar[l] > 0) return 3;
    for (int i = 0; i < 24; i++) {
      if (state.countAt(i, l) == 0) continue;
      if (w == 0 && i <= 5) return 3;
      if (w == 1 && i >= 18) return 3;
    }
    return 2;
  }

  // ══════════════════════════════════════════════════════
  // الذكاء الاصطناعي
  // ══════════════════════════════════════════════════════

  /// أفضل تسلسل حركات للاعب الحالي
  List<BgMove> bestSequence({BgBotLevel level = BgBotLevel.medium}) {
    final seqs = <String, (List<BgMove>, BgState)>{};
    final visited = <String>{};
    void dfs(BgState s, List<int> d, List<BgMove> path) {
      if (!visited.add('${s.key}#${d.join()}')) return;
      final singles = _singles(s, turn, d);
      if (singles.isEmpty) {
        final prev = seqs[s.key];
        if (prev == null || prev.$1.length < path.length) {
          seqs[s.key] = (path, s);
        }
        return;
      }
      for (final m in singles) {
        dfs(applyTo(s, turn, m), _without(d, m.die), [...path, m]);
      }
    }

    dfs(state, dice, const []);
    if (seqs.isEmpty) return const [];

    // قاعدة استخدام أقصى عدد من النرد + الأكبر إلزامي
    final maxLen = seqs.values.map((e) => e.$1.length).reduce(math.max);
    if (maxLen == 0) return const [];
    var pool = seqs.values.where((e) => e.$1.length == maxLen).toList();
    if (maxLen == 1 && dice.length == 2 && dice[0] != dice[1]) {
      final hi = math.max(dice[0], dice[1]);
      final big = pool.where((e) => e.$1.first.die == hi).toList();
      if (big.isNotEmpty) pool = big;
    }

    final scored = pool.map((e) => (e.$1, evaluate(e.$2, turn))).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    switch (level) {
      case BgBotLevel.hard:
        return scored.first.$1;
      case BgBotLevel.medium:
        final top = scored.take(3).toList();
        return _rng.nextDouble() < 0.8 ? top.first.$1 : top.last.$1;
      case BgBotLevel.easy:
        final n = math.max(1, (scored.length * 0.4).ceil());
        return scored[_rng.nextInt(n)].$1;
    }
  }

  static const List<int> _shotOdds = [
    0,
    11,
    12,
    14,
    15,
    15,
    17,
    6,
    6,
    5,
    3,
    2,
    3,
    0,
    0,
    1,
    1,
    0,
    1,
    0,
    1,
    0,
    0,
    0,
    1
  ];

  /// تقييم الوضع من منظور [side] — كلما زاد كان أفضل
  static double evaluate(BgState s, int side) {
    final opp = 1 - side;
    double score = 0;
    score += (s.pip(opp) - s.pip(side)) * 1.0;
    score += s.off[side] * 8.0 - s.off[opp] * 8.0;
    score += s.bar[opp] * 14.0 - s.bar[side] * 14.0;

    // هل ما زال هناك احتكاك؟
    int myBack = side == 0 ? -1 : 24, oppBack = side == 0 ? 24 : -1;
    for (int i = 0; i < 24; i++) {
      if (s.countAt(i, side) > 0) {
        myBack = side == 0 ? math.max(myBack, i) : math.min(myBack, i);
      }
      if (s.countAt(i, opp) > 0) {
        oppBack = side == 0 ? math.min(oppBack, i) : math.max(oppBack, i);
      }
    }
    if (s.bar[side] > 0) myBack = side == 0 ? 24 : -1;
    if (s.bar[opp] > 0) oppBack = side == 0 ? -1 : 24;
    final contact = side == 0 ? myBack > oppBack : myBack < oppBack;
    if (!contact) return score + s.off[side] * 4.0;

    int run = 0;
    for (int k = 0; k < 24; k++) {
      final i = side == 0 ? k : 23 - k;
      final c = s.countAt(i, side);
      final inHome = k <= 5;
      if (c >= 2) {
        score += 2.0 + (inHome ? 3.0 : 0.0);
        if (k >= 18) score += 1.5;
        run++;
        if (run >= 2) score += run * 1.2;
        if (c > 4) score -= (c - 4) * 0.8;
      } else {
        run = 0;
      }
      if (c == 1) {
        // احتمال ضرب الحجر المكشوف من أحجار الخصم خلفه
        int shots = 0;
        for (int j = 0; j < 24; j++) {
          if (s.countAt(j, opp) == 0) continue;
          final dist = side == 0 ? i - j : j - i;
          if (dist > 0 && dist < _shotOdds.length) shots += _shotOdds[dist];
        }
        if (s.bar[opp] > 0) {
          final dist = side == 0 ? i + 1 : 24 - i;
          if (dist < _shotOdds.length) shots += _shotOdds[dist] * 2;
        }
        final risk = math.min(36, shots) / 36.0;
        final loss = (24 - k) + 4.0;
        score -= risk * loss;
      }
    }
    return score;
  }
}
