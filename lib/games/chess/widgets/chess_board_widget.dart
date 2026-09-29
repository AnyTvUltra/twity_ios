import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../chess_engine.dart';
import '../chess_piece_metrics.dart';

/// لوحة الشطرنج ثنائية الأبعاد — قطع PNG حقيقية + إطار أنيق + إبرازات ذهبية
class ChessBoardWidget extends StatefulWidget {
  final ChessEngine engine;
  final int? selected;
  final Set<int> legalTargets;
  final Set<int> captureTargets;
  final void Function(int square) onSquareTap;
  final void Function(int from, int to) onPieceDrop;

  /// نسيج صورة سكن اللوحة من المتجر (اختياري)
  final ui.Image? boardImage;

  /// تلوين سكن القطع من المتجر (اختياري) — لون متوسط صورة السكن
  final Color? pieceTint;

  /// يتغير عند كل لعبة جديدة ليعاد تشغيل أنيميشن السقوط
  final int introSeed;

  const ChessBoardWidget({
    super.key,
    required this.engine,
    required this.selected,
    required this.legalTargets,
    required this.captureTargets,
    required this.onSquareTap,
    required this.onPieceDrop,
    this.boardImage,
    this.pieceTint,
    this.introSeed = 0,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _Ghost {
  final ChessPiece piece;
  final int square;
  final int key;
  const _Ghost(this.piece, this.square, this.key);
}

class _ChessBoardWidgetState extends State<ChessBoardWidget>
    with SingleTickerProviderStateMixin {
  static const double _tilt = 0.22;
  late final AnimationController _pulse;
  final List<_Ghost> _ghosts = [];
  int _ghostSeq = 0;
  int _seenSeed = -1;

  /// القطع الموجودة في الإطار السابق: pieceId -> (piece, square)
  final Map<int, (ChessPiece, int)> _prevPieces = {};

  // الارتفاع المرئي للقطعة كنسبة من المربع
  static const _heights = {
    PieceType.pawn: 0.66,
    PieceType.rook: 0.74,
    PieceType.knight: 0.82,
    PieceType.bishop: 0.88,
    PieceType.queen: 0.97,
    PieceType.king: 1.04,
  };

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// يقارن اللوحة الحالية بالسابقة ويضيف شبحاً لكل قطعة اختفت (قتل)
  void _detectCaptures() {
    if (widget.introSeed != _seenSeed) {
      _seenSeed = widget.introSeed;
      _prevPieces.clear();
      _ghosts.clear();
    }
    final cur = <int, (ChessPiece, int)>{};
    for (int i = 0; i < 64; i++) {
      final p = widget.engine.board[i];
      if (p != null) cur[p.id] = (p, i);
    }
    for (final e in _prevPieces.entries) {
      if (!cur.containsKey(e.key)) {
        final g = _Ghost(e.value.$1, e.value.$2, _ghostSeq++);
        _ghosts.add(g);
        Timer(const Duration(milliseconds: 430), () {
          if (mounted) setState(() => _ghosts.remove(g));
        });
      }
    }
    _prevPieces
      ..clear()
      ..addAll(cur);
  }

  int? get _checkedKingSq {
    if (widget.engine.status != GameStatus.check) return null;
    return widget.engine.kingSquare(widget.engine.turn);
  }

  String _assetFor(ChessPiece p) =>
      'assets/images/chess/'
      '${p.color == ChessColor.white ? 'white' : 'black'}'
      '_${p.type.name}.png';

  String _keyFor(ChessPiece p) =>
      '${p.color == ChessColor.white ? 'white' : 'black'}'
      '_${p.type.name}';

  /// نقطة ارتكاز القطعة داخل المربع: مركز قاعدتها على مركز المربع
  /// أفقياً تماماً، وأخفض بقليل عمودياً لتبدو مزروعة في الخانة
  static const double _baseAnchorY = 0.60;

  Widget _pieceImage(ChessPiece p, double height, {bool ghost = false}) {
    Widget img = Image.asset(
      _assetFor(p),
      height: height,
      fit: BoxFit.fitHeight,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    final tint = widget.pieceTint;
    if (tint != null) {
      img = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.hue),
        child: img,
      );
    }
    return img;
  }

  /// هندسة قطعة داخل مربع: ترجع (left, top, w, h) بإحداثيات اللوحة
  /// بحيث يقع مركز قاعدة القطعة على نقطة الارتكاز بدقة.
  Rect _pieceRect(ChessPiece p, double f, double r, double s,
      double frame, double ph) {
    final m = chessPieceMetrics[_keyFor(p)]!;
    final drawnH = ph / m.visH;
    final drawnW = drawnH * m.aspect;
    final cx = frame + (f + 0.5) * s; // مركز المربع X
    final baseY = frame + (r + _baseAnchorY) * s; // نقطة القاعدة
    return Rect.fromLTWH(
        cx - m.baseX * drawnW, baseY - m.visB * drawnH, drawnW, drawnH);
  }

  @override
  Widget build(BuildContext context) {
    _detectCaptures();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final frame = size * 0.034;
        final inner = size - frame * 2;
        final s = inner / 8;
        final checkedSq = _checkedKingSq;

        final children = <Widget>[
          CustomPaint(
            size: Size(size, size),
            painter: _ChessBoardPainter(
              engine: widget.engine,
              frame: frame,
              selected: widget.selected,
              legalTargets: widget.legalTargets,
              captureTargets: widget.captureTargets,
              boardImage: widget.boardImage,
              pulse: _pulse,
            ),
          ),
          // طبقة اللمس + الإفلات
          Positioned(
            left: frame,
            top: frame,
            width: inner,
            height: inner,
            child: Builder(
              builder: (innerCtx) => DragTarget<int>(
                onAcceptWithDetails: (details) {
                  final box = innerCtx.findRenderObject() as RenderBox;
                  final local = box.globalToLocal(details.offset);
                  final f = (local.dx / s).floor();
                  final r = (local.dy / s).floor();
                  if (ChessEngine.inBounds(f, r)) {
                    widget.onPieceDrop(details.data, ChessEngine.sq(f, r));
                  }
                },
                builder: (context, _, __) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    final f = (d.localPosition.dx / s).floor();
                    final r = (d.localPosition.dy / s).floor();
                    if (ChessEngine.inBounds(f, r)) {
                      widget.onSquareTap(ChessEngine.sq(f, r));
                    }
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ];

        // ═══ الأحجار — مركز القاعدة على مركز المربع هندسياً ═══
        for (int i = 0; i < 64; i++) {
          final p = widget.engine.board[i];
          if (p == null) continue;
          final f = ChessEngine.fileOf(i);
          final r = ChessEngine.rankOf(i);
          final delay = (r * 8 + f) / 64 * 0.55;
          final isCheckedKing = checkedSq == i;
          final ph = s * _heights[p.type]!;
          final rect = _pieceRect(p, f.toDouble(), r.toDouble(),
              s, frame, ph);

          children.add(
            AnimatedPositioned(
              key: ValueKey('piece_${p.id}'),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('drop_${p.id}_${widget.introSeed}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Interval(delay, 1.0, curve: Curves.bounceOut),
                builder: (context, v, child) => Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -(1 - v) * s * 5.5),
                    child: child,
                  ),
                ),
                child: _Upright(
                  tilt: _tilt,
                  cellSize: s,
                  shake: isCheckedKing ? _pulse : null,
                  child: _DraggablePiece(
                    piece: p,
                    square: i,
                    pieceHeight: rect.height,
                    isSelected: widget.selected == i,
                    tint: widget.pieceTint,
                    imageBuilder: _pieceImage,
                    onTap: () => widget.onSquareTap(i),
                  ),
                ),
              ),
            ),
          );
        }

        // ═══ أشباح القتل — نفس نقطة الارتكاز ═══
        for (final g in _ghosts) {
          final f = ChessEngine.fileOf(g.square);
          final r = ChessEngine.rankOf(g.square);
          final rect = _pieceRect(g.piece, f.toDouble(),
              r.toDouble(), s, frame,
              s * _heights[g.piece.type]!);
          children.add(
            Positioned(
              key: ValueKey('ghost_${g.key}'),
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeIn,
                builder: (context, v, child) => Opacity(
                  opacity: (1 - v).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 - v * 0.4,
                    child: Transform.translate(
                      offset: Offset(0, -v * s * 0.5),
                      child: Transform.rotate(
                        angle: v * 0.4,
                        child: child,
                      ),
                    ),
                  ),
                ),
                child: _pieceImage(
                    g.piece, s * _heights[g.piece.type]!,
                    ghost: true),
              ),
            ),
          );
        }

        final board = SizedBox(
          width: size,
          height: size,
          child: Stack(clipBehavior: Clip.none, children: children),
        );

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateX(_tilt);

        return Transform(
          transform: matrix,
          alignment: const Alignment(0, 0.55),
          child: board,
        );
      },
    );
  }
}

