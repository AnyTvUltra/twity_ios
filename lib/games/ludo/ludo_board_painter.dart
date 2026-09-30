import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ludo_engine.dart';

/// هندسة لوحة اللودو 15×15 + الرسّام — إطار خشبي، قواعد ملونة بالزوايا،
/// مسار أبيض متقاطع، نجوم آمنة، أعمدة بيت ملونة، ومثلثات المركز.
class LudoBoard {
  LudoBoard._();

  /// سمك الإطار الخشبي حول الشبكة
  static double frame(Size size) => size.width * 0.038;

  /// مستطيل الشبكة الداخلية (15×15)
  static Rect gridRect(Size size) {
    final f = frame(size);
    return Rect.fromLTWH(f, f, size.width - f * 2, size.height - f * 2);
  }

  static double cell(Size size) => gridRect(size).width / 15;

  static Rect cellRect(Size size, int r, int c) {
    final g = gridRect(size);
    final cw = cell(size);
    return Rect.fromLTWH(g.left + c * cw, g.top + r * cw, cw, cw);
  }

  static Offset cellCenter(Size size, int r, int c) =>
      cellRect(size, r, c).center;

  /// مركز خانة عالمية على المسار
  static Offset trackCenter(Size size, int global) {
    final rc = LudoEngine.track[global];
    return cellCenter(size, rc.$1, rc.$2);
  }

  /// ألوان الزوايا الأربع: 0 أحمر(علوي-يسار)، 1 أخضر(علوي-يمين)، 2 أصفر(سفلي-يمين)، 3 أزرق(سفلي-يسار)
  static const baseColors = [
    Color(0xFFE11D48), // أحمر
    Color(0xFF16A34A), // أخضر
    Color(0xFFF59E0B), // أصفر
    Color(0xFF2563EB), // أزرق
  ];

  /// لاعب → لون قاعدته (0 = أزرق سفلي-يسار، 1 = أخضر علوي-يمين)
  static const playerColorIdx = {0: 3, 1: 1};

  /// مستطيل قاعدة لون معيّن (6×6)
  static Rect baseRect(Size size, int colorIdx) {
    final g = gridRect(size);
    final cw = cell(size);
    const origins = {
      0: (0, 0), // أحمر علوي-يسار
      1: (0, 9), // أخضر علوي-يمين
      2: (9, 9), // أصفر سفلي-يمين
      3: (9, 0), // أزرق سفلي-يسار
    };
    final o = origins[colorIdx]!;
    return Rect.fromLTWH(g.left + o.$2 * cw, g.top + o.$1 * cw, cw * 6, cw * 6);
  }

  /// مواقع الأحجار الأربعة داخل القاعدة (2×2)
  static Offset baseSpot(Size size, int colorIdx, int i) {
    final b = baseRect(size, colorIdx);
    const q = [
      (0.30, 0.30),
      (0.70, 0.30),
      (0.30, 0.70),
      (0.70, 0.70),
    ];
    return Offset(b.left + b.width * q[i].$1, b.top + b.height * q[i].$2);
  }

  /// مركز الحجر لتقدّم p: -1 قاعدة، 0..51 مسار، 52..56 عمود بيت، 57 مركز
  static Offset positionOf(Size size, int player, int tokenIdx, int p) {
    if (p == -1) {
      return baseSpot(size, playerColorIdx[player]!, tokenIdx);
    }
    if (p <= 51) {
      return trackCenter(size, LudoEngine.globalOf(player, p));
    }
    if (p <= 56) {
      final rc = LudoEngine.homeCells[player]![p - 52];
      return cellCenter(size, rc.$1, rc.$2);
    }
    // المركز — انزياح بسيط لكل حجر
    final c = gridRect(size).center;
    const off = [(-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)];
    final cw = cell(size);
    return c +
        Offset(off[tokenIdx].$1 * cw * 0.55, off[tokenIdx].$2 * cw * 0.55);
  }
}

