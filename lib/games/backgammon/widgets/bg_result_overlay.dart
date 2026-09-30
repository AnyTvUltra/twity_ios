import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../l10n/app_lang.dart';

/// طبقة نهاية المباراة — فوز: أشعة ذهبية دوّارة + كأس + كونفيتي
/// خسارة: تعتيم أحمر هادئ — مع المضاعف (مارس) والعملات وزرّي الإعادة/الخروج
class BgResultOverlay extends StatefulWidget {
  final bool win;
  final int multiplier;
  final int chips;
  final String title;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  const BgResultOverlay({
    super.key,
    required this.win,
    required this.multiplier,
    required this.chips,
    required this.title,
    required this.onRematch,
    required this.onExit,
  });

  @override
  State<BgResultOverlay> createState() => _BgResultOverlayState();
}

class _BgResultOverlayState extends State<BgResultOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward();
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

  static const _gold = Color(0xFFFFD54F);
  static const _mint = Color(0xFF3FF5A8);
  static const _red = Color(0xFFEF4444);

  @override
  void dispose() {
    _enter.dispose();
    _loop.dispose();
    super.dispose();
  }

  String get _multLabel => switch (widget.multiplier) {
        3 => 'مارس مضاعف ×3 🔥'.tr,
        2 => 'مارس ×2 ⚡'.tr,
        _ => 'فوز عادي'.tr,
      };

  @override
  Widget build(BuildContext context) {
    final accent = widget.win ? _gold : _red;
    return AnimatedBuilder(
      animation: Listenable.merge([_enter, _loop]),
      builder: (context, _) {
        final t = _enter.value;
        final fade = Curves.easeOut.transform((t * 2).clamp(0.0, 1.0));
        final pop =
            Curves.elasticOut.transform(((t - 0.1) / 0.9).clamp(0.0, 1.0));
        final count =
            Curves.easeOutCubic.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black.withValues(alpha: 0.62 * fade)),
            if (widget.win)
              CustomPaint(painter: _RaysPainter(_loop.value, fade, accent)),
            if (widget.win)
              IgnorePointer(
                  child: CustomPaint(
                      painter: _ConfettiPainter(_loop.value, fade))),
            Center(
              child: Transform.scale(
                scale: 0.4 + 0.6 * pop,
                child: Opacity(
                  opacity: fade,
                  child: Container(
                    width: 460,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xF0182448), Color(0xF00A1024)],
                      ),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.6), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 40,
                            spreadRadius: -4),
                      ],
                    ),
                    child: Row(
                      children: [
                        // الكأس مع هالة متوهجة
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    accent.withValues(alpha: 0.35),
                                    accent.withValues(alpha: 0.0),
                                  ]),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(
                                    0, math.sin(_loop.value * math.pi * 6) * 5),
                                child: Transform.rotate(
                                  angle: math.sin(_loop.value * math.pi * 4) *
                                      0.06,
                                  child: Text(widget.win ? '🏆' : '🎲',
                                      style: const TextStyle(fontSize: 76)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShaderMask(
                                shaderCallback: (r) => LinearGradient(
                                  colors: widget.win
                                      ? const [
                                          Color(0xFFFFF3C4),
                                          _gold,
                                          Color(0xFFE8A820)
                                        ]
                                      : const [Color(0xFFFFB4B4), _red],
                                ).createShader(r),
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (widget.win)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: accent.withValues(alpha: 0.14),
                                        border: Border.all(
                                            color:
                                                accent.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(_multLabel,
                                          style: TextStyle(
                                              color: accent,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12)),
                                    ),
                                  if (widget.chips != 0) ...[
                                    const SizedBox(width: 10),
                                    Text(
                                      '${widget.chips > 0 ? '+' : '-'}${(widget.chips.abs() * count).round()} 🪙',
                                      style: TextStyle(
                                          color:
                                              widget.chips > 0 ? _gold : _red,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _btn('خروج'.tr, Colors.white24,
                                        Colors.white, widget.onExit),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _btn(
                                        'جولة جديدة'.tr,
                                        _mint,
                                        const Color(0xFF052E1C),
                                        widget.onRematch),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: fg, fontWeight: FontWeight.w900, fontSize: 14)),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final double t, fade;
  final Color color;
  _RaysPainter(this.t, this.fade, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2 / 3);
    const n = 14;
    for (int i = 0; i < n; i++) {
      final a = i * math.pi * 2 / n;
      final p = Path()
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - 0.09) * r, math.sin(a - 0.09) * r)
        ..lineTo(math.cos(a + 0.09) * r, math.sin(a + 0.09) * r)
        ..close();
      canvas.drawPath(
          p,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: 0.28 * fade),
              color.withValues(alpha: 0.0),
            ]).createShader(
                Rect.fromCircle(center: Offset.zero, radius: r * 0.6)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaysPainter old) => true;
}

class _ConfettiPainter extends CustomPainter {
  final double t, fade;
  _ConfettiPainter(this.t, this.fade);

  static const _colors = [
    Color(0xFFFFD54F),
    Color(0xFF3FF5A8),
    Color(0xFF38BDF8),
    Color(0xFFF472B6),
    Color(0xFFFFFFFF),
    Color(0xFFFB923C),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    for (int i = 0; i < 110; i++) {
      final x0 = rnd.nextDouble();
      final speed = 0.6 + rnd.nextDouble() * 0.9;
      final off = rnd.nextDouble();
      final sway = rnd.nextDouble() * 30;
      final rot = rnd.nextDouble() * 6;
      final color = _colors[i % _colors.length];
      final y = ((t * speed * 3 + off) % 1.15 - 0.1) * size.height;
      final x = x0 * size.width + math.sin(t * 20 + i) * sway;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot + t * 30 * speed);
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: 7,
              height: 3.5 + 3 * math.sin(t * 40 + i).abs()),
          Paint()..color = color.withValues(alpha: fade));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
