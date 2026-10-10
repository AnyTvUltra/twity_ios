import 'dart:io';

/// تشخيص الكراشات الميدانية — خصوصاً على iOS حيث الأخطاء
/// الـnative أو موت الـisolate لا تولّد تقريراً يصلنا.
///
/// فكرتان:
/// 1) «أثر الخطوات»: نقطة ممرّ متزامنة تُكتب على القرص — تنجو من
///    موت العملية فنعرف آخر خطوة قبل الكراش الـnative.
/// 2) «تقرير الخطأ»: حارس الـzone يكتب أي استثناء غير معالج
///    في ملف يُعرض للمستخدم عند إعادة الفتح.
///
/// يعتمد dart:io فقط (Directory.systemTemp) — بلا إضافات ولا
/// قنوات منصة، فيعمل حتى لو ماتت قنوات Flutter مبكراً.
class CrashDiag {
  static String? _dir;

  /// تقرير مُجمّع من الجلسة الميتة — يُقرأ مرة واحدة عند الإقلاع
  static String? pendingReport;

  /// يُستدعى أولاً في main() — يجهّز المسار ويلتقط مخلّفات الجلسة السابقة
  static void init() {
    try {
      _dir = Directory.systemTemp.path;
      final buf = StringBuffer();
      final crash = File('$_dir/yy_crash.txt');
      if (crash.existsSync()) {
        final body = crash.readAsStringSync().trim();
        if (body.isNotEmpty) {
          buf.writeln('⚠️ آخر خطأ مسجّل قبل الإغلاق:\n$body');
        }
        crash.deleteSync();
      }
      final steps = File('$_dir/yy_steps.txt');
      if (steps.existsSync()) {
        final lines = steps
            .readAsStringSync()
            .trim()
            .split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
        if (lines.isNotEmpty) {
          final tail =
              lines.length > 40 ? lines.sublist(lines.length - 40) : lines;
          buf.writeln(
              '📍 أثر الخطوات قبل الإغلاق (${lines.length} خطوة):\n${tail.join('\n')}');
        }
        steps.deleteSync();
      }
      pendingReport = buf.isEmpty ? null : buf.toString();
    } catch (_) {
      pendingReport = null;
    }
  }

  /// امسح أثر الخطوات — يُستدعى عند خروج نظيف للخلفية حتى لا
  /// يظهر تقرير كراش زائف بعد قتلٍ يدوي من مبدّل التطبيقات
  static void clearSteps() {
    final d = _dir;
    if (d == null) return;
    try {
      final f = File('$d/yy_steps.txt');
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// نقطة ممرّ — متزامنة عمداً حتى تكتمل حتى لو ماتت العملية فوراً
  static void step(String s) {
    final d = _dir;
    if (d == null) return;
    try {
      File('$d/yy_steps.txt').writeAsStringSync(
          '${DateTime.now().toIso8601String()}  $s\n',
          mode: FileMode.append);
    } catch (_) {}
  }

  /// خطأ غير معالج — يُستدعى من حارس الـzone ومعالجات الأخطاء
  /// العليا. متزامن ليكتمل قبل أي إنهاء محتمل
  static void crash(Object e, StackTrace? st) {
    final d = _dir;
    if (d == null) return;
    try {
      File('$d/yy_crash.txt').writeAsStringSync(
          '═══ ${DateTime.now().toIso8601String()} ═══\n$e\n$st\n',
          mode: FileMode.append);
    } catch (_) {}
  }
}
