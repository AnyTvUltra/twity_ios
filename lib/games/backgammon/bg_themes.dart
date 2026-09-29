import 'package:flutter/material.dart';
import '../../widgets/animated_skin_effect.dart';

// ══════════════════════════════════════════════════════════════
// سكنات الطاولي — ثيمات اللوح ومجموعات الأحجار
// معرّف عنصر المتجر: builtin_bgboard_<id> / builtin_bgcheckers_<id>
// ══════════════════════════════════════════════════════════════

class BgBoardTheme {
  final String id;
  final List<Color> caseColors;
  final List<Color> trayColors;
  final List<Color> fieldColors;
  final List<Color> darkPoint;
  final List<Color> lightPoint;
  final Color grain;
  final double grainAlpha;
  final List<Color> metal;
  final Color ornament;
  final Color pointStroke;

  /// تأثير متحرك فوق الميدان (نار/جليد/مجرة...)
  final SkinEffect effect;
  final double effectAlpha;

  /// توهج حواف المثلثات (نيون)
  final Color? pointGlow;

  /// استخدام خامة الخشب الحقيقية على الحقيبة
  final bool woodTexture;

  const BgBoardTheme({
    required this.id,
    required this.caseColors,
    required this.trayColors,
    required this.fieldColors,
    required this.darkPoint,
    required this.lightPoint,
    this.grain = const Color(0xFF8A4B1C),
    this.grainAlpha = 0.13,
    this.metal = const [
      Color(0xFFFFE9A8),
      Color(0xFFD4A437),
      Color(0xFF8A6415)
    ],
    this.ornament = const Color(0xFF7A3E12),
    this.pointStroke = const Color(0xFF3A1606),
    this.effect = SkinEffect.none,
    this.effectAlpha = 0.5,
    this.pointGlow,
    this.woodTexture = false,
  });

  bool get animated => effect != SkinEffect.none;
}

enum BgPattern { none, wood, marble, metal, fire, ice, neon, gem }

class BgCheckerStyle {
  final List<Color> face;
  final List<Color> edge;
  final List<Color> rim;
  final Color groove;
  final double grooveLight;
  final double spec;
  final BgPattern pattern;
  final Color accent;

  const BgCheckerStyle({
    required this.face,
    required this.edge,
    required this.rim,
    required this.groove,
    this.grooveLight = 0.5,
    this.spec = 0.6,
    this.pattern = BgPattern.none,
    this.accent = Colors.white,
  });

  bool get animated =>
      pattern == BgPattern.fire ||
      pattern == BgPattern.neon ||
      pattern == BgPattern.ice;
}

/// مجموعة أحجار: أحجارك + أحجار الخصم بلون متباين
class BgCheckerSet {
  final String id;
  final BgCheckerStyle mine;
  final BgCheckerStyle opp;
  const BgCheckerSet(this.id, this.mine, this.opp);

  BgCheckerStyle of(int side) => side == 0 ? mine : opp;
  bool get animated => mine.animated || opp.animated;
}

class BgThemes {
  BgThemes._();

  // ── الألواح ──
  static const classic = BgBoardTheme(
    id: 'classic',
    caseColors: [Color(0xFF7A3E1A), Color(0xFF4A220C), Color(0xFF2A1105)],
    trayColors: [Color(0xFF1E40AF), Color(0xFF14286E), Color(0xFF0B1845)],
    fieldColors: [Color(0xFFF2C68B), Color(0xFFE0A765), Color(0xFFC98A48)],
    darkPoint: [Color(0xFF8E2F10), Color(0xFFB4481C), Color(0xFF7A2208)],
    lightPoint: [Color(0xFFFFE7BE), Color(0xFFF5CF92), Color(0xFFE2B06C)],
    woodTexture: true,
  );

