import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'snake_engine.dart';

/// هندسة لوحة الحية والدرج — نفس الإحداثيات السابقة حتى يبقى
/// توافق الأنيميشن (cellCenter / snakePoint / homeSpot) كما هو.
class SnakeBoard {
  SnakeBoard._();

  /// سمك الإطار حول الشبكة
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
    final row = idx ~/ 10;
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

/// رسّام اللوحة الكرتونية — نمط ملوّن مرح:
/// إطار مخملي ملوّن، خانات باستيل مدوّرة بأرقام عريضة،
/// درجات مخططة بألوان الحلوى، وحيات سمينة بعيون كبيرة ضاحكة.
class SnakeBoardPainter extends CustomPainter {
  const SnakeBoardPainter();

  // لوحات الحيات الكرتونية — [الجسم، الغامق، لون البقع]
  static const _snakePalettes = [
    [Color(0xFF66BB33), Color(0xFF2E7D18), Color(0xFFD8F5B0)], // أخضر نعناعي
    [Color(0xFFFF7043), Color(0xFFC63F17), Color(0xFFFFE0B2)], // برتقالي فاقع
    [Color(0xFFAB47BC), Color(0xFF6A1B9A), Color(0xFFF3E5F5)], // بنفسجي مرح
    [Color(0xFF26C6DA), Color(0xFF00838F), Color(0xFFB2EBF2)], // فيروزي
    [Color(0xFFEC407A), Color(0xFFAD1457), Color(0xFFFCE4EC)], // وردي
  ];

  // ألوان الدرجات الكرتونية — كل درج بلونين مخططين
  static const _ladderPalettes = [
    [Color(0xFFFFB300), Color(0xFFFF6F00)], // برتقالي
    [Color(0xFF42A5F5), Color(0xFF1565C0)], // أزرق
    [Color(0xFFEC407A), Color(0xFFC2185B)], // وردي
    [Color(0xFF66BB6A), Color(0xFF2E7D32)], // أخضر
  ];

  // ألوان الخانات الباستيلية المتعاقبة (أربعة ألوان تتكرر)
  static const _cellPalette = [
    Color(0xFFFDEBC8), // كريمي دافئ
    Color(0xFFCDE7FF), // أزرق سماوي فاتح
    Color(0xFFD5F5D0), // أخضر نعناعي
    Color(0xFFFFD9E8), // وردي فاتح
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrame(canvas, size);
    _paintCells(canvas, size);
    _paintLadders(canvas, size);
    _paintSnakes(canvas, size);
    _paintConfetti(canvas, size);
  }

