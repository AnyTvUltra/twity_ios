import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class TitleBanner extends StatelessWidget {
  const TitleBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 42,
            left: 28,
            right: 28,
            height: 82,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.12),
                          const Color(0xFF6D5DFF).withOpacity(0.08),
                          const Color(0xFF061126).withOpacity(0.20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.14)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Main Title & Subtitle Column
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 3D Golden Crown with surrounding sparkle stars
              SizedBox(
                height: 48,
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      left: 6,
                      top: 14,
                      child: _SparkleStar(color: Color(0xFF60A5FA), size: 12),
                    ),
                    const Positioned(
                      left: 24,
                      top: 4,
                      child: _SparkleStar(color: Color(0xFFFFD54F), size: 14),
                    ),
                    const Positioned(
                      right: 22,
                      top: 6,
                      child: _SparkleStar(color: Color(0xFFFFD54F), size: 14),
                    ),
                    const Positioned(
                      right: 6,
                      top: 16,
                      child: _SparkleStar(color: Color(0xFF60A5FA), size: 12),
                    ),

                    // Golden 3D Crown
                    CustomPaint(
                      size: const Size(54, 38),
                      painter: _CrownPainter(),
                    ),
                  ],
                ),
              ),

              // "مجموعة" - 3D Golden Arabic Text (scaled to fit)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, 3),
                      child: Text(
                        'یەڵا یاری',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 6
                            ..color = const Color(0xFF5D2E05),
                        ),
                      ),
                    ),
                    Text(
                      'یەڵا یاری',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = const Color(0xFF7A3E00),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFBEA),
                          Color(0xFFFFEA79),
                          Color(0xFFFFB300),
                          Color(0xFFE67E00),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'یەڵا یاری',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Color(0xFFFFB300),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // "الألعاب الممتعة" - 3D White Arabic Text with Purple Outline (scaled to fit)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, 3.5),
                      child: Text(
                        'Yalla Yari',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 6.5
                            ..color = const Color(0xFF1B0B33),
                        ),
                      ),
                    ),
                    Text(
                      'Yalla Yari',
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = const Color(0xFF38146B),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white,
                          Color(0xFFF3E8FF),
                          Color(0xFFD8B4FE),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Yalla Yari',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Color(0xFFC084FC),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle dark capsule
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.18),
                          const Color(0xFF253A72).withOpacity(0.46),
                          const Color(0xFF111B3E).withOpacity(0.62),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withOpacity(0.28)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C5CFF).withOpacity(0.16),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Text(
                      'اختر لعبتك المفضلة واستمتع بالوقت!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF4F5FF),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Pinned Sticky Note on the top-right
          Positioned(
            right: 0,
            top: 28,
            child: Transform.rotate(
              angle: 6 * math.pi / 180,
              child: const _StickyNoteWidget(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final crownPath = Path()
      ..moveTo(0, h * 0.2)
      ..lineTo(w * 0.22, h * 0.5)
      ..lineTo(w * 0.35, h * 0.1)
      ..lineTo(w * 0.5, h * 0.45)
      ..lineTo(w * 0.5, h * 0.0)
      ..lineTo(w * 0.5, h * 0.45)
      ..lineTo(w * 0.65, h * 0.1)
      ..lineTo(w * 0.78, h * 0.5)
      ..lineTo(w, h * 0.2)
      ..lineTo(w * 0.9, h * 0.9)
      ..quadraticBezierTo(w * 0.5, h * 0.96, w * 0.1, h * 0.9)
      ..close();

    final shadowPaint = Paint()..color = const Color(0xFF6B4300);
    canvas.drawPath(crownPath.shift(const Offset(0, 2)), shadowPaint);

    final crownPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFDE7),
          Color(0xFFFFEE58),
          Color(0xFFFFB300),
          Color(0xFFE65100),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(crownPath, crownPaint);

    final jewelPaint = Paint()..color = const Color(0xFFE91E63);
    canvas.drawCircle(Offset(w * 0.5, h * 0.08), 2.5, jewelPaint);
    canvas.drawCircle(Offset(w * 0.35, h * 0.18), 2.0, jewelPaint);
    canvas.drawCircle(Offset(w * 0.65, h * 0.18), 2.0, jewelPaint);

    final bandPath = Path()
      ..moveTo(w * 0.12, h * 0.82)
      ..quadraticBezierTo(w * 0.5, h * 0.88, w * 0.88, h * 0.82)
      ..lineTo(w * 0.9, h * 0.9)
      ..quadraticBezierTo(w * 0.5, h * 0.96, w * 0.1, h * 0.9)
      ..close();
    final bandPaint = Paint()..color = const Color(0xFFFF8F00);
    canvas.drawPath(bandPath, bandPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparkleStar extends StatelessWidget {
  final Color color;
  final double size;

  const _SparkleStar({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SparkleStarPainter(color: color),
    );
  }
}

class _SparkleStarPainter extends CustomPainter {
  final Color color;

  _SparkleStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..quadraticBezierTo(w / 2, h / 2, w, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, h)
      ..quadraticBezierTo(w / 2, h / 2, 0, h / 2)
      ..quadraticBezierTo(w / 2, h / 2, w / 2, 0)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StickyNoteWidget extends StatelessWidget {
  const _StickyNoteWidget();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 70,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.72),
                const Color(0xFFFFE8A3).withOpacity(0.54),
                Colors.white.withOpacity(0.24),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.72)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD76A).withOpacity(0.18),
                blurRadius: 12,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: -10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 3,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 3),
                  Text(
                    'الـلـعـب\nمـتـعـة\nلا تنتهي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF42210B),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '❤️',
                    style: TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
