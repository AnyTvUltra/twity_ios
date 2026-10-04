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

/// رسّام اللوحة الفاخرة — إطار خشب جوز بتطعيم ذهبي، خانات بلونين
/// دافئين متعاقبين بأرقام منقوشة، درجات خشبية ثلاثية الأبعاد،
/// وحيات واقعية مظللة بنقش ماسي ورأس بعينين حادتين.
class SnakeBoardPainter extends CustomPainter {
  const SnakeBoardPainter();

  // [الجسم، الظل الغامق، النقش، البطن الفاتح]
  static const _snakePalettes = [
    [
      Color(0xFF2E9E4F),
      Color(0xFF0F4D25),
      Color(0xFFF2C94C),
      Color(0xFFB7E4A8)
    ],
    [
      Color(0xFFD9541E),
      Color(0xFF6E2109),
      Color(0xFF2B1A10),
      Color(0xFFFFC9A3)
    ],
    [
      Color(0xFF2D6CDF),
      Color(0xFF0E2A66),
      Color(0xFFF5F5F5),
      Color(0xFFA9C8FF)
    ],
    [
      Color(0xFF8E44AD),
      Color(0xFF3E1452),
      Color(0xFFF7DC6F),
      Color(0xFFD7B8E8)
    ],
    [
      Color(0xFFC0392B),
      Color(0xFF5B140D),
      Color(0xFF1C1C1C),
      Color(0xFFF5B7B1)
    ],
  ];

