import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// متحكم الوضع النهاري/الليلي — حالياً يؤثر على صفحة الملف الشخصي وشريط التنقل.
/// يُحفظ الاختيار محلياً عبر SharedPreferences.
class UiTheme extends ChangeNotifier {
  UiTheme._();
  static final UiTheme instance = UiTheme._();

  bool _light = false;
  bool get isLight => _light;

  /// مدة الانتقال بين الوضعين
  static const transition = Duration(milliseconds: 280);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _light = prefs.getBool('ui_light_mode') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setLight(bool v) async {
    if (_light == v) return;
    _light = v;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ui_light_mode', v);
    } catch (_) {}
  }

  Future<void> toggle() => setLight(!_light);
}

/// رموز ألوان صفحة الملف الشخصي — Light/Dark.
/// الوضع الليلي يعيد نفس الألوان الحالية تماماً.
class PT {
  final bool light;
  const PT(this.light);

  // ── الألوان العامة للوضع النهاري ──
  static const navy = Color(0xFF111B3A);
  static const textSoft = Color(0xFF71809A);
  static const cardWhite = Color(0xFFFFFFFF);
  static const goldL = Color(0xFFE8AD22);
  static const greenL = Color(0xFF21C7A0);
  static const blueL = Color(0xFF2F8EF5);
  static const pinkL = Color(0xFFF05A9D);
  static const purpleL = Color(0xFF8B65E8);
  static const lineL = Color(0xFFEAEEF6);

  // ── الوضع الليلي (القيم الحالية) ──
  static const _textW = Color(0xFFF1F5FF);
  static const _textD = Color(0xFF8EA3C8);
  static const _goldD = Color(0xFFFFD54F);
  static const _emeraldD = Color(0xFF34D399);
  static const _cyanD = Color(0xFF38BDF8);
  static const _pinkD = Color(0xFFF472B6);
  static const _purpleD = Color(0xFFA78BFA);
  static const _redD = Color(0xFFF87171);

  // ── الخلفية ──
  List<Color> get bgGradient => light
      ? const [Color(0xFFFBFCFE), Color(0xFFF7F9FC), Color(0xFFEFF3FA)]
      : const [Color(0xFF0A0F24), Color(0xFF080C1C), Color(0xFF04060F)];

  // ── النصوص ──
  Color get text => light ? navy : _textW;
  Color get textDim => light ? textSoft : _textD;
  Color get textFaint =>
      light ? const Color(0xFFA5B1C6) : const Color(0xFF64748B);

  // ── الأكسنتات ──
  Color get gold => light ? goldL : _goldD;
  Color get emerald => light ? const Color(0xFF12A787) : _emeraldD;
  Color get cyan => light ? blueL : _cyanD;
  Color get pink => light ? pinkL : _pinkD;
  Color get purple => light ? purpleL : _purpleD;
  Color get red => light ? const Color(0xFFE5484D) : _redD;
  Color get blue => light ? blueL : const Color(0xFF3B82F6);