/// يعكس ميلان اللوحة لتبقى القطعة قائمة مواجهة
class _Upright extends StatelessWidget {
  final double tilt;
  final double cellSize;
  final Animation<double>? shake;
  final Widget child;

  const _Upright({
    required this.tilt,
    required this.cellSize,
    required this.child,
    this.shake,
  });

  @override
  Widget build(BuildContext context) {
    Widget w = Transform(
      transform: Matrix4.identity()..rotateX(-tilt),
      alignment: Alignment.center,
      child: child,
    );
    if (shake != null) {
      w = AnimatedBuilder(
        animation: shake!,
        builder: (context, c) => Transform.translate(
          offset:
              Offset(math.sin(shake!.value * math.pi * 4) * 2.4, 0),
          child: c,
        ),
        child: w,
      );
    }
    return w;
  }
}

class _DraggablePiece extends StatelessWidget {
  final ChessPiece piece;
  final int square;

  /// ارتفاع الصورة المرسومة الكامل (يشمل الحواف الشفافة)
  final double pieceHeight;
  final bool isSelected;
  final Color? tint;
  final Widget Function(ChessPiece, double, {bool ghost}) imageBuilder;
  final VoidCallback onTap;

  const _DraggablePiece({
    required this.piece,
    required this.square,
    required this.pieceHeight,
    required this.isSelected,
    required this.imageBuilder,
    required this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final m = chessPieceMetrics[
        '${piece.color == ChessColor.white ? 'white' : 'black'}'
            '_${piece.type.name}']!;
    final drawnW = pieceHeight * m.aspect;
    final body = SizedBox(
      width: drawnW,
      height: pieceHeight,
      child: imageBuilder(piece, pieceHeight),
    );

    return GestureDetector(
      onTap: onTap,
      child: Draggable<int>(
        data: square,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: drawnW * 1.25,
            height: pieceHeight * 1.25,
            child: imageBuilder(piece, pieceHeight * 1.25),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.2, child: body),
        child: body,
      ),
    );
  }
}

