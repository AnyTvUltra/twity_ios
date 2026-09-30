import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../l10n/app_lang.dart';
import 'solitaire_audio.dart';

/// ورقة لعب: rank 1=A..13=K، suit حسب الترتيب
enum SolSuit { hearts, diamonds, clubs, spades }

class SolCard {
  final int rank;
  final SolSuit suit;
  bool faceUp;

  SolCard(this.rank, this.suit, {this.faceUp = false});

  bool get isRed => suit == SolSuit.hearts || suit == SolSuit.diamonds;
  int get id => (rank - 1) * 4 + suit.index;

  String get rankLabel => switch (rank) {
        1 => 'A',
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        _ => '$rank',
      };

  String get suitChar => switch (suit) {
        SolSuit.hearts => '♥',
        SolSuit.diamonds => '♦',
        SolSuit.clubs => '♣',
        SolSuit.spades => '♠',
      };
}

/// محرك سوليتر كلوندايك — سحب 1، تدوير لا نهائي للمخزون، تراجع، تلميح
class SolitaireEngine extends ChangeNotifier {
  SolitaireEngine() {
    _newGame();
  }

  final math.Random _random = math.Random();

  final List<SolCard> stock = [];
  final List<SolCard> waste = [];
  final List<List<SolCard>> foundations = [[], [], [], []];
  final List<List<SolCard>> tableau = [[], [], [], [], [], [], []];
  final Map<int, SolCard> _deck = {};

  int moves = 0;
  bool won = false;

  /// بطاقة تُنقل حالياً للأساس (لأنيميشن الإنهاء التلقائي)
  bool autoCompleting = false;

  final List<String> _undoStack = [];
  static const _undoCap = 300;

  void Function(String message)? onNotice;
  void _notice(String m) => onNotice?.call(m);

  // ─────────────────────────────────────────────
  //  التوزيع
  // ─────────────────────────────────────────────
  void _newGame() {
    _deck.clear();
    final cards = <SolCard>[
      for (var r = 1; r <= 13; r++)
        for (final s in SolSuit.values) SolCard(r, s),
    ]..shuffle(_random);
    for (final c in cards) {
      _deck[c.id] = c;
    }

    stock.clear();
    waste.clear();
    for (final f in foundations) {
      f.clear();
    }
    for (final t in tableau) {
      t.clear();
    }

    var k = 0;
    for (var i = 0; i < 7; i++) {
      for (var j = 0; j <= i; j++) {
        final c = cards[k++];
        c.faceUp = (j == i);
        tableau[i].add(c);
      }
    }
    while (k < 52) {
      stock.add(cards[k++]);
    }

    moves = 0;
    won = false;
    autoCompleting = false;
    _undoStack.clear();
    SolAudio.shuffle();
    notifyListeners();
  }

  void reset() => _newGame();

  // ─────────────────────────────────────────────
  //  لقطة تراجع
  // ─────────────────────────────────────────────
  String _snap() {
    String enc(List<SolCard> l) =>
        l.map((c) => c.id + (c.faceUp ? 64 : 0)).join(',');
    return '${enc(stock)};${enc(waste)};${foundations.map(enc).join(';')};${tableau.map(enc).join(';')}|$moves';
  }

  void _restore(String s) {
    final parts = s.split('|');
    moves = int.parse(parts[1]);
    final piles = parts[0].split(';');
    SolCard? dec(String v) {
      if (v.isEmpty) return null;
      final n = int.parse(v);
      final c = _deck[n % 64]!;
      c.faceUp = n >= 64;
      return c;
    }

    List<SolCard> fill(List<SolCard> dst, String enc) {
      dst.clear();
      if (enc.isEmpty) return dst;
      for (final v in enc.split(',')) {
        dst.add(dec(v)!);
      }
      return dst;
    }

    fill(stock, piles[0]);
    fill(waste, piles[1]);
    for (var i = 0; i < 4; i++) {
      fill(foundations[i], piles[2 + i]);
    }
    for (var i = 0; i < 7; i++) {
      fill(tableau[i], piles[6 + i]);
    }
    won = false;
    autoCompleting = false;
    notifyListeners();
  }

