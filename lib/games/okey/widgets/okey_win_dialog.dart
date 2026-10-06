import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../okey_models.dart';
import 'okey_tile_widget.dart';
import 'game_notice.dart';
import 'package:game_hub/utils/haptics.dart';
import '../../../l10n/app_lang.dart';

/// بطاقة نهاية الجولة — تصميم أفقي زجاجي: ميدالية متحركة بأشعة
/// دوّارة على جانب، والعنوان ونوع الفوز وأحجار الفائز والأزرار على الآخر.
/// ذهبية عند فوزك، وبنفسجية-حمراء هادئة عند فوز غيرك.
class OkeyWinDialog extends StatefulWidget {
  final OkeyPlayer winner;
  final WinType winType;
  final VoidCallback onPlayAgain;
  final VoidCallback? onExit;

  const OkeyWinDialog({
    super.key,
    required this.winner,
    required this.winType,
    required this.onPlayAgain,
    this.onExit,
  });

  static Future<void> show(
    BuildContext context, {
    required OkeyPlayer winner,
    required WinType winType,
    required VoidCallback onPlayAgain,
    VoidCallback? onExit,
  }) {
    return showOkeyLandscapeDialog(
      context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (_) => OkeyWinDialog(
        winner: winner,
        winType: winType,
        onPlayAgain: onPlayAgain,
        onExit: onExit,
      ),
    );
  }

  @override
  State<OkeyWinDialog> createState() => _OkeyWinDialogState();
}

class _OkeyWinDialogState extends State<OkeyWinDialog>
    with TickerProviderStateMixin {
  late final AnimationController _rays =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650))
    ..forward();

  @override
  void dispose() {
    _rays.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHuman = widget.winner.isHuman;
    final accent = isHuman ? const Color(0xFFFFD54F) : const Color(0xFFF472B6);
    final accentDeep =
        isHuman ? const Color(0xFFD97706) : const Color(0xFF9D174D);
    final title = isHuman
        ? '🎉 مبروك! لقد فزت بالجولة!'.tr
        : 'انتهت الجولة بفوز {}'.trp([widget.winner.name]);
    final sub = widget.winType == WinType.discardOkey
        ? 'فوز استثنائي برمي حجر الأوكي! (Okey ile Bitti)'.tr
        : (widget.winType == WinType.sevenPairs
            ? 'فوز بالأزواج السبعة! (7 Çift ile Bitti)'.tr
            : 'فوز نظامي بإكمال المجموعات! (Normal Bitiş)'.tr);
    final tiles = widget.winner.activeTiles;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ScaleTransition(
        scale: CurvedAnimation(parent: _enter, curve: Curves.easeOutBack),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 540,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(const Color(0xFF121A36), accentDeep, 0.18)!
                        .withOpacity(0.94),
                    const Color(0xFF0A0F24).withOpacity(0.96),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accent.withOpacity(0.55), width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: accent.withOpacity(0.28),
                      blurRadius: 34,
                      spreadRadius: -2),
                ],
              ),
              child: Row(
                children: [
                  // ═══ الميدالية بأشعة دوّارة ═══
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RotationTransition(
                          turns: _rays,
                          child: CustomPaint(
                            size: const Size(150, 150),
                            painter: _RaysPainter(accent),
                          ),
                        ),
                        Container(
                          width: 92,
                          height: 92,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, accent, accentDeep],
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: accent.withOpacity(0.55),
                                  blurRadius: 22),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                Color.lerp(accentDeep, Colors.black, 0.25)!,
                                const Color(0xFF0A0F24),
                              ]),
                            ),
                            child: Icon(
                              isHuman
                                  ? Icons.emoji_events_rounded
                                  : Icons.military_tech_rounded,
                              color: accent,
                              size: 46,
                            ),
                          ),
                        ),
                        // شريط النتيجة تحت الميدالية
                        Positioned(
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              gradient:
                                  LinearGradient(colors: [accent, accentDeep]),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 0.8),
                            ),
                            child: Text(
                              isHuman ? 'فوز'.tr : 'خسارة'.tr,
                              style: TextStyle(
                                color: isHuman
                                    ? const Color(0xFF2A1A00)
                                    : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),

                  // ═══ التفاصيل والأزرار ═══
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                  color: accent.withOpacity(0.4),
                                  blurRadius: 10),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Text(
                            sub,
                            style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // أحجار الفائز — تظهر فقط إن بقي في يده شيء
                        if (tiles.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final t in tiles)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 3),
                                    child: OkeyTileWidget(
                                        tile: t, width: 24, height: 32),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _button(
                                label: 'جولة جديدة'.tr,
                                icon: Icons.replay_rounded,
                                gradient: const [
                                  Color(0xFF4ADE80),
                                  Color(0xFF16A34A)
                                ],
                                textColor: Colors.white,
                                onTap: () {
                                  AppHaptics.heavy();
                                  Navigator.of(context).pop();
                                  widget.onPlayAgain();
                                },
                              ),
                            ),
                            if (widget.onExit != null) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _button(
                                  label: 'خروج'.tr,
                                  icon: Icons.logout_rounded,
                                  textColor: Colors.white70,
                                  onTap: () {
                                    AppHaptics.light();
                                    Navigator.of(context).pop();
                                    widget.onExit!();
                                  },
                                ),
                              ),
                            ],
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
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required Color textColor,
    required VoidCallback onTap,
    List<Color>? gradient,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: gradient != null ? LinearGradient(colors: gradient) : null,
          color: gradient == null ? Colors.white.withOpacity(0.08) : null,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: gradient != null
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white.withOpacity(0.22),
              width: 1),
          boxShadow: gradient != null
              ? [
                  BoxShadow(
                      color: gradient.last.withOpacity(0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4)),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// أشعة ضوء متوهجة خلف الميدالية
class _RaysPainter extends CustomPainter {
  final Color color;
  const _RaysPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        color.withOpacity(0.45),
        color.withOpacity(0.08),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: c, radius: r));
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi * 2 / 14;
      final p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.09) * r, c.dy + math.sin(a - 0.09) * r)
        ..lineTo(c.dx + math.cos(a + 0.09) * r, c.dy + math.sin(a + 0.09) * r)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.color != color;
}