  // ── البطاقات ──
  Color get card => light ? cardWhite : const Color(0x2E141C3C);
  Color get cardBorder => light ? lineL : const Color(0x26FFFFFF);
  List<BoxShadow> get cardShadow => light
      ? [
          BoxShadow(
              color: navy.withOpacity(0.07),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ]
      : [];

  // بطاقة الملف الرئيسية
  List<Color> get heroCardGradient => light
      ? [cardWhite, const Color(0xFFFCFDFF)]
      : [
          const Color(0xFF1B2A5E).withOpacity(0.55),
          const Color(0xFF101838).withOpacity(0.45),
        ];
  Color get heroCardBorder =>
      light ? const Color(0xFFE9E2CE) : _goldD.withOpacity(0.45);
  List<BoxShadow> get heroCardShadow => light
      ? [
          BoxShadow(
              color: navy.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ]
      : [
          BoxShadow(
              color: _goldD.withOpacity(0.14),
              blurRadius: 26,
              spreadRadius: -4),
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ];

  // ── أيقونات الهيدر ──
  Color get iconTile => light ? cardWhite : const Color(0x2E16204A);
  Color get iconTileBorder => light ? lineL : const Color(0x26FFFFFF);
  List<BoxShadow> get iconTileShadow => light
      ? [
          BoxShadow(
              color: navy.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ]
      : [];

  // ── بطاقات الإحصائيات ──
  Color statBg(Color accent) =>
      light ? accent.withOpacity(0.08) : const Color(0x1FFFFFFF);
  Color statBorder(Color accent) => accent.withOpacity(light ? 0.30 : 0.30);
  List<BoxShadow> statShadow(Color accent) => light
      ? [
          BoxShadow(
              color: navy.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ]
      : [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 8)];

  // ── شارة التوثيق ──
  Color get verifiedBg =>
      light ? const Color(0xFFE2F8F2) : _emeraldD.withOpacity(0.12);
  Color get verifiedBorder =>
      light ? const Color(0xFFB9EBDF) : _emeraldD.withOpacity(0.55);

  // ── الفواصل ──
  Color get divider =>
      light ? const Color(0xFFEDF1F7) : const Color(0x14FFFFFF);
  Color get dividerStrong =>
      light ? const Color(0xFFE4EAF3) : const Color(0x1FFFFFFF);

  // ── مربع أيقونة عنصر الإعدادات ──
  Color iconBoxBg(Color accent) => accent.withOpacity(light ? 0.12 : 0.12);
  Color iconBoxBorder(Color accent) => accent.withOpacity(light ? 0.28 : 0.40);

  // ── حقول الإدخال والحوارات ──
  Color get dialogBg => light ? cardWhite : const Color(0xFF141C34);
  Color get inputFill =>
      light ? const Color(0xFFF3F6FB) : const Color(0x2E141C3C);
  Color get sheetTop => light ? cardWhite : const Color(0xF2152150);
  Color get sheetBot =>
      light ? const Color(0xFFF7F9FC) : const Color(0xF20A0F24);

  // ── دوائر الصور الرمزية في النافذة السفلية ──
  List<Color> get avatarPickGradient => light
      ? const [Color(0xFFF1F5FB), Color(0xFFE7EDF7)]
      : const [Color(0xFF26335E), Color(0xFF131B36)];

  // ── شريط التنقل السفلي ──
  List<Color> get navGradient => light
      ? [cardWhite, const Color(0xFFF5F7FB)]
      : [
          Colors.white.withValues(alpha: 0.12),
          const Color(0xFF0B1220).withValues(alpha: 0.66)
        ];
  Color get navBorder =>
      light ? const Color(0xFFE6EBF4) : Colors.white.withValues(alpha: 0.14);
  List<BoxShadow> get navShadow => light
      ? [
          BoxShadow(
              color: navy.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ]
      : [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 26,
              offset: const Offset(0, 12)),
        ];
  Color get navInactive =>
      light ? const Color(0xFF7C8AA5) : const Color(0xFF94A3B8);
  Color get navIconCircle =>
      light ? const Color(0xFFF2F5FA) : Colors.white.withValues(alpha: 0.05);
}

// ══════════════════════════════════════════════════════════════════
// التحويل العام للألوان بين الليلي والنهاري (للشاشات الأخرى)
// ══════════════════════════════════════════════════════════════════

/// خريطة: كل لون داكن مستخدم في الواجهة -> بديله النهاري.
final Map<int, Color> _dayMap = {
  // خلفيات داكنة -> أفتح ما يمكن
  0xFF050914: const Color(0xFFF5F8FC),
  0xFF070D1C: const Color(0xFFF3F6FB),
  0xFF0A1124: const Color(0xFFF0F4FA),
  0xFF0B1220: const Color(0xFFEFF3F9),
  0xFF0B1020: const Color(0xFFEFF3F9),
  0xFF0C1530: const Color(0xFFEFF4FA),
  0xFF0D1B33: const Color(0xFFEFF4FB),
  0xFF0E1C3A: const Color(0xFFEDF3FA),
  0xFF0F1B33: const Color(0xFFEDF3FA),
  0xFF101730: const Color(0xFFEDF2F9),
  0xFF121B36: const Color(0xFFECF1F8),
  0xFF131B36: const Color(0xFFECF1F8),
  0xFF14264D: const Color(0xFFE8EFF8),
  0xFF152642: const Color(0xFFE9F0F9),
  0xFF16224B: const Color(0xFFE8EFF8),
  0xFF1A2450: const Color(0xFFE5EDF7),
  0xFF1B2440: const Color(0xFFE4EBF5),
  0xFF1E2B4F: const Color(0xFFE3EAF4),
  0xFF1F2B52: const Color(0xFFE3EAF4),
  0xFF202A4D: const Color(0xFFE3EAF4),
  0xFF233055: const Color(0xFFE2E9F3),
  0xFF26335E: const Color(0xFFE1E8F2),
  0xFF2A3554: const Color(0xFFDEE6F0),
  0xFF2E3A5C: const Color(0xFFDDE5EF),
  // نصوص فاتحة -> داكنة
  0xFFFFFFFF: const Color(0xFF111B3A),
  0xFFF5F7FF: const Color(0xFF141F3E),
  0xFFF0F4FF: const Color(0xFF16213F),
  0xFFE2E8F0: const Color(0xFF2B3A5E),
  0xFFCBD5E1: const Color(0xFF3A4A6E),
  0xFFB0B8CC: const Color(0xFF5A6A8C),
  0xFF94A3B8: const Color(0xFF71809A),
  0xFF8E9BC0: const Color(0xFF6B7A99),
  0xFF7C8AA5: const Color(0xFF8A97B2),
  0xFF64748B: const Color(0xFF7C8AA5),
  // ألوان مميزة: إبقاء الروح لكن أفتح/أكثر قراءةً على الأبيض
  0xFFF7C948: const Color(0xFFE8AD22),
  0xFFFFD54F: const Color(0xFFE8AD22),
  0xFFFFC94D: const Color(0xFFE8A920),
  0xFFE8B12C: const Color(0xFFDD9E1A),
  0xFFFFB300: const Color(0xFFE8A200),
  0xFFFFA000: const Color(0xFFE89500),
  0xFF3FF5A8: const Color(0xFF14B888),
  0xFF22E39E: const Color(0xFF14B988),
  0xFF4ADE80: const Color(0xFF22B573),
  0xFF3B82F6: const Color(0xFF2F8EF5),
  0xFF60A5FA: const Color(0xFF3D8FE8),
  0xFF38BDF8: const Color(0xFF1E96E8),
  0xFF22D3EE: const Color(0xFF0FA8C8),
  0xFF67E8F9: const Color(0xFF28A8C4),
  0xFFA855F7: const Color(0xFF8B65E8),
  0xFF8B5CF6: const Color(0xFF8B65E8),
  0xFFC084FC: const Color(0xFFA679EE),
  0xFFEC4899: const Color(0xFFE84A92),
  0xFFF472B6: const Color(0xFFF05A9D),
  0xFFEF4444: const Color(0xFFD93A3A),
  0xFFF87171: const Color(0xFFE35C5C),
  0xFFFB923C: const Color(0xFFF07818),
};

/// ترجع اللون المقابل للوضع الحالي. يُستخدم في ملفات الواجهة بدلاً من
/// Color(0xFF...) الثابتة حتى تستجيب كل الشاشات للوضع النهائي تلقائياً.
Color L(int argb) {
  if (!UiTheme.instance.isLight) return Color(argb);
  return _dayMap[argb] ?? _autoLight(Color(argb));
}

/// لألوان غير موجودة في الخريطة: تحويل تلقائي
/// (الداكنة جداً -> أفتح قليلاً فوق الأبيض، الفاتحة جداً -> كحلي داكن).
Color _autoLight(Color c) {
  final r = (c.r * 255.0).round();
  final g = (c.g * 255.0).round();
  final b = (c.b * 255.0).round();
  final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  if (lum < 90) {
    // داكن -> يصبح سطحاً فاتحاً يحافظ على الصبغة
    final mix = 0.88;
    return Color.fromARGB(
        255,
        (r * (1 - mix) + 255 * mix).round(),
        (g * (1 - mix) + 255 * mix).round(),
        (b * (1 - mix) + 255 * mix).round());
  }
  if (lum > 200) {
    // فاتح جداً (نص أبيض مثلاً) -> كحلي داكن
    final mix = 0.82;
    const navy = 0x3A;
    return Color.fromARGB(
        255,
        (r * (1 - mix) + navy * mix).round(),
        (g * (1 - mix) + navy * mix).round(),
        (b * (1 - mix) + navy * mix).round());
  }
  return c;
}