class _ChessBoardPainter extends CustomPainter {
  final ChessEngine engine;
  final double frame;
  final int? selected;
  final Set<int> legalTargets;
  final Set<int> captureTargets;
  final ui.Image? boardImage;
  final Animation<double> pulse;

  // هوية Neon Violet — مطابقة للمرجع: مربعات لافندر باستيل + بنفسجي متوسط
  static const _lightSq = Color(0xFFE9E2F6); // Pearl Lavender شبه أبيض
  static const _darkSq = Color(0xFF57488C); // Medium Violet
  static const _frameTop = Color(0xFF4A3578); // بنفسجي
  static const _frameBottom = Color(0xFF1E1138); // بنفسجي داكن
  static const _frameEdge = Color(0xFF120A26);
  static const _coord = Color(0xFFBFAEE6);
  static const _accent = Color(0xFF3FF5A8); // Neon Mint
  static const _glow = Color(0xFF7C4DFF); // Purple Glow
  static const _lastMove = Color(0xFFCBB5F0); // Lavender خافت لآخر حركة

  /// نقطة قاعدة القطعة داخل المربع (مركزه) — مطابق لـ _baseAnchorY
  static const double _anchorY = 0.6;

  _ChessBoardPainter({
    required this.engine,
    required this.frame,
    required this.selected,
    required this.legalTargets,
    required this.captureTargets,
    required this.pulse,
    this.boardImage,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final inner = w - frame * 2;
    final s = inner / 8;
    final outer = Rect.fromLTWH(0, 0, w, w);
    final rrect = RRect.fromRectAndRadius(
        outer, Radius.circular(w * 0.028));

    // ═══ هالة بنفسجية نيونية حول الرقعة (كالمرجع) ═══
    canvas.drawRRect(
      rrect.inflate(w * 0.008),
      Paint()
        ..color = _glow.withOpacity(0.32)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, w * 0.03),
    );

    // ═══ سماكة اللوحة السفلية ═══
    final thickness = w * 0.032;
    final slabPath = Path()
      ..moveTo(w * 0.02, w)
      ..lineTo(w * 0.98, w)
      ..lineTo(w * 0.955, w + thickness)
      ..lineTo(w * 0.045, w + thickness)
      ..close();
    canvas.drawPath(
      slabPath.shift(const Offset(0, 7)),
      Paint()
        ..color = Colors.black.withOpacity(0.45)
        ..maskFilter =
            const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      slabPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _frameBottom,
            Color.lerp(_frameEdge, _glow, 0.18)!
          ],
        ).createShader(Rect.fromLTWH(0, w, w, thickness + 4)),
    );

    // ═══ الإطار ═══
    if (boardImage != null) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawImageRect(
        boardImage!,
        Rect.fromLTWH(0, 0, boardImage!.width.toDouble(),
            boardImage!.height.toDouble()),
        outer,
        Paint()..filterQuality = FilterQuality.medium,
      );
      canvas.restore();
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x66000000),
      );
    } else {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_frameTop, _frameBottom],
          ).createShader(outer),
      );
    }
    // شطبة مضيئة أعلى الإطار
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, w * 0.5));
    canvas.drawRRect(
      rrect.deflate(0.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(0.18),
    );
    canvas.restore();
    // إضاءة بنفسجية على الحافة السفلية
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, w * 0.7, w, w * 0.3));
    canvas.drawRRect(
      rrect.deflate(1.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _glow.withOpacity(0.30),
            _glow.withOpacity(0.30),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, w * 0.7, w, w * 0.3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();

    // ═══ المربعات ═══
    final boardRect = Rect.fromLTWH(frame, frame, inner, inner);
    canvas.save();
    canvas.clipRect(boardRect);
    if (boardImage != null) {
      canvas.drawImageRect(
        boardImage!,
        Rect.fromLTWH(0, 0, boardImage!.width.toDouble(),
            boardImage!.height.toDouble()),
        boardRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final light = (r + f) % 2 == 0;
        final rect =
            Rect.fromLTWH(frame + f * s, frame + r * s, s, s);
        if (boardImage != null) {
          canvas.drawRect(
            rect,
            Paint()
              ..color = light
                  ? _lightSq.withOpacity(0.30)
                  : _darkSq.withOpacity(0.62),
          );
        } else {
          canvas.drawRect(
            rect,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: light
                    ? [
                        Color.lerp(_lightSq, Colors.white, 0.10)!,
                        _lightSq,
                      ]
                    : [
                        Color.lerp(_darkSq, Colors.white, 0.06)!,
                        _darkSq,
                      ],
              ).createShader(rect),
          );
        }
      }
    }
    // إضاءة قطرية ناعمة + فينييت حواف — مزاج داكن راقٍ
    canvas.drawRect(
      boardRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.transparent,
            Colors.black.withOpacity(0.13),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(boardRect),
    );
    canvas.drawRect(
      boardRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            Colors.transparent,
            const Color(0xFF0D0718).withOpacity(0.10),
          ],
          stops: const [0.62, 1.0],
        ).createShader(boardRect),
    );

    // ═══ ظلال أرضية ناعمة تحت الأحجار — عند مركز كل مربع ═══
    for (int i = 0; i < 64; i++) {
      if (engine.board[i] == null) continue;
      final cx = frame + (ChessEngine.fileOf(i) + 0.5) * s;
      final cy = frame + (ChessEngine.rankOf(i) + _anchorY) * s;
      final shRect = Rect.fromCenter(
          center: Offset(cx, cy), width: s * 0.62, height: s * 0.17);
      canvas.drawOval(
        shRect,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ]).createShader(shRect),
      );
    }

    // ═══ الإبرازات ═══
    void fillSq(int sq, Color c) {
      final f = ChessEngine.fileOf(sq), r = ChessEngine.rankOf(sq);
      canvas.drawRect(
          Rect.fromLTWH(frame + f * s, frame + r * s, s, s),
          Paint()..color = c);
    }

    final lm = engine.lastMove;
    if (lm != null) {
      fillSq(lm.from, _lastMove.withOpacity(0.18));
      fillSq(lm.to, _lastMove.withOpacity(0.28));
    }

    // الملك المهدد — هالة حمراء نابضة
    for (final c in [ChessColor.white, ChessColor.black]) {
      if (engine.inCheck(c)) {
        final k = engine.kingSquare(c);
        final f = ChessEngine.fileOf(k), r = ChessEngine.rankOf(k);
        final center =
            Offset(frame + f * s + s / 2, frame + r * s + s / 2);
        final wave = math.sin(pulse.value * math.pi * 2);
        canvas.drawCircle(
          center,
          s * (0.5 + 0.1 * wave),
          Paint()
            ..shader = RadialGradient(colors: [
              const Color(0xFFEF4444)
                  .withOpacity(0.55 + 0.3 * wave),
              const Color(0xFFEF4444).withOpacity(0.15),
              Colors.transparent,
            ]).createShader(
                Rect.fromCircle(center: center, radius: s * 0.62)),
        );
      }
    }

    if (selected != null) {
      final f = ChessEngine.fileOf(selected!);
      final r = ChessEngine.rankOf(selected!);
      final selRect =
          Rect.fromLTWH(frame + f * s, frame + r * s, s, s);
      canvas.drawRect(
        selRect,
        Paint()
          ..shader = RadialGradient(colors: [
            _accent.withOpacity(0.5),
            _accent.withOpacity(0.15),
          ]).createShader(selRect.inflate(s * 0.15)),
      );
      canvas.drawRect(
        selRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _accent.withOpacity(0.95),
      );
    }

    // نقطة نعناعية صغيرة متوهجة للحركة العادية
    for (final t in legalTargets) {
      final f = ChessEngine.fileOf(t), r = ChessEngine.rankOf(t);
      final center =
          Offset(frame + f * s + s / 2, frame + r * s + s / 2);
      canvas.drawCircle(
        center,
        s * 0.15,
        Paint()
          ..color = _accent.withOpacity(0.4)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, s * 0.08),
      );
      canvas.drawCircle(center, s * 0.10,
          Paint()..color = _accent.withOpacity(0.9));
    }
    // حلقة نعناعية للأخذ
    for (final t in captureTargets) {
      final f = ChessEngine.fileOf(t), r = ChessEngine.rankOf(t);
      final center =
          Offset(frame + f * s + s / 2, frame + r * s + s / 2);
      canvas.drawCircle(
        center,
        s * 0.38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.055
          ..color = _accent.withOpacity(0.85),
      );
      canvas.drawCircle(
        center,
        s * 0.38,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.055
          ..color = _accent.withOpacity(0.4)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, s * 0.06),
      );
    }

    // ظل داخلي خفيف داخل حدود الرقعة — إحساس بالعمق
    canvas.drawRect(
      boardRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09
        ..color = const Color(0xFF150D24).withOpacity(0.35)
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, s * 0.07),
    );

    canvas.restore();
    // حد رفيع لامع بنفسجي حول الرقعة
    canvas.drawRect(
      boardRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = _glow.withOpacity(0.55),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _glow.withOpacity(0.65),
    );

    // ═══ الإحداثيات — صغيرة داخل مربعات الأطراف ═══
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final coordPaint = _coord.withOpacity(0.6);
    for (int f = 0; f < 8; f++) {
      // الحروف أسفل-يمين مربعات الصف الأخير
      _drawText(canvas, files[f],
          Offset(frame + f * s + s * 0.85,
              frame + 7 * s + s * 0.83),
          s * 0.15, coordPaint);
      // الأرقام أعلى-يسار مربعات العمود الأول
      _drawText(canvas, '${8 - f}',
          Offset(frame + s * 0.15,
              frame + f * s + s * 0.16),
          s * 0.15, coordPaint);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center,
      double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChessBoardPainter old) => true;
}
