import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../widgets/animated_skin_effect.dart';
import '../bg_themes.dart';
import 'bg_geometry.dart';

void _grain(Canvas canvas, Rect r, Color color, double alpha, int lines,
    {required bool vertical, int seed = 0}) {
  if (alpha <= 0) return;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..color = color.withValues(alpha: alpha);
  final rnd = math.Random(r.width.toInt() * 7 + r.left.toInt() + seed);
  for (int k = 0; k < lines; k++) {
    paint.strokeWidth = 0.5 + rnd.nextDouble() * 1.1;
    final t = rnd.nextDouble();
    final amp = 1.0 + rnd.nextDouble() * 3.5;
    final freq = 2 + rnd.nextDouble() * 4;
    final phase = rnd.nextDouble() * 6;
    final p = Path();
    const steps = 24;
    for (int s = 0; s <= steps; s++) {
      final u = s / steps;
      final off = math.sin(u * freq + phase) * amp;
      final pt = vertical
          ? Offset(r.left + r.width * t + off, r.top + r.height * u)
          : Offset(r.left + r.width * u, r.top + r.height * t + off);
      s == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p, paint);
  }
}

void _drawImageCover(Canvas canvas, ui.Image img, Rect dst, Paint paint) {
  final iw = img.width.toDouble(), ih = img.height.toDouble();
  final scale = math.max(dst.width / iw, dst.height / ih);
  final sw = dst.width / scale, sh = dst.height / scale;
  final src = Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh);
  canvas.drawImageRect(img, src, dst, paint);
}

void _goldPlate(Canvas canvas, Rect r, List<Color> metal,
    {bool vertical = false}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.25));
  canvas.drawRRect(
      rr.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
          end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [metal[2], metal[0], metal[1], metal[2]],
          stops: const [0.0, 0.35, 0.6, 1.0],
        ).createShader(r));
  final screw = r.shortestSide * 0.13;
  final pts = vertical
      ? [
          Offset(r.center.dx, r.top + r.height * 0.2),
          Offset(r.center.dx, r.bottom - r.height * 0.2)
        ]
      : [
          Offset(r.left + r.width * 0.2, r.center.dy),
          Offset(r.right - r.width * 0.2, r.center.dy)
        ];
  for (final p in pts) {
    canvas.drawCircle(p, screw, Paint()..color = metal[2]);
    canvas.drawCircle(p - Offset(screw * 0.25, screw * 0.25), screw * 0.5,
        Paint()..color = metal[0].withValues(alpha: 0.8));
  }
}

void _innerShadow(Canvas canvas, RRect rr, double blur) {
  canvas.save();
  canvas.clipRRect(rr);
  canvas.drawRRect(
      rr.inflate(blur),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = blur * 2
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur * 0.6));
  canvas.restore();
}

void _caseBody(Canvas canvas, Size size, BgBoardTheme th, ui.Image? wood) {
  final w = size.width;
  final outer =
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.022));
  canvas.save();
  canvas.clipRRect(outer);
  canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: th.caseColors,
        ).createShader(Offset.zero & size));
  if (wood != null && th.woodTexture) {
    _drawImageCover(canvas, wood, Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.5));
    canvas.drawRect(Offset.zero & size,
        Paint()..color = th.caseColors.last.withValues(alpha: 0.35));
  }
  _grain(canvas, Offset.zero & size, Colors.black, 0.16, 40, vertical: false);
  canvas.restore();
  canvas.drawRRect(
      outer.deflate(1.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
                colors: [th.metal[0], th.metal[1], th.metal[2], th.metal[1]])
            .createShader(Offset.zero & size));
}

void _corners(Canvas canvas, Size size, List<Color> metal) {
  final w = size.width, h = size.height;
  final outer =
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.022));
  final c = w * 0.045;
  for (final corner in [
    Offset.zero,
    Offset(w, 0),
    Offset(0, h),
    Offset(w, h)
  ]) {
    final sx = corner.dx == 0 ? 1.0 : -1.0;
    final sy = corner.dy == 0 ? 1.0 : -1.0;
    final p = Path()
      ..moveTo(corner.dx, corner.dy)
      ..lineTo(corner.dx + sx * c, corner.dy)
      ..lineTo(corner.dx + sx * c, corner.dy + sy * c * 0.28)
      ..lineTo(corner.dx + sx * c * 0.28, corner.dy + sy * c * 0.28)
      ..lineTo(corner.dx + sx * c * 0.28, corner.dy + sy * c)
      ..lineTo(corner.dx, corner.dy + sy * c)
      ..close();
    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(colors: metal)
              .createShader(Rect.fromCircle(center: corner, radius: c)));
    canvas.restore();
  }
}