  // ── إطار كرتوني سميك بلونين ──
  void _paintFrame(Canvas canvas, Size size) {
    final frameRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(frameRect, const Radius.circular(24));

    // إطار متدرّج فيروزي→بنفسجي (مثل ألعاب الكرتون)
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C4DFF), Color(0xFF448AFF), Color(0xFF00BFA5)],
        ).createShader(frameRect),
    );

    // حد أبيض لامع داخلي يعطي إحساس "اللعبة المصنوعة"
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect.deflate(3), const Radius.circular(21)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Colors.white.withOpacity(0.55),
    );

    // لمعة علوية خفيفة
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.22), Colors.transparent],
          stops: const [0.0, 0.14],
        ).createShader(frameRect),
    );
  }

  // ── الخلايا: مربعات باستيل مدوّرة بأرقام عريضة ──
  void _paintCells(Canvas canvas, Size size) {
    final g = SnakeBoard.gridRect(size);
    final cw = g.width / 10;

    // خلفية الشبكة: بيضاء حليبية
    canvas.drawRRect(
      RRect.fromRectAndRadius(g, const Radius.circular(14)),
      Paint()..color = const Color(0xFFFFFDF7),
    );

    final numPaint = TextStyle(
      fontSize: cw * 0.30,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: -0.5,
    );

    for (var cell = 1; cell <= 100; cell++) {
      final c = SnakeBoard.cellCenter(size, cell);
      final idx = cell - 1;
      final row = idx ~/ 10;
      final col = row.isEven ? idx % 10 : 9 - (idx % 10);
      final cellColor = _cellPalette[(row + col) % _cellPalette.length];

      final rect =
          Rect.fromCenter(center: c, width: cw, height: cw).deflate(cw * 0.055);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cw * 0.16));

      // ظل داخلي خفيف + لون الخانة
      canvas.drawRRect(
        rr.shift(const Offset(0, 1.2)),
        Paint()..color = Colors.black.withOpacity(0.10),
      );
      canvas.drawRRect(rr, Paint()..color = cellColor);

      // لمعة صغيرة أعلى الخانة
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.45),
          Radius.circular(cw * 0.16),
        ),
        Paint()..color = Colors.white.withOpacity(0.35),
      );

      // الرقم — عريض وغامق مقروء
      final tp = TextPainter(
        text: TextSpan(
          text: '$cell',
          style: numPaint.copyWith(color: const Color(0xFF4A3B2A)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(c.dx - tp.width / 2, rect.top + rect.height * 0.10));

      // خانة البداية: دائرة انطلاق خضراء مرحة
      if (cell == 1) {
        canvas.drawCircle(
          c + Offset(0, cw * 0.14),
          cw * 0.20,
          Paint()..color = const Color(0xFF8BC34A),
        );
        canvas.drawCircle(
          c + Offset(0, cw * 0.14),
          cw * 0.20,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Colors.white,
        );
        final go = TextPainter(
          text: TextSpan(
            text: 'GO',
            style: TextStyle(
                fontSize: cw * 0.20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        go.paint(canvas, c + Offset(-go.width / 2, cw * 0.14 - go.height / 2));
      }

      // خانة النهاية: تاج ذهبي متوهج
      if (cell == 100) {
        final glow = Paint()
          ..color = const Color(0xFFFFC107).withOpacity(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
        canvas.drawCircle(c + Offset(0, cw * 0.10), cw * 0.34, glow);
        _drawCrown(canvas, c + Offset(0, cw * 0.08), cw * 0.46);
      }
    }
  }

  /// تاج ذهبي كرتوني على خانة 100
  void _drawCrown(Canvas canvas, Offset c, double w) {
    final h = w * 0.62;
    final path = Path()
      ..moveTo(c.dx - w / 2, c.dy + h / 2)
      ..lineTo(c.dx - w / 2, c.dy - h * 0.10)
      ..lineTo(c.dx - w * 0.25, c.dy + h * 0.12)
      ..lineTo(c.dx, c.dy - h / 2)
      ..lineTo(c.dx + w * 0.25, c.dy + h * 0.12)
      ..lineTo(c.dx + w / 2, c.dy - h * 0.10)
      ..lineTo(c.dx + w / 2, c.dy + h / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFC107));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF9A6A00),
    );
    // جواهر التاج
    for (final dx in [-w * 0.26, 0.0, w * 0.26]) {
      canvas.drawCircle(Offset(c.dx + dx, c.dy + h * 0.28), w * 0.06,
          Paint()..color = const Color(0xFFE91E63));
    }
  }

  // ── الدرجات: سكتان سمينتان مدورتان + درجات مخططة بألوان الحلوى ──
  void _paintLadders(Canvas canvas, Size size) {
    final cw = SnakeBoard.gridRect(size).width / 10;
    var li = 0;
    for (final entry in SnakeEngine.ladders.entries) {
      final pal = _ladderPalettes[li++ % _ladderPalettes.length];
      final a = SnakeBoard.cellCenter(size, entry.key);
      final b = SnakeBoard.cellCenter(size, entry.value);
      final dir = b - a;
      final len = dir.distance;
      if (len == 0) continue;
      final unit = dir / len;
      final perp = Offset(-unit.dy, unit.dx) * cw * 0.24;

      // ظل كرتوني خفيف
      final shadow = Paint()
        ..color = Colors.black.withOpacity(0.18)
        ..strokeWidth = cw * 0.13
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a + perp + const Offset(2, 2.5),
          b + perp + const Offset(2, 2.5), shadow);
      canvas.drawLine(a - perp + const Offset(2, 2.5),
          b - perp + const Offset(2, 2.5), shadow);

      // القضيبان — سمينان مدوران بلون الحلوى
      final rail = Paint()
        ..strokeWidth = cw * 0.16
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(a + perp, b + perp, rail..color = pal[1]);
      canvas.drawLine(a - perp, b - perp, rail);
      // لمعة القضبان
      final railHi = Paint()
        ..strokeWidth = cw * 0.06
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.45);
      canvas.drawLine(a + perp - unit * cw * 0.02 + const Offset(-1, -1),
          b + perp + const Offset(-1, -1), railHi);
      canvas.drawLine(a - perp - unit * cw * 0.02 + const Offset(-1, -1),
          b - perp + const Offset(-1, -1), railHi);

      // الدرجات — مخططة بالتناوب بين لوني الحلوى
      final rungCount = math.max(2, (len / (cw * 0.58)).floor());
      for (var i = 1; i < rungCount; i++) {
        final c = a + unit * (len * i / rungCount);
        final rp = Paint()
          ..color = i.isOdd ? pal[0] : Colors.white.withOpacity(0.95)
          ..strokeWidth = cw * 0.115
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c - perp * 0.9, c + perp * 0.9, rp);
      }
    }
  }

  // ── الحيات الكرتونية: جسم سمين منقط + رأس ضخم بعيون واسعة وابتسامة ──
  void _paintSnakes(Canvas canvas, Size size) {
    final cw = SnakeBoard.gridRect(size).width / 10;
    var i = 0;
    for (final entry in SnakeEngine.snakes.entries) {
      final palette = _snakePalettes[i++ % _snakePalettes.length];
      final head = entry.key;
      final tail = entry.value;
      final metric =
          SnakeBoard.snakePath(size, head, tail).computeMetrics().first;
      final headC = SnakeBoard.cellCenter(size, head);

      // ظل الجسم أولاً
      _drawBody(canvas, metric, cw, Colors.black.withOpacity(0.22),
          radiusMul: 1.10, offset: const Offset(2, 3.5), spots: null);
      // الجسم بلون الحية + بقع فاتحة
      _drawBody(canvas, metric, cw, palette[0], spots: palette[2]);
      // لمسة حافة أغمق أسفل الجسم
      _drawBody(canvas, metric, cw, palette[1].withOpacity(0.35),
          radiusMul: 0.55, offset: const Offset(0, 1.5), spots: null);

      // الرأس الكرتوني الكبير
      _drawCartoonHead(canvas, headC, metric, cw, palette);
    }
  }

  void _drawBody(Canvas canvas, ui.PathMetric metric, double cw, Color color,
      {double radiusMul = 1.0, Offset offset = Offset.zero, Color? spots}) {
    const samples = 30;
    final paint = Paint()..color = color;
    final spotPaint = spots != null ? (Paint()..color = spots) : null;
    for (var s = 0; s <= samples; s++) {
      final t = s / samples;
      final tan = metric.getTangentForOffset(metric.length * t);
      if (tan == null) continue;
      final p = tan.position + offset;
      // جسم سمين ثابت تقريباً — ينحف قليلاً عند الذيل
      final r = cw * radiusMul * (0.30 - 0.10 * t);
      canvas.drawCircle(p, r, paint);
      // بقع كرتونية كل بضع نقاط
      if (spotPaint != null && s % 3 == 1) {
        canvas.drawCircle(p - Offset(r * 0.15, r * 0.25), r * 0.34, spotPaint);
      }
    }
  }

  void _drawCartoonHead(Canvas canvas, Offset headC, ui.PathMetric metric,
      double cw, List<Color> palette) {
    final tan = metric.getTangentForOffset(0);
    final angle = tan == null ? 0.0 : math.atan2(tan.vector.dy, tan.vector.dx);
    final hr = cw * 0.46; // رأس أكبر من الجسم — طابع كرتوني

    canvas.save();
    canvas.translate(headC.dx, headC.dy);
    canvas.rotate(angle);

    // رأس مدوّر ضخم
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: hr * 2.15, height: hr * 1.85),
      Paint()..color = palette[0],
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: hr * 2.15, height: hr * 1.85),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = palette[1],
    );
    // خطفة فاتحة أسفل الرأس (خدود)
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(-hr * 0.15, hr * 0.42),
          width: hr * 1.1,
          height: hr * 0.5),
      Paint()..color = palette[2].withOpacity(0.7),
    );

    // عينان ضخمتان (ستايل كرتون: بيض كبيرتان + حدقات)
    for (final dy in [-hr * 0.42, hr * 0.42]) {
      canvas.drawCircle(
          Offset(hr * 0.28, dy), hr * 0.30, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(hr * 0.34, dy), hr * 0.155,
          Paint()..color = const Color(0xFF212121));
      // لمعان العين
      canvas.drawCircle(Offset(hr * 0.39, dy - hr * 0.05), hr * 0.055,
          Paint()..color = Colors.white);
    }

    // ابتسامة كرتونية — قوس صغير أمام الرأس
    final smile = Path()
      ..moveTo(hr * 0.62, hr * 0.28)
      ..quadraticBezierTo(hr * 0.95, hr * 0.18, hr * 0.92, -hr * 0.10);
    canvas.drawPath(
      smile,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hr * 0.09
        ..strokeCap = StrokeCap.round
        ..color = palette[1],
    );

    // لسان مفترق أحمر يتدلى
    final tongue = Paint()
      ..color = const Color(0xFFEF5350)
      ..strokeWidth = hr * 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(hr * 1.0, hr * 0.10), Offset(hr * 1.5, hr * 0.12), tongue);
    canvas.drawLine(
        Offset(hr * 1.5, hr * 0.12), Offset(hr * 1.72, -hr * 0.08), tongue);
    canvas.drawLine(
        Offset(hr * 1.5, hr * 0.12), Offset(hr * 1.72, hr * 0.34), tongue);
    canvas.restore();
  }

  // ── كونفيتي ونجوم صغيرة مرحة فوق اللوحة ──
  void _paintConfetti(Canvas canvas, Size size) {
    final g = SnakeBoard.gridRect(size);
    final rng = math.Random(7);
    final colors = [
      const Color(0xFFFF7043),
      const Color(0xFFFFCA28),
      const Color(0xFFAB47BC),
      const Color(0xFF26C6DA),
      const Color(0xFF66BB6A),
    ];
    // بقع صغيرة شبه شفافة موزعة على إطار اللوحة
    for (var i = 0; i < 26; i++) {
      final onEdge = rng.nextBool();
      final x = onEdge
          ? (rng.nextBool()
              ? g.left - SnakeBoard.frame(size) * rng.nextDouble() * 0.7
              : g.right + SnakeBoard.frame(size) * rng.nextDouble() * 0.7)
          : g.left + rng.nextDouble() * g.width;
      final y = onEdge
          ? rng.nextDouble() * size.height
          : (rng.nextBool()
              ? g.top - SnakeBoard.frame(size) * rng.nextDouble() * 0.7
              : g.bottom + SnakeBoard.frame(size) * rng.nextDouble() * 0.7);
      if (x < 2 || y < 2 || x > size.width - 2 || y > size.height - 2) continue;
      canvas.drawCircle(
        Offset(x, y),
        size.width * 0.008 * (1 + rng.nextDouble()),
        Paint()..color = colors[i % colors.length].withOpacity(0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
