import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة التحديث الداخلي — تقرأ إعدادات الإصدار من Firestore:
///   config/app_update → {
///     minBuild:   رقم أدنى إصدار مسموح (أقل منه = تحديث إجباري)
///     latestBuild: أحدث إصدار متاح (أقل منه = تنبيه تحديث قابل للتخطي)
///     url:        رابط التحميل/التحديث
///     notes:      ملاحظات الإصدار (تظهر للمستخدم)
///     title:      عنوان الحوار (اختياري)
///   }
/// لا يظهر الحوار إطلاقاً إن كان التطبيق محدثاً بالفعل.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  /// رقم البناء الحالي للتطبيق — يُرفع يدوياً مع كل إصدار جديد
  static const int currentBuild = 3;

  final _firestore = FirebaseFirestore.instance;
  static const _skipKey = 'skipped_update_build';

  /// يعيد معلومات التحديث إن وُجدت، وإلا null
  /// - required: تحديث إجباري (لا يمكن إغلاق الحوار)
  /// - required=false: تحديث اختياري (يظهر مرة واحدة لكل إصدار)
  Future<AppUpdateInfo?> check() async {
    try {
      final doc = await _firestore.collection('config').doc('app_update').get();
      if (!doc.exists) return null;
      final d = doc.data()!;
      final minBuild = (d['minBuild'] as num?)?.toInt() ?? 0;
      final latestBuild = (d['latestBuild'] as num?)?.toInt() ?? 0;
      final url = (d['url'] ?? '').toString();
      final notes = (d['notes'] ?? '').toString();
      final title = (d['title'] ?? '').toString();

      if (latestBuild <= currentBuild) return null;

      final force = currentBuild < minBuild;
      if (!force) {
        // تنبيه اختياري: يظهر مرة واحدة فقط لكل إصدار
        final prefs = await SharedPreferences.getInstance();
        final skipped = prefs.getInt(_skipKey) ?? 0;
        if (skipped >= latestBuild) return null;
      }
      return AppUpdateInfo(
        latestBuild: latestBuild,
        url: url,
        notes: notes,
        title: title,
        required: force,
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
      return null;
    }
  }

  /// تذكّر أن المستخدم تخطّى هذا الإصدار — لا يُسأل مجدداً عنه
  Future<void> markSkipped(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_skipKey, build);
    } catch (_) {}
  }
}

class AppUpdateInfo {
  final int latestBuild;
  final String url;
  final String notes;
  final String title;
  final bool required;
  const AppUpdateInfo({
    required this.latestBuild,
    required this.url,
    required this.notes,
    required this.title,
    required this.required,
  });
}
