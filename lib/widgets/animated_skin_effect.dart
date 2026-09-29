import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/store_service.dart';
import '../l10n/app_lang.dart';

/// تأثيرات الكسنات المتحركة — نار و جليد مرسومة إجرائياً (Procedural)
/// بدون ملفات خارجية: ألسنة لهب، جمرات صاعدة، بريق جليدي، وميض متلألئ
enum SkinEffect {
  none,
  fire,
  ice,
  lava,
  blaze,
  frost,
  storm,
  gold,
  crystal,
  neon,
  galaxy,
  ocean,
  aurora,
  dragon,
  ember,
  wood,
  walnut,
  mahogany,
}

const _kEffectMap = {
  'fire': SkinEffect.fire,
  'ice': SkinEffect.ice,
  'lava': SkinEffect.lava,
  'blaze': SkinEffect.blaze,
  'frost': SkinEffect.frost,
  'storm': SkinEffect.storm,
  'gold': SkinEffect.gold,
  'crystal': SkinEffect.crystal,
  'neon': SkinEffect.neon,
  'galaxy': SkinEffect.galaxy,
  'ocean': SkinEffect.ocean,
  'aurora': SkinEffect.aurora,
  'dragon': SkinEffect.dragon,
  'ember': SkinEffect.ember,
  'wood': SkinEffect.wood,
  'walnut': SkinEffect.walnut,
  'mahogany': SkinEffect.mahogany,
};

/// تحويل اسم تأثير نصي إلى SkinEffect
SkinEffect skinEffectFromString(String e) =>
    _kEffectMap[e.toLowerCase()] ?? SkinEffect.none;

/// استخراج التأثير من عنصر المتجر (حقل effect أو من الاسم)
SkinEffect skinEffectOf(StoreItem? item) {
  if (item == null) return SkinEffect.none;
  final e = item.effect.toLowerCase();
  if (_kEffectMap.containsKey(e)) return _kEffectMap[e]!;
  final n = item.name.toLowerCase();
  if (n.contains('fire') || n.contains('نار'.tr) || n.contains('flame')) {
    return SkinEffect.fire;
  }
  if (n.contains('ice') || n.contains('جليد'.tr) || n.contains('frost')) {
    return SkinEffect.ice;
  }
  if (n.contains('لافا'.tr) || n.contains('lava')) return SkinEffect.lava;
  if (n.contains('برق'.tr) || n.contains('storm') || n.contains('lightning')) {
    return SkinEffect.storm;
  }
  if (n.contains('ذهب'.tr) || n.contains('gold')) return SkinEffect.gold;
  if (n.contains('نيون'.tr) || n.contains('neon')) return SkinEffect.neon;
  if (n.contains('سديم'.tr) || n.contains('galaxy') || n.contains('مجر'.tr)) {
    return SkinEffect.galaxy;
  }
  if (n.contains('محيط'.tr) || n.contains('ocean') || n.contains('موج'.tr)) {
    return SkinEffect.ocean;
  }
  if (n.contains('شفق'.tr) || n.contains('aurora')) return SkinEffect.aurora;
  if (n.contains('تنين'.tr) || n.contains('dragon')) return SkinEffect.dragon;
  if (n.contains('جمر'.tr) || n.contains('ember')) return SkinEffect.ember;
  if (n.contains('صقيع'.tr) ||
      n.contains('كريستال'.tr) ||
      n.contains('crystal')) {
    return SkinEffect.crystal;
  }
  // ملاحظة: تأثيرات الخشب (wood/walnut/mahogany) تُفعَّل فقط عبر
  // حقل effect الصريح في العنصر — لا مطابقة بالاسم حتى لا تستبدل
  // السكنات المصوّرة الموجودة
  return SkinEffect.none;
}

/// لون التمييز لكل تأثير — يُستخدم للإطارات والتوهجات
Color skinAccentColor(SkinEffect e) {
  switch (e) {
    case SkinEffect.fire:
      return const Color(0xFFFF9F1C);
    case SkinEffect.ice:
      return const Color(0xFF8AD4F5);
    case SkinEffect.lava:
      return const Color(0xFFFF5A00);
    case SkinEffect.blaze:
      return const Color(0xFFFFB340);
    case SkinEffect.frost:
      return const Color(0xFFBDEFFF);
    case SkinEffect.storm:
      return const Color(0xFF7DD3FC);
    case SkinEffect.gold:
      return const Color(0xFFFFD54F);
    case SkinEffect.crystal:
      return const Color(0xFFB388FF);
    case SkinEffect.neon:
      return const Color(0xFF3FF5A8);
    case SkinEffect.galaxy:
      return const Color(0xFFA78BFA);
    case SkinEffect.ocean:
      return const Color(0xFF38BDF8);
    case SkinEffect.aurora:
      return const Color(0xFF6EE7B7);
    case SkinEffect.dragon:
      return const Color(0xFFFBBF24);
    case SkinEffect.ember:
      return const Color(0xFFFF7847);
    case SkinEffect.wood:
      return const Color(0xFFD9A05B);
    case SkinEffect.walnut:
      return const Color(0xFF9A6537);
    case SkinEffect.mahogany:
      return const Color(0xFFBF6B4A);
    case SkinEffect.none:
      return Colors.transparent;
  }
}

/// طبقة كسنة متحركة تملأ المساحة — تتفاعل مع مرور الإصبع/المؤشر
/// والسحب (تتركز الطاقة حيث يلمس المستخدم)
class AnimatedSkinLayer extends StatefulWidget {
  final SkinEffect effect;

  /// شدة إضافية (مثلاً أثناء السحب)
  final double intensity;

  /// يضيف حبيبات الخشب الحقيقية فوق التأثير (للاستكانة/الطاولة — لا للأحجار)
  final bool woodUnderlay;

  const AnimatedSkinLayer({
    super.key,
    required this.effect,
    this.intensity = 0.0,
    this.woodUnderlay = false,
  });

  @override
  State<AnimatedSkinLayer> createState() => _AnimatedSkinLayerState();
}

class _AnimatedSkinLayerState extends State<AnimatedSkinLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  Offset? _pointer;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
    if (widget.woodUnderlay) {
      StoreService().ensureWoodBase().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerHover: (e) => setState(() => _pointer = e.localPosition),
      onPointerMove: (e) => setState(() => _pointer = e.localPosition),
      onPointerDown: (e) => setState(() => _pointer = e.localPosition),
      onPointerUp: (_) => setState(() => _pointer = null),
      onPointerCancel: (_) => setState(() => _pointer = null),
      child: MouseRegion(
        onExit: (_) => setState(() => _pointer = null),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _WoodFxPainter(
                _surfacePainter(
                  widget.effect,
                  _c.value,
                  _pointer,
                  widget.intensity + (_pointer != null ? 0.35 : 0),
                ),
                widget.woodUnderlay ? StoreService().defaultWoodImage : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// إطار دائري متحرك (نار/جليد/بقية التأثيرات) للصور الشخصية
class AnimatedFrameRing extends StatefulWidget {
  final SkinEffect effect;
  final double size;

  /// حبيبات خشب حقيقية داخل حلقة الإطار
  final bool woodUnderlay;

  const AnimatedFrameRing({
    super.key,
    required this.effect,
    this.size = 60,
    this.woodUnderlay = false,
  });

  @override
  State<AnimatedFrameRing> createState() => _AnimatedFrameRingState();
}

class _AnimatedFrameRingState extends State<AnimatedFrameRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    if (widget.woodUnderlay) {
      StoreService().ensureWoodBase().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ringPainter(
            widget.effect,
            _c.value,
            widget.woodUnderlay ? StoreService().defaultWoodImage : null,
          ),
        ),
      ),
    );
  }
}

