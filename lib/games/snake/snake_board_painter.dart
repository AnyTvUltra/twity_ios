import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'snake_engine.dart';

/// هندسة لوحة الحية والدرج + الرسّام — الإطار الخشبي، اللباد الأخضر،
/// الخلايا المتعرجة، الدرجات الخشبية، والحيات بجسم S متدرّج.
/// يصدّر cellCenter/snakePoint لتحريك الأحجار على نفس الهندسة.
class SnakeBoard {
  SnakeBoard._();

  /// سمك الإطار الخشبي حول الشبكة
  static double frame(Size size) => size.width * 0.045;

  /// مستطيل الشبكة الداخلية (10×10)
  static Rect gridRect(Size size) {
    final f = frame(size);
    return Rect.fromLTWH(f, f, size.width - f * 2, size.height - f * 2);
  }

  /// مركز خانة معيّنة — الترتيب متعرج: خانة 1 أسفل-يسار، 100 أعلى
  static Offset cellCenter(Size size, int cell) {
    final g = gridRect(size);
    final cw = g.width / 10;
    final idx = cell.clamp(1, 100) - 1;
    final row = idx ~/ 10; // 0 = الصف السفلي
    final i = idx % 10;
    final col = row.isEven ? i : 9 - i;
    return Offset(
      g.left + (col + 0.5) * cw,
      g.bottom - (row + 0.5) * cw,
    );
  }

  /// موقع الحجر خارج اللوحة قبل بدء اللعب (على حافة الإطار السفلية)
  static Offset homeSpot(Size size, int player) {
    final g = gridRect(size);
    return Offset(
      g.left + g.width * 0.22 + player * g.width * 0.14,
      g.bottom + frame(size) * 0.55,
    );
  }

  /// مسار جسم الحية: منحنى S من مركز خانة الرأس إلى خانة الذيل
  static Path snakePath(Size size, int head, int tail) {
    final a = cellCenter(size, head);
    final b = cellCenter(size, tail);
    final dir = b - a;
    final len = dir.distance;
    if (len == 0) return Path()..moveTo(a.dx, a.dy);
    final perp = Offset(-dir.dy, dir.dx) / len;
    // اتجاه الالتواء ثابت لكل حية (من رقم الرأس) لتنويع الأشكال
    final bend =
        (head.isEven ? 1.0 : -1.0) * (gridRect(size).width / 10) * 1.15;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(
        a.dx + dir.dx * 0.25 + perp.dx * bend,
        a.dy + dir.dy * 0.25 + perp.dy * bend,
        a.dx + dir.dx * 0.70 - perp.dx * bend * 0.75,
        a.dy + dir.dy * 0.70 - perp.dy * bend * 0.75,
        b.dx,
        b.dy,
      );
  }

  /// نقطة على جسم الحية عند النسبة t — لأنيميشن الانزلاق
  static Offset snakePoint(Size size, int head, int tail, double t) {
    final metric = snakePath(size, head, tail).computeMetrics().first;
    final clamped = t.clamp(0.0, 1.0);
    return metric.getTangentForOffset(metric.length * clamped)!.position;
  }
}

/// رسّام اللوحة الكاملة (ثابتة — الأحجار تُرسم كويدجتز فوقها)
class SnakeBoardPainter extends CustomPainter {
  const SnakeBoardPainter();

  static const _frameDark = Color(0xFF2A170B);
  static const _frameMid = Color(0xFF4A2E17);
  static const _frameLight = Color(0xFF6B4527);
  static const _feltDark = Color(0xFF1C3A12);
  static const _feltLight = Color(0xFF3F7031);
  static const _cellLight = Color(0xFFF0E2B6);
  static const _cellDark = Color(0xFF2E5620);
  static const _ladderWood = Color(0xFFCF9B62);
  static const _ladderEdge = Color(0xFF6B4226);

  // لوحات ألوان الحيات — أخضر زمردي، برتقالي ناري، بنفسجي ملكي، فيروزي
  static const _snakePalettes = [
    [Color(0xFF84CC16), Color(0xFF166534)],
    [Color(0xFFFB923C), Color(0xFF9A3412)],
    [Color(0xFFA78BFA), Color(0xFF5B21B6)],
    [Color(0xFF2DD4BF), Color(0xFF115E59)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrame(canvas, size);
    _paintFeltAndCells(canvas, size);
    _paintLadders(canvas, size);
    _paintSnakes(canvas, size);
    _paintVignette(canvas, size);
  }

  // ── الإطار الخشبي الفخم ──
  void _paintFrame(Canvas canvas, Size size) {
    final frameRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(frameRect, const Radius.circular(18));

    final framePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_frameLight, _frameMid, _frameDark],
        stops: [0.0, 0.45, 1.0],
      ).createShader(frameRect);
    canvas.drawRRect(rrect, framePaint);

