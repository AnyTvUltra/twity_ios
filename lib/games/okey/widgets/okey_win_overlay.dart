import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../okey_models.dart';
import 'okey_tile_widget.dart';
import '../../../l10n/app_lang.dart';

/// طبقة احتفال الفوز — تظهر لكل اللاعبين فوق الطاولة قبل نافذة النتيجة
/// آخر حجر مرمي يطير بقوس درامي إلى المنتصف، ثم كونفيتي + لافتة كأس
class OkeyWinOverlay extends StatefulWidget {
  final OkeyPlayer winner;
  final WinType winType;

  /// آخر حجر رماه الفائز — يطير بشكل درامي إلى منتصف المشهد
  final OkeyTile? lastTile;

  const OkeyWinOverlay({
    super.key,
    required this.winner,
    required this.winType,
    this.lastTile,
  });

  @override
  State<OkeyWinOverlay> createState() => _OkeyWinOverlayState();
}

class _OkeyWinOverlayState extends State<OkeyWinOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bannerScale;
  late Animation<double> _bannerOpacity;
  late Animation<double> _tileFlight;
  final List<_ConfettiPiece> _pieces = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2900),
    )..forward();

    // الحجر يطير أولاً (0 → 38%)، ثم اللافتة تنبثق (18% → 46%)
    _tileFlight = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.38, curve: Curves.easeOutCubic),
    );
    _bannerScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.50, curve: Curves.elasticOut),
    );
    _bannerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.30, curve: Curves.easeIn),
    );

    final rng = math.Random(7);
    const palette = [
      Color(0xFFFFD54F),
      Color(0xFF4ADE80),
      Color(0xFF60A5FA),
      Color(0xFFF472B6),
      Color(0xFFF97316),
      Color(0xFF22D3EE),
      Color(0xFFE9E2F6),
    ];
    for (int i = 0; i < 110; i++) {
      _pieces.add(_ConfettiPiece(
        x: rng.nextDouble(),
        delay: 0.30 + rng.nextDouble() * 0.35,
        speed: 0.55 + rng.nextDouble() * 0.5,
        size: 3.5 + rng.nextDouble() * 5,
        sway: 14 + rng.nextDouble() * 26,
        swayFreq: 1.4 + rng.nextDouble() * 2.2,
        spin: (rng.nextDouble() - 0.5) * 9,
        color: palette[rng.nextInt(palette.length)],
        isCircle: rng.nextBool(),
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHuman = widget.winner.isHuman;
    final accent =
        isHuman ? const Color(0xFFFFD54F) : const Color(0xFF60A5FA);
    final title = isHuman ? 'مبروك! فزت!'.tr : 'فاز {}!'.trp([widget.winner.name]);
    final sub = switch (widget.winType) {
      WinType.discardOkey => 'برمي حجر الأوكي — Okey ile Bitti'.tr,
      WinType.sevenPairs => 'بالأزواج السبعة — 7 Çift'.tr,
      WinType.normal => 'بإكمال المجموعات'.tr,
    };

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sw = constraints.maxWidth;
          final sh = constraints.maxHeight;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final ft = _tileFlight.value;
              // مسار الحَجر: من أسفل الشاشة إلى فوق اللافتة بقوس
              final tileX = sw / 2;
              final tileY = sh * 1.15 +
                  (sh * 0.30 - sh * 1.15) * ft -
                  math.sin(ft * math.pi) * 60;
              final tileRot = (1 - ft) * math.pi * 2.2;
              final tileScale = 0.7 + ft * 0.9;
              // وميض الهبوط عند وصول الحجر
              final landBurst =
                  ft >= 0.98 ? ((_controller.value - 0.38) / 0.12).clamp(0.0, 1.0) : 0.0;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // تعتيم خفيف يخفت مع الوقت
                  Container(
                    color: Colors.black
                        .withOpacity(0.30 * (1 - _controller.value * 0.6)),
                  ),
                  // الكونفيتي
                  CustomPaint(
                    painter: _ConfettiPainter(
                      pieces: _pieces,
                      t: _controller.value,
                    ),
                  ),

                  // توهج هبوط الحجر (وميض دائري يتمدد)
                  if (landBurst > 0 && widget.lastTile != null)
                    Positioned(
                      left: sw / 2 - 60,
                      top: sh * 0.30 - 60,
                      child: Opacity(
                        opacity: 1 - landBurst,
                        child: Container(
                          width: 120 * (0.4 + landBurst),
                          height: 120 * (0.4 + landBurst),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withOpacity(0.8),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // اللافتة المركزية
                  Center(
                    child: Transform.scale(
                      scale: _bannerScale.value,
                      child: Opacity(
                        opacity: _bannerOpacity.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 34, vertical: 18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isHuman
                                  ? const [
                                      Color(0xFF3B2A07),
                                      Color(0xFF1A1204)
                                    ]
                                  : const [
                                      Color(0xFF10203C),
                                      Color(0xFF0A1220)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: accent.withOpacity(0.85), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.45),
                                blurRadius: 34,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_rounded,
                                  color: accent, size: 52),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sub,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // آخر حجر مرمي يطير إلى المنتصف فوق اللافتة
                  if (widget.lastTile != null && _controller.value < 0.92)
                    Positioned(
                      left: tileX - 30 * tileScale,
                      top: tileY - 42 * tileScale,
                      child: Transform.rotate(
                        angle: tileRot,
                        child: Transform.scale(
                          scale: tileScale,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: accent
                                      .withOpacity(0.55 * ft.clamp(0.0, 1.0)),
                                  blurRadius: 26,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: OkeyTileWidget(
                              tile: widget.lastTile,
                              isDragging: true,
                              width: 60,
                              height: 84,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ConfettiPiece {
  final double x;
  final double delay;
  final double speed;
  final double size;
  final double sway;
  final double swayFreq;
  final double spin;
  final Color color;
  final bool isCircle;

  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.sway,
    required this.swayFreq,
    required this.spin,
    required this.color,
    required this.isCircle,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double t;

  _ConfettiPainter({required this.pieces, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = (t - p.delay) / (1 - p.delay);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 80);
      if (y > size.height + 20) continue;
      final x = p.x * size.width +
          math.sin(local * math.pi * p.swayFreq) * p.sway;
      final fade = (1 - local).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(0.95 * fade);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin * math.pi);
      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