/// رسم تأثير متحرك مباشرة على Canvas — لاستخدامه داخل رسامات مخصصة
/// (مثل OkeyTablePainter) حيث لا تصلح ودجت AnimatedSkinLayer.
/// [wood] يضيف حبيبات الخشب الحقيقية فوق التأثير (softLight).
void paintSkinEffect(
  Canvas canvas,
  Size size,
  SkinEffect effect,
  double t, {
  Offset? pointer,
  double intensity = 0,
  ui.Image? wood,
}) {
  _surfacePainter(effect, t, pointer, intensity).paint(canvas, size);
  _woodOverlay(canvas, size, wood);
}

/// طبقة حبيبات خشب حقيقية فوق أي سطح مرسوم — softLight يحافظ على
/// ألوان التأثير ويُظهر نسيج الخشب الطبيعي عليه
void _woodOverlay(Canvas canvas, Size size, ui.Image? wood,
    {double alpha = 0.5}) {
  if (wood == null) return;
  final src =
      Rect.fromLTWH(0, 0, wood.width.toDouble(), wood.height.toDouble());
  final dst = Offset.zero & size;
  final scale = math.max(dst.width / src.width, dst.height / src.height);
  final dw = src.width * scale;
  final dh = src.height * scale;
  canvas.drawImageRect(
    wood,
    src,
    Rect.fromLTWH(dst.center.dx - dw / 2, dst.center.dy - dh / 2, dw, dh),
    Paint()
      ..blendMode = BlendMode.softLight
      ..color = Colors.white.withOpacity(alpha),
  );
}

/// حبيبات خشب داخل حلقة الإطار فقط (لا تخرج عن الحلقة)
void _woodRingOverlay(Canvas canvas, Size size, ui.Image? wood) {
  if (wood == null) return;
  final c = size.center(Offset.zero);
  final ringR = size.shortestSide / 2 * 0.82;
  final radius = size.shortestSide / 2;
  canvas.save();
  canvas.clipPath(Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: c, radius: ringR + radius * 0.09))
    ..addOval(Rect.fromCircle(center: c, radius: ringR - radius * 0.09)));
  _woodOverlay(canvas, size, wood);
  canvas.restore();
}

/// رسام يغلّف أي رسام سطح ويضيف حبيبات الخشب فوقه
class _WoodFxPainter extends CustomPainter {
  final CustomPainter inner;
  final ui.Image? wood;
  _WoodFxPainter(this.inner, this.wood);

  @override
  void paint(Canvas canvas, Size size) {
    inner.paint(canvas, size);
    _woodOverlay(canvas, size, wood);
  }

  @override
  bool shouldRepaint(_WoodFxPainter old) =>
      old.inner != inner || old.wood != wood;
}

// ════════════════════════════════════════════════════════════════════
// موزّع الرسامات — سطح لكل تأثير + إطار دائري عام يعيد استخدام السطح
// ════════════════════════════════════════════════════════════════════
CustomPainter _surfacePainter(
    SkinEffect e, double t, Offset? pointer, double intensity) {
  switch (e) {
    case SkinEffect.fire:
      return _FireSurfacePainter(t, pointer, intensity);
    case SkinEffect.ice:
      return _IceSurfacePainter(t, pointer, intensity);
    default:
      return _FxSurfacePainter(e, t, pointer, intensity);
  }
}

CustomPainter _ringPainter(SkinEffect e, double t, [ui.Image? wood]) {
  switch (e) {
    case SkinEffect.fire:
      return _FireRingPainter(t, wood);
    case SkinEffect.ice:
      return _IceRingPainter(t, wood);
    default:
      return _FxRingPainter(e, t, wood);
  }
}

// ════════════════════════════════════════════════════════════════════
// رسام سطح النار — احتراق واقعي: جمر متوهج + ألسنة لهب حادة بطبقات
// + شرار متطاير + دخان خفيف أعلى السطح
// ════════════════════════════════════════════════════════════════════
class _FireSurfacePainter extends CustomPainter {
  final double t;
  final Offset? pointer;
  final double intensity;