// ══════════════════════════════════════════════════════════════
// لوح الطاولي — قابل للتلوين بالسكنات (BgBoardTheme)
// ══════════════════════════════════════════════════════════════
class BackgammonBoardPainter extends CustomPainter {
  final BgGeom g;
  final ui.Image? wood;
  final BgBoardTheme theme;

  BackgammonBoardPainter(this.g, {this.wood, this.theme = BgThemes.classic});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final th = theme;
    final outer =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(w * 0.022));

    canvas.drawRRect(
        outer.shift(Offset(0, h * 0.02)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02));

    _caseBody(canvas, size, th, wood);

    // الصواني الجانبية
    for (final t in [g.leftTray, g.rightTray]) {
      final rr = RRect.fromRectAndRadius(t, Radius.circular(g.trayW * 0.18));
      canvas.drawRRect(
          rr,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: th.trayColors,
            ).createShader(t));
      _innerShadow(canvas, rr, g.trayW * 0.25);
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = th.metal[1].withValues(alpha: 0.7));
      final sep = Rect.fromCenter(
          center: t.center, width: t.width, height: g.trayW * 0.34);
      canvas.drawRect(
          sep,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [th.caseColors[0], th.caseColors[2]],
            ).createShader(sep));
      _goldPlate(canvas, sep.deflate(sep.height * 0.18), th.metal);
    }

    // الحافة الداخلية حول الميدان
    final fieldOuter = RRect.fromRectAndRadius(
        g.field.inflate(g.rim * 0.6), Radius.circular(g.rim));
    canvas.drawRRect(
        fieldOuter,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(th.caseColors[0], Colors.white, 0.12)!,
              th.caseColors[2]
            ],
          ).createShader(fieldOuter.outerRect));

    // نصفا الميدان
    for (final half in [g.leftHalf, g.rightHalf]) {
      final rr = RRect.fromRectAndRadius(half, Radius.circular(g.rim * 0.6));
      canvas.save();
      canvas.clipRRect(rr);
      canvas.drawRect(
          half,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0, -0.1),
              radius: 1.1,
              colors: th.fieldColors,
              stops: const [0.0, 0.6, 1.0],
            ).createShader(half));
      _grain(canvas, half, th.grain, th.grainAlpha, 26, vertical: true);
      _ornament(canvas, half);
      canvas.restore();
      _innerShadow(canvas, rr, g.pointW * 0.5);
    }

    for (int i = 0; i < 24; i++) {
      _triangle(canvas, i);
    }

    // البار
    final bar = Rect.fromLTRB(g.bar.left, g.field.top - g.rim * 0.6,
        g.bar.right, g.field.bottom + g.rim * 0.6);
    canvas.drawRect(
        bar,
        Paint()
          ..shader = LinearGradient(
            colors: [
              th.caseColors[2],
              Color.lerp(th.caseColors[0], Colors.white, 0.1)!,
              th.caseColors[1],
              th.caseColors[2],
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ).createShader(bar));
    _grain(canvas, bar, Colors.black, 0.2, 6, vertical: true);
    for (final fy in [0.22, 0.78]) {
      _goldPlate(
          canvas,
          Rect.fromCenter(
              center: Offset(bar.center.dx, h * fy),
              width: g.barW * 0.62,
              height: g.barW * 1.5),
          th.metal,
          vertical: true);
    }

    _corners(canvas, size, th.metal);

    canvas.save();
    canvas.clipRRect(outer);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: const Alignment(-1, -1),
            end: const Alignment(0.2, 0.4),
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Offset.zero & size));
    canvas.restore();
  }

  void _triangle(Canvas canvas, int i) {
    final th = theme;
    final path = g.triangle(i);
    final top = g.isTop(i);
    final dark = i.isOdd;
    final x = g.pointX(i);
    final base = top ? g.field.top : g.field.bottom;
    final tip = top ? g.field.top + g.triH : g.field.bottom - g.triH;
    final rect = Rect.fromLTRB(x - g.pointW / 2, math.min(base, tip),
        x + g.pointW / 2, math.max(base, tip));

    canvas.drawPath(
        path.shift(Offset(g.pointW * 0.03, g.pointW * 0.04)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    final colors = dark ? th.darkPoint : th.lightPoint;
    canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: colors,
          ).createShader(rect));

    canvas.save();
    canvas.clipPath(path);
    final grain = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color =
          Color.lerp(colors.last, Colors.black, 0.4)!.withValues(alpha: 0.28);
    for (int k = -2; k <= 2; k++) {
      final gx = x + k * g.pointW * 0.13;
      final p = Path()..moveTo(gx, base);
      for (int s = 1; s <= 8; s++) {
        final t = s / 8;
        p.lineTo(gx + math.sin(t * 6 + i + k) * g.pointW * 0.03,
            base + (tip - base) * t);
      }
      canvas.drawPath(p, grain);
    }
    canvas.drawLine(
        Offset(x, base),
        Offset(x, base + (tip - base) * 0.85),
        Paint()
          ..strokeWidth = g.pointW * 0.12
          ..color = Colors.white.withValues(alpha: dark ? 0.08 : 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.restore();

    if (th.pointGlow != null) {
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = (dark ? colors[1] : th.pointGlow!).withValues(alpha: 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = th.pointStroke.withValues(alpha: 0.55));

    final dy = top ? g.pointW * 0.32 : -g.pointW * 0.32;
    final dm = g.pointW * 0.09;
    final diamond = Path()
      ..moveTo(x, base + dy - dm)
      ..lineTo(x + dm * 0.7, base + dy)
      ..lineTo(x, base + dy + dm)
      ..lineTo(x - dm * 0.7, base + dy)
      ..close();
    canvas.drawPath(
        diamond,
        Paint()
          ..color = (dark ? th.lightPoint[0] : th.darkPoint[1])
              .withValues(alpha: 0.7));
  }

  void _ornament(Canvas canvas, Rect half) {
    final c = half.center;
    final s = half.width * 0.16;
    final dark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = theme.ornament.withValues(alpha: 0.35);
    final light = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.18);
    for (final paint in [light, dark]) {
      final o = paint == light ? const Offset(0.8, 0.8) : Offset.zero;
      canvas.drawCircle(c + o, s * 0.42, paint);
      canvas.drawCircle(c + o, s * 0.24, paint);
      for (final sx in [-1.0, 1.0]) {
        for (final sy in [-1.0, 1.0]) {
          final p = Path()
            ..moveTo(c.dx + sx * s * 0.42 + o.dx, c.dy + o.dy)
            ..cubicTo(
                c.dx + sx * s * 1.0 + o.dx,
                c.dy - sy * s * 0.5 + o.dy,
                c.dx + sx * s * 1.5 + o.dx,
                c.dy + sy * s * 0.35 + o.dy,
                c.dx + sx * s * 2.3 + o.dx,
                c.dy + o.dy);
          canvas.drawPath(p, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(BackgammonBoardPainter old) =>
      old.g.size != g.size || old.wood != wood || old.theme != theme;
}

/// طبقة التأثير المتحرك فوق ميدان اللوح (نار/جليد/مجرة/نيون)
class BoardEffectPainter extends CustomPainter {
  final BgGeom g;
  final BgBoardTheme theme;
  final double t;

  BoardEffectPainter(this.g, this.theme, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (!theme.animated) return;
    for (final half in [g.leftHalf, g.rightHalf]) {
      canvas.save();
      canvas.clipRRect(
          RRect.fromRectAndRadius(half, Radius.circular(g.rim * 0.6)));
      canvas.translate(half.left, half.top);
      canvas.saveLayer(Offset.zero & half.size,
          Paint()..color = Colors.white.withValues(alpha: theme.effectAlpha));
      paintSkinEffect(canvas, half.size, theme.effect, t);
      canvas.restore();
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(BoardEffectPainter old) =>
      old.t != t || old.theme != theme;
}

// ══════════════════════════════════════════════════════════════
// غطاء الطاولي المغلق — ظهر الحقيبة: ميدالية ذهبية + أقفال
// ══════════════════════════════════════════════════════════════
class BoardLidPainter extends CustomPainter {
  final BgBoardTheme theme;
  final ui.Image? wood;

  BoardLidPainter(this.theme, {this.wood});

  @override
  void paint(Canvas canvas, Size size) {
    final th = theme;
    _caseBody(canvas, size, th, wood);
    final w = size.width, h = size.height;
    // إطار داخلي مطعّم
    final inset = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(w * 0.07), Radius.circular(w * 0.03));
    canvas.drawRRect(
        inset,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = th.metal[1].withValues(alpha: 0.75));
    canvas.drawRRect(
        inset.deflate(6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = th.metal[0].withValues(alpha: 0.35));

    // ميدالية مركزية
    final c = size.center(Offset.zero);
    final r = math.min(w, h) * 0.26;
    canvas.drawCircle(
        c + const Offset(0, 3),
        r,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [th.metal[0], th.metal[1], th.metal[2]],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        c,
        r * 0.82,
        Paint()
          ..shader = RadialGradient(
            colors: [th.caseColors[0], th.caseColors[2]],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p1 = c + Offset(math.cos(a), math.sin(a)) * r * 0.3;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * r * 0.72;
      canvas.drawLine(
          p1,
          p2,
          Paint()
            ..strokeWidth = 1.6
            ..color = th.metal[1].withValues(alpha: 0.8));
    }
    canvas.drawCircle(c, r * 0.22, Paint()..color = th.metal[1]);
    canvas.drawCircle(
        c - Offset(r * 0.06, r * 0.06), r * 0.1, Paint()..color = th.metal[0]);

    // أقفال ذهبية على الحافة الخارجية (يسار = جهة الإغلاق)
    for (final fy in [0.28, 0.72]) {
      _goldPlate(
          canvas,
          Rect.fromCenter(
              center: Offset(w * 0.035, h * fy),
              width: w * 0.05,
              height: h * 0.11),
          th.metal,
          vertical: true);
    }
    _corners(canvas, size, th.metal);
  }

  @override
  bool shouldRepaint(BoardLidPainter old) =>
      old.theme != theme || old.wood != wood;
}

// ══════════════════════════════════════════════════════════════
// حجر ثلاثي الأبعاد — مواد: لؤلؤ/خشب/رخام/معدن/نار/جليد/نيون/جوهرة
// ══════════════════════════════════════════════════════════════
class CheckerPainter extends CustomPainter {
  final BgCheckerStyle style;
  final double lift;
  final double glow;
  final Color glowColor;
  final double flash;

  /// زمن التأثير المتحرك 0..1
  final double time;

  /// بذرة لتدوير النقش (تنوّع طبيعي بين الأحجار)
  final int seed;

  const CheckerPainter({
    required this.style,
    this.lift = 0,
    this.glow = 0,
    this.glowColor = const Color(0xFF3FF5A8),
    this.flash = 0,
    this.time = 0,
    this.seed = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final st = style;
    final r = size.width / 2;
    final c = Offset(r, r);
    final depth = r * 0.16;
    final top = c - Offset(0, depth * 0.35);
    final faceR = r * 0.97;
    final faceRect = Rect.fromCircle(center: top, radius: faceR);

    canvas.drawOval(
        Rect.fromCenter(
            center:
                c + Offset(r * (0.1 + lift * 0.35), r * (0.18 + lift * 0.6)),
            width: r * 2 * (1 - lift * 0.1),
            height: r * 1.8 * (1 - lift * 0.1)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5 - lift * 0.18)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, r * (0.12 + lift * 0.35)));

    if (glow > 0) {
      canvas.drawCircle(
          top,
          r * 1.08,
          Paint()
            ..color = glowColor.withValues(alpha: 0.55 * glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
    }

    final pulse = 0.5 + 0.5 * math.sin(time * math.pi * 2 + seed);
    if (st.pattern == BgPattern.neon || st.pattern == BgPattern.fire) {
      canvas.drawCircle(
          top,
          r * 1.02,
          Paint()
            ..color = st.accent.withValues(alpha: 0.25 + 0.3 * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.25));
    }

    canvas.drawCircle(
        c + Offset(0, depth * 0.65),
        faceR,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: st.edge,
          ).createShader(Rect.fromCircle(center: c, radius: r)));

    canvas.drawCircle(
        top,
        faceR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 1.05,
            colors: st.face,
            stops: const [0.0, 0.55, 1.0],
          ).createShader(faceRect));

    // النقش الخاص بالمادة
    canvas.save();
    canvas.clipPath(Path()..addOval(faceRect));
    _pattern(canvas, top, faceR, pulse);
    canvas.restore();

    canvas.drawCircle(
        top,
        r * 0.86,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.13
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: st.rim,
          ).createShader(faceRect));

    final neon = st.pattern == BgPattern.neon;
    for (final gr in [0.66, 0.44]) {
      canvas.drawCircle(
          top,
          r * gr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.8, r * (neon ? 0.07 : 0.05))
            ..color =
                st.groove.withValues(alpha: neon ? 0.6 + 0.4 * pulse : 0.6)
            ..maskFilter =
                neon ? MaskFilter.blur(BlurStyle.normal, r * 0.04) : null);
      if (st.grooveLight > 0) {
        canvas.drawCircle(
            top + Offset(r * 0.03, r * 0.03),
            r * gr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.6, r * 0.03)
              ..color = Colors.white.withValues(alpha: st.grooveLight));
      }
    }

    canvas.drawCircle(
        top,
        r * 0.3,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [st.face[0], st.face[1]],
          ).createShader(Rect.fromCircle(center: top, radius: r * 0.3)));

    canvas.drawPath(
        Path()
          ..addArc(Rect.fromCircle(center: top, radius: r * 0.8),
              math.pi * 1.05, math.pi * 0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.12
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: st.spec)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05));

    if (flash > 0) {
      canvas.drawCircle(
          top,
          faceR,
          Paint()
            ..color = const Color(0xFFFF3B30).withValues(alpha: 0.55 * flash));
    }
  }

  void _pattern(Canvas canvas, Offset c, double r, double pulse) {
    final st = style;
    final rnd = math.Random(seed * 31 + 7);
    switch (st.pattern) {
      case BgPattern.none:
        return;
      case BgPattern.wood:
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..color = st.accent.withValues(alpha: 0.32);
        final center = c + Offset(r * (rnd.nextDouble() - 0.5), r * 1.4);
        for (int k = 1; k <= 9; k++) {
          p.strokeWidth = 0.6 + rnd.nextDouble() * 1.2;
          canvas.drawOval(
              Rect.fromCenter(
                  center: center, width: r * 0.5 * k, height: r * 0.34 * k),
              p);
        }
        return;
      case BgPattern.marble:
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..color = st.accent.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
        for (int k = 0; k < 4; k++) {
          p.strokeWidth = 0.6 + rnd.nextDouble() * 1.4;
          final a = rnd.nextDouble() * math.pi * 2;
          final s = c + Offset(math.cos(a), math.sin(a)) * r;
          final e = c - Offset(math.cos(a), math.sin(a)) * r;
          final path = Path()
            ..moveTo(s.dx, s.dy)
            ..cubicTo(
                c.dx + (rnd.nextDouble() - 0.5) * r * 1.4,
                c.dy + (rnd.nextDouble() - 0.5) * r * 1.4,
                c.dx + (rnd.nextDouble() - 0.5) * r * 1.4,
                c.dy + (rnd.nextDouble() - 0.5) * r * 1.4,
                e.dx,
                e.dy);
          canvas.drawPath(path, p);
        }
        return;
      case BgPattern.metal:
        final p = Paint()..style = PaintingStyle.stroke;
        for (double k = 0.1; k < 1; k += 0.035) {
          p
            ..strokeWidth = 0.5
            ..color = (rnd.nextBool() ? Colors.white : Colors.black)
                .withValues(alpha: 0.07);
          canvas.drawCircle(c, r * k, p);
        }
        return;
      case BgPattern.fire:
        // شقوق حمم متوهجة نابضة
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.07
          ..color = Color.lerp(st.accent, const Color(0xFFFFE08A), pulse)!
              .withValues(alpha: 0.5 + 0.45 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04);
        for (int k = 0; k < 5; k++) {
          final a = k * math.pi * 2 / 5 + rnd.nextDouble();
          var pt = c + Offset(math.cos(a), math.sin(a)) * r * 0.2;
          final path = Path()..moveTo(pt.dx, pt.dy);
          for (int s = 0; s < 3; s++) {
            final aa = a + (rnd.nextDouble() - 0.5) * 0.9;
            pt += Offset(math.cos(aa), math.sin(aa)) * r * 0.28;
            path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path, p);
        }
        canvas.drawCircle(
            c,
            r * 0.5,
            Paint()
              ..color = st.accent.withValues(alpha: 0.18 + 0.2 * pulse)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.3));
        return;
      case BgPattern.ice:
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = st.accent.withValues(alpha: 0.55);
        for (int k = 0; k < 6; k++) {
          final a = k * math.pi / 3 + seed;
          canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r, p);
          final m = c + Offset(math.cos(a), math.sin(a)) * r * 0.55;
          canvas.drawLine(m,
              m + Offset(math.cos(a + 0.6), math.sin(a + 0.6)) * r * 0.25, p);
        }
        // وميض يعبر سطح الجليد
        final sx = -r + (time * 1.3 % 1) * r * 4;
        canvas.drawRect(
            Rect.fromLTWH(c.dx - r + sx, c.dy - r, r * 0.35, r * 2),
            Paint()
              ..shader = LinearGradient(colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0),
              ]).createShader(
                  Rect.fromLTWH(c.dx - r + sx, c.dy - r, r * 0.35, r * 2)));
        return;
      case BgPattern.neon:
        return;
      case BgPattern.gem:
        const n = 8;
        for (int k = 0; k < n; k++) {
          final a1 = k * math.pi * 2 / n;
          final a2 = (k + 1) * math.pi * 2 / n;
          final path = Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + math.cos(a1) * r, c.dy + math.sin(a1) * r)
            ..lineTo(c.dx + math.cos(a2) * r, c.dy + math.sin(a2) * r)
            ..close();
          canvas.drawPath(
              path,
              Paint()
                ..color = (k.isEven ? Colors.white : Colors.black)
                    .withValues(alpha: k.isEven ? 0.14 : 0.12));
        }
        return;
    }
  }

  @override
  bool shouldRepaint(CheckerPainter old) =>
      old.style != style ||
      old.lift != lift ||
      old.glow != glow ||
      old.flash != flash ||
      old.glowColor != glowColor ||
      old.time != time ||
      old.seed != seed;
}