  static const Map<String, BgBoardTheme> boards = {
    'classic': classic,
    'ebony': BgBoardTheme(
      id: 'ebony',
      caseColors: [Color(0xFF2A2522), Color(0xFF15110F), Color(0xFF050404)],
      trayColors: [Color(0xFF3B0A14), Color(0xFF250610), Color(0xFF12030A)],
      fieldColors: [Color(0xFF3A302A), Color(0xFF241D19), Color(0xFF130F0D)],
      darkPoint: [Color(0xFFB8862B), Color(0xFFF2D27A), Color(0xFF8A6415)],
      lightPoint: [Color(0xFFF5EBDD), Color(0xFFE2D4BF), Color(0xFFBFAE95)],
      grain: Color(0xFF000000),
      grainAlpha: 0.35,
      ornament: Color(0xFFD4A437),
      pointStroke: Color(0xFF000000),
    ),
    'teak': BgBoardTheme(
      id: 'teak',
      caseColors: [Color(0xFFA0642E), Color(0xFF7A4518), Color(0xFF4E2A0B)],
      trayColors: [Color(0xFF3F6212), Color(0xFF2B4A0C), Color(0xFF1A2E06)],
      fieldColors: [Color(0xFFE8B570), Color(0xFFD29A50), Color(0xFFB57A34)],
      darkPoint: [Color(0xFF5A2E0E), Color(0xFF7A4518), Color(0xFF3E1E06)],
      lightPoint: [Color(0xFFF7DDA8), Color(0xFFEBC47E), Color(0xFFD4A45A)],
      grain: Color(0xFF6B3A12),
      grainAlpha: 0.22,
      woodTexture: true,
    ),
    'pearl': BgBoardTheme(
      id: 'pearl',
      caseColors: [Color(0xFF3A1D10), Color(0xFF26120A), Color(0xFF140905)],
      trayColors: [Color(0xFF0F766E), Color(0xFF0B524D), Color(0xFF06302D)],
      fieldColors: [Color(0xFFFDF8F0), Color(0xFFEDE3D6), Color(0xFFD9CBB8)],
      darkPoint: [Color(0xFF7F1D1D), Color(0xFFA83232), Color(0xFF5C1010)],
      lightPoint: [Color(0xFF5EEAD4), Color(0xFF2DD4BF), Color(0xFF0F9488)],
      grain: Color(0xFFB9A7FF),
      grainAlpha: 0.12,
      ornament: Color(0xFFB08A5A),
      effect: SkinEffect.crystal,
      effectAlpha: 0.18,
    ),
    'felt': BgBoardTheme(
      id: 'felt',
      caseColors: [Color(0xFF6B2A12), Color(0xFF451A0A), Color(0xFF250D04)],
      trayColors: [Color(0xFF1F2937), Color(0xFF111827), Color(0xFF030712)],
      fieldColors: [Color(0xFF1B7A43), Color(0xFF12603A), Color(0xFF0A3F26)],
      darkPoint: [Color(0xFFB91C1C), Color(0xFFDC2626), Color(0xFF7F1D1D)],
      lightPoint: [Color(0xFFFFF7E6), Color(0xFFF1E4C8), Color(0xFFD8C7A2)],
      grain: Color(0xFF000000),
      grainAlpha: 0.08,
      ornament: Color(0xFF0A2E1A),
      woodTexture: true,
    ),
    'fire': BgBoardTheme(
      id: 'fire',
      caseColors: [Color(0xFF2A1410), Color(0xFF160906), Color(0xFF070302)],
      trayColors: [Color(0xFF7C1D06), Color(0xFF4A1004), Color(0xFF220602)],
      fieldColors: [Color(0xFF3B1A10), Color(0xFF24100A), Color(0xFF120604)],
      darkPoint: [Color(0xFFFF7A1A), Color(0xFFFFB347), Color(0xFFC2410C)],
      lightPoint: [Color(0xFF3F3F46), Color(0xFF27272A), Color(0xFF18181B)],
      grain: Color(0xFFFF5A1F),
      grainAlpha: 0.1,
      metal: [Color(0xFFFFD1A6), Color(0xFFD97738), Color(0xFF7A3510)],
      ornament: Color(0xFFFF7A1A),
      pointStroke: Color(0xFF000000),
      effect: SkinEffect.lava,
      effectAlpha: 0.28,
      pointGlow: Color(0xFFFF6A00),
    ),
    'ice': BgBoardTheme(
      id: 'ice',
      caseColors: [Color(0xFFB8D4E8), Color(0xFF7FA7C4), Color(0xFF4A7394)],
      trayColors: [Color(0xFF0C4A6E), Color(0xFF083556), Color(0xFF041E33)],
      fieldColors: [Color(0xFFEFF8FF), Color(0xFFD4ECFB), Color(0xFFA8D2EE)],
      darkPoint: [Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFF075985)],
      lightPoint: [Color(0xFFFFFFFF), Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
      grain: Color(0xFFFFFFFF),
      grainAlpha: 0.25,
      metal: [Color(0xFFFFFFFF), Color(0xFFCBD5E1), Color(0xFF64748B)],
      ornament: Color(0xFF7DD3FC),
      pointStroke: Color(0xFF0C4A6E),
      effect: SkinEffect.frost,
      effectAlpha: 0.35,
    ),
    'neon': BgBoardTheme(
      id: 'neon',
      caseColors: [Color(0xFF111735), Color(0xFF0A0E22), Color(0xFF03050F)],
      trayColors: [Color(0xFF1E1B4B), Color(0xFF14123A), Color(0xFF0A0920)],
      fieldColors: [Color(0xFF0F1633), Color(0xFF0A0F24), Color(0xFF050814)],
      darkPoint: [Color(0xFF7C3AED), Color(0xFFC026D3), Color(0xFF581C87)],
      lightPoint: [Color(0xFF0891B2), Color(0xFF22D3EE), Color(0xFF155E75)],
      grain: Color(0xFF22D3EE),
      grainAlpha: 0.05,
      metal: [Color(0xFFE0F2FE), Color(0xFF22D3EE), Color(0xFF0E7490)],
      ornament: Color(0xFF22D3EE),
      pointStroke: Color(0xFF000000),
      effect: SkinEffect.neon,
      effectAlpha: 0.25,
      pointGlow: Color(0xFF22D3EE),
    ),
    'galaxy': BgBoardTheme(
      id: 'galaxy',
      caseColors: [Color(0xFF1E1036), Color(0xFF120822), Color(0xFF06030E)],
      trayColors: [Color(0xFF312E81), Color(0xFF1E1B4B), Color(0xFF0B0A24)],
      fieldColors: [Color(0xFF1A1440), Color(0xFF100C2A), Color(0xFF070514)],
      darkPoint: [Color(0xFFDB2777), Color(0xFFF472B6), Color(0xFF9D174D)],
      lightPoint: [Color(0xFFE9D5FF), Color(0xFFC4B5FD), Color(0xFF8B5CF6)],
      grain: Color(0xFFFFFFFF),
      grainAlpha: 0.04,
      metal: [Color(0xFFF5D0FE), Color(0xFFC084FC), Color(0xFF6B21A8)],
      ornament: Color(0xFFE9D5FF),
      pointStroke: Color(0xFF000000),
      effect: SkinEffect.galaxy,
      effectAlpha: 0.6,
    ),
  };

