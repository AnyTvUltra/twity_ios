import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../services/store_service.dart';
import '../../../widgets/animated_skin_effect.dart';

/// رسام الطاولة الفاخرة — Premium 3D + Glassmorphism
/// نفس هندسة المنظور السابقة (Trapezoid) لكن بخامة كحلية زجاجية عميقة
/// مع حواف ناعمة وإضاءة محيطية خفيفة حول الإطار
class OkeyTablePainter extends CustomPainter {
  final bool isHumanTurn;

  /// كسنة سطح الطاولة المشتراة من المتجر (اختيارية) — مع التكبير والإزاحة
  final StoreItem? surfaceItem;

  /// تأثير متحرك على سطح الطاولة (نار/لافا/سديم...) + زمن الدورة 0..1
  final SkinEffect surfaceEffect;
  final double animT;

  const OkeyTablePainter({
    this.isHumanTurn = true,
    this.surfaceItem,
    this.surfaceEffect = SkinEffect.none,
    this.animT = 0,
  });

  // بأليت الطاولة الزجاجية — كحلي عميق بلمسات نعناعية خافتة
  static const _rimLight = Color(0xFF8FA8E8);
  static const _accent = Color(0xFF3FF5A8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // أبعاد سطح الطاولة بمنظور ثلاثي الأبعاد حقيقي (Trapezoid Perspective)
    final double topL = w * 0.14;
    final double topR = w * 0.86;
    final double topY = h * 0.08;

    final double botL = w * 0.07;
    final double botR = w * 0.93;
    final double botY = h * 0.85;

    // مسار سطح الطاولة مع زوايا ناعمة مستديرة
    final tablePath = Path()
      ..moveTo(topL + 20, topY)
      ..lineTo(topR - 20, topY)
      ..quadraticBezierTo(topR, topY, topR + 6, topY + 12)
      ..lineTo(botR, botY - 14)
      ..quadraticBezierTo(botR, botY, botR - 20, botY)
      ..lineTo(botL + 20, botY)
      ..quadraticBezierTo(botL, botY, botL, botY - 14)
      ..lineTo(topL - 6, topY + 12)
      ..quadraticBezierTo(topL, topY, topL + 20, topY)
      ..close();

    // ══════════════════════════════════════════════════════════
    // 1. توهج محيطي خافت حول الطاولة (Ambient Edge Glow)
    // ══════════════════════════════════════════════════════════
    canvas.drawPath(
      tablePath,
      Paint()
        ..color = _accent.withOpacity(0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawPath(
      tablePath,
      Paint()
        ..color = _rimLight.withOpacity(0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // ══════════════════════════════════════════════════════════
    // 2. أرجل زجاجية داكنة (بدل الخشبية)
    // ══════════════════════════════════════════════════════════
    final legPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, botY),
        Offset(0, botY + 28),
        const [
          Color(0xFF141B33),
          Color(0xFF0A0F22),
          Color(0xFF04060F),
        ],
        const [0.0, 0.5, 1.0],
      );

    final leftLeg = Path()
      ..moveTo(botL + 34, botY)
      ..lineTo(botL + 54, botY)
      ..lineTo(botL + 48, botY + 25)
      ..lineTo(botL + 28, botY + 25)
      ..close();
    canvas.drawPath(leftLeg, legPaint);

    final rightLeg = Path()
      ..moveTo(botR - 54, botY)
      ..lineTo(botR - 34, botY)
      ..lineTo(botR - 28, botY + 25)
      ..lineTo(botR - 48, botY + 25)
      ..close();
    canvas.drawPath(rightLeg, legPaint);

    // لمعة زجاجية خفيفة على الأرجل
    for (final leg in [leftLeg, rightLeg]) {
      canvas.drawPath(
        leg,
        Paint()
          ..color = Colors.white.withOpacity(0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // ══════════════════════════════════════════════════════════
    // 3. ظل الطاولة العميق على الأرضية المحيطة
    // ══════════════════════════════════════════════════════════
    final shadowPath = Path()
      ..moveTo(topL + 16, topY + 8)
      ..lineTo(topR - 16, topY + 8)
      ..lineTo(botR + 8, botY + 22)
      ..lineTo(botL - 8, botY + 22)
      ..close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // ══════════════════════════════════════════════════════════
    // 4. الحافة السفلية ثلاثية الأبعاد — معدن زجاجي داكن
    // ══════════════════════════════════════════════════════════
    const thickness = 14.0;
    final edgePath = Path()
      ..moveTo(botL, botY - 10)
      ..lineTo(botR, botY - 10)
      ..lineTo(botR, botY + thickness - 8)
      ..quadraticBezierTo(botR, botY + thickness, botR - 20, botY + thickness)
      ..lineTo(botL + 20, botY + thickness)
      ..quadraticBezierTo(botL, botY + thickness, botL, botY + thickness - 8)
      ..close();

    final edgePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, botY - 5),
        Offset(0, botY + thickness),
        const [
          Color(0xFF2A3454),
          Color(0xFF18203C),
          Color(0xFF0B1023),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawPath(edgePath, edgePaint);

    // خط لمعان سفلي زجاجي على الحافة
    canvas.drawLine(
      Offset(botL + 25, botY + thickness),
      Offset(botR - 25, botY + thickness),
      Paint()
        ..color = _rimLight.withOpacity(0.30)
        ..strokeWidth = 1.0,
    );

    // ══════════════════════════════════════════════════════════
    // 5. سطح الطاولة — زجاج كحلي عميق / كسنة / تأثير متحرك
    // ══════════════════════════════════════════════════════════
    final surfaceImage =
        surfaceItem != null ? StoreService().uiImageOf(surfaceItem!) : null;
    final woodBase = StoreService().defaultWoodImage;
    if (surfaceEffect != SkinEffect.none) {
      // تأثير متحرك على خشب حقيقي — حبيبات الخشب تُدمج فوق التأثير
      canvas.save();
      canvas.clipPath(tablePath);
      paintSkinEffect(canvas, size, surfaceEffect, animT, wood: woodBase);
      canvas.drawRect(
        tablePath.getBounds(),
        Paint()..color = Colors.black.withOpacity(0.15),
      );
      canvas.restore();
    } else if (surfaceImage != null) {
      final img = surfaceImage;
      final imgW = img.width.toDouble();
      final imgH = img.height.toDouble();
      final dst = tablePath.getBounds();
      final zoom = (surfaceItem!.zoom).clamp(0.5, 5.0);
      final cover = math.max(dst.width / imgW, dst.height / imgH) * zoom;
      final dw = imgW * cover;
      final dh = imgH * cover;
      final dx = dst.center.dx - dw / 2 + surfaceItem!.offsetX * dst.width / 2;
      final dy = dst.center.dy - dh / 2 + surfaceItem!.offsetY * dst.height / 2;
      canvas.save();
      canvas.clipPath(tablePath);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, imgW, imgH),
        Rect.fromLTWH(dx, dy, dw, dh),
        Paint(),
      );
      canvas.drawRect(
        dst,
        Paint()..color = Colors.black.withOpacity(0.18),
      );
      canvas.restore();
    } else {
      // السطح الافتراضي: خامة خشب الماهوغني الحقيقية (أو زجاج كحلي كبديل)
      if (woodBase != null) {
        final dst = tablePath.getBounds();
        final iw = woodBase.width.toDouble();
        final ih = woodBase.height.toDouble();
        final cover = math.max(dst.width / iw, dst.height / ih);
        final dw = iw * cover;
        final dh = ih * cover;
        canvas.save();
        canvas.clipPath(tablePath);
        canvas.drawImageRect(
          woodBase,
          Rect.fromLTWH(0, 0, iw, ih),
          Rect.fromLTWH(dst.center.dx - dw / 2, dst.center.dy - dh / 2, dw, dh),
          Paint(),
        );
        // بقعة ضوء مركزية خفيفة فوق الخشب
        canvas.drawRect(
          dst,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(w * 0.5, h * 0.40),
              w * 0.5,
              [
                Colors.white.withOpacity(0.14),
                Colors.transparent,
                Colors.black.withOpacity(0.28),
              ],
              const [0.0, 0.55, 1.0],
            ),
        );
        canvas.restore();
      } else {
        canvas.drawPath(
          tablePath,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(w * 0.5, h * 0.44),
              w * 0.55,
              const [
                Color(0xFF2A3A66),
                Color(0xFF1C2949),
                Color(0xFF121A36),
                Color(0xFF0A0F22),
                Color(0xFF060A18),
              ],
              const [0.0, 0.35, 0.65, 0.88, 1.0],
            ),
        );
      }
      // طبقة زجاجية: لمعان علوي ناعم (Glass sheen)
      canvas.save();
      canvas.clipPath(tablePath);
      canvas.drawRect(
        Rect.fromLTWH(topL - 10, topY, topR - topL + 20, (botY - topY) * 0.45),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, topY),
            Offset(0, topY + (botY - topY) * 0.45),
            [
              Colors.white.withOpacity(0.09),
              Colors.white.withOpacity(0.02),
              Colors.transparent,
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
      // انعكاس جانبي زجاجي خفيف
      canvas.drawRect(
        Rect.fromLTWH(topL - 6, topY, 26, botY - topY),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(topL - 6, 0),
            Offset(topL + 20, 0),
            [
              Colors.white.withOpacity(0.06),
              Colors.transparent,
            ],
          ),
      );
      canvas.restore();
    }

    // لمعان حافة السطح العلوية — زجاجي فاتح
    canvas.drawPath(
      tablePath,
      Paint()
        ..color = _rimLight.withOpacity(0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ══════════════════════════════════════════════════════════
    // 6. منطقة اللعب الغائرة (Inset Glass Play-Field)
    // ══════════════════════════════════════════════════════════
    const gInset = 12.0;
    final groovePath = Path()
      ..moveTo(topL + 24, topY + gInset)
      ..lineTo(topR - 24, topY + gInset)
      ..lineTo(botR - gInset - 4, botY - gInset)
      ..lineTo(botL + gInset + 4, botY - gInset)
      ..close();

    // عمق داخلي خفيف جداً — يعطي إحساس الغور دون ازدحام
    canvas.drawPath(
      groovePath,
      Paint()..color = Colors.black.withOpacity(0.16),
    );

    // خط المجرى الغائر
    canvas.drawPath(
      groovePath,
      Paint()
        ..color = const Color(0xFF04060F).withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // لمعان الحافة الخارجية للمجرى — زجاجي
    canvas.drawPath(
      groovePath,
      Paint()
        ..color = _rimLight.withOpacity(0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ══════════════════════════════════════════════════════════
    // 7. خطوط زجاجية دقيقة على السطح (بدل عروق الخشب)
    // ══════════════════════════════════════════════════════════
    final sheenPaint = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 0.8;

    for (double t = 0.16; t < 0.80; t += 0.10) {
      final y = topY + (botY - topY) * t;
      final x1 = topL + (botL - topL) * t + 20;
      final x2 = topR + (botR - topR) * t - 20;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), sheenPaint);
    }

    // ══════════════════════════════════════════════════════════
    // 9. مؤشر خفيف في المنتصف
    // ══════════════════════════════════════════════════════════
    _drawText(
      canvas,
      'Indicator',
      Offset(w * 0.50, h * 0.28),
      fontSize: 8.5,
      color: _rimLight.withOpacity(0.35),
      isBold: false,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color color,
    required bool isBold,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.5,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant OkeyTablePainter oldDelegate) =>
      oldDelegate.isHumanTurn != isHumanTurn ||
      oldDelegate.surfaceItem != surfaceItem ||
      oldDelegate.surfaceEffect != surfaceEffect ||
      oldDelegate.animT != animT;
}