    // لمعة علوية خفيفة على الخشب
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.16),
          Colors.transparent,
        ],
        stops: const [0.0, 0.18],
      ).createShader(frameRect);
    canvas.drawRRect(rrect, sheen);

    // خط ذهبي داخلي رفيع يفصل الإطار عن اللباد
    final f = SnakeBoard.frame(size);
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          f - 2, f - 2, size.width - f * 2 + 4, size.height - f * 2 + 4),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xAAE8C872),
    );
  }

  // ── اللباد الأخضر + الخلايا المتعرجة + الأرقام ──
  void _paintFeltAndCells(Canvas canvas, Size size) {
    final g = SnakeBoard.gridRect(size);
    final feltRect = RRect.fromRectAndRadius(g, const Radius.circular(8));
    canvas.save();
    canvas.clipRRect(feltRect);

    final felt = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.1,
        colors: const [_feltLight, _feltDark],
      ).createShader(g);
    canvas.drawRect(g, felt);

    final cw = g.width / 10;
    final numStyle = TextStyle(
      fontSize: cw * 0.24,
      fontWeight: FontWeight.w800,
      height: 1,
    );

    for (var cell = 1; cell <= 100; cell++) {
      final c = SnakeBoard.cellCenter(size, cell);
      final rect = Rect.fromCenter(center: c, width: cw, height: cw);
      final idx = cell - 1;
      final row = idx ~/ 10;
      final col = row.isEven ? idx % 10 : 9 - (idx % 10);
      final light = (row + col).isEven;

      // خانات متناوبة: بردي فاتح / أخضر داكن بشفافية
      canvas.drawRect(
        rect.deflate(0.6),
        Paint()
          ..color = light
              ? _cellLight.withOpacity(0.92)
              : _cellDark.withOpacity(0.55),
      );

      // رقم الخانة في الزاوية
      final tp = TextPainter(
        text: TextSpan(
          text: '$cell',
          style: numStyle.copyWith(
            color: light ? const Color(0xFF5A4A22) : const Color(0xCCF5E9C9),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left + cw * 0.08, rect.top + cw * 0.06));

      // خانة النهاية 100: نجمة ذهبية متوهجة
      if (cell == 100) {
        final glow = Paint()
          ..color = const Color(0xFFFFD54F).withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(c, cw * 0.42, glow);
        _drawStar(canvas, c, cw * 0.3, const Color(0xFFFFD54F));
      }
      // خانة البداية: سهم انطلاق أخضر
      if (cell == 1) {
        _drawStartFlag(canvas, rect, cw);
      }
    }

    canvas.restore();
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8D6E00),
    );
  }

  void _drawStartFlag(Canvas canvas, Rect rect, double cw) {
    final c = rect.center;
    final paint = Paint()..color = const Color(0xFF7CB342);
    final path = Path()
      ..moveTo(c.dx - cw * 0.22, c.dy + cw * 0.18)
      ..lineTo(c.dx - cw * 0.22, c.dy - cw * 0.22)
      ..lineTo(c.dx + cw * 0.20, c.dy - cw * 0.10)
      ..lineTo(c.dx - cw * 0.22, c.dy + cw * 0.02)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(c.dx - cw * 0.22, c.dy - cw * 0.24),
      Offset(c.dx - cw * 0.22, c.dy + cw * 0.22),
      Paint()
        ..color = const Color(0xFF4A3315)
        ..strokeWidth = 1.6,
    );
  }

  // ── الدرجات الخشبية ──
  void _paintLadders(Canvas canvas, Size size) {
    final cw = SnakeBoard.gridRect(size).width / 10;
    for (final entry in SnakeEngine.ladders.entries) {
      final a = SnakeBoard.cellCenter(size, entry.key);
      final b = SnakeBoard.cellCenter(size, entry.value);
      final dir = b - a;
      final len = dir.distance;
      if (len == 0) continue;
      final unit = dir / len;
      final perp = Offset(-unit.dy, unit.dx) * cw * 0.20;

      // ظل خفيف تحت الدرج
      final shadow = Paint()
        ..color = Colors.black.withOpacity(0.30)
        ..strokeWidth = cw * 0.16
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a + perp + const Offset(1.5, 2),
          b + perp + const Offset(1.5, 2), shadow);
      canvas.drawLine(a - perp + const Offset(1.5, 2),
          b - perp + const Offset(1.5, 2), shadow);

      // القضيبان
      final rail = Paint()
        ..color = _ladderEdge
        ..strokeWidth = cw * 0.15
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a + perp, b + perp, rail);
      canvas.drawLine(a - perp, b - perp, rail);
      final railTop = Paint()
        ..color = _ladderWood
        ..strokeWidth = cw * 0.10
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a + perp, b + perp, railTop);
      canvas.drawLine(a - perp, b - perp, railTop);

      // الدرجات الأفقية
      final rungCount = math.max(2, (len / (cw * 0.62)).floor());
      final rung = Paint()
        ..color = _ladderWood
        ..strokeWidth = cw * 0.09
        ..strokeCap = StrokeCap.round;
      final rungEdge = Paint()
        ..color = _ladderEdge.withOpacity(0.8)
        ..strokeWidth = cw * 0.12
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < rungCount; i++) {
        final c = a + unit * (len * i / rungCount);
        canvas.drawLine(c - perp, c + perp, rungEdge);
        canvas.drawLine(c - perp * 0.85, c + perp * 0.85, rung);
      }
    }
  }

  // ── الحيات: جسم S متدرّج مرسوم كدوائر متناقصة على المسار ──
  void _paintSnakes(Canvas canvas, Size size) {
    final cw = SnakeBoard.gridRect(size).width / 10;
    var i = 0;
    for (final entry in SnakeEngine.snakes.entries) {
      final palette = _snakePalettes[i++ % _snakePalettes.length];
      final head = entry.key;
      final tail = entry.value;
      final path = SnakeBoard.snakePath(size, head, tail);
      final metric = path.computeMetrics().first;
      final headC = SnakeBoard.cellCenter(size, head);

      // ظل الجسم
      _drawSnakeBody(canvas, metric, cw,
          dark: Colors.black.withOpacity(0.32),
          light: Colors.transparent,
          radiusMul: 1.06,
          offset: const Offset(2, 3));

      // جسم متدرج اللون (فاتح على الظهر، داكن على الأطراف عبر طبقتين)
      _drawSnakeBody(canvas, metric, cw, dark: palette[1], light: palette[0]);

      // الرأس: دائرة أكبر + عينان + لسان مفترق
      _drawSnakeHead(canvas, headC, metric, cw, palette);
    }
  }

  void _drawSnakeBody(Canvas canvas, ui.PathMetric metric, double cw,
      {required Color dark,
      required Color light,
      double radiusMul = 1.0,
      Offset offset = Offset.zero}) {
    const samples = 34;
    final paint = Paint()..color = dark;
    final belly = Paint()..color = light;
    for (var s = 0; s <= samples; s++) {
      final t = s / samples;
      final tan = metric.getTangentForOffset(metric.length * t);
      if (tan == null) continue;
      final p = tan.position + offset;
      // سماكة متناقصة نحو الذيل + نبض خفيف في المنتصف
      final r =
          cw * radiusMul * (0.30 - 0.13 * t + 0.05 * math.sin(t * math.pi * 2));
      canvas.drawCircle(p, r, paint);
      if (light != Colors.transparent) {
        // خط بطن فاتح منزاح قليلاً نحو الداخل
        canvas.drawCircle(
          p - Offset(0, r * 0.22),
          r * 0.62,
          belly..color = light.withOpacity(0.55),
        );
      }
    }
  }

  void _drawSnakeHead(Canvas canvas, Offset headC, ui.PathMetric metric,
      double cw, List<Color> palette) {
    // اتجاه الرأس = مماس البداية
    final tan = metric.getTangentForOffset(0);
    final angle = tan == null ? 0.0 : math.atan2(tan.vector.dy, tan.vector.dx);
    final hr = cw * 0.40;

    canvas.save();
    canvas.translate(headC.dx, headC.dy);
    canvas.rotate(angle);

    // رأس بيضاوي بلون أغمق
    final headPaint = Paint()..color = palette[1];
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: hr * 2.3, height: hr * 1.7),
      headPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-hr * 0.2, 0), width: hr * 1.5, height: hr * 1.2),
      Paint()..color = palette[0].withOpacity(0.85),
    );

    // عينان
    for (final dy in [-hr * 0.32, hr * 0.32]) {
      canvas.drawCircle(
          Offset(hr * 0.15, dy), hr * 0.20, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(hr * 0.19, dy), hr * 0.10,
          Paint()..color = const Color(0xFF111111));
    }

    // لسان مفترق أحمر يسبق الرأس
    final tongue = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = hr * 0.10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(hr * 1.05, 0), Offset(hr * 1.5, 0), tongue);
    canvas.drawLine(Offset(hr * 1.5, 0), Offset(hr * 1.72, -hr * 0.22), tongue);
    canvas.drawLine(Offset(hr * 1.5, 0), Offset(hr * 1.72, hr * 0.22), tongue);
    canvas.restore();
  }

  // ── تظليل حواف خفيف فوق الكل ──
  void _paintVignette(Canvas canvas, Size size) {
    final g = SnakeBoard.gridRect(size);
    final paint = Paint()
      ..shader = RadialGradient(
        radius: 1.25,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.22),
        ],
        stops: const [0.72, 1.0],
      ).createShader(g);
    canvas.drawRect(g, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