/// رسّام لوحة اللودو الكاملة (ثابتة — الأحجار ويدجتز فوقها)
class LudoBoardPainter extends CustomPainter {
  const LudoBoardPainter();

  static const _frameDark = Color(0xFF2A170B);
  static const _frameMid = Color(0xFF4A2E17);
  static const _frameLight = Color(0xFF6B4527);
  static const _paper = Color(0xFFF6EFDD);
  static const _cellLine = Color(0xFF8A7B5C);

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrame(canvas, size);
    _paintBoardBase(canvas, size);
    _paintBases(canvas, size);
    _paintTrack(canvas, size);
    _paintHomeColumns(canvas, size);
    _paintCenter(canvas, size);
    _paintVignette(canvas, size);
  }

  void _paintFrame(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_frameLight, _frameMid, _frameDark],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withOpacity(0.15), Colors.transparent],
          stops: const [0.0, 0.18],
        ).createShader(rect),
    );
    final f = LudoBoard.frame(size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            f - 2, f - 2, size.width - f * 2 + 4, size.height - f * 2 + 4),
        const Radius.circular(10),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xAAE8C872),
    );
  }

  void _paintBoardBase(Canvas canvas, Size size) {
    final g = LudoBoard.gridRect(size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(g, const Radius.circular(8)),
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.15),
          radius: 1.15,
          colors: [Color(0xFFFBF5E4), _paper],
        ).createShader(g),
    );
  }

  // ── القواعد الأربع بالزوايا ──
  void _paintBases(Canvas canvas, Size size) {
    final cw = LudoBoard.cell(size);
    for (var i = 0; i < 4; i++) {
      final b = LudoBoard.baseRect(size, i);
      final color = LudoBoard.baseColors[i];
      // جسم القاعدة الملون بتدرج
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            b.deflate(cw * 0.12), Radius.circular(cw * 0.5)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.25)!,
              color,
              Color.lerp(color, Colors.black, 0.3)!,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(b),
      );
      // لوحة داخلية بيضاء
      final inner = b.deflate(cw * 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cw * 0.35)),
        Paint()..color = const Color(0xFFFCF7EA),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(inner, Radius.circular(cw * 0.35)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withOpacity(0.55),
      );
      // مواقع الأحجار الأربعة
      for (var s = 0; s < 4; s++) {
        final p = LudoBoard.baseSpot(size, i, s);
        canvas.drawCircle(
          p,
          cw * 0.62,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          p,
          cw * 0.62,
          Paint()
            ..color = color.withOpacity(0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cw * 0.07,
        );
      }
    }
  }

  // ── المسار الرئيسي: خلايا بيضاء + انطلاقات ملونة + نجوم آمنة ──
  void _paintTrack(Canvas canvas, Size size) {
    final cw = LudoBoard.cell(size);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _cellLine.withOpacity(0.55);
    final fill = Paint()..color = const Color(0xFFFDFAF0);

    // خلايا الانطلاق بلون صاحبها
    const startColors = {
      0: 0xFFE11D48, // أحمر
      13: 0xFF16A34A, // أخضر
      26: 0xFFF59E0B, // أصفر
      39: 0xFF2563EB, // أزرق
    };
    const starCells = {8, 21, 34, 47};

    for (var i = 0; i < LudoEngine.track.length; i++) {
      final rc = LudoEngine.track[i];
      final rect = LudoBoard.cellRect(size, rc.$1, rc.$2);

      final startColor = startColors[i];
      canvas.drawRect(
          rect,
          startColor != null
              ? (Paint()
                ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  colors: [
                    Color.lerp(Color(startColor), Colors.white, 0.2)!,
                    Color(startColor),
                  ],
                ).createShader(rect))
              : fill);
      canvas.drawRect(rect, border);

      // سهم اتجاه على خانة الانطلاق
      if (startColor != null) {
        _drawStartArrow(canvas, rect, i);
      }
      // نجمة آمنة
      if (starCells.contains(i)) {
        _drawStar(
            canvas, rect.center, cw * 0.30, const Color(0xFF94A3B8), rect);
      }
    }
  }

  void _drawStartArrow(Canvas canvas, Rect rect, int global) {
    // اتجاه السير = اتجاه الخانة التالية في المسار
    final next = LudoEngine.track[(global + 1) % 52];
    final cur = LudoEngine.track[global];
    final dir =
        Offset((next.$2 - cur.$2).toDouble(), (next.$1 - cur.$1).toDouble());
    final c = rect.center;
    final s = rect.width;
    final fwd = dir; // مركّبة واحدة فقط دائماً
    final side = Offset(-fwd.dy, fwd.dx);
    final tip = c + fwd * s * 0.26;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((c - fwd * s * 0.14 + side * s * 0.16).dx,
          (c - fwd * s * 0.14 + side * s * 0.16).dy)
      ..lineTo((c - fwd * s * 0.14 - side * s * 0.16).dx,
          (c - fwd * s * 0.14 - side * s * 0.16).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(0.9));
  }

  // ── أعمدة البيت الأربعة (الأربعة مرسومة للشكل الكلاسيكي) ──
  void _paintHomeColumns(Canvas canvas, Size size) {
    const cols = {
      0: [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)], // أحمر →
      1: [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)], // أخضر ↓
      2: [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)], // أصفر ←
      3: [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)], // أزرق ↑
    };
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = _cellLine.withOpacity(0.55);
    for (final e in cols.entries) {
      for (final rc in e.value) {
        final rect = LudoBoard.cellRect(size, rc.$1, rc.$2);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              colors: [
                Color.lerp(LudoBoard.baseColors[e.key], Colors.white, 0.35)!,
                LudoBoard.baseColors[e.key],
              ],
            ).createShader(rect),
        );
        canvas.drawRect(rect, border);
      }
    }
  }

  // ── مثلثات المركز الأربعة ──
  void _paintCenter(Canvas canvas, Size size) {
    final tl = LudoBoard.cellRect(size, 6, 6).topLeft;
    final br = LudoBoard.cellRect(size, 8, 8).bottomRight;
    final c = LudoBoard.gridRect(size).center;
    final tr = Offset(br.dx, tl.dy);
    final bl = Offset(tl.dx, br.dy);

    void tri(Offset a, Offset b, Color col) {
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment(((a.dx + b.dx) / 2 - c.dx) / c.dx,
                  ((a.dy + b.dy) / 2 - c.dy) / c.dy),
              colors: [col, Color.lerp(col, Colors.black, 0.25)!],
            ).createShader(Rect.fromPoints(tl, br)));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = const Color(0xFF4A3A1E).withOpacity(0.6));
    }

    tri(tl, tr, LudoBoard.baseColors[1]); // أعلى = أخضر
    tri(tr, br, LudoBoard.baseColors[2]); // يمين = أصفر
    tri(br, bl, LudoBoard.baseColors[3]); // أسفل = أزرق
    tri(bl, tl, LudoBoard.baseColors[0]); // يسار = أحمر
    canvas.drawCircle(c, LudoBoard.cell(size) * 0.16,
        Paint()..color = const Color(0xFFFCF7EA));
  }

  void _drawStar(
      Canvas canvas, Offset c, double r, Color color, Rect cellRect) {
    // هالة خفيفة على الخانة
    canvas.drawCircle(
        c, r * 1.6, Paint()..color = const Color(0xFF64748B).withOpacity(0.10));
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
          ..strokeWidth = 0.8
          ..color = const Color(0xFF475569));
  }

  void _paintVignette(Canvas canvas, Size size) {
    final g = LudoBoard.gridRect(size);
    canvas.drawRect(
      g,
      Paint()
        ..shader = RadialGradient(
          radius: 1.25,
          colors: [Colors.transparent, Colors.black.withOpacity(0.16)],
          stops: const [0.74, 1.0],
        ).createShader(g),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