  // خانتان متعاقبتان: عاجي دافئ / رملي ذهبي
  static const _cellA = Color(0xFFF7EBD3);
  static const _cellB = Color(0xFFE7CF9F);

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrame(canvas, size);
    _paintCells(canvas, size);
    _paintLadders(canvas, size);
    _paintSnakes(canvas, size);
  }

  // ── إطار خشب جوز داكن بتطعيم ذهبي ولمعة ──
  void _paintFrame(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(18));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B3E1F), Color(0xFF3F220F), Color(0xFF5A321A)],
        ).createShader(r),
    );
    // عروق الخشب
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withOpacity(0.14);
    for (var i = 1; i < 14; i++) {
      final y = size.height * i / 14;
      canvas.drawPath(
          Path()
            ..moveTo(0, y)
            ..quadraticBezierTo(
                size.width / 2, y + (i.isEven ? 5 : -5), size.width, y),
          grain);
    }
    // تطعيم ذهبي حول الشبكة
    final g = SnakeBoard.gridRect(size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(g.inflate(3.5), const Radius.circular(10)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE08A), Color(0xFFC9932E), Color(0xFFFFE08A)],
        ).createShader(r),
    );
    // لمعة علوية
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.16), Colors.transparent],
          stops: const [0.0, 0.18],
        ).createShader(r),
    );
  }

  // ── الخانات ──
  void _paintCells(Canvas canvas, Size size) {
    final g = SnakeBoard.gridRect(size);
    final cw = g.width / 10;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(g, const Radius.circular(8)));
    for (var cell = 1; cell <= 100; cell++) {
      final c = SnakeBoard.cellCenter(size, cell);
      final idx = cell - 1;
      final row = idx ~/ 10;
      final col = row.isEven ? idx % 10 : 9 - (idx % 10);
      final rect = Rect.fromCenter(center: c, width: cw, height: cw);
      final base = (row + col).isEven ? _cellA : _cellB;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(base, Colors.white, 0.25)!, base],
          ).createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = const Color(0xFF8B6B3D).withOpacity(0.35),
      );
      // الرقم منقوش في الزاوية العليا — حافة ضوء تحته
      final tp = TextPainter(
        text: TextSpan(
          text: '$cell',
          style: TextStyle(
            fontSize: cw * 0.26,
            fontWeight: FontWeight.w800,
            height: 1,
            color: const Color(0xFF6B4A22),
            shadows: const [
              Shadow(color: Color(0xAAFFFFFF), offset: Offset(0, 0.8)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rect.topLeft + Offset(cw * 0.08, cw * 0.07));

      if (cell == 1) _badge(canvas, c, cw, const Color(0xFF16A34A), 'GO');
      if (cell == 100) {
        canvas.drawCircle(
            c,
            cw * 0.42,
            Paint()
              ..color = const Color(0xFFFFC107).withOpacity(0.5)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        _drawCrown(canvas, c + Offset(0, cw * 0.08), cw * 0.52);
      }
    }
    // ظل داخلي خفيف على حافة الشبكة
    canvas.drawRect(
      g,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.black.withOpacity(0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();
  }

  void _badge(Canvas canvas, Offset c, double cw, Color color, String text) {
    final center = c + Offset(0, cw * 0.10);
    canvas.drawCircle(center, cw * 0.24, Paint()..color = color);
    canvas.drawCircle(
        center,
        cw * 0.24,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Colors.white);
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              fontSize: cw * 0.19,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

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
    canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE082), Color(0xFFF59E0B)],
          ).createShader(path.getBounds()));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color(0xFF8A5A00));
    for (final dx in [-w * 0.26, 0.0, w * 0.26]) {
      canvas.drawCircle(Offset(c.dx + dx, c.dy + h * 0.28), w * 0.06,
          Paint()..color = const Color(0xFFDC2626));
    }
  }

  // ── درجات خشبية ثلاثية الأبعاد ──
  void _paintLadders(Canvas canvas, Size size) {
    final cw = SnakeBoard.gridRect(size).width / 10;
    for (final entry in SnakeEngine.ladders.entries) {
      final a = SnakeBoard.cellCenter(size, entry.key);
      final b = SnakeBoard.cellCenter(size, entry.value);
      final dir = b - a;
      final len = dir.distance;
      if (len == 0) continue;
      final unit = dir / len;
      final perp = Offset(-unit.dy, unit.dx) * cw * 0.26;

      // ظل الدرج على اللوحة
      final shadow = Paint()
        ..color = Colors.black.withOpacity(0.28)
        ..strokeWidth = cw * 0.14
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      const so = Offset(3, 4);
      canvas.drawLine(a + perp + so, b + perp + so, shadow);
      canvas.drawLine(a - perp + so, b - perp + so, shadow);

      // الدرجات أولاً (تحت السكّتين)
      final rungCount = math.max(2, (len / (cw * 0.55)).floor());
      final rungDark = Paint()
        ..color = const Color(0xFF7A4A22)
        ..strokeWidth = cw * 0.12
        ..strokeCap = StrokeCap.round;
      final rungHi = Paint()
        ..color = const Color(0xFFC89060)
        ..strokeWidth = cw * 0.045
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i < rungCount; i++) {
        final c = a + unit * (len * i / rungCount);
        canvas.drawLine(c - perp, c + perp, rungDark);
        canvas.drawLine(
            c - perp * 0.92 - unit * 1.2, c + perp * 0.92 - unit * 1.2, rungHi);
      }
      // السكّتان: حافة داكنة + خشب + لمعة
      final edge = Paint()
        ..color = const Color(0xFF4A2A12)
        ..strokeWidth = cw * 0.17
        ..strokeCap = StrokeCap.round;
      final wood = Paint()
        ..color = const Color(0xFFA8693A)
        ..strokeWidth = cw * 0.12
        ..strokeCap = StrokeCap.round;
      final shine = Paint()
        ..color = const Color(0xFFE2B07E).withOpacity(0.8)
        ..strokeWidth = cw * 0.035
        ..strokeCap = StrokeCap.round;
      for (final side in [perp, -perp]) {
        canvas.drawLine(a + side, b + side, edge);
        canvas.drawLine(a + side, b + side, wood);
        const o = Offset(-0.8, -0.8);
        canvas.drawLine(a + side + o, b + side + o, shine);
      }
    }
  }

  // ── حيات واقعية مظللة ──
  void _paintSnakes(Canvas canvas, Size size) {
    final cw = SnakeBoard.gridRect(size).width / 10;
    var i = 0;
    for (final entry in SnakeEngine.snakes.entries) {
      final pal = _snakePalettes[i++ % _snakePalettes.length];
      final metric = SnakeBoard.snakePath(size, entry.key, entry.value)
          .computeMetrics()
          .first;
      _drawBody(canvas, metric, cw, pal);
      _drawHead(canvas, metric, cw, pal);
    }
  }

  /// الجسم يستدق تدريجياً نحو الذيل
  double _radius(double cw, double t) => cw * (0.26 - 0.17 * t * t);

  void _drawBody(
      Canvas canvas, ui.PathMetric metric, double cw, List<Color> pal) {
    const samples = 70;
    Offset at(double t) =>
        metric.getTangentForOffset(metric.length * t)!.position;

    // ظل أرضي ناعم
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var s = 0; s <= samples; s++) {
      final t = s / samples;
      canvas.drawCircle(
          at(t) + const Offset(2.5, 3.5), _radius(cw, t) * 1.05, shadow);
    }
    // حافة داكنة ← جسم ← بطن فاتح: مظهر أنبوبي مجسّم
    final layers = [
      (pal[1], 1.0, Offset.zero),
      (pal[0], 0.86, const Offset(-0.4, -0.4)),
      (pal[3].withOpacity(0.55), 0.42, const Offset(0.9, 1.1)),
    ];
    for (final l in layers) {
      final paint = Paint()..color = l.$1;
      for (var s = 0; s <= samples; s++) {
        final t = s / samples;
        canvas.drawCircle(at(t) + l.$3 * (1 - t), _radius(cw, t) * l.$2, paint);
      }
    }
    // نقش ماسي على الظهر
    final pattern = Paint()..color = pal[2].withOpacity(0.9);
    for (var s = 4; s < samples - 3; s += 5) {
      final t = s / samples;
      final tan = metric.getTangentForOffset(metric.length * t)!;
      final r = _radius(cw, t) * 0.45;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(math.atan2(tan.vector.dy, tan.vector.dx));
      canvas.drawPath(
          Path()
            ..moveTo(-r * 1.3, 0)
            ..lineTo(0, -r)
            ..lineTo(r * 1.3, 0)
            ..lineTo(0, r)
            ..close(),
          pattern);
      canvas.restore();
    }
    // لمعة ضوئية على طول الظهر
    final hi = Paint()..color = Colors.white.withOpacity(0.28);
    for (var s = 0; s <= samples; s += 2) {
      final t = s / samples;
      final r = _radius(cw, t);
      canvas.drawCircle(at(t) + Offset(-r * 0.35, -r * 0.38), r * 0.18, hi);
    }
  }

  void _drawHead(
      Canvas canvas, ui.PathMetric metric, double cw, List<Color> pal) {
    final tan = metric.getTangentForOffset(0)!;
    // الرأس يتجه عكس اتجاه الجسم (للخارج من خانة الرأس)
    final ang = math.atan2(-tan.vector.dy, -tan.vector.dx);
    final hr = cw * 0.34;
    canvas.save();
    canvas.translate(tan.position.dx, tan.position.dy);
    canvas.rotate(ang);

    final headPath = Path()
      ..moveTo(-hr * 0.6, -hr * 0.78)
      ..quadraticBezierTo(hr * 1.1, -hr * 0.95, hr * 1.35, 0)
      ..quadraticBezierTo(hr * 1.1, hr * 0.95, -hr * 0.6, hr * 0.78)
      ..quadraticBezierTo(-hr * 0.9, 0, -hr * 0.6, -hr * 0.78)
      ..close();
    canvas.drawPath(
        headPath.shift(const Offset(2, 3)),
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(headPath, Paint()..color = pal[1]);
    canvas.drawPath(
        headPath,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.2, -0.3),
            colors: [Color.lerp(pal[0], Colors.white, 0.25)!, pal[0]],
          ).createShader(headPath.getBounds().deflate(1)));
    // عينان بحدقة شقّية
    for (final dy in [-hr * 0.42, hr * 0.42]) {
      final e = Offset(hr * 0.45, dy);
      canvas.drawCircle(e, hr * 0.22, Paint()..color = const Color(0xFFFDE047));
      canvas.drawOval(
          Rect.fromCenter(center: e, width: hr * 0.09, height: hr * 0.34),
          Paint()..color = Colors.black);
      canvas.drawCircle(e + Offset(-hr * 0.06, -hr * 0.07), hr * 0.05,
          Paint()..color = Colors.white);
    }
    // فتحتا الأنف
    for (final dy in [-hr * 0.16, hr * 0.16]) {
      canvas.drawCircle(
          Offset(hr * 1.12, dy), hr * 0.045, Paint()..color = pal[1]);
    }
    // لسان مفترق
    canvas.drawPath(
        Path()
          ..moveTo(hr * 1.3, 0)
          ..lineTo(hr * 1.75, 0)
          ..lineTo(hr * 1.98, -hr * 0.16)
          ..moveTo(hr * 1.75, 0)
          ..lineTo(hr * 1.98, hr * 0.16),
        Paint()
          ..color = const Color(0xFFE11D48)
          ..strokeWidth = hr * 0.09
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
