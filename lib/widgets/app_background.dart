import 'package:flutter/material.dart';
import '../theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  /// وضع الزجاج الأبيض الفاتح — يُستخدم في الصفحات الداخلية (الرئيسية تبقى داكنة)
  final bool light;

  const AppBackground({super.key, required this.child, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Gradient
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: light
                  ? AppGradients.lightBackground
                  : AppGradients.fullBackground,
            ),
          ),
        ),

        // Ambient Lamp Light & Warm Wood Floor Effects
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _AmbiancePainter(light: light),
            ),
          ),
        ),

        // Foreground content
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}

class _AmbiancePainter extends CustomPainter {
  final bool light;

  _AmbiancePainter({this.light = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (light) {
      _paintLight(canvas, size);
      return;
    }
    // 1. Warm lamp light glow on the top-left
    final lampCenter = Offset(size.width * 0.15, size.height * 0.12);
    final lampGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C5CFF).withOpacity(0.30),
          const Color(0xFF4F46E5).withOpacity(0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
          Rect.fromCircle(center: lampCenter, radius: size.width * 0.55));

    canvas.drawCircle(lampCenter, size.width * 0.55, lampGlowPaint);

    // 2. Hanging Lamp Cone of Light
    final lampPath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.08)
      ..lineTo(size.width * 0.35, size.height * 0.4)
      ..lineTo(0, size.height * 0.4)
      ..close();

    final conePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B5CF6).withOpacity(0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(
          0, size.height * 0.08, size.width * 0.35, size.height * 0.32));

    canvas.drawPath(lampPath, conePaint);

    // 3. Warm wooden tabletop glow across the lower middle area
    final tableRect =
        Rect.fromLTWH(0, size.height * 0.28, size.width, size.height * 0.72);
    final tableGlowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.2),
        radius: 0.85,
        colors: [
          const Color(0xFF2563EB).withOpacity(0.18),
          const Color(0xFF06B6D4).withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(tableRect);

    canvas.drawRect(tableRect, tableGlowPaint);

    // 4. Subtle wood plank horizontal grain lines
    final plankPaint = Paint()
      ..color = const Color(0xFF9DB7FF).withOpacity(0.025)
      ..strokeWidth = 1.0;

    for (double y = size.height * 0.35;
        y < size.height;
        y += size.height * 0.12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), plankPaint);
    }

    // 5. Floating atmospheric dust motes / glowing specks
    final speckPaint = Paint()
      ..color = const Color(0xFFFFE082).withOpacity(0.3);
    final randomSpecks = [
      Offset(size.width * 0.12, size.height * 0.2),
      Offset(size.width * 0.25, size.height * 0.16),
      Offset(size.width * 0.08, size.height * 0.28),
      Offset(size.width * 0.82, size.height * 0.18),
      Offset(size.width * 0.75, size.height * 0.26),
      Offset(size.width * 0.88, size.height * 0.12),
      Offset(size.width * 0.5, size.height * 0.1),
    ];

    for (final pt in randomSpecks) {
      canvas.drawCircle(pt, 1.5, speckPaint);
    }
  }

  /// توهجات هوائية ناعمة للوضع الليلي (زجاج داكن)
  void _paintLight(Canvas canvas, Size size) {
    // 1. توهج نيلي خافت أعلى اليسار
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF38BDF8).withOpacity(0.14),
          const Color(0xFF4F46E5).withOpacity(0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.10),
          radius: size.width * 0.55));
    canvas.drawCircle(
        Offset(size.width * 0.15, size.height * 0.10), size.width * 0.55,
        glowPaint);

    // 2. توهج بنفسجي خافت أسفل اليمين
    final skyPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C5CFF).withOpacity(0.12),
          const Color(0xFF38BDF8).withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.9),
          radius: size.width * 0.6));
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.9), size.width * 0.6,
        skyPaint);

    // 3. خطوط زجاجية خافتة
    final streakPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;
    for (double y = size.height * 0.25;
        y < size.height;
        y += size.height * 0.16) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), streakPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbiancePainter oldDelegate) =>
      oldDelegate.light != light;
}
