import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/store_service.dart';
import '../bg_themes.dart';
import 'bg_geometry.dart';
import 'bg_painters.dart';

/// معاينة سكن الطاولي في المتجر — لوح مصغّر حقيقي أو مجموعة أحجار ثري دي
class BgSkinPreview extends StatefulWidget {
  final String category;
  final String itemId;

  const BgSkinPreview({super.key, required this.category, required this.itemId});

  @override
  State<BgSkinPreview> createState() => _BgSkinPreviewState();
}

class _BgSkinPreviewState extends State<BgSkinPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fx =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));

  bool get _isBoard => widget.category == StoreCategory.bgBoard;
  BgBoardTheme get _board => _isBoard
      ? BgThemes.boardFromItemId(widget.itemId)
      : BgThemes.classic;
  BgCheckerSet get _set => _isBoard
      ? BgThemes.classicSet
      : BgThemes.checkersFromItemId(widget.itemId);

  @override
  void initState() {
    super.initState();
    if (_board.animated || _set.animated) _fx.repeat();
  }

  @override
  void dispose() {
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth.isFinite ? c.maxWidth : 220.0;
      final h = c.maxHeight.isFinite ? c.maxHeight : 130.0;
      return _isBoard ? _boardPreview(w, h) : _checkersPreview(w, h);
    });
  }

  Widget _boardPreview(double w, double h) {
    final bw = math.min(w, h * 1.45);
    final size = Size(bw, bw / 1.45);
    final g = BgGeom(size);
    final s = [
      (23, 2, 0), (12, 5, 0), (7, 3, 0), (5, 5, 0),
      (0, 2, 1), (11, 5, 1), (16, 3, 1), (18, 5, 1),
    ];
    return Center(
      child: SizedBox.fromSize(
        size: size,
        child: AnimatedBuilder(
          animation: _fx,
          builder: (_, __) => Stack(children: [
            CustomPaint(
                size: size,
                painter: BackgammonBoardPainter(g,
                    theme: _board, wood: StoreService().defaultWoodImage)),
            if (_board.animated)
              CustomPaint(
                  size: size,
                  painter: BoardEffectPainter(g, _board, _fx.value)),
            for (final (p, n, side) in s)
              for (int k = 0; k < n; k++)
                Positioned(
                  left: g.checker(p, k, n).dx - g.d / 2,
                  top: g.checker(p, k, n).dy - g.d / 2,
                  width: g.d,
                  height: g.d,
                  child: CustomPaint(
                      painter: CheckerPainter(style: _set.of(side))),
                ),
          ]),
        ),
      ),
    );
  }

  Widget _checkersPreview(double w, double h) {
    final d = math.min(h * 0.42, w / 4.2);
    return AnimatedBuilder(
      animation: _fx,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: RadialGradient(colors: [
            BgThemes.classic.fieldColors[0],
            BgThemes.classic.fieldColors[2],
          ]),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int side = 0; side < 2; side++)
              for (int k = 0; k < 3; k++)
                Positioned(
                  left: w / 2 + (side == 0 ? -d * 1.2 : d * 0.2),
                  top: h / 2 - d / 2 + (1 - k) * d * 0.32,
                  width: d,
                  height: d,
                  child: CustomPaint(
                    painter: CheckerPainter(
                        style: _set.of(side), time: _fx.value, seed: k),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
