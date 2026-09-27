/// قوانين الكونكان (الأوكي) المتاحة للاعب قبل دخول الطاولة
enum OkeyRulesVariant { sulaymaniyah, erbil, turkish }

class OkeyRules {
  final OkeyRulesVariant variant;
  final String name;
  final String subtitle;
  final String icon;

  /// الحد الأدنى من النقاط المطلوبة للافتتاح (النزول الأول)
  final int openingPoints;

  /// هل يُسمح بالفوز عبر الأزواج السبعة (Çift)؟
  final bool allowSevenPairs;

  const OkeyRules({
    required this.variant,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.openingPoints,
    required this.allowSevenPairs,
  });

  static const sulaymaniyah = OkeyRules(
    variant: OkeyRulesVariant.sulaymaniyah,
    name: 'قانون سليمانية',
    subtitle: 'افتتاح سريع 51 نقطة',
    icon: '🏔️',
    openingPoints: 51,
    allowSevenPairs: true,
  );

  static const erbil = OkeyRules(
    variant: OkeyRulesVariant.erbil,
    name: 'قانون أربيل',
    subtitle: 'احترافي — بدون أزواج',
    icon: '🏰',
    openingPoints: 101,
    allowSevenPairs: false,
  );

  static const turkish = OkeyRules(
    variant: OkeyRulesVariant.turkish,
    name: 'القانون التركي',
    subtitle: 'الكلاسيكي — 101 + أزواج',
    icon: '🀄',
    openingPoints: 101,
    allowSevenPairs: true,
  );

  static OkeyRules of(OkeyRulesVariant v) {
    switch (v) {
      case OkeyRulesVariant.sulaymaniyah:
        return sulaymaniyah;
      case OkeyRulesVariant.erbil:
        return erbil;
      case OkeyRulesVariant.turkish:
        return turkish;
    }
  }

  static OkeyRules fromId(String? id) {
    switch (id) {
      case 'sulaymaniyah':
        return sulaymaniyah;
      case 'erbil':
        return erbil;
      default:
        return turkish;
    }
  }

  String get id => variant.name;

  /// الشرح الكامل للقانون — يظهر في نافذة "؟"
  String get fullDescription {
    switch (variant) {
      case OkeyRulesVariant.sulaymaniyah:
        return '''
قانون سليمانية — النسخة السريعة من الكونكان:

• الافتتاح (النزول الأول): يكفي تجميع 51 نقطة فقط من مجموعاتك لبدء النزول على الطاولة — أسرع بكثير من القانون التركي.

• المجموعات الصالحة: تسلسل (Per) من نفس اللون مثل 3-4-5، أو مجموعة (Küt) بنفس الرقم بألوان مختلفة، بحد أدنى 3 أحجار.

• حجر الأوكي (الجوكر): يحل محل أي حجر ناقص في المجموعة، وحجره الملوّن يُحدد بحجر المؤشر الظاهر على الطاولة.

• الأزواج السبعة: مسموحة — إذا جمعت 7 أزواج متطابقة تفوز فوراً.

• الرمي بأوكي: رمي حجر الأوكي الحقيقي يعاقب اللاعب في معظم الأعراف — انتبه.

• الفوز: أنهِ يدك بإكمال 14 حجراً في مجموعات صالحة ثم ارمِ الحجر الأخير. الفوز برمي الأوكي يمنح نقاطاً مضاعفة.

الأنسب لمن يريد جولات سريعة بدون انتظار طويل لتجميع 101.''';
      case OkeyRulesVariant.erbil:
        return '''
قانون أربيل — النسخة الاحترافية الصارمة:

• الافتتاح (النزول الأول): يتطلب 101 نقطة كاملة من مجموعاتك في نفس الدور — إن أنزلت أقل من ذلك ورميت، تُعاد أحجارك إلى رفّك.

• الفوز بالأزواج غير مسموح: لا يمكنك الفوز بـ7 أزواج متشابهة — يجب إكمال اليد بمجموعات (Per/Küt) فقط. هذا يجعل اللعبة أطول وأكثر تكتيكاً.

• المجموعات الصالحة: تسلسل من نفس اللون (3+ أحجار) أو نفس الرقم بألوان مختلفة (3-4 أحجار).

• حجر الأوكي: يعمل كجوكر في أي مجموعة، والجوكر المقلوب (Sahte Okey) يحل محل رقم الأوكي فقط.

• الفتح المزدوج: بعد افتتاحك يمكنك الإضافة على مجموعات الآخرين الموضوعة على الطاولة.

الأنسب للاعبين المحترفين الذين يفضلون التحدي الطويل ولا يعتمدون على حظ الأزواج.''';
      case OkeyRulesVariant.turkish:
        return '''
القانون التركي — القواعد الكلاسيكية المعتمدة:

• الافتتاح (النزول الأول): يتطلب 101 نقطة كاملة من مجموعاتك في نفس الدور — إن رميت قبل اكتمالها تُعاد الأحجار المنزولة إلى رفّك.

• الأزواج السبعة (Çift): مسموحة — جمع 7 أزواج متطابقة يكفي للفوز بالجولة.

• المجموعات الصالحة: تسلسل من نفس اللون بأرقام متتالية (3 أحجار فأكثر، ويمكن إكمال 13→1)، أو نفس الرقم بألوان مختلفة (3-4 أحجار).

• حجر الأوكي: يُحدد بالحجر المؤشر (الرقم التالي له بنفس اللون) ويعمل كجوكر لأي حجر. الحجر المقلوب يحل محل قيمة الأوكي فقط.

• الفوز: أكمل 14 حجراً في مجموعات صالحة أو 7 أزواج ثم ارمِ حجراً. الفوز برمي حجر الأوكي يُحتسب مضاعفاً.

هذا هو القانون المعتمد في البطولات التركية الرسمية للعبة Okey.''';
    }
  }
}
