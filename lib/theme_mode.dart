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
