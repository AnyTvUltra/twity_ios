import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/chess/chess_engine.dart';

void main() {
  test('الوضع الابتدائي: 20 حركة قانونية للأبيض', () {
    final e = ChessEngine();
    expect(e.allLegalMoves(ChessColor.white).length, 20);
    expect(e.allLegalMoves(ChessColor.black).length, 20);
  });

  test('كش مات بأحمق مات (Fool\'s mate)', () {
    final e = ChessEngine();
    // f3 e5 g4 Qh4#
    void mv(int ff, int fr, int tf, int tr) {
      final m = e
          .allLegalMoves(e.turn)
          .firstWhere((m) =>
              m.from == ChessEngine.sq(ff, fr) &&
              m.to == ChessEngine.sq(tf, tr));
      e.makeMove(m);
    }

    mv(5, 6, 5, 5); // f3
    mv(4, 1, 4, 3); // e5
    mv(6, 6, 6, 4); // g4
    mv(3, 0, 7, 4); // Qh4#
    expect(e.status, GameStatus.checkmate);
    expect(e.turn, ChessColor.white);
  });

  test('التبييت يعمل بعد إخلاء الطريق', () {
    final e = ChessEngine();
    // أخلِ المربعات بين الملك والقلعة
    e.board[ChessEngine.sq(5, 7)] = null;
    e.board[ChessEngine.sq(6, 7)] = null;
    final moves = e.legalMovesFrom(ChessEngine.sq(4, 7));
    expect(moves.any((m) => m.isCastle && m.to == ChessEngine.sq(6, 7)),
        true);
    // نفّذ التبييت
    e.makeMove(moves.firstWhere(
        (m) => m.isCastle && m.to == ChessEngine.sq(6, 7)));
    expect(e.board[ChessEngine.sq(6, 7)]?.type, PieceType.king);
    expect(e.board[ChessEngine.sq(5, 7)]?.type, PieceType.rook);
  });

  test('الأخذ بالتجاوز يعمل', () {
    final e = ChessEngine();
    void mv(int ff, int fr, int tf, int tr) {
      final m = e
          .allLegalMoves(e.turn)
          .firstWhere((m) =>
              m.from == ChessEngine.sq(ff, fr) &&
              m.to == ChessEngine.sq(tf, tr));
      e.makeMove(m);
    }

    mv(4, 6, 4, 4); // e4 أبيض
    mv(0, 1, 0, 2); // a6 أسود
    mv(4, 4, 4, 3); // e5 أبيض
    mv(3, 1, 3, 3); // d5 أسود (دفعة مزدوجة)
    // الأبيض يأخذ بالتجاوز: e5xd6
    final ep = e.legalMovesFrom(ChessEngine.sq(4, 3))
        .firstWhere((m) => m.isEnPassant);
    expect(ep.to, ChessEngine.sq(3, 2));
    e.makeMove(ep);
    expect(e.board[ChessEngine.sq(3, 2)]?.type, PieceType.pawn);
    expect(e.board[ChessEngine.sq(3, 3)], isNull); // البيدق المأخوذ اختفى
  });

  test('الترقية تنتج وزير', () {
    final e = ChessEngine();
    // ضع بيدق أبيض على وشك الترقية
    e.board.fillRange(0, 64, null);
    e.board[ChessEngine.sq(4, 1)] =
        ChessPiece(PieceType.pawn, ChessColor.white);
    e.board[ChessEngine.sq(4, 7)] =
        ChessPiece(PieceType.king, ChessColor.white);
    e.board[ChessEngine.sq(0, 0)] =
        ChessPiece(PieceType.king, ChessColor.black);
    final moves = e.legalMovesFrom(ChessEngine.sq(4, 1));
    final promos = moves.where((m) => m.promotion != null).toList();
    expect(promos.length, 4);
    e.makeMove(
        promos.firstWhere((m) => m.promotion == PieceType.queen));
    expect(e.board[ChessEngine.sq(4, 0)]?.type, PieceType.queen);
  });

  test('الذكاء الاصطناعي يرجع حركة قانونية', () {
    final e = ChessEngine();
    final m = ChessAI.bestMove(e, depth: 2);
    expect(m, isNotNull);
    e.makeMove(m!);
    expect(e.turn, ChessColor.black);
  });
}