  _FireSurfacePainter(this.t, this.pointer, this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tt = t * math.pi * 2;
    final rng = math.Random(11);

    // ── قاعدة: جمر متوهج أسفل → فحم محترق أعلى ──
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFFFFF3B0), // جمر ساخن شديد
            Color(0xFFFFB340),
            Color(0xFFF2610F),
            Color(0xFFB91C1C),
            Color(0xFF571210),
            Color(0xFF200505), // قمة محترقة داكنة
          ],
          stops: [0.0, 0.16, 0.36, 0.58, 0.8, 1.0],
        ).createShader(rect),
    );

    // ── ألسنة لهب خلفية (برتقالية عريضة) ──
    for (int i = 0; i < 8; i++) {
      final seed = rng.nextDouble() * 10;
      _flameTongue(
        canvas,
        size,
        baseX: (i + 0.35 + rng.nextDouble() * 0.3) / 8 * size.width,
        maxH:
            size.height * (0.5 + 0.28 * (0.5 + 0.5 * math.sin(tt * 2 + seed))),
        w: size.width * (0.13 + rng.nextDouble() * 0.07),
        swayPhase: seed,
        tt: tt,
        colors: [
          const Color(0xFFFF9F1C).withOpacity(0.55),
          const Color(0xFFEF4444).withOpacity(0.28),
          Colors.transparent,
        ],
      );
    }

    // ── ألسنة لهب أمامية (صفراء لامعة أضيق) ──
    for (int i = 0; i < 5; i++) {
      final seed = 3 + rng.nextDouble() * 10;
      _flameTongue(
        canvas,
        size,
        baseX: (i + 0.5) / 5 * size.width +
            math.sin(tt + seed) * size.width * 0.04,
        maxH:
            size.height * (0.42 + 0.22 * (0.5 + 0.5 * math.sin(tt * 2 + seed))),
        w: size.width * (0.07 + rng.nextDouble() * 0.045),
        swayPhase: seed * 1.7,
        tt: tt,
        colors: [
          const Color(0xFFFFF3B0).withOpacity(0.85),
          const Color(0xFFFFC93C).withOpacity(0.5),
          Colors.transparent,
        ],
      );
    }

    // ── شرار متطاير: نقاط مضيئة تصعد بقوس وتخفت ──
    for (int i = 0; i < 16; i++) {
      // دورات صحيحة لكل شرارة حتى لا يظهر انقطاع عند إعادة الحلقة
      final cycles = 1 + rng.nextInt(3);
      final p = (t * cycles + rng.nextDouble()) % 1.0;
      final x0 = rng.nextDouble() * size.width;
      final x = x0 +
          math.sin(p * 7 + i * 2.3) * size.width * 0.06 +
          p * size.width * 0.06 * (rng.nextBool() ? 1 : -1);
      final y = size.height - p * size.height * 1.05;
      if (y < -4) continue;
      final tw = 0.6 + 0.4 * math.sin(tt * 6 + i * 3.1);
      final alpha = (1 - p) * tw;
      final r = 0.8 + rng.nextDouble() * 1.7;
      // ذيل الشرارة
      canvas.drawLine(
        Offset(x, y + r * 3.2),
        Offset(x, y),
        Paint()
          ..color = const Color(0xFFFFB340).withOpacity(alpha * 0.5)
          ..strokeWidth = r * 0.8
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color =
              Color.lerp(const Color(0xFFFFF3B0), const Color(0xFFF97316), p)!
                  .withOpacity(alpha.clamp(0.0, 1.0)),
      );
    }

    // ── دخان خفيف أعلى السطح ──
    for (int i = 0; i < 3; i++) {
      final p = (t + i * 0.33) % 1.0;
      final cx = size.width * (0.25 + i * 0.27) +
          math.sin(tt + i * 2.0) * size.width * 0.05;
      final cy = size.height * (0.12 + p * 0.15);
      canvas.drawCircle(
        Offset(cx, cy),
        size.width * (0.14 + p * 0.1),
        Paint()
          ..color = const Color(0xFF1A0A06).withOpacity(0.16 * (1 - p))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // ── توهج حراري يتبع الإصبع ──
    if (pointer != null) {
      final r = size.shortestSide * (0.6 + intensity * 0.3);
      canvas.drawCircle(
        pointer!,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF6C8).withOpacity(0.6 * (1 + intensity)),
              const Color(0xFFFF9F1C).withOpacity(0.3 * (1 + intensity)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: pointer!, radius: r)),
      );
    }
  }

  /// لسان لهب حاد الطرف بمنحنيات ناعمة يتمايل مع الوقت
  void _flameTongue(
    Canvas canvas,
    Size size, {
    required double baseX,
    required double maxH,
    required double w,
    required double swayPhase,
    required double tt,
    required List<Color> colors,
  }) {
    final baseY = size.height;
    final tipX = baseX + math.sin(tt * 2 + swayPhase) * w * 1.1;
    final tipY = baseY - maxH;
    final path = Path()..moveTo(baseX - w, baseY);
    // الجانب الأيسر للسان
    path.quadraticBezierTo(baseX - w * 0.9, baseY - maxH * 0.4, tipX - w * 0.1,
        tipY + maxH * 0.15);
    path.quadraticBezierTo(tipX, tipY, tipX, tipY);
    // الجانب الأيمن
    path.quadraticBezierTo(
        tipX + w * 0.1, tipY + maxH * 0.15, baseX + w, baseY - maxH * 0.1);
    path.lineTo(baseX + w, baseY);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: colors,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromLTWH(baseX - w, tipY, w * 2, maxH)),
    );
  }

  @override
  bool shouldRepaint(_FireSurfacePainter old) =>
      old.t != t || old.pointer != pointer || old.intensity != intensity;
}

// ════════════════════════════════════════════════════════════════════
// رسام سطح الجليد — أزرق متجمد + ومضات انجرافية + نجوم متلألئة
// ════════════════════════════════════════════════════════════════════
class _IceSurfacePainter extends CustomPainter {
  final double t;
  final Offset? pointer;
  final double intensity;

