import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ku_strings.dart';

/// لغات التطبيق المدعومة
enum AppLanguage {
  ar('ar', 'العربية', TextDirection.rtl),
  ku('ku', 'کوردی سورانی', TextDirection.rtl),
  en('en', 'English', TextDirection.ltr);

  final String code;
  final String nativeName;
  final TextDirection direction;
  const AppLanguage(this.code, this.nativeName, this.direction);

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.ar);
}

/// متحكّم اللغة — يُحمَّل مرة واحدة عند بدء التطبيق ويُحفظ الاختيار محلياً
class AppLangController extends ChangeNotifier {
  AppLangController._();
  static final AppLangController instance = AppLangController._();

  static const _prefsKey = 'app_language';
  AppLanguage _lang = AppLanguage.ar;
  bool _loaded = false;

  AppLanguage get lang => _lang;
  String get code => _lang.code;
  TextDirection get direction => _lang.direction;
  bool get isKurdish => _lang == AppLanguage.ku;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _lang = AppLanguage.fromCode(prefs.getString(_prefsKey));
    } catch (_) {}
  }

  Future<void> setLang(AppLanguage lang) async {
    if (_lang == lang) return;
    _lang = lang;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, lang.code);
    } catch (_) {}
  }
}

/// الترجمة الفعلية: المفتاح هو النص العربي الأصلي، والقيمة ترجمته.
/// إن لم تُوجد ترجمة تُرجع النص العربي كما هو (لا يحدث أي كسر).
class L10n {
  static String t(String source) {
    final lang = AppLangController.instance._lang;
    switch (lang) {
      case AppLanguage.ku:
        return kuStrings[source] ?? source;
      case AppLanguage.ar:
      case AppLanguage.en:
        return source;
    }
  }

  /// نص مع وسائط: القالب يستخدم {} بالترتيب — مثال 'رصيدك: {}'
  static String fmt(String template, List<Object?> args) {
    var out = t(template);
    for (final a in args) {
      out = out.replaceFirst('{}', '$a');
    }
    return out;
  }
}

/// امتداد مريح: 'نص'.tr — يعمل على أي String داخل الواجهة
extension TrString on String {
  String get tr => L10n.t(this);

  /// 'قالب {} و {}' .trp([a, b])
  String trp(List<Object?> args) => L10n.fmt(this, args);
}