// ══════════════════════════════════════════════════════════════
// الأحجار المُخرجة — أسطوانات ثلاثية الأبعاد مرصوصة على حافتها
// ══════════════════════════════════════════════════════════════
class OffTrayPainter extends CustomPainter {
  final BgGeom g;
  final List<int> counts;
  final BgCheckerSet set;

  OffTrayPainter(this.g, this.counts, this.set);

  @override
  void paint(Canvas canvas, Size size) {
    for (int side = 0; side < 2; side++) {
      // من الأسفل للأعلى ليظهر الظل بين الشرائح
      final n = counts[side];
      final order = side == 0
          ? List.generate(n, (k) => k)
          : List.generate(n, (k) => n - 1 - k);
      for (final k in order) {
        paintSlab(canvas, g.offSlab(side, k), set.of(side));
      }
    }
  }

  static void paintSlab(Canvas canvas, Rect r, BgCheckerStyle st) {
    final body = r.deflate(r.height * 0.04);
    final rad = Radius.elliptical(body.height * 0.9, body.height * 0.5);
    final rr = RRect.fromRectAndRadius(body, rad);

    canvas.drawRRect(
        rr.shift(Offset(0, body.height * 0.35)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, body.height * 0.3));

    // جسم الأسطوانة: تدرج عمودي (وجه علوي فاتح ← حافة داكنة)
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [st.face[0], st.face[1], st.edge[0], st.edge[1]],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ).createShader(body));

    // تظليل أسطواني أفقي (لمعة عند الثلث + أطراف داكنة)
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.45),
              Colors.white.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.5),
            ],
            stops: const [0.0, 0.28, 0.55, 1.0],
          ).createShader(body));

    // أخاديد الحافة (خطوط محفورة على الجانب)
    final gy = body.top + body.height * 0.55;
    canvas.drawLine(
        Offset(body.left + body.width * 0.12, gy),
        Offset(body.right - body.width * 0.12, gy),
        Paint()
          ..strokeWidth = math.max(0.5, body.height * 0.08)
          ..color = st.groove.withValues(alpha: 0.55));
    canvas.drawLine(
        Offset(body.left + body.width * 0.12, body.top + body.height * 0.2),
        Offset(body.right - body.width * 0.12, body.top + body.height * 0.2),
        Paint()
          ..strokeWidth = math.max(0.5, body.height * 0.06)
          ..color = Colors.white.withValues(alpha: st.spec * 0.6));

    if (st.pattern == BgPattern.neon || st.pattern == BgPattern.fire) {
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = st.accent.withValues(alpha: 0.8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
    }
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = Colors.black.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(OffTrayPainter old) =>
      old.counts[0] != counts[0] ||
      old.counts[1] != counts[1] ||
      old.g.size != g.size ||
      old.set != set;
}

