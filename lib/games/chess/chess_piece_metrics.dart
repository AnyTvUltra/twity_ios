/// قياسات هندسية لأحجار الشطرنج — مولّدة بـ tool/gen_piece_metrics.py
/// baseX: مركز قاعدة القطعة (نسبة من عرض الصورة)
/// visT/visB/visL/visR: حدود البكسلات المعتمة (نسبة من أبعاد الصورة)
class ChessPieceMetric {
  final double aspect;
  final double visL, visT, visR, visB;
  final double baseX;
  const ChessPieceMetric(
      this.aspect, this.visL, this.visT, this.visR, this.visB, this.baseX);
  double get visW => visR - visL;
  double get visH => visB - visT;
}

const Map<String, ChessPieceMetric> chessPieceMetrics = {
  'white_pawn':
      ChessPieceMetric(0.65644, 0.00000, 0.00000, 1.00000, 1.00000, 0.50519),
  'white_rook':
      ChessPieceMetric(0.58630, 0.00000, 0.00000, 1.00000, 1.00000, 0.50487),
  'white_knight':
      ChessPieceMetric(0.59723, 0.00000, 0.00000, 1.00000, 1.00000, 0.53248),
  'white_bishop':
      ChessPieceMetric(0.46930, 0.00000, 0.00000, 1.00000, 1.00000, 0.50379),
  'white_queen':
      ChessPieceMetric(0.41031, 0.00000, 0.00000, 1.00000, 1.00000, 0.50137),
  'white_king':
      ChessPieceMetric(0.35682, 0.00000, 0.00000, 1.00000, 1.00000, 0.49680),
  'black_pawn':
      ChessPieceMetric(0.65567, 0.00000, 0.00000, 1.00000, 1.00000, 0.49302),
  'black_rook':
      ChessPieceMetric(0.58670, 0.00000, 0.00000, 1.00000, 1.00000, 0.49350),
  'black_knight':
      ChessPieceMetric(0.59758, 0.00000, 0.00000, 1.00000, 1.00000, 0.46585),
  'black_bishop':
      ChessPieceMetric(0.46930, 0.00000, 0.00000, 1.00000, 1.00000, 0.49507),
  'black_queen':
      ChessPieceMetric(0.40983, 0.00000, 0.00000, 1.00000, 1.00000, 0.49762),
  'black_king':
      ChessPieceMetric(0.35682, 0.00000, 0.00000, 1.00000, 1.00000, 0.50151),
};