  _IceSurfacePainter(this.t, this.pointer, this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final tt = t * math.pi * 2;
    final rng = math.Random(23);

    // ── قاعدة جليدية عميقة ──
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF2FBFF),
            Color(0xFFCDEBFA),
            Color(0xFF8FC8EC),
            Color(0xFF4B93C4),
            Color(0xFF25638F),
            Color(0xFF123A5C),
          ],
          stops: [0.0, 0.22, 0.45, 0.68, 0.86, 1.0],
        ).createShader(rect),
    );

    // ── بقع صقيع زاحفة على أجزاء من القطعة (زوايا وأطراف) ──
    final frostSpots = [
      Offset(0.0, 0.0),
      Offset(size.width, size.height * 0.12),
      Offset(size.width * 0.15, size.height),
      Offset(size.width * 0.85, size.height * 0.92),
    ];
    for (int i = 0; i < frostSpots.length; i++) {
      final c = frostSpots[i];
      final r = size.shortestSide * (0.42 + 0.10 * math.sin(tt + i * 1.8));
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFF4FCFF).withOpacity(0.85),
              const Color(0xFFD8F1FC).withOpacity(0.45),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      // زوائد إبرية صغيرة حول بقعة الصقيع
      for (int k = 0; k < 6; k++) {
        final ang = k / 6 * math.pi * 2 + i * 0.7;
        final p1 = Offset(
            c.dx + math.cos(ang) * r * 0.4, c.dy + math.sin(ang) * r * 0.4);
        final p2 = Offset(
            c.dx + math.cos(ang) * r * 0.95, c.dy + math.sin(ang) * r * 0.95);
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.white.withOpacity(0.5)
            ..strokeWidth = 1.1
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // ── بلّورات جليدية صغيرة (معادن مثلثة بوجهين) ──
    for (int i = 0; i < 7; i++) {
      final cx = size.width * (0.1 + rng.nextDouble() * 0.8);
      final cy = size.height * (0.12 + rng.nextDouble() * 0.76);
      final s = 3.0 + rng.nextDouble() * 4.5;
      final rot = rng.nextDouble() * math.pi;
      final shimmer = 0.55 + 0.45 * math.sin(tt * 2 + i * 2.4);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot);
      final shard = Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.7, s * 0.5)
        ..lineTo(-s * 0.7, s * 0.5)
        ..close();
      // وجه مضيء
      canvas.drawPath(
        shard,
        Paint()..color = Color(0xFFEAF9FF).withOpacity(0.75 * shimmer),
      );
      // وجه ظلّي
      final half = Path()
        ..moveTo(0, -s)
        ..lineTo(s * 0.7, s * 0.5)
        ..lineTo(0, s * 0.2)
        ..close();
      canvas.drawPath(
        half,
        Paint()..color = const Color(0xFF7FC4EA).withOpacity(0.5 * shimmer),
      );
      canvas.restore();
    }

    // ── شقوق جليدية رفيعة متفرعة ──
    final crackPaint = Paint()
      ..color = Colors.white.withOpacity(0.34)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final y0 = rng.nextDouble() * size.height;
      final path = Path()..moveTo(0, y0);
      double x = 0, y = y0;
      while (x < size.width) {
        x += size.width * 0.16;
        y += (rng.nextDouble() - 0.5) * size.height * 0.14;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, crackPaint);
      // فرع صغير
      final bx = size.width * (0.3 + rng.nextDouble() * 0.4);
      canvas.drawLine(
        Offset(bx, y0 + (rng.nextDouble() - 0.5) * 8),
        Offset(bx + size.width * 0.08, y0 - size.height * 0.12),
        crackPaint,
      );
    }

    // ── رقاقات ثلج بلّورية تتساقط بنعومة ──
    for (int i = 0; i < 10; i++) {
      final cycles = 1 + rng.nextInt(2);
      final p = (t * cycles + rng.nextDouble()) % 1.0;
      final x = rng.nextDouble() * size.width +
          math.sin(p * 5 + i * 1.9) * size.width * 0.04;
      final y = -4 + p * (size.height + 8);
      final r = 1.4 + rng.nextDouble() * 2.2;
      // بلّورة سداسية الأذرع
      for (int k = 0; k < 3; k++) {
        final ang = k * math.pi / 3 + tt + i;
        canvas.drawLine(
          Offset(x - math.cos(ang) * r, y - math.sin(ang) * r),
          Offset(x + math.cos(ang) * r, y + math.sin(ang) * r),
          Paint()
            ..color = Colors.white.withOpacity((1 - p * 0.5) * 0.7)
            ..strokeWidth = 0.8
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(
        Offset(x, y),
        r * 0.35,
        Paint()
          ..color = const Color(0xFFD8F1FC).withOpacity((1 - p * 0.5) * 0.8),
      );
    }

    // ── نجوم متلألئة ──
    for (int i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final tw = 0.5 + 0.5 * math.sin(tt * (1 + rng.nextInt(3)) + i * 2.1);
      final r = 0.9 + tw * 1.5;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withOpacity(0.25 + tw * 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
      if (tw > 0.85) {
        canvas.drawLine(
          Offset(x - r * 2.2, y),
          Offset(x + r * 2.2, y),
          Paint()
            ..color = Colors.white.withOpacity(0.5 * tw)
            ..strokeWidth = 0.7,
        );
      }
    }

    // ── بريق متجمد يتبع الإصبع ──
    if (pointer != null) {
      final r = size.shortestSide * (0.5 + intensity * 0.3);
      canvas.drawCircle(
        pointer!,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFEAF9FF).withOpacity(0.65 * (1 + intensity)),
              const Color(0xFF8AD4F5).withOpacity(0.3 * (1 + intensity)),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: pointer!, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_IceSurfacePainter old) =>
      old.t != t || old.pointer != pointer || old.intensity != intensity;
}

// ════════════════════════════════════════════════════════════════════
// رسام إطار النار الدائري — حلقة ملتهبة + ألسنة + جمرات مدارية
// ════════════════════════════════════════════════════════════════════
class _FireRingPainter extends CustomPainter {
  final double t;
  final ui.Image? wood;
  _FireRingPainter(this.t, [this.wood]);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ringR = radius * 0.82;
    final tt = t * math.pi * 2;
    final rng = math.Random(31);

    // توهج خارجي نابض
    canvas.drawCircle(
      c,
      ringR + 5,
      Paint()
        ..color = const Color(0xFFFF6A00).withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // الحلقة الأساسية — تدرّج دائري ملتهب يدور ببطء
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.13
        ..shader = SweepGradient(
          startAngle: tt,
          endAngle: tt + math.pi * 2,
          colors: const [
            Color(0xFFFFE066),
            Color(0xFFFF9F1C),
            Color(0xFFEF4444),
            Color(0xFFFF9F1C),
            Color(0xFFFFE066),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: ringR)),
    );

    // حبيبات خشب حقيقية داخل حلقة الإطار
    _woodRingOverlay(canvas, size, wood);

    // ألسنة لهب صغيرة حول المحيط
    for (int i = 0; i < 18; i++) {
      final ang = i / 18 * math.pi * 2;
      final flick = 0.5 + 0.5 * math.sin(tt * 3 + i * 1.7 + rng.nextDouble());
      final len = radius * (0.06 + 0.11 * flick);
      final p1 =
          Offset(c.dx + math.cos(ang) * ringR, c.dy + math.sin(ang) * ringR);
      final p2 = Offset(c.dx + math.cos(ang + 0.06) * (ringR + len),
          c.dy + math.sin(ang + 0.06) * (ringR + len));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFFFB340).withOpacity(0.9),
              const Color(0xFFFFF3B0).withOpacity(0.0),
            ],
          ).createShader(Rect.fromPoints(p1, p2)),
      );
    }

    // جمرات تدور حول الحلقة (دورات صحيحة = بلا انقطاع)
    for (int i = 0; i < 8; i++) {
      final revs = 1 + rng.nextInt(2);
      final ang = tt * revs + i * 0.9;
      final rr = ringR + 3 + math.sin(tt * 2 + i) * 3;
      canvas.drawCircle(
        Offset(c.dx + math.cos(ang) * rr, c.dy + math.sin(ang) * rr),
        1.3 + rng.nextDouble() * 1.4,
        Paint()
          ..color = const Color(0xFFFFE08A)
              .withOpacity(0.5 + 0.5 * math.sin(tt * 3 + i * 2)),
      );
    }

    // شرار يتطاير للخارج ويخفت
    for (int i = 0; i < 10; i++) {
      final cycles = 1 + rng.nextInt(2);
      final p = (t * cycles + rng.nextDouble()) % 1.0;
      final ang = rng.nextDouble() * math.pi * 2;
      final rr = ringR + p * radius * 0.55;
      final pos =
          Offset(c.dx + math.cos(ang) * rr, c.dy + math.sin(ang) * rr - p * 4);
      canvas.drawCircle(
        pos,
        (1.6 - p) * 1.4,
        Paint()
          ..color =
              Color.lerp(const Color(0xFFFFE08A), const Color(0xFFEF4444), p)!
                  .withOpacity((1 - p) * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_FireRingPainter old) => old.t != t;
}

// ════════════════════════════════════════════════════════════════════
// رسام إطار الجليد الدائري — حلقة متجمدة + بريق دوّار + نجوم
// ════════════════════════════════════════════════════════════════════
class _IceRingPainter extends CustomPainter {
  final double t;
  final ui.Image? wood;
  _IceRingPainter(this.t, [this.wood]);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ringR = radius * 0.82;
    final tt = t * math.pi * 2;
    final rng = math.Random(47);

    // توهج أزرق بارد
    canvas.drawCircle(
      c,
      ringR + 4,
      Paint()
        ..color = const Color(0xFF7DD3FC).withOpacity(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // الحلقة الجليدية
    canvas.drawCircle(
      c,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.12
        ..shader = SweepGradient(
          startAngle: -tt,
          endAngle: -tt + math.pi * 2,
          colors: const [
            Color(0xFFEAF9FF),
            Color(0xFF8AD4F5),
            Color(0xFF3B9BD8),
            Color(0xFFBFE9FF),
            Color(0xFFEAF9FF),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: ringR)),
    );

    // حبيبات خشب حقيقية داخل حلقة الإطار
    _woodRingOverlay(canvas, size, wood);

    // بريقان دوّاران على الحلقة (glints)
    for (int i = 0; i < 2; i++) {
      final ang = tt + i * math.pi;
      final pos =
          Offset(c.dx + math.cos(ang) * ringR, c.dy + math.sin(ang) * ringR);
      canvas.drawCircle(
        pos,
        4.5,
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(pos, 1.6, Paint()..color = Colors.white);
    }

    // بلّورات/نجوم ثابتة المواقع متلألئة حول المحيط
    for (int i = 0; i < 12; i++) {
      final ang = i / 12 * math.pi * 2 + rng.nextDouble() * 0.3;
      final tw = 0.5 + 0.5 * math.sin(tt * 2 + i * 1.9);
      final rr = ringR + (rng.nextDouble() - 0.5) * radius * 0.22;
      final pos = Offset(c.dx + math.cos(ang) * rr, c.dy + math.sin(ang) * rr);
      canvas.drawCircle(
        pos,
        1.0 + tw * 1.3,
        Paint()..color = Colors.white.withOpacity(0.3 + tw * 0.55),
      );
    }

    // سنابل جليدية (بلّورات شائكة) حول الحلقة
    for (int i = 0; i < 10; i++) {
      final ang = i / 10 * math.pi * 2 + 0.31;
      final glint = 0.5 + 0.5 * math.sin(tt * 2 + i * 2.2);
      final len = radius * (0.10 + 0.08 * glint);
      final p1 = Offset(c.dx + math.cos(ang) * (ringR - 2),
          c.dy + math.sin(ang) * (ringR - 2));
      final tip = Offset(c.dx + math.cos(ang) * (ringR + len),
          c.dy + math.sin(ang) * (ringR + len));
      final side1 = Offset(c.dx + math.cos(ang + 0.09) * ringR,
          c.dy + math.sin(ang + 0.09) * ringR);
      final side2 = Offset(c.dx + math.cos(ang - 0.09) * ringR,
          c.dy + math.sin(ang - 0.09) * ringR);
      final shard = Path()
        ..moveTo(side1.dx, side1.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(side2.dx, side2.dy)
        ..close();
      canvas.drawPath(
        shard,
        Paint()..color = Color(0xFFD8F1FC).withOpacity(0.35 + glint * 0.45),
      );
      // حد مضيء على السنبلة
      canvas.drawLine(
        p1,
        tip,
        Paint()
          ..color = Colors.white.withOpacity(0.3 + glint * 0.5)
          ..strokeWidth = 0.9,
      );
    }
  }

  @override
  bool shouldRepaint(_IceRingPainter old) => old.t != t;
}

// ════════════════════════════════════════════════════════════════════
// رسام السطح العام — لافا، احتراق ملكي، صقيع زاحف، برق، ذهب سائل،
// كريستال، نيون، سديم، محيط، شفق، تنّين، جمر
// كل الترددات الزمنية بأعداد صحيحة → حلقة بلا انقطاع
// ════════════════════════════════════════════════════════════════════
class _FxSurfacePainter extends CustomPainter {
  final SkinEffect effect;
  final double t;
  final Offset? pointer;
  final double intensity;

  _FxSurfacePainter(this.effect, this.t, this.pointer, this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    final tt = t * math.pi * 2;
    final rng = math.Random(97);
    switch (effect) {
      case SkinEffect.lava:
        _lava(canvas, size, tt, rng);
        break;
      case SkinEffect.blaze:
        _blaze(canvas, size, tt, rng);
        break;
      case SkinEffect.frost:
        _frost(canvas, size, tt, rng);
        break;
      case SkinEffect.storm:
        _storm(canvas, size, tt, rng);
        break;
      case SkinEffect.gold:
        _gold(canvas, size, tt, rng);
        break;
      case SkinEffect.crystal:
        _crystal(canvas, size, tt, rng);
        break;
      case SkinEffect.neon:
        _neon(canvas, size, tt, rng);
        break;
      case SkinEffect.galaxy:
        _galaxy(canvas, size, tt, rng);
        break;
      case SkinEffect.ocean:
        _ocean(canvas, size, tt, rng);
        break;
      case SkinEffect.aurora:
        _aurora(canvas, size, tt, rng);
        break;
      case SkinEffect.dragon:
        _dragon(canvas, size, tt, rng);
        break;
      case SkinEffect.ember:
        _ember(canvas, size, tt, rng);
        break;
      case SkinEffect.wood:
        _woodPlanks(canvas, size, tt, rng, 0);
        break;
      case SkinEffect.walnut:
        _woodPlanks(canvas, size, tt, rng, 1);
        break;
      case SkinEffect.mahogany:
        _woodPlanks(canvas, size, tt, rng, 2);
        break;
      default:
        break;
    }
    _pointerGlow(canvas, size);
  }

  void _bg(Canvas c, Size s, List<Color> colors,
      [Alignment a = Alignment.topCenter,
      Alignment b = Alignment.bottomCenter]) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(begin: a, end: b, colors: colors)
            .createShader(Offset.zero & s),
    );
  }

  /// توهج لمس بلون التأثير
  void _pointerGlow(Canvas canvas, Size size) {
    if (pointer == null) return;
    final accent = skinAccentColor(effect);
    final r = size.shortestSide * (0.55 + intensity * 0.3);
    canvas.drawCircle(
      pointer!,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(0.45 * (1 + intensity)),
            accent.withOpacity(0.28 * (1 + intensity)),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: pointer!, radius: r)),
    );
  }

  /// جزيئات صاعدة (شرار/رماد) — دورات صحيحة
  void _sparks(Canvas c, Size s, math.Random rng, int n, Color a, Color b,
      {double spread = 1.0}) {
    for (int i = 0; i < n; i++) {
      final cycles = 1 + rng.nextInt(3);
      final p = (t * cycles + rng.nextDouble()) % 1.0;
      final x = rng.nextDouble() * s.width +
          math.sin(p * 6 + i * 2.2) * s.width * 0.05 * spread;
      final y = s.height - p * s.height * 1.05;
      if (y < -4) continue;
      final r = 0.8 + rng.nextDouble() * 1.6;
      c.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Color.lerp(a, b, p)!.withOpacity((1 - p) * 0.85),
      );
    }
  }

  /// نجوم متلألئة
  void _twinkles(Canvas c, Size s, math.Random rng, int n, Color col,
      {double blur = 1.2}) {
    for (int i = 0; i < n; i++) {
      final x = rng.nextDouble() * s.width;
      final y = rng.nextDouble() * s.height;
      final tw = 0.5 + 0.5 * math.sin(ttHelper(i) + i * 2.1);
      c.drawCircle(
        Offset(x, y),
        0.9 + tw * 1.4,
        Paint()
          ..color = col.withOpacity(0.2 + tw * 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }
  }

  double ttHelper(int i) => t * math.pi * 2 * (1 + i % 3);

  // ── اللافا الحية: بازلت داكن + شقوق حمم تنبض ──
  void _lava(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF2A0A06), Color(0xFF160402), Color(0xFF0A0101)]);
    for (int i = 0; i < 6; i++) {
      final pulse = 0.55 + 0.45 * math.sin(tt * (1 + i % 2) + i * 1.9);
      double x = rng.nextDouble() * s.width * 0.9;
      double y = rng.nextDouble() * s.height;
      final path = Path()..moveTo(x, y);
      for (int k = 0; k < 7; k++) {
        x += s.width * 0.07 + rng.nextDouble() * s.width * 0.06;
        y += (rng.nextDouble() - 0.5) * s.height * 0.22;
        path.lineTo(x, y);
      }
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFF4400).withOpacity(0.35 * pulse)
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      c.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
                  const Color(0xFFFF6A00), const Color(0xFFFFE08A), pulse)!
              .withOpacity(0.8 * pulse)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }
    _sparks(c, s, rng, 10, const Color(0xFFFFE08A), const Color(0xFFEF4444));
  }

  // ── النار الملكية: خشب يحترق من أسفل بألسنة صغيرة ──
  void _blaze(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF3A1E0C), Color(0xFF1E0E04), Color(0xFF0D0502)]);
    final pulse = 0.6 + 0.4 * math.sin(tt);
    c.drawRect(
      Rect.fromLTWH(0, s.height * 0.55, s.width, s.height * 0.45),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFFFF9F1C).withOpacity(0.5 * pulse),
            const Color(0xFFEF4444).withOpacity(0.18 * pulse),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromLTWH(0, s.height * 0.55, s.width, s.height * 0.45)),
    );
    for (int i = 0; i < 10; i++) {
      final bx = (i + 0.5) / 10 * s.width + math.sin(tt * 2 + i) * 3;
      final h =
          s.height * (0.10 + 0.08 * (0.5 + 0.5 * math.sin(tt * 3 + i * 2)));
      final w = s.width * 0.035;
      final path = Path()
        ..moveTo(bx - w, s.height)
        ..quadraticBezierTo(bx - w * 0.4, s.height - h * 0.7, bx, s.height - h)
        ..quadraticBezierTo(bx + w * 0.4, s.height - h * 0.7, bx + w, s.height)
        ..close();
      c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFFFE08A).withOpacity(0.9),
              const Color(0xFFFF6A00).withOpacity(0.5),
              Colors.transparent,
            ],
          ).createShader(Rect.fromLTWH(bx - w, s.height - h, w * 2, h)),
      );
    }
    _sparks(c, s, rng, 14, const Color(0xFFFFF3B0), const Color(0xFFF97316));
  }

  // ── الصقيع الزاحف: بقع تجمد تنمو من الأطراف + بخار بارد ──
  void _frost(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF9CC4DE), Color(0xFF5C8FB4), Color(0xFF2A4A66)],
        Alignment.topLeft, Alignment.bottomRight);
    final spots = [
      const Offset(0, 0),
      Offset(s.width, 0),
      Offset(0, s.height),
      Offset(s.width, s.height),
      Offset(s.width * 0.5, 0),
    ];
    for (int i = 0; i < spots.length; i++) {
      final grow = 0.5 + 0.5 * math.sin(tt * (1 + i % 2) + i * 2.3);
      final r = s.shortestSide * (0.35 + 0.22 * grow);
      c.drawCircle(
        spots[i],
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFFFFF).withOpacity(0.85),
            const Color(0xFFD8F1FC).withOpacity(0.4),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: spots[i], radius: r)),
      );
      for (int k = 0; k < 5; k++) {
        final ang = k / 5 * math.pi * 2 + i * 1.1;
        c.drawLine(
          spots[i] + Offset(math.cos(ang) * r * 0.3, math.sin(ang) * r * 0.3),
          spots[i] + Offset(math.cos(ang) * r * 0.9, math.sin(ang) * r * 0.9),
          Paint()
            ..color = Colors.white.withOpacity(0.45)
            ..strokeWidth = 1.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (int i = 0; i < 3; i++) {
      final p = (t + i * 0.37) % 1.0;
      c.drawCircle(
        Offset(s.width * (0.2 + i * 0.3) + math.sin(tt + i) * 8,
            s.height * (0.9 - p * 0.7)),
        s.width * 0.10 * (0.6 + p),
        Paint()
          ..color = Colors.white.withOpacity(0.12 * (1 - p))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }
    _twinkles(c, s, rng, 10, Colors.white);
  }

  // ── البرق العاصف: معدن داكن + صواعق تومض ──
  void _storm(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF232A36), Color(0xFF12171F), Color(0xFF080B10)]);
    final ambient = 0.5 + 0.5 * math.sin(tt * 2);
    c.drawRect(
      Offset.zero & s,
      Paint()..color = const Color(0xFF7DD3FC).withOpacity(0.05 * ambient),
    );
    for (int i = 0; i < 3; i++) {
      final flash = math.sin(tt * (1 + i) + i * 2.7);
      if (flash < 0.72) continue;
      final alpha = (flash - 0.72) / 0.28;
      double x = s.width * (0.15 + rng.nextDouble() * 0.7);
      double y = -4;
      final bolt = Path()..moveTo(x, y);
      while (y < s.height) {
        x += (rng.nextDouble() - 0.5) * s.width * 0.14;
        y += s.height * 0.18;
        bolt.lineTo(x, y);
      }
      c.drawPath(
        bolt,
        Paint()
          ..color = const Color(0xFFBDEFFF).withOpacity(0.5 * alpha)
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      c.drawPath(
        bolt,
        Paint()
          ..color = Colors.white.withOpacity(0.95 * alpha)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
    _twinkles(c, s, rng, 8, const Color(0xFF7DD3FC));
  }

  // ── الذهب السائل: معدن ذهبي + موجة لمعان تعبر ──
  void _gold(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF8C6A1F), Color(0xFFD4A821), Color(0xFF5C400C)],
        Alignment.topLeft, Alignment.bottomRight);
    // غبار ذهبي يتطاير بنعومة
    _sparks(c, s, rng, 16, const Color(0xFFFFF6C8), const Color(0xFFD4A821),
        spread: 0.35);
    for (int i = 0; i < 8; i++) {
      final y = s.height * (i + 0.5) / 8;
      c.drawLine(
        Offset(0, y),
        Offset(s.width, y),
        Paint()
          ..color = Colors.white.withOpacity(0.05)
          ..strokeWidth = 1,
      );
    }
    _twinkles(c, s, rng, 10, const Color(0xFFFFE08A));
  }

  // ── الكريستال البنفسجي: أوجه بلّورية + انعكاسات منجرفة ──
  void _crystal(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF3B2570), Color(0xFF2A1A4A), Color(0xFF150B2E)],
        Alignment.topLeft, Alignment.bottomRight);
    for (int i = 0; i < 7; i++) {
      final cx = rng.nextDouble() * s.width;
      final cy = rng.nextDouble() * s.height;
      final r = s.shortestSide * (0.14 + rng.nextDouble() * 0.12);
      final rot = rng.nextDouble() * math.pi;
      final sh = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(tt * (1 + i % 3) + i * 2));
      c.save();
      c.translate(cx, cy);
      c.rotate(rot);
      final face = Path()
        ..moveTo(0, -r)
        ..lineTo(r * 0.9, r * 0.3)
        ..lineTo(0, r)
        ..lineTo(-r * 0.9, r * 0.3)
        ..close();
      c.drawPath(face,
          Paint()..color = const Color(0xFFB388FF).withOpacity(0.22 * sh));
      c.drawPath(
        face,
        Paint()
          ..color = const Color(0xFFE9D5FF).withOpacity(0.5 * sh)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      c.restore();
    }
    // شظايا بلّورية معيّنة تتطاير وتدور
    for (int i = 0; i < 9; i++) {
      final cycles = 1 + rng.nextInt(2);
      final p = (t * cycles + rng.nextDouble()) % 1.0;
      final x = rng.nextDouble() * s.width + math.sin(p * 5 + i * 1.8) * 10;
      final y = s.height - p * s.height * 1.1;
      if (y < -6) continue;
      final r = 2.0 + rng.nextDouble() * 2.6;
      final fade = 1 - p * 0.7;
      c.save();
      c.translate(x, y);
      c.rotate(tt + i * 0.8);
      final shard = Path()
        ..moveTo(0, -r)
        ..lineTo(r * 0.7, 0)
        ..lineTo(0, r)
        ..lineTo(-r * 0.7, 0)
        ..close();
      c.drawPath(
        shard,
        Paint()..color = const Color(0xFFE9D5FF).withOpacity(0.55 * fade),
      );
      c.drawPath(
        shard,
        Paint()
          ..color = Colors.white.withOpacity(0.5 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
      c.restore();
    }
    _twinkles(c, s, rng, 12, const Color(0xFFD8B4FE));
  }

  // ── النعناع النيوني: حواف نيون نابضة + موجة ضوء ──
  void _neon(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF0B1220), Color(0xFF070B14), Color(0xFF04060C)]);
    final pulse = 0.55 + 0.45 * math.sin(tt);
    const mint = Color(0xFF3FF5A8);
    for (final top in [true, false]) {
      final rect = Rect.fromLTWH(0, top ? 0 : s.height - 3, s.width, 3);
      c.drawRect(
        rect,
        Paint()
          ..color = mint.withOpacity(0.75 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      c.drawRect(rect, Paint()..color = mint.withOpacity(0.9));
    }
    // جزيئات نيون تتطاير كالوهجات
    _sparks(c, s, rng, 12, mint, const Color(0xFFA78BFA), spread: 0.4);
    for (int i = 0; i < 4; i++) {
      final p = [
        const Offset(8, 8),
        Offset(s.width - 8, 8),
        Offset(8, s.height - 8),
        Offset(s.width - 8, s.height - 8),
      ][i];
      final tw = 0.5 + 0.5 * math.sin(tt * 2 + i * 1.6);
      c.drawCircle(
          p,
          2.2 + tw * 1.5,
          Paint()
            ..color = mint.withOpacity(0.4 + tw * 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    _twinkles(c, s, rng, 6, mint);
  }

  // ── السديم الكوني: سحب بنفسجية منجرفة + نجوم ──
  void _galaxy(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF12082A), Color(0xFF0A0418), Color(0xFF020108)],
        Alignment.topLeft, Alignment.bottomRight);
    const nebs = [
      Color(0xFF7C3AED),
      Color(0xFFEC4899),
      Color(0xFF3B82F6),
    ];
    for (int i = 0; i < 3; i++) {
      final ang = tt * (1 + i) * 0.5 + i * 2.1;
      final cx = s.width * (0.3 + i * 0.2) + math.cos(ang) * s.width * 0.08;
      final cy = s.height * (0.35 + i * 0.15) + math.sin(ang) * s.height * 0.1;
      final r = s.shortestSide * (0.55 + i * 0.15);
      c.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            nebs[i].withOpacity(0.28),
            nebs[i].withOpacity(0.08),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }
    _twinkles(c, s, rng, 26, Colors.white);
  }

  // ── المحيط الليلي: موجات متموجة + لمعان قمري ──
  void _ocean(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF0B3550), Color(0xFF062038), Color(0xFF030E18)]);
    for (int i = 0; i < 3; i++) {
      final yBase = s.height * (0.35 + i * 0.2);
      final path = Path()..moveTo(0, s.height);
      path.lineTo(0, yBase);
      for (double x = 0; x <= s.width; x += 12) {
        path.lineTo(
          x,
          yBase + math.sin(x * 0.02 + tt * (1 + i) + i * 2.4) * 5,
        );
      }
      path.lineTo(s.width, s.height);
      path.close();
      c.drawPath(
        path,
        Paint()..color = const Color(0xFF38BDF8).withOpacity(0.10 - i * 0.025),
      );
    }
    // فقاعات صاعدة ببطء
    for (int i = 0; i < 10; i++) {
      final cycles = 1 + rng.nextInt(2);
      final p = (t * cycles + rng.nextDouble()) % 1.0;
      final x = rng.nextDouble() * s.width +
          math.sin(p * 6 + i * 1.7) * s.width * 0.03;
      final y = s.height - p * s.height * 1.05;
      if (y < -4) continue;
      final r = 1.6 + rng.nextDouble() * 2.8;
      final fade = 1 - p * 0.6;
      c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = const Color(0xFFBAE6FD).withOpacity(0.30 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
      // لمعة صغيرة داخل الفقاعة
      c.drawCircle(
        Offset(x - r * 0.3, y - r * 0.3),
        r * 0.22,
        Paint()..color = Colors.white.withOpacity(0.5 * fade),
      );
    }
    _twinkles(c, s, rng, 12, const Color(0xFFBAE6FD));
  }

  // ── شفق أورورا: ستائر ضوء منسابة ──
  void _aurora(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF0A1220), Color(0xFF060A14), Color(0xFF030508)]);
    const cols = [
      Color(0xFF6EE7B7),
      Color(0xFF7DD3FC),
      Color(0xFFA78BFA),
    ];
    for (int i = 0; i < 3; i++) {
      final path = Path();
      final yTop = s.height * (0.15 + i * 0.12);
      path.moveTo(0, s.height);
      path.lineTo(0, yTop);
      for (double x = 0; x <= s.width; x += 14) {
        path.lineTo(
          x,
          yTop +
              math.sin(x * 0.014 + tt * (1 + i) + i * 2.2) * s.height * 0.09 +
              math.sin(x * 0.05 + tt) * s.height * 0.03,
        );
      }
      path.lineTo(s.width, s.height);
      path.close();
      c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cols[i].withOpacity(0.30),
              cols[i].withOpacity(0.10),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & s)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    _twinkles(c, s, rng, 14, Colors.white);
  }

  // ── عرش التنّين: حراشف ذهبية-حمراء + شرار ──
  void _dragon(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF4A1608), Color(0xFF2A0C05), Color(0xFF140401)]);
    final sc = s.width / 22;
    for (int row = 0; row * sc * 0.7 < s.height + sc; row++) {
      final y = row * sc * 0.7;
      final off = row.isOdd ? sc * 0.5 : 0.0;
      for (double x = -sc + off; x < s.width + sc; x += sc) {
        final shimmer = 0.5 + 0.5 * math.sin(tt * 2 + row + x * 0.01);
        c.drawArc(
          Rect.fromCircle(center: Offset(x, y), radius: sc * 0.52),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = Color.lerp(const Color(0xFFFBBF24),
                    const Color(0xFFEF4444), (row % 3) / 2)!
                .withOpacity(0.25 + shimmer * 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
    // رقائق ذهبية صغيرة تتطاير فوق الحراشف
    for (int i = 0; i < 8; i++) {
      final cycles = 1 + rng.nextInt(2);
      final p = (t * cycles + rng.nextDouble()) % 1.0;
      final x = rng.nextDouble() * s.width + math.sin(p * 4 + i * 2.3) * 12;
      final y = s.height - p * s.height * 1.1;
      if (y < -5) continue;
      final r = 1.8 + rng.nextDouble() * 2.0;
      c.save();
      c.translate(x, y);
      c.rotate(tt + i * 1.3);
      c.drawRect(
        Rect.fromCenter(center: Offset.zero, width: r, height: r * 0.6),
        Paint()
          ..color = const Color(0xFFFDE68A).withOpacity((1 - p * 0.7) * 0.75),
      );
      c.restore();
    }
    _sparks(c, s, rng, 14, const Color(0xFFFDE68A), const Color(0xFFEF4444));
  }

  // ── الجمر الخالد: فحم يتنفس بتوهج داخلي ──
  void _ember(Canvas c, Size s, double tt, math.Random rng) {
    _bg(c, s, const [Color(0xFF1E0E06), Color(0xFF120703), Color(0xFF080302)]);
    for (int i = 0; i < 12; i++) {
      final cx = rng.nextDouble() * s.width;
      final cy = rng.nextDouble() * s.height;
      final breath = 0.5 + 0.5 * math.sin(tt * (1 + i % 2) + i * 1.7);
      final r = s.shortestSide * (0.05 + rng.nextDouble() * 0.08);
      c.drawCircle(
        Offset(cx, cy),
        r * (0.8 + breath * 0.4),
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFE08A).withOpacity(0.75 * breath),
            const Color(0xFFFF6A00).withOpacity(0.35 * breath),
            Colors.transparent,
          ]).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.2)),
      );
    }
    _sparks(c, s, rng, 10, const Color(0xFFFCA5A5), const Color(0xFF7F1D1D),
        spread: 0.6);
  }

  // ── خشبة استكانة كلاسيكية: ألواح خشبية + مسامير نحاسية يمين ويسار ──
  void _woodPlanks(Canvas c, Size s, double tt, math.Random rng, int kind) {
    const palettes = [
      // بلوط فاتح
      [Color(0xFFA9764A), Color(0xFF8A5A30), Color(0xFF5F3A1A)],
      // جوز داكن
      [Color(0xFF6E452A), Color(0xFF4E2E17), Color(0xFF2F1B0C)],
      // ماهوجني محمر
      [Color(0xFF8A4630), Color(0xFF64301E), Color(0xFF3E1C0F)],
    ];
    final cols = palettes[kind];
    _bg(c, s, cols);

    // عروق الخشب — خطوط متموجة بطول القطعة
    final grain = dark2(kind);
    for (int i = 0; i < 8; i++) {
      final y0 = s.height * (0.10 + rng.nextDouble() * 0.8);
      final path = Path()..moveTo(-4, y0);
      double x = -4, y = y0;
      while (x < s.width + 8) {
        x += s.width * 0.11;
        y = y0 +
            math.sin(x * 0.02 + i * 1.6) * s.height * 0.035 +
            (rng.nextDouble() - 0.5) * 2.5;
        path.lineTo(x, y);
      }
      c.drawPath(
        path,
        Paint()
          ..color = grain.withOpacity(0.28)
          ..strokeWidth = 0.9 + rng.nextDouble() * 1.1
          ..style = PaintingStyle.stroke,
      );
    }

    // عقدة خشبية أو اثنتان (دوائر متحدة المركز)
    for (int i = 0; i < 2; i++) {
      final cx = s.width * (0.28 + i * 0.44 + rng.nextDouble() * 0.08);
      final cy = s.height * (0.3 + rng.nextDouble() * 0.4);
      for (int k = 3; k >= 1; k--) {
        c.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy),
              width: k * s.height * 0.16,
              height: k * s.height * 0.11),
          Paint()
            ..color = grain.withOpacity(0.10 + 0.05 * k)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    // لمعة سطح + ظل سفلي (إحساس لاكر)
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x2EFFFFFF), Colors.transparent, Color(0x33000000)],
          stops: [0.0, 0.38, 1.0],
        ).createShader(Offset.zero & s),
    );

    // مسامير نحاسية على الطرفين (يمين ويسار) — 3 لكل طرف
    final nailR = (s.shortestSide * 0.085).clamp(2.2, 7.0);
    for (final side in [0, 1]) {
      final cx = side == 0
          ? s.shortestSide * 0.16 + nailR
          : s.width - s.shortestSide * 0.16 - nailR;
      for (int k = 0; k < 3; k++) {
        _nail(c, Offset(cx, s.height * (0.24 + k * 0.26)), nailR, tt,
            side * 3 + k);
      }
    }
  }

  Color dark2(int kind) => kind == 0
      ? const Color(0xFF573517)
      : kind == 1
          ? const Color(0xFF241305)
          : const Color(0xFF3A1B0D);

  /// رأس مسمار نحاسي — ظل + جسم معدني + لمعة خفيفة تتحرك
  void _nail(Canvas c, Offset p, double r, double tt, int i) {
    c.drawCircle(
      p.translate(r * 0.14, r * 0.2),
      r,
      Paint()..color = Colors.black.withOpacity(0.4),
    );
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE9A8), Color(0xFFC9912F), Color(0xFF5F3E10)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(
            center: p.translate(-r * 0.35, -r * 0.35), radius: r * 1.5)),
    );
    c.drawCircle(
      p,
      r * 0.58,
      Paint()..color = const Color(0xFF7A5016).withOpacity(0.65),
    );
    final glint = 0.5 + 0.5 * math.sin(tt * 1.4 + i * 2.2);
    c.drawCircle(
      p.translate(-r * 0.3, -r * 0.32),
      r * 0.22,
      Paint()..color = Colors.white.withOpacity(0.45 + 0.35 * glint),
    );
  }

  @override
  bool shouldRepaint(_FxSurfacePainter old) =>
      old.t != t || old.pointer != pointer || old.intensity != intensity;
}