/// إبراز الوجهات القانونية
class TargetsPainter extends CustomPainter {
  final BgGeom g;
  final Set<int> targets;
  final double pulse;
  final int? hover;

  TargetsPainter(this.g, this.targets, this.pulse, {this.hover});

  static const _mint = Color(0xFF3FF5A8);

  @override
  void paint(Canvas canvas, Size size) {
    for (final t in targets) {
      final isHover = t == hover;
      final a = (isHover ? 0.75 : 0.35 + 0.25 * pulse);
      if (t == 24) {
        final z = g.rightTray.deflate(2);
        final rr = RRect.fromRectAndRadius(z, Radius.circular(g.trayW * 0.18));
        canvas.drawRRect(
            rr,
            Paint()
              ..color = _mint.withValues(alpha: a * 0.45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawRRect(
            rr,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = _mint.withValues(alpha: math.min(1, a + 0.2)));
        continue;
      }
      if (t < 0) continue;
      final path = g.triangle(t);
      canvas.drawPath(
          path,
          Paint()
            ..color = _mint.withValues(alpha: a * 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isHover ? 2.6 : 1.8
            ..color = _mint.withValues(alpha: math.min(1, a + 0.3)));
    }
  }

  @override
  bool shouldRepaint(TargetsPainter old) => true;
}

/// نرد ثلاثي الأبعاد
class DicePainter extends CustomPainter {
  final int value;
  final bool used;
  final Color pip;

  const DicePainter(this.value,
      {this.used = false, this.pip = const Color(0xFF0E7490)});

  static const Map<int, List<Offset>> _pips = {
    1: [Offset(0, 0)],
    2: [Offset(-1, -1), Offset(1, 1)],
    3: [Offset(-1, -1), Offset(0, 0), Offset(1, 1)],
    4: [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
    5: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(0, 0),
      Offset(-1, 1),
      Offset(1, 1)
    ],
    6: [
      Offset(-1, -1),
      Offset(1, -1),
      Offset(-1, 0),
      Offset(1, 0),
      Offset(-1, 1),
      Offset(1, 1)
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final depth = s * 0.11;
    final face = Rect.fromLTWH(0, 0, s - depth, s - depth);
    final rad = Radius.circular(s * 0.2);

    canvas.drawRRect(
        RRect.fromRectAndRadius(
            face.shift(Offset(depth * 1.4, depth * 1.8)), rad),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08));
    canvas.drawRRect(
        RRect.fromRectAndRadius(face.shift(Offset(depth, depth)), rad),
        Paint()..color = const Color(0xFFA9A293));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            face.shift(Offset(depth * 0.5, depth * 0.5)), rad),
        Paint()..color = const Color(0xFFCFC8B8));

    final rr = RRect.fromRectAndRadius(face, rad);
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.5),
            radius: 1.2,
            colors: [Color(0xFFFFFFFF), Color(0xFFF4F1EA), Color(0xFFDCD6C9)],
          ).createShader(face));
    canvas.drawRRect(
        rr.deflate(s * 0.03),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.04
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.12),
            ],
          ).createShader(face));

    final pr = face.width * 0.095;
    final step = face.width * 0.27;
    for (final o in _pips[value.clamp(1, 6)]!) {
      final p = face.center + o * step;
      canvas.drawCircle(
          p + Offset(pr * 0.12, pr * 0.15), pr, Paint()..color = Colors.white);
      canvas.drawCircle(
          p,
          pr,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(0.3, 0.35),
              colors: [pip, Color.lerp(pip, Colors.black, 0.55)!],
            ).createShader(Rect.fromCircle(center: p, radius: pr)));
    }

    if (used) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, s, s), Radius.circular(s * 0.2)),
          Paint()..color = const Color(0xFF0B1020).withValues(alpha: 0.55));
    }
  }

  @override
  bool shouldRepaint(DicePainter old) =>
      old.value != value || old.used != used || old.pip != pip;
}
