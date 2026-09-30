import 'package:flutter/foundation.dart';

enum PieceType { pawn, knight, bishop, rook, queen, king }

enum ChessColor { white, black }

enum GameStatus { playing, check, checkmate, stalemate, draw }

class ChessPiece {
  static int _nextId = 0;
  final int id;
  final PieceType type;
  final ChessColor color;

  ChessPiece(this.type, this.color) : id = _nextId++;
}

class ChessMove {
  final int from;
  final int to;
  final PieceType? promotion;
  final bool isCastle;
  final bool isEnPassant;
  final bool isDoublePush;

  const ChessMove(
    this.from,
    this.to, {
    this.promotion,
    this.isCastle = false,
    this.isEnPassant = false,
    this.isDoublePush = false,
  });
}

class _Undo {
  ChessPiece? moved;
  ChessPiece? captured;
  int capturedSq = -1;
  int ep = -1;
  int half = 0;
  bool wk = false, wq = false, bk = false, bq = false;
}

/// محرك شطرنج كامل — كل القوانين: تبييت، أخذ بالتجاوز، ترقية، كش مات، تعادل
class ChessEngine extends ChangeNotifier {
  final List<ChessPiece?> board = List<ChessPiece?>.filled(64, null);

  ChessColor turn = ChessColor.white;
  bool wkCastle = true, wqCastle = true, bkCastle = true, bqCastle = true;
  int epSquare = -1;
  int halfmoveClock = 0;
  GameStatus status = GameStatus.playing;
  ChessMove? lastMove;

  final List<ChessMove> history = [];
  final List<_Undo> _undoStack = [];
  final List<ChessPiece> capturedByWhite = [];
  final List<ChessPiece> capturedByBlack = [];

  ChessEngine() {
    setup();
  }

  static int sq(int file, int rank) => rank * 8 + file;
  static int fileOf(int s) => s % 8;
  static int rankOf(int s) => s ~/ 8;
  static bool inBounds(int f, int r) => f >= 0 && f < 8 && r >= 0 && r < 8;
  static ChessColor opponent(ChessColor c) =>
      c == ChessColor.white ? ChessColor.black : ChessColor.white;

  void setup() {
    board.fillRange(0, 64, null);
    const back = [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.queen,
      PieceType.king,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ];
    for (int f = 0; f < 8; f++) {
      board[sq(f, 0)] = ChessPiece(back[f], ChessColor.black);
      board[sq(f, 1)] = ChessPiece(PieceType.pawn, ChessColor.black);
      board[sq(f, 6)] = ChessPiece(PieceType.pawn, ChessColor.white);
      board[sq(f, 7)] = ChessPiece(back[f], ChessColor.white);
    }
    turn = ChessColor.white;
    wkCastle = wqCastle = bkCastle = bqCastle = true;
    epSquare = -1;
    halfmoveClock = 0;
    status = GameStatus.playing;
    lastMove = null;
    history.clear();
    _undoStack.clear();
    capturedByWhite.clear();
    capturedByBlack.clear();
    notifyListeners();
  }

  int kingSquare(ChessColor c) {
    for (int i = 0; i < 64; i++) {
      final p = board[i];
      if (p != null && p.type == PieceType.king && p.color == c) return i;
    }
    return -1;
  }

