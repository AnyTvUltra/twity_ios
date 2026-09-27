import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models.dart';
import '../utils/haptics.dart';
import 'game_artwork.dart';

class GameCard extends StatefulWidget {
  final GameModel game;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const GameCard({
    super.key,
    required this.game,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    AppHaptics.light();
    _animController.forward();
  }

  void _onTapUp(TapUpDetails _) {
    AppHaptics.medium();
    _animController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * (_isHovered ? 1.018 : 1.0),
          child: child,
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: SizedBox(
            width: widget.width ?? double.infinity,
            height: widget.height ?? 205,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // Main Card Body with Custom Arched Shape
                Positioned.fill(
                  bottom: 14, // leave room for overlapping play button
                  child: CustomPaint(
                    painter: _CardShapePainter(
                      gradient: widget.game.gradient,
                      borderColor: widget.game.borderColor,
                      borderLightColor: widget.game.borderLightColor,
                      glowColor: widget.game.glowColor,
                    ),
                    child: ClipPath(
                      clipper: _CardClipper(),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Stack(
                          children: [
                            // Glossy top-to-bottom sheen
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withOpacity(0.18),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.25),
                                    ],
                                    stops: const [0.0, 0.35, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Card Content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 1. Artwork area (top 58%)
                                Expanded(
                                  flex: 58,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 14, left: 6, right: 6),
                                    child: GameArtwork(gameId: widget.game.id),
                                  ),
                                ),

                                // 2. Info area (bottom 42%)
                                Expanded(
                                  flex: 42,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(8, 0, 8, 14),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // Game Title
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            widget.game.title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.2,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black54,
                                                  blurRadius: 4,
                                                  offset: Offset(0, 1.5),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),

                                        // Subtitle / Description
                                        Text(
                                          widget.game.description,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.85),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            shadows: const [
                                              Shadow(
                                                color: Colors.black45,
                                                blurRadius: 3,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Corner Doodle details (small white sketch lines)
                            Positioned(
                              top: 10,
                              left: 8,
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 11,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              right: 8,
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 11,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 3D Golden Crown on top of card (if flagged)
                if (widget.game.hasCrown)
                  Positioned(
                    top: -14,
                    right: 12,
                    child: CustomPaint(
                      size: const Size(36, 26),
                      painter: _MiniCrownPainter(),
                    ),
                  ),

                // Circular Play Button overlapping the bottom center
                Positioned(
                  bottom: 0,
                  child: _PlayButton(
                    glowColor: widget.game.glowColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// CARD SHAPE CLIPPER WITH SCALLOPED ARCHED TOP
// ----------------------------------------------------
class _CardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(24),
      ));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ----------------------------------------------------
// CARD SHAPE PAINTER WITH RICH 3D BEVEL & BORDER
// ----------------------------------------------------
class _CardShapePainter extends CustomPainter {
  final LinearGradient gradient;
  final Color borderColor;
  final Color borderLightColor;
  final Color glowColor;

  _CardShapePainter({
    required this.gradient,
    required this.borderColor,
    required this.borderLightColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(24),
      ));

    // 1. Drop Shadow under card (hardware accelerated)
    canvas.drawPath(path.shift(const Offset(0, 7)),
        Paint()..color = Colors.black.withOpacity(0.28));
    canvas.drawPath(path.shift(const Offset(0, 2)),
        Paint()..color = glowColor.withOpacity(0.10));

    // 2. Outer Glow around card (fast vector stroke)
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withOpacity(0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );

    // 3. Card Base Gradient Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: gradient.begin,
        end: gradient.end,
        stops: gradient.stops,
        colors:
            gradient.colors.map((color) => color.withOpacity(0.54)).toList(),
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(path, fillPaint);

    // 4. Outer Colored Border
    final borderPaint = Paint()
      ..color = borderLightColor.withOpacity(0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(path, borderPaint);

    // 5. Inner Highlight Rim on top edge
    final rimPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          borderLightColor.withOpacity(0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, 24))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawPath(path, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ----------------------------------------------------
// CIRCULAR PLAY BUTTON OVERLAPPING BOTTOM OF CARD
// ----------------------------------------------------
class _PlayButton extends StatelessWidget {
  final Color glowColor;

  const _PlayButton({required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.38),
            glowColor.withOpacity(0.72),
            glowColor.withOpacity(0.34),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.55),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.arrow_forward_ios_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// MINI 3D CROWN FOR CARD CREST
// ----------------------------------------------------
class _MiniCrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final crownPath = Path()
      ..moveTo(0, h * 0.25)
      ..lineTo(w * 0.25, h * 0.5)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.75, h * 0.5)
      ..lineTo(w, h * 0.25)
      ..lineTo(w * 0.85, h)
      ..lineTo(w * 0.15, h)
      ..close();

    // Shadow
    canvas.drawPath(
      crownPath.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    // Gold Gradient
    final crownPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(crownPath, crownPaint);

    // Jewel
    canvas.drawCircle(Offset(w * 0.5, h * 0.18), 2.2,
        Paint()..color = const Color(0xFFD32F2F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
