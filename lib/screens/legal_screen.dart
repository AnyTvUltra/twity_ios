import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../theme_mode.dart';

/// صفحة قانونية داخل التطبيق — سياسة الخصوصية وشروط الاستخدام
/// بنفس محتوى الصفحات المنشورة (privacy.html / terms.html)
class LegalScreen extends StatefulWidget {
  /// 0 = سياسة الخصوصية، 1 = شروط الاستخدام
  final int initialTab;
  const LegalScreen({super.key, this.initialTab = 0});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: L(0xFF0A0E1F),
      body: SafeArea(
        child: Column(
          children: [
            // شريط علوي مع زر رجوع
            Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 4),
                  Text(
                    _tab == 0 ? 'سياسة الخصوصية'.tr : 'شروط الاستخدام'.tr,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            // تبويبات
            Padding(
              padding: EdgeInsets.all(12),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: L(0xFF141C34),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    _tabBtn(0, Icons.privacy_tip_rounded, 'سياسة الخصوصية'.tr),
                    _tabBtn(1, Icons.description_rounded, 'شروط الاستخدام'.tr),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                child: _tab == 0 ? _privacy() : _terms(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(int i, IconData icon, String label) {
    final active = _tab == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: [L(0xFF7C3AED), L(0xFF4F46E5)])
                : null,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16, color: active ? Colors.white : L(0xFF94A3B8)),
              SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : L(0xFF94A3B8),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _h(String t) => Padding(
        padding: EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t.tr,
            style: TextStyle(
                color: L(0xFFC4B5FD),
                fontSize: 15,
                fontWeight: FontWeight.w900)),
      );

  Widget _p(String t) => Padding(
        padding: EdgeInsets.only(bottom: 6),
        child: Text(t.tr,
            style: TextStyle(color: L(0xFFC9D4EC), fontSize: 13, height: 1.75)),
      );

  Widget _bullet(String t) => Padding(
        padding: EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• ', style: TextStyle(color: L(0xFF7DD3FC), fontSize: 14)),
            Expanded(
              child: Text(t.tr,
                  style: TextStyle(
                      color: L(0xFFC9D4EC), fontSize: 13, height: 1.6)),
            ),
          ],
        ),
      );

  Widget _privacy() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h('1. البيانات التي نجمعها'),
          _bullet('اسم المستخدم والصورة الرمزية التي تختارها.'),
          _bullet('البريد الإلكتروني عند تسجيل الدخول بحساب Google.'),
          _bullet('تقدّمك في اللعبة: رصيدك، مستواك، سكناتك، إنجازاتك.'),
          _bullet('سجل المباريات والإحصائيات.'),
          _h('2. كيف نستخدم البيانات'),
          _bullet('تشغيل اللعبة وحفظ تقدّمك ورصيدك.'),
          _bullet('عرض لوحات الصدارة والأصدقاء والدردشة.'),
          _bullet('الرد على الدعم ومعالجة البلاغات وحماية المجتمع من الإساءة.'),
          _p('لا نبيع بياناتك، ولا نستخدمها للإعلانات، ولا نتتبّعك عبر تطبيقات أو مواقع أخرى.'),
          _h('3. أين تُخزّن البيانات'),
          _p('تُخزّن البيانات على خدمات Google Firebase (المصادقة وقاعدة بيانات Firestore)، كما تُحفظ نسخة من بيانات ملفك على جهازك لتسريع فتح التطبيق.'),
          _h('4. مشاركة البيانات'),
          _p('يظهر للاعبين الآخرين فقط: اسمك المعروض واسم المستخدم وصورتك ومستواك ونتائجك العامة. لا نشارك بريدك الإلكتروني مع أي لاعب.'),
          _h('5. حذف الحساب والبيانات'),
          _p('يمكنك حذف حسابك وكل بياناتك في أي وقت من داخل التطبيق: الملف الشخصي ← زر حذف الحساب. يُحذف حسابك وجميع بياناتك نهائياً.'),
          _h('6. الأطفال'),
          _p('اللعبة غير موجّهة للأطفال دون 13 عاماً ولا نجمع بياناتهم عن قصد. العملات داخل اللعبة افتراضية ولا قيمة نقدية لها ولا يمكن صرفها.'),
          _h('7. التواصل'),
          _p('لأي سؤال حول خصوصيتك استخدم نموذج «الدعم» داخل التطبيق من الملف الشخصي.'),
        ],
      );

  Widget _terms() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _h('1. طبيعة اللعبة'),
          _p('يەڵا یاری منصة ألعاب ترفيهية تقدّم ألعاب ورق وطاولة كلاسيكية. جميع العملات والجواهر والمكافآت افتراضية تماماً ولا تُمثّل مالاً حقيقياً.'),
          _h('2. الحساب والاستخدام'),
          _bullet('أنت مسؤول عن حسابك ونشاطه.'),
          _bullet('يُمنع استخدام أسماء مسيئة أو انتحال هوية الآخرين.'),
          _bullet(
              'يُمنع الغش أو استغلال الأخطاء البرمجية أو التلاعب بالنتائج.'),
          _h('3. العملات الافتراضية والشراء'),
          _bullet(
              'العملات والجواهر والسكنات افتراضية وليست قابلة للاسترداد نقداً.'),
          _bullet('المشتريات والهدايا داخل اللعبة نهائية ولا تُسترجع.'),
          _bullet('قد نعدّل أسعار المحتوى الافتراضي أو محتواه في أي وقت.'),
          _h('4. المحتوى والسلوك'),
          _bullet('يُمنع نشر محتوى مسيء أو غير قانوني في الدردشة والأسماء.'),
          _bullet('يحق للإدارة حظر أو حذف الحسابات المخالفة دون إشعار.'),
          _h('5. حدود المسؤولية'),
          _p('تُقدَّم اللعبة «كما هي». لا نضمن عملها دون انقطاع، ولسنا مسؤولين عن فقدان ناتج عن مشاكل تقنية خارجة عن سيطرتنا.'),
          _h('6. التعديلات'),
          _p('قد نحدّث هذه الشروط من وقت لآخر، واستمرارك في استخدام اللعبة يعني موافقتك على النسخة الأحدث.'),
        ],
      );
}
