import 'package:flutter/material.dart';

/// مجوهرة زرقاء ثلاثية الأبعاد بلا خلفية — مرسومة بأوجه متعددة
/// تشبه إيموجي 💎 في iOS لكن بتدرجات ولمعان أجمل
class GemIcon extends StatelessWidget {
  final double size;

  const GemIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GemPainter()),
    );
  }
}

class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // نقاط الشكل: تاج عريض في الأعلى + قاع مدبب
    final topL = Offset(w * 0.18, h * 0.12);
    final topR = Offset(w * 0.82, h * 0.12);
    final midL = Offset(w * 0.02, h * 0.38);
    final midR = Offset(w * 0.98, h * 0.38);
    final bottom = Offset(w * 0.5, h * 0.97);

    final shoulderY = h * 0.36;
    final midTop = Offset(w * 0.5, shoulderY);

    Paint facet(Color a, Color b, AlignmentGeometry begin,
        AlignmentGeometry end, Rect bounds) {
      return Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: [a, b],
        ).createShader(bounds);
    }

    final bounds = Offset.zero & size;

    // ── التاج العلوي: 3 أوجه ──
    // الوجه الأيسر
    final f1 = Path()
      ..moveTo(topL.dx, topL.dy)
      ..lineTo(midTop.dx, midTop.dy)
      ..lineTo(midL.dx, midL.dy)
      ..close();
    canvas.drawPath(
      f1,
      facet(const Color(0xFF7DD3FC), const Color(0xFF38BDF8),
          Alignment.topLeft, Alignment.bottomRight, bounds),
    );

    // الوجه الأوسط
    final f2 = Path()
      ..moveTo(topL.dx, topL.dy)
      ..lineTo(topR.dx, topR.dy)
      ..lineTo(midTop.dx, midTop.dy)
      ..close();
    canvas.drawPath(
      f2,
      facet(const Color(0xFFE0F2FE), const Color(0xFF7DD3FC),
          Alignment.topCenter, Alignment.bottomCenter, bounds),
    );

    // الوجه الأيمن
    final f3 = Path()
      ..moveTo(topR.dx, topR.dy)
      ..lineTo(midTop.dx, midTop.dy)
      ..lineTo(midR.dx, midR.dy)
      ..close();
    canvas.drawPath(
      f3,
      facet(const Color(0xFF38BDF8), const Color(0xFF0EA5E9),
          Alignment.topRight, Alignment.bottomLeft, bounds),
    );

    // ── القاع المدبب: 3 أوجه ──
    // الوجه الأيسر
    final b1 = Path()
      ..moveTo(midL.dx, midL.dy)
      ..lineTo(midTop.dx, midTop.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..close();
    canvas.drawPath(
      b1,
      facet(const Color(0xFF0EA5E9), const Color(0xFF0369A1),
          Alignment.topLeft, Alignment.bottomRight, bounds),
    );

    // الوجه الأيمن
    final b2 = Path()
      ..moveTo(midR.dx, midR.dy)
      ..lineTo(midTop.dx, midTop.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..close();
    canvas.drawPath(
      b2,
      facet(const Color(0xFF0284C7), const Color(0xFF075985),
          Alignment.topRight, Alignment.bottomLeft, bounds),
    );

    // الوجه الأوسط اللامع
    final b3 = Path()
      ..moveTo(midL.dx + w * 0.16, midL.dy)
      ..lineTo(midTop.dx, midTop.dy)
      ..lineTo(midR.dx - w * 0.16, midR.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..close();
    canvas.drawPath(
      b3,
      facet(const Color(0xFFBAE6FD), const Color(0xFF0EA5E9),
          Alignment.topCenter, Alignment.bottomCenter, bounds),
    );

    // ── لمعة صغيرة أعلى اليسار ──
    final shine = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(Offset(w * 0.3, h * 0.2), w * 0.07, shine);

    // ── حدود خفيفة توحّد الشكل ──
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..color = const Color(0xFF0C4A6E).withOpacity(0.5)
      ..strokeJoin = StrokeJoin.round;
    final outlinePath = Path()
      ..moveTo(topL.dx, topL.dy)
      ..lineTo(topR.dx, topR.dy)
      ..lineTo(midR.dx, midR.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(midL.dx, midL.dy)
      ..close();
    canvas.drawPath(outlinePath, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
