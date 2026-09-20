import 'package:flutter/material.dart';
import '../utils/haptics.dart';

class MoreGamesBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const MoreGamesBanner({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.light();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: SizedBox(
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Orange artistic background splash/brush under the ribbon
              Positioned(
                left: 8,
                right: 48,
                height: 48,
                child: CustomPaint(
                  painter: _OrangeBrushPainter(),
                ),
              ),

              // Main Dark Indigo Ribbon with text & controller
              Positioned(
                left: 14,
                right: 54,
                height: 42,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF311B92),
                        Color(0xFF1E1B4B),
                        Color(0xFF2E1065),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: const Color(0x60A78BFA),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.sports_esports_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'المزيد من الألعاب بانتظارك!',
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Stack of 3D Gold Coins + Crown on the right
              Positioned(
                right: 6,
                bottom: 2,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: CustomPaint(
                    painter: _CoinStackWithCrownPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrangeBrushPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFF6D00),
          Color(0xFFFF9100),
          Color(0xFFFFAB40),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = Path()
      ..moveTo(w * 0.05, h * 0.5)
      ..quadraticBezierTo(0, h * 0.1, w * 0.2, h * 0.05)
      ..quadraticBezierTo(w * 0.5, -4, w * 0.8, h * 0.08)
      ..quadraticBezierTo(w, h * 0.2, w * 0.96, h * 0.6)
      ..quadraticBezierTo(w * 0.9, h * 1.05, w * 0.6, h * 0.95)
      ..quadraticBezierTo(w * 0.2, h * 1.08, w * 0.05, h * 0.5)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoinStackWithCrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawCoin(canvas, Offset(w * 0.45, h * 0.78), 24, 7);
    _drawCoin(canvas, Offset(w * 0.52, h * 0.68), 24, 7);
    _drawCoin(canvas, Offset(w * 0.32, h * 0.65), 24, 7);

    final crownPath = Path()
      ..moveTo(w * 0.35, h * 0.32)
      ..lineTo(w * 0.48, h * 0.42)
      ..lineTo(w * 0.60, h * 0.22)
      ..lineTo(w * 0.72, h * 0.42)
      ..lineTo(w * 0.85, h * 0.32)
      ..lineTo(w * 0.78, h * 0.58)
      ..lineTo(w * 0.42, h * 0.58)
      ..close();

    final crownPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFFDE7), Color(0xFFFFD54F), Color(0xFFFF8F00)],
      ).createShader(Rect.fromLTWH(w * 0.35, h * 0.22, w * 0.5, h * 0.36));

    canvas.drawPath(
      crownPath.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withOpacity(0.35),
    );
    canvas.drawPath(crownPath, crownPaint);

    canvas.drawCircle(Offset(w * 0.60, h * 0.32), 2, Paint()..color = const Color(0xFFD32F2F));
  }

  void _drawCoin(Canvas canvas, Offset center, double width, double thickness) {
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, thickness), width: width, height: thickness * 1.4),
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    final edgePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFB300), Color(0xFFC67D00)],
      ).createShader(Rect.fromCenter(center: center, width: width, height: thickness));
    canvas.drawRect(
      Rect.fromCenter(center: center, width: width, height: thickness),
      edgePaint,
    );

    final topPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
      ).createShader(Rect.fromCenter(center: center.translate(0, -thickness * 0.5), width: width, height: thickness * 1.5));

    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, -thickness * 0.5), width: width, height: thickness * 1.5),
      topPaint,
    );

    canvas.drawCircle(center.translate(0, -thickness * 0.5), 2.5, Paint()..color = const Color(0xFFBF360C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
