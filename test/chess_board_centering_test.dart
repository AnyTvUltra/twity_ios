import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/chess/chess_engine.dart';
import 'package:game_hub/games/chess/chess_piece_metrics.dart';
import 'package:game_hub/games/chess/widgets/chess_board_widget.dart';

void main() {
  testWidgets('قاعدة كل حجر على مركز مربعه بالضبط في الـ64 خانة',
      (tester) async {
    const boardSize = 400.0;
    final engine = ChessEngine()..setup();
    var drops = <int, int>{};
    var taps = <int>{};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: ChessBoardWidget(
              engine: engine,
              selected: null,
              legalTargets: const {},
              captureTargets: const {},
              onSquareTap: (s) => taps.add(s),
              onPieceDrop: (f, t) => drops[f] = t,
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    // نفس حسابات الودجت الداخلية
    const size = boardSize;
    const frame = size * 0.034;
    const inner = size - frame * 2;
    const s = inner / 8;

    final positions =
        tester.widgetList<AnimatedPositioned>(find.byType(AnimatedPositioned));

    var checked = 0;
    for (final ap in positions) {
      final key = ap.key as ValueKey<String>;
      if (!key.value.startsWith('piece_')) continue;
      final id = int.parse(key.value.substring(6));

      // نجد القطعة ومربعها من المحرك
      int sq = -1;
      ChessPiece? piece;
      for (int i = 0; i < 64; i++) {
        final p = engine.board[i];
        if (p != null && p.id == id) {
          sq = i;
          piece = p;
          break;
        }
      }
      expect(piece, isNotNull, reason: 'piece $id موجودة');

      final m = chessPieceMetrics[
          '${piece!.color == ChessColor.white ? 'white' : 'black'}'
              '_${piece.type.name}']!;

      // مركز قاعدة القطعة بإحداثيات اللوحة
      final baseCX = ap.left! + m.baseX * ap.width!;
      final baseCY = ap.top! + m.visB * ap.height!;

      // مركز المربع أفقياً + نقطة ارتكاز القاعدة عمودياً (0.60)
      final f = ChessEngine.fileOf(sq);
      final r = ChessEngine.rankOf(sq);
      final tileCX = frame + (f + 0.5) * s;
      final tileCY = frame + (r + 0.6) * s;

      expect(baseCX, closeTo(tileCX, 0.01),
          reason: '${key.value} على مربع $sq: X ${baseCX.toStringAsFixed(2)}'
              ' != $tileCX');
      expect(baseCY, closeTo(tileCY, 0.01),
          reason: '${key.value} على مربع $sq: Y ${baseCY.toStringAsFixed(2)}'
              ' != $tileCY');
      checked++;
    }
    expect(checked, 32, reason: 'كل الأحجار الـ32 الابتدائية');
  });

  test('الـ12 حجراً كلها لها قياسات صالحة وقاعدة داخل الصورة', () {
    for (final c in ['white', 'black']) {
      for (final t in [
        'pawn', 'rook', 'knight', 'bishop', 'queen', 'king'
      ]) {
        final m = chessPieceMetrics['${c}_$t'];
        expect(m, isNotNull, reason: '$c $t');
        expect(m!.baseX, inInclusiveRange(0.35, 0.65));
        expect(m.visB, greaterThan(0.9));
        expect(m.visT, greaterThanOrEqualTo(0));
        expect(m.aspect, greaterThan(0.2));
      }
    }
  });
}