  /// هل المربع [s] مهدد من قطع اللون [by]؟
  bool isAttacked(int s, ChessColor by) {
    final f = fileOf(s), r = rankOf(s);

    // هجوم البيادق
    final pr = by == ChessColor.white ? r + 1 : r - 1;
    for (final df in const [-1, 1]) {
      final nf = f + df;
      if (inBounds(nf, pr)) {
        final p = board[sq(nf, pr)];
        if (p != null && p.type == PieceType.pawn && p.color == by) return true;
      }
    }

    // هجوم الفرسان
    for (final o in const [
      [1, 2],
      [2, 1],
      [-1, 2],
      [-2, 1],
      [1, -2],
      [2, -1],
      [-1, -2],
      [-2, -1],
    ]) {
      final nf = f + o[0], nr = r + o[1];
      if (inBounds(nf, nr)) {
        final p = board[sq(nf, nr)];
        if (p != null && p.type == PieceType.knight && p.color == by) {
          return true;
        }
      }
    }

    // هجوم الملك المجاور
    for (int df = -1; df <= 1; df++) {
      for (int dr = -1; dr <= 1; dr++) {
        if (df == 0 && dr == 0) continue;
        final nf = f + df, nr = r + dr;
        if (inBounds(nf, nr)) {
          final p = board[sq(nf, nr)];
          if (p != null && p.type == PieceType.king && p.color == by) {
            return true;
          }
        }
      }
    }

    // انزلاق عمودي/أفقي (قلعة + وزير)
    for (final d in const [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1]
    ]) {
      var nf = f + d[0], nr = r + d[1];
      while (inBounds(nf, nr)) {
        final p = board[sq(nf, nr)];
        if (p != null) {
          if (p.color == by &&
              (p.type == PieceType.rook || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        nf += d[0];
        nr += d[1];
      }
    }

    // انزلاق قطري (فيل + وزير)
    for (final d in const [
      [1, 1],
      [1, -1],
      [-1, 1],
      [-1, -1]
    ]) {
      var nf = f + d[0], nr = r + d[1];
      while (inBounds(nf, nr)) {
        final p = board[sq(nf, nr)];
        if (p != null) {
          if (p.color == by &&
              (p.type == PieceType.bishop || p.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        nf += d[0];
        nr += d[1];
      }
    }
    return false;
  }

  void _addPawnMoves(
      List<ChessMove> out, int from, int to, bool reachesLastRank) {
    if (reachesLastRank) {
      for (final t in const [
        PieceType.queen,
        PieceType.rook,
        PieceType.bishop,
        PieceType.knight,
      ]) {
        out.add(ChessMove(from, to, promotion: t));
      }
    } else {
      out.add(ChessMove(from, to));
    }
  }

  /// حركات شبه قانونية (بدون فحص أمان الملك) — للمربع [s]
  List<ChessMove> pseudoMoves(int s) {
    final p = board[s];
    if (p == null) return const [];
    final out = <ChessMove>[];
    final f = fileOf(s), r = rankOf(s);
    final enemy = opponent(p.color);

    switch (p.type) {
      case PieceType.pawn:
        final dir = p.color == ChessColor.white ? -1 : 1;
        final startRank = p.color == ChessColor.white ? 6 : 1;
        final lastRank = p.color == ChessColor.white ? 0 : 7;

        // تقدم للأمام
        if (inBounds(f, r + dir) && board[sq(f, r + dir)] == null) {
          _addPawnMoves(out, s, sq(f, r + dir), r + dir == lastRank);
          if (r == startRank && board[sq(f, r + 2 * dir)] == null) {
            out.add(ChessMove(s, sq(f, r + 2 * dir), isDoublePush: true));
          }
        }
        // أخذ قطري + أخذ بالتجاوز
        for (final df in const [-1, 1]) {
          final nf = f + df, nr = r + dir;
          if (!inBounds(nf, nr)) continue;
          final t = sq(nf, nr);
          final target = board[t];
          if (target != null && target.color == enemy) {
            _addPawnMoves(out, s, t, nr == lastRank);
          } else if (t == epSquare) {
            out.add(ChessMove(s, t, isEnPassant: true));
          }
        }
        break;

      case PieceType.knight:
        for (final o in const [
          [1, 2],
          [2, 1],
          [-1, 2],
          [-2, 1],
          [1, -2],
          [2, -1],
          [-1, -2],
          [-2, -1],
        ]) {
          final nf = f + o[0], nr = r + o[1];
          if (!inBounds(nf, nr)) continue;
          final t = sq(nf, nr);
          final target = board[t];
          if (target == null || target.color == enemy) {
            out.add(ChessMove(s, t));
          }
        }
        break;

      case PieceType.bishop:
      case PieceType.rook:
      case PieceType.queen:
        final dirs = <List<int>>[];
        if (p.type != PieceType.bishop) {
          dirs.addAll(const [
            [1, 0],
            [-1, 0],
            [0, 1],
            [0, -1]
          ]);
        }
        if (p.type != PieceType.rook) {
          dirs.addAll(const [
            [1, 1],
            [1, -1],
            [-1, 1],
            [-1, -1]
          ]);
        }
        for (final d in dirs) {
          var nf = f + d[0], nr = r + d[1];
          while (inBounds(nf, nr)) {
            final t = sq(nf, nr);
            final target = board[t];
            if (target == null) {
              out.add(ChessMove(s, t));
            } else {
              if (target.color == enemy) out.add(ChessMove(s, t));
              break;
            }
            nf += d[0];
            nr += d[1];
          }
        }
        break;

      case PieceType.king:
        for (int df = -1; df <= 1; df++) {
          for (int dr = -1; dr <= 1; dr++) {
            if (df == 0 && dr == 0) continue;
            final nf = f + df, nr = r + dr;
            if (!inBounds(nf, nr)) continue;
            final t = sq(nf, nr);
            final target = board[t];
            if (target == null || target.color == enemy) {
              out.add(ChessMove(s, t));
            }
          }
        }
        // التبييت
        final home = p.color == ChessColor.white ? 7 : 0;
        if (r == home && f == 4) {
          final kingSide = p.color == ChessColor.white ? wkCastle : bkCastle;
          final queenSide = p.color == ChessColor.white ? wqCastle : bqCastle;
          if (kingSide &&
              board[sq(5, home)] == null &&
              board[sq(6, home)] == null &&
              board[sq(7, home)]?.type == PieceType.rook &&
              !isAttacked(sq(4, home), enemy) &&
              !isAttacked(sq(5, home), enemy) &&
              !isAttacked(sq(6, home), enemy)) {
            out.add(ChessMove(s, sq(6, home), isCastle: true));
          }
          if (queenSide &&
              board[sq(3, home)] == null &&
              board[sq(2, home)] == null &&
              board[sq(1, home)] == null &&
              board[sq(0, home)]?.type == PieceType.rook &&
              !isAttacked(sq(4, home), enemy) &&
              !isAttacked(sq(3, home), enemy) &&
              !isAttacked(sq(2, home), enemy)) {
            out.add(ChessMove(s, sq(2, home), isCastle: true));
          }
        }
        break;
    }
    return out;
  }

  _Undo _apply(ChessMove m) {
    final undo = _Undo()
      ..ep = epSquare
      ..half = halfmoveClock
      ..wk = wkCastle
      ..wq = wqCastle
      ..bk = bkCastle
      ..bq = bqCastle;

    final piece = board[m.from]!;
    undo.moved = piece;
    undo.captured = board[m.to];
    undo.capturedSq = m.to;

    board[m.from] = null;

    if (m.isEnPassant) {
      final dir = piece.color == ChessColor.white ? -1 : 1;
      undo.capturedSq = m.to + (dir * -8);
      undo.captured = board[undo.capturedSq];
      board[undo.capturedSq] = null;
    }

    board[m.to] =
        m.promotion != null ? ChessPiece(m.promotion!, piece.color) : piece;

    // تحريك القلعة في التبييت
    if (m.isCastle) {
      final home = piece.color == ChessColor.white ? 7 : 0;
      if (m.to == sq(6, home)) {
        board[sq(5, home)] = board[sq(7, home)];
        board[sq(7, home)] = null;
      } else {
        board[sq(3, home)] = board[sq(0, home)];
        board[sq(0, home)] = null;
      }
    }

    // تحديث حقوق التبييت
    if (piece.type == PieceType.king) {
      if (piece.color == ChessColor.white) {
        wkCastle = wqCastle = false;
      } else {
        bkCastle = bqCastle = false;
      }
    }
    for (final e in [
      [sq(7, 7), () => wkCastle = false],
      [sq(0, 7), () => wqCastle = false],
      [sq(7, 0), () => bkCastle = false],
      [sq(0, 0), () => bqCastle = false],
    ]) {
      if (m.from == e[0] || undo.capturedSq == e[0]) {
        (e[1] as void Function())();
      }
    }

    epSquare = m.isDoublePush ? (m.from + m.to) ~/ 2 : -1;
    halfmoveClock = (piece.type == PieceType.pawn || undo.captured != null)
        ? 0
        : halfmoveClock + 1;
    turn = opponent(turn);
    return undo;
  }

  void _unapply(_Undo u, ChessMove m) {
    turn = opponent(turn);
    epSquare = u.ep;
    halfmoveClock = u.half;
    wkCastle = u.wk;
    wqCastle = u.wq;
    bkCastle = u.bk;
    bqCastle = u.bq;

    board[m.from] = u.moved;
    board[m.to] = null;
    if (u.captured != null) board[u.capturedSq] = u.captured;

    if (m.isCastle) {
      final home = u.moved!.color == ChessColor.white ? 7 : 0;
      if (m.to == sq(6, home)) {
        board[sq(7, home)] = board[sq(5, home)];
        board[sq(5, home)] = null;
      } else {
        board[sq(0, home)] = board[sq(3, home)];
        board[sq(3, home)] = null;
      }
    }
  }

  /// الحركات القانونية من مربع معيّن (مع فحص أمان الملك)
  List<ChessMove> legalMovesFrom(int s) {
    final p = board[s];
    if (p == null) return const [];
    final out = <ChessMove>[];
    for (final m in pseudoMoves(s)) {
      final u = _apply(m);
      if (!isAttacked(kingSquare(p.color), opponent(p.color))) {
        out.add(m);
      }
      _unapply(u, m);
    }
    return out;
  }

  List<ChessMove> allLegalMoves(ChessColor c) {
    final out = <ChessMove>[];
    for (int i = 0; i < 64; i++) {
      final p = board[i];
      if (p != null && p.color == c) out.addAll(legalMovesFrom(i));
    }
    return out;
  }

  bool inCheck(ChessColor c) => isAttacked(kingSquare(c), opponent(c));

  bool insufficientMaterial() {
    int minors = 0;
    for (final p in board) {
      if (p == null || p.type == PieceType.king) continue;
      if (p.type == PieceType.bishop || p.type == PieceType.knight) {
        minors++;
        if (minors > 1) return false;
      } else {
        return false;
      }
    }
    return true;
  }

  void _updateStatus() {
    final moves = allLegalMoves(turn);
    final check = inCheck(turn);
    if (moves.isEmpty) {
      status = check ? GameStatus.checkmate : GameStatus.stalemate;
    } else if (insufficientMaterial() || halfmoveClock >= 100) {
      status = GameStatus.draw;
    } else {
      status = check ? GameStatus.check : GameStatus.playing;
    }
  }

  /// تنفيذ حركة على اللوحة الحقيقية
  void makeMove(ChessMove m) {
    final u = _apply(m);
    if (u.captured != null) {
      if (u.captured!.color == ChessColor.black) {
        capturedByWhite.add(u.captured!);
      } else {
        capturedByBlack.add(u.captured!);
      }
    }
    history.add(m);
    _undoStack.add(u);
    lastMove = m;
    _updateStatus();
    notifyListeners();
  }

  /// تراجع عن آخر حركة — يعيد القطعة المأخوذة ويحدّث الحالة
  bool undoMove() {
    if (history.isEmpty || _undoStack.isEmpty) return false;
    final m = history.removeLast();
    final u = _undoStack.removeLast();
    if (u.captured != null) {
      capturedByWhite.remove(u.captured);
      capturedByBlack.remove(u.captured);
    }
    _unapply(u, m);
    lastMove = history.isEmpty ? null : history.last;
    _updateStatus();
    notifyListeners();
    return true;
  }

  /// فرق المادة (موجب = لصالح الأبيض)
  int materialDiff() {
    int d = 0;
    for (final p in capturedByWhite) {
      d += ChessAI.valueOf(p.type);
    }
    for (final p in capturedByBlack) {
      d -= ChessAI.valueOf(p.type);
    }
    return d;
  }
}

/// ذكاء اصطناعي — Minimax مع Alpha-Beta بعمق 2
class ChessAI {
  static const _values = {
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.queen: 900,
    PieceType.king: 0,
  };

  static int valueOf(PieceType t) => _values[t]!;

  /// تقييم علني للموقف (موجب = لصالح الأبيض) — يُستخدم لعروض التعادل
  static int evaluate(ChessEngine e) => _eval(e);

  static int _eval(ChessEngine e) {
    int score = 0;
    for (int i = 0; i < 64; i++) {
      final p = e.board[i];
      if (p == null) continue;
      final sign = p.color == ChessColor.white ? 1 : -1;
      score += sign * _values[p.type]!;
      // مكافأة بسيطة للسيطرة على المركز
      final f = ChessEngine.fileOf(i), r = ChessEngine.rankOf(i);
      if (p.type != PieceType.king && f >= 2 && f <= 5 && r >= 2 && r <= 5) {
        score += sign * 8;
      }
    }
    return score;
  }

  static int _orderScore(ChessEngine e, ChessMove m) {
    final victim = e.board[m.to];
    final attacker = e.board[m.from];
    int s = 0;
    if (victim != null && attacker != null) {
      s = 10 * _values[victim.type]! - _values[attacker.type]!;
    }
    if (m.promotion != null) s += 800;
    return s;
  }

  static int _negamax(ChessEngine e, int depth, int alpha, int beta) {
    final moves = e.allLegalMoves(e.turn);
    if (moves.isEmpty) {
      return e.inCheck(e.turn) ? -99990 - depth : 0;
    }
    if (depth == 0) {
      return (e.turn == ChessColor.white ? 1 : -1) * _eval(e);
    }
    moves.sort((a, b) => _orderScore(e, b).compareTo(_orderScore(e, a)));
    var best = -1000000;
    for (final m in moves) {
      final u = e._apply(m);
      final s = -_negamax(e, depth - 1, -beta, -alpha);
      e._unapply(u, m);
      if (s > best) best = s;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  static ChessMove? bestMove(ChessEngine e, {int depth = 2}) {
    final moves = e.allLegalMoves(e.turn);
    if (moves.isEmpty) return null;
    moves.sort((a, b) => _orderScore(e, b).compareTo(_orderScore(e, a)));
    ChessMove? best;
    var bestScore = -1000000;
    for (final m in moves) {
      final u = e._apply(m);
      final s = -_negamax(e, depth - 1, -1000000, 1000000);
      e._unapply(u, m);
      if (s > bestScore) {
        bestScore = s;
        best = m;
      }
    }
    return best;
  }
}