  // ── الأحجار ──
  static const pearl = BgCheckerStyle(
    face: [Color(0xFFFFFFFF), Color(0xFFF1ECE2), Color(0xFFC7BEAE)],
    edge: [Color(0xFFB9B1A2), Color(0xFF8A8274)],
    rim: [Color(0xFFFFFFFF), Color(0xFFD9D1C2), Color(0xFFA89F8E)],
    groove: Color(0xFF8E8676),
    grooveLight: 0.7,
    spec: 0.75,
  );
  static const obsidian = BgCheckerStyle(
    face: [Color(0xFF6B717E), Color(0xFF2A2E36), Color(0xFF0B0C10)],
    edge: [Color(0xFF15171C), Color(0xFF000000)],
    rim: [Color(0xFF8A909C), Color(0xFF3A3F48), Color(0xFF050608)],
    groove: Color(0xFF000000),
    grooveLight: 0.18,
    spec: 0.35,
  );

  static const classicSet = BgCheckerSet('classic', pearl, obsidian);

  static const Map<String, BgCheckerSet> checkers = {
    'classic': classicSet,
    'wood': BgCheckerSet(
      'wood',
      BgCheckerStyle(
        face: [Color(0xFFFFE0B0), Color(0xFFE8B878), Color(0xFFB9854A)],
        edge: [Color(0xFFA06A34), Color(0xFF6E4420)],
        rim: [Color(0xFFFFEBC8), Color(0xFFD9A868), Color(0xFF9A6A34)],
        groove: Color(0xFF7A4A1E),
        pattern: BgPattern.wood,
        accent: Color(0xFF8A5424),
        spec: 0.45,
      ),
      BgCheckerStyle(
        face: [Color(0xFF9A5A2E), Color(0xFF5E3014), Color(0xFF2E1406)],
        edge: [Color(0xFF3A1A08), Color(0xFF1A0A02)],
        rim: [Color(0xFFB0703E), Color(0xFF5E3014), Color(0xFF200C02)],
        groove: Color(0xFF1A0A02),
        grooveLight: 0.2,
        pattern: BgPattern.wood,
        accent: Color(0xFF1E0A02),
        spec: 0.35,
      ),
    ),
    'teak': BgCheckerSet(
      'teak',
      BgCheckerStyle(
        face: [Color(0xFFF0B868), Color(0xFFC98A3E), Color(0xFF94601F)],
        edge: [Color(0xFF8A5A22), Color(0xFF5A3812)],
        rim: [Color(0xFFFFD08A), Color(0xFFC98A3E), Color(0xFF7A4A14)],
        groove: Color(0xFF6A3E10),
        pattern: BgPattern.wood,
        accent: Color(0xFF7A4A14),
        spec: 0.5,
      ),
      BgCheckerStyle(
        face: [Color(0xFF4A4038), Color(0xFF221C18), Color(0xFF0A0806)],
        edge: [Color(0xFF14100C), Color(0xFF000000)],
        rim: [Color(0xFF6A5E54), Color(0xFF2A2420), Color(0xFF050404)],
        groove: Color(0xFF000000),
        grooveLight: 0.15,
        pattern: BgPattern.wood,
        accent: Color(0xFF000000),
        spec: 0.4,
      ),
    ),
    'marble': BgCheckerSet(
      'marble',
      BgCheckerStyle(
        face: [Color(0xFFFFFFFF), Color(0xFFF3F4F6), Color(0xFFD1D5DB)],
        edge: [Color(0xFFB8BCC4), Color(0xFF8A8E96)],
        rim: [Color(0xFFFFFFFF), Color(0xFFE5E7EB), Color(0xFF9CA3AF)],
        groove: Color(0xFF9CA3AF),
        pattern: BgPattern.marble,
        accent: Color(0xFF9CA3AF),
        spec: 0.85,
      ),
      BgCheckerStyle(
        face: [Color(0xFF4B5563), Color(0xFF1F2937), Color(0xFF030712)],
        edge: [Color(0xFF111827), Color(0xFF000000)],
        rim: [Color(0xFF6B7280), Color(0xFF1F2937), Color(0xFF000000)],
        groove: Color(0xFF000000),
        grooveLight: 0.2,
        pattern: BgPattern.marble,
        accent: Color(0xFFD4A437),
        spec: 0.6,
      ),
    ),
    'gold': BgCheckerSet(
      'gold',
      BgCheckerStyle(
        face: [Color(0xFFFFF3C4), Color(0xFFF2C94C), Color(0xFFA87B12)],
        edge: [Color(0xFFB8860B), Color(0xFF7A5608)],
        rim: [Color(0xFFFFF8DC), Color(0xFFE0B040), Color(0xFF8A6415)],
        groove: Color(0xFF8A6415),
        pattern: BgPattern.metal,
        spec: 0.9,
      ),
      BgCheckerStyle(
        face: [Color(0xFFF8FAFC), Color(0xFFB8C2CF), Color(0xFF5E6A7A)],
        edge: [Color(0xFF64748B), Color(0xFF334155)],
        rim: [Color(0xFFFFFFFF), Color(0xFFCBD5E1), Color(0xFF475569)],
        groove: Color(0xFF475569),
        pattern: BgPattern.metal,
        spec: 0.9,
      ),
    ),
    'fire': BgCheckerSet(
      'fire',
      BgCheckerStyle(
        face: [Color(0xFFFFE08A), Color(0xFFFF8A1A), Color(0xFFB42A06)],
        edge: [Color(0xFF9A2A06), Color(0xFF4A0E02)],
        rim: [Color(0xFFFFD27A), Color(0xFFFF6A00), Color(0xFF7A1A04)],
        groove: Color(0xFF6A1204),
        pattern: BgPattern.fire,
        accent: Color(0xFFFF6A00),
        spec: 0.55,
      ),
      BgCheckerStyle(
        face: [Color(0xFF52525B), Color(0xFF27272A), Color(0xFF09090B)],
        edge: [Color(0xFF18181B), Color(0xFF000000)],
        rim: [Color(0xFF71717A), Color(0xFF27272A), Color(0xFF000000)],
        groove: Color(0xFF000000),
        grooveLight: 0.15,
        pattern: BgPattern.fire,
        accent: Color(0xFFEF4444),
        spec: 0.35,
      ),
    ),
    'ice': BgCheckerSet(
      'ice',
      BgCheckerStyle(
        face: [Color(0xFFFFFFFF), Color(0xFFBAE6FD), Color(0xFF38BDF8)],
        edge: [Color(0xFF7DD3FC), Color(0xFF0284C7)],
        rim: [Color(0xFFFFFFFF), Color(0xFF7DD3FC), Color(0xFF0369A1)],
        groove: Color(0xFF0369A1),
        pattern: BgPattern.ice,
        accent: Color(0xFFE0F2FE),
        spec: 0.9,
      ),
      BgCheckerStyle(
        face: [Color(0xFF3B5B8C), Color(0xFF1E3A5F), Color(0xFF0A1A30)],
        edge: [Color(0xFF0F2440), Color(0xFF050E1C)],
        rim: [Color(0xFF6B8CBF), Color(0xFF1E3A5F), Color(0xFF050E1C)],
        groove: Color(0xFF050E1C),
        grooveLight: 0.25,
        pattern: BgPattern.ice,
        accent: Color(0xFF7DD3FC),
        spec: 0.6,
      ),
    ),
    'neon': BgCheckerSet(
      'neon',
      BgCheckerStyle(
        face: [Color(0xFF1E293B), Color(0xFF0F172A), Color(0xFF020617)],
        edge: [Color(0xFF0F172A), Color(0xFF000000)],
        rim: [Color(0xFF67E8F9), Color(0xFF06B6D4), Color(0xFF0E7490)],
        groove: Color(0xFF22D3EE),
        grooveLight: 0.0,
        pattern: BgPattern.neon,
        accent: Color(0xFF22D3EE),
        spec: 0.3,
      ),
      BgCheckerStyle(
        face: [Color(0xFF2E1065), Color(0xFF1E0B45), Color(0xFF0B0320)],
        edge: [Color(0xFF1E0B45), Color(0xFF000000)],
        rim: [Color(0xFFF0ABFC), Color(0xFFD946EF), Color(0xFF86198F)],
        groove: Color(0xFFE879F9),
        grooveLight: 0.0,
        pattern: BgPattern.neon,
        accent: Color(0xFFE879F9),
        spec: 0.3,
      ),
    ),
    'gem': BgCheckerSet(
      'gem',
      BgCheckerStyle(
        face: [Color(0xFFFFB4C0), Color(0xFFE11D48), Color(0xFF7F0A24)],
        edge: [Color(0xFF9F1239), Color(0xFF4C0519)],
        rim: [Color(0xFFFFE4E6), Color(0xFFF43F5E), Color(0xFF881337)],
        groove: Color(0xFF4C0519),
        pattern: BgPattern.gem,
        accent: Color(0xFFFFE4E6),
        spec: 0.9,
      ),
      BgCheckerStyle(
        face: [Color(0xFFA7F3D0), Color(0xFF059669), Color(0xFF064E3B)],
        edge: [Color(0xFF065F46), Color(0xFF022C22)],
        rim: [Color(0xFFD1FAE5), Color(0xFF10B981), Color(0xFF064E3B)],
        groove: Color(0xFF022C22),
        pattern: BgPattern.gem,
        accent: Color(0xFFD1FAE5),
        spec: 0.9,
      ),
    ),
  };

  static BgBoardTheme boardFromItemId(String? id) {
    if (id == null || !id.startsWith('builtin_bgboard_')) return classic;
    return boards[id.substring('builtin_bgboard_'.length)] ?? classic;
  }

  static BgCheckerSet checkersFromItemId(String? id) {
    if (id == null || !id.startsWith('builtin_bgcheckers_')) return classicSet;
    return checkers[id.substring('builtin_bgcheckers_'.length)] ?? classicSet;
  }
}
