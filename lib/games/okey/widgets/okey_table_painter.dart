import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// رسام الطاولة الخشبية ثلاثية الأبعاد الفاخرة - مطابق تماماً لمنظور ولون الصورة المرجعية
class OkeyTablePainter extends CustomPainter {
  final bool isHumanTurn;

  const OkeyTablePainter({this.isHumanTurn = true});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // أبعاد سطح الطاولة بمنظور ثلاثي الأبعاد حقيقي (Trapezoid Perspective)
    // الحافة العلوية أضيق لأنها أبعد، والحافة السفلية أوسع لأنها أقرب
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
    // 1. أرجل الطاولة السفلية (Wooden Table Legs)
    // ══════════════════════════════════════════════════════════
    final legPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, botY),
        Offset(0, botY + 28),
        [
          const Color(0xFF1E0A03),
          const Color(0xFF0F0401),
          const Color(0xFF050100),
        ],
      );

    // رجل الطاولة اليسرى
    final leftLeg = Path()
      ..moveTo(botL + 34, botY)
      ..lineTo(botL + 54, botY)
      ..lineTo(botL + 48, botY + 25)
      ..lineTo(botL + 28, botY + 25)
      ..close();
    canvas.drawPath(leftLeg, legPaint);

    // رجل الطاولة اليمنى
    final rightLeg = Path()
      ..moveTo(botR - 54, botY)
      ..lineTo(botR - 34, botY)
      ..lineTo(botR - 28, botY + 25)
      ..lineTo(botR - 48, botY + 25)
      ..close();
    canvas.drawPath(rightLeg, legPaint);

    // ══════════════════════════════════════════════════════════
    // 2. ظل الطاولة العميق على الأرضية المحيطة
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
    // 3. الحافة السفلية ثلاثية الأبعاد (3D Front Bevel Thickness)
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
        [
          const Color(0xFF351A0D),
          const Color(0xFF220F06),
          const Color(0xFF140803),
        ],
      );
    canvas.drawPath(edgePath, edgePaint);

    // خط لمعان سفلي على الحافة
    canvas.drawLine(
      Offset(botL + 25, botY + thickness),
      Offset(botR - 25, botY + thickness),
      Paint()
        ..color = const Color(0xFFD4A373).withOpacity(0.18)
        ..strokeWidth = 1.0,
    );

    // ══════════════════════════════════════════════════════════
    // 4. سطح الطاولة الخشبي الفاخر (Polished Mahogany Wood)
    // ══════════════════════════════════════════════════════════
    final surfacePaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(w * 0.5, h * 0.44),
        w * 0.55,
        [
          const Color(0xFF5A2F17), // إضاءة دافئة في الوسط
          const Color(0xFF492410),
          const Color(0xFF381A0B),
          const Color(0xFF281106),
          const Color(0xFF1B0A03),
        ],
        [0.0, 0.35, 0.65, 0.88, 1.0],
      );
    canvas.drawPath(tablePath, surfacePaint);

    // خط لمعان الحافة العلوية لسطح الطاولة
    canvas.drawPath(
      tablePath,
      Paint()
        ..color = const Color(0xFFE8B88A).withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ══════════════════════════════════════════════════════════
    // 5. المجرى المحفور الأنيق (Routed Groove Inset)
    // ══════════════════════════════════════════════════════════
    const gInset = 12.0;
    final groovePath = Path()
      ..moveTo(topL + 24, topY + gInset)
      ..lineTo(topR - 24, topY + gInset)
      ..lineTo(botR - gInset - 4, botY - gInset)
      ..lineTo(botL + gInset + 4, botY - gInset)
      ..close();

    // ظل المجرى الداخلي الغائر
    canvas.drawPath(
      groovePath,
      Paint()
        ..color = const Color(0xFF120501).withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // لمعان الحافة الخارجية للمجرى
    canvas.drawPath(
      groovePath,
      Paint()
        ..color = const Color(0xFFD4A373).withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ══════════════════════════════════════════════════════════
    // 6. عروق الخشب الناعمة المنقوشة على السطح
    // ══════════════════════════════════════════════════════════
    final grainPaint = Paint()
      ..color = Colors.black.withOpacity(0.035)
      ..strokeWidth = 0.8;

    for (double t = 0.12; t < 0.82; t += 0.04) {
      final y = topY + (botY - topY) * t;
      final x1 = topL + (botL - topL) * t + 20;
      final x2 = topR + (botR - topR) * t - 20;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), grainPaint);
    }

    // ══════════════════════════════════════════════════════════
    // 7. الأسهم التوجيهية المنقوشة على الطاولة
    // ══════════════════════════════════════════════════════════
    final arrowPaint = Paint()
      ..color = const Color(0xFFECC29C).withOpacity(0.38)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arrowTipPaint = Paint()
      ..color = const Color(0xFFECC29C).withOpacity(0.42)
      ..style = PaintingStyle.fill;

    // السهم الأيسر المتجه للأعلى
    final leftX = w * 0.28;
    final leftY1 = h * 0.54;
    final leftY2 = h * 0.34;
    _drawArrow(canvas, Offset(leftX, leftY1), Offset(leftX, leftY2), arrowPaint, arrowTipPaint, isUp: true);

    // السهم الأيمن المتجه للأسفل
    final rightX = w * 0.72;
    final rightY1 = h * 0.34;
    final rightY2 = h * 0.54;
    _drawArrow(canvas, Offset(rightX, rightY1), Offset(rightX, rightY2), arrowPaint, arrowTipPaint, isUp: false);

    // ══════════════════════════════════════════════════════════
    // 8. مؤشر الحجر المركزي الخفيف (Indicator Label)
    // ══════════════════════════════════════════════════════════
    _drawText(
      canvas,
      'Indicator',
      Offset(w * 0.50, h * 0.28),
      fontSize: 8.5,
      color: const Color(0xFFECC29C).withOpacity(0.4),
      isBold: false,
    );
  }

  void _drawArrow(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint linePaint,
    Paint tipPaint, {
    required bool isUp,
  }) {
    canvas.drawLine(start, end, linePaint);

    final tip = Path();
    if (isUp) {
      tip.moveTo(end.dx, end.dy - 2);
      tip.lineTo(end.dx - 5.5, end.dy + 8);
      tip.lineTo(end.dx + 5.5, end.dy + 8);
    } else {
      tip.moveTo(end.dx, end.dy + 2);
      tip.lineTo(end.dx - 5.5, end.dy - 8);
      tip.lineTo(end.dx + 5.5, end.dy - 8);
    }
    tip.close();
    canvas.drawPath(tip, tipPaint);
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
      oldDelegate.isHumanTurn != isHumanTurn;
}