  void _pushUndo() {
    _undoStack.add(_snap());
    if (_undoStack.length > _undoCap) _undoStack.removeAt(0);
  }

  bool get canUndo => _undoStack.isNotEmpty && !autoCompleting;

  void undo() {
    if (!canUndo || won) return;
    _restore(_undoStack.removeLast());
    SolAudio.draw();
  }

  // ─────────────────────────────────────────────
  //  السحب
  // ─────────────────────────────────────────────
  void draw() {
    if (won || autoCompleting) return;
    if (stock.isEmpty) {
      if (waste.isEmpty) return;
      // إعادة التدوير: المهملات ترجع للمخزون مقلوبة
      _pushUndo();
      while (waste.isNotEmpty) {
        final c = waste.removeLast();
        c.faceUp = false;
        stock.add(c);
      }
      SolAudio.shuffle();
      notifyListeners();
      return;
    }
    _pushUndo();
    final c = stock.removeLast();
    c.faceUp = true;
    waste.add(c);
    moves++;
    SolAudio.draw();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  القواعد
  // ─────────────────────────────────────────────
  /// خانة الأساس المناسبة لبطاقة: نفس الشعار إن بدأت، أو خانة فارغة للآس
  int foundationSlotFor(SolCard c) {
    for (var i = 0; i < 4; i++) {
      final f = foundations[i];
      if (f.isNotEmpty && f.first.suit == c.suit) {
        return f.last.rank + 1 == c.rank ? i : -1;
      }
    }
    if (c.rank == 1) {
      for (var i = 0; i < 4; i++) {
        if (foundations[i].isEmpty) return i;
      }
    }
    return -1;
  }

  /// هل تُقبل البطاقة المتحركة على رأس العمود؟
  bool canDropOnTableau(SolCard moving, int col) {
    final t = tableau[col];
    if (t.isEmpty) return moving.rank == 13;
    final top = t.last;
    if (!top.faceUp) return false;
    return top.isRed != moving.isRed && top.rank == moving.rank + 1;
  }

  /// تسلسل صالح من عمود بدءاً من idx (كل الجزء المكشوف تسلسل صالح دائماً)
  List<SolCard> stackFrom(int col, int idx) =>
      tableau[col].sublist(idx).toList();

  // ─────────────────────────────────────────────
  //  النقل — src/dst: 'w'، 'f0..f3'، 't0..t6'
  // ─────────────────────────────────────────────
  List<SolCard>? _srcPile(String src) {
    if (src == 'w') return waste;
    if (src.startsWith('f')) return foundations[int.parse(src[1])];
    if (src.startsWith('t')) return tableau[int.parse(src[1])];
    return null;
  }

  /// نقل بطاقة/تسلسل من src[idx..] إلى عمود تابلو dst
  bool moveToTableau(String src, int idx, int dstCol) {
    if (won || autoCompleting) return false;
    final pile = _srcPile(src);
    if (pile == null || idx < 0 || idx >= pile.length) return false;
    // من غير التابلو يُسمح ببطاقة واحدة فقط (القمة)
    if (!src.startsWith('t') && idx != pile.length - 1) return false;
    final moving = pile[idx];
    if (!moving.faceUp) return false;
    if (!canDropOnTableau(moving, dstCol)) return false;
    if (src == 't$dstCol') return false;

    _pushUndo();
    final seg = pile.sublist(idx);
    pile.removeRange(idx, pile.length);
    tableau[dstCol].addAll(seg);
    _flipTop(src);
    moves++;
    SolAudio.place();
    notifyListeners();
    return true;
  }

  /// نقل بطاقة واحدة إلى خانة أساس
  bool moveToFoundation(String src, int idx) {
    if (won || autoCompleting) return false;
    final pile = _srcPile(src);
    if (pile == null || idx != pile.length - 1 || pile.isEmpty) return false;
    final c = pile.last;
    final slot = foundationSlotFor(c);
    if (slot == -1) return false;

    _pushUndo();
    pile.removeLast();
    foundations[slot].add(c);
    _flipTop(src);
    moves++;
    SolAudio.place();
    _checkWin();
    notifyListeners();
    return true;
  }

  /// اقلب آخر بطاقة مكشوفة بالمصدر بعد نقلها (للتابلو فقط)
  void _flipTop(String src) {
    if (!src.startsWith('t')) return;
    final col = tableau[int.parse(src[1])];
    if (col.isNotEmpty && !col.last.faceUp) {
      col.last.faceUp = true;
      SolAudio.flip();
    }
  }

  void _checkWin() {
    if (foundations.every((f) => f.length == 13)) {
      won = true;
      SolAudio.win();
    }
  }

  // ─────────────────────────────────────────────
  //  الإنهاء التلقائي: كل التابلو مكشوف → انقل كل شيء للأساس
  // ─────────────────────────────────────────────
  bool get canAutoComplete =>
      !won && !autoCompleting && tableau.every((t) => t.every((c) => c.faceUp));

  Future<void> autoComplete() async {
    if (!canAutoComplete) return;
    _pushUndo();
    autoCompleting = true;
    notifyListeners();
    _notice('✨ إنهاء تلقائي…'.tr);

    var guard = 0;
    while (!won && guard++ < 400) {
      var moved = false;
      // مهملات ثم قمم التابلو
      for (final src in [
        if (waste.isNotEmpty) 'w',
        for (var i = 0; i < 7; i++)
          if (tableau[i].isNotEmpty) 't$i',
      ]) {
        final pile = _srcPile(src)!;
        final c = pile.last;
        final slot = foundationSlotFor(c);
        if (slot != -1) {
          pile.removeLast();
          foundations[slot].add(c);
          moves++;
          SolAudio.place();
          notifyListeners();
          moved = true;
          await Future<void>.delayed(const Duration(milliseconds: 130));
          break;
        }
      }
      if (!moved) {
        if (stock.isNotEmpty) {
          final c = stock.removeLast();
          c.faceUp = true;
          waste.add(c);
          moves++;
          SolAudio.draw();
          notifyListeners();
          await Future<void>.delayed(const Duration(milliseconds: 110));
          continue;
        }
        break; // لا حركة — غير قابل للإنهاء بعد
      }
    }

    autoCompleting = false;
    _checkWin();
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  تلميح — أول حركة مفيدة
  // ─────────────────────────────────────────────
  (String, String)? hint() {
    // 1) مهملة/تابلو → أساس
    for (final src in [
      if (waste.isNotEmpty) 'w',
      for (var i = 0; i < 7; i++)
        if (tableau[i].isNotEmpty) 't$i',
    ]) {
      final pile = _srcPile(src)!;
      if (foundationSlotFor(pile.last) != -1) return (src, 'f');
    }
    // 2) مهملة → تابلو
    if (waste.isNotEmpty) {
      for (var d = 0; d < 7; d++) {
        if (canDropOnTableau(waste.last, d)) return ('w', 't$d');
      }
    }
    // 3) تسلسل من عمود مكشوف جزئياً → عمود آخر (يكشف بطاقة)
    for (var s = 0; s < 7; s++) {
      final col = tableau[s];
      for (var i = 0; i < col.length; i++) {
        if (!col[i].faceUp) continue;
        if (i == 0 && col.every((c) => c.faceUp))
          continue; // لا فائدة بنقل عمود كامل مكشوف إلا للفراغ
        for (var d = 0; d < 7; d++) {
          if (d == s) continue;
          if (canDropOnTableau(col[i], d) && !(i == 0 && tableau[d].isEmpty)) {
            return ('t$s', 't$d');
          }
        }
        break; // أول بطاقة مكشوفة فقط تكفي للتلميح
      }
    }
    // 4) ملك → عمود فارغ
    for (var s = 0; s < 7; s++) {
      final col = tableau[s];
      if (col.isEmpty) continue;
      for (var i = 0; i < col.length; i++) {
        if (col[i].faceUp && col[i].rank == 13 && i > 0) {
          for (var d = 0; d < 7; d++) {
            if (tableau[d].isEmpty) return ('t$s', 't$d');
          }
        }
      }
    }
    // 5) سحب من المخزون
    if (stock.isNotEmpty || waste.isNotEmpty) return ('stock', 'waste');
    return null;
  }

  bool get hasAnyMove =>
      hint() != null || (stock.isEmpty && waste.isEmpty) == false;
}