// ════════════════════════════════════════════════════════════════════
// إطار دائري عام — يعيد استخدام رسام السطح داخل حلقة + حافة ملونة
// ════════════════════════════════════════════════════════════════════
class _FxRingPainter extends CustomPainter {
  final SkinEffect effect;
  final double t;
  final ui.Image? wood;
  _FxRingPainter(this.effect, this.t, [this.wood]);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final ringR = radius * 0.82;
    final tt = t * math.pi * 2;
    final accent = skinAccentColor(effect);
    final rng = math.Random(53);

    canvas.drawCircle(
      c,
      ringR + 4,
      Paint()
        ..color = accent.withOpacity(0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.save();
    final ringPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: ringR + radius * 0.09))
      ..addOval(Rect.fromCircle(center: c, radius: ringR - radius * 0.09));
    canvas.clipPath(ringPath);
    _FxSurfacePainter(effect, t, null, 0).paint(canvas, size);
    _woodOverlay(canvas, size, wood);
    canvas.restore();

    canvas.drawCircle(
      c,
      ringR + radius * 0.085,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withOpacity(0.9),
    );
    canvas.drawCircle(
      c,
      ringR - radius * 0.085,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withOpacity(0.7),
    );

    for (int i = 0; i < 2; i++) {
      final ang = tt * (1 + i) + i * math.pi;
      final pos =
          Offset(c.dx + math.cos(ang) * ringR, c.dy + math.sin(ang) * ringR);
      canvas.drawCircle(
        pos,
        3.2,
        Paint()
          ..color = accent.withOpacity(0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(pos, 1.2, Paint()..color = Colors.white);
    }
    for (int i = 0; i < 8; i++) {
      final ang = i / 8 * math.pi * 2 + rng.nextDouble() * 0.4;
      final tw = 0.5 + 0.5 * math.sin(tt * 2 + i * 1.9);
      final pos =
          Offset(c.dx + math.cos(ang) * ringR, c.dy + math.sin(ang) * ringR);
      canvas.drawCircle(
        pos,
        1.0 + tw,
        Paint()..color = Colors.white.withOpacity(0.3 + tw * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_FxRingPainter old) => old.t != t;
}
