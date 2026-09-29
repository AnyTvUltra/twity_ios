import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_update_service.dart';
import '../utils/haptics.dart';
import '../l10n/app_lang.dart';
import '../theme_mode.dart';

/// حوار التحديث — إجباري (لا يُغلق) أو اختياري حسب إعداد Firestore
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;
  const UpdateDialog({super.key, required this.info});

  static Future<void> showIfNeeded(BuildContext context) async {
    AppUpdateInfo? info;
    try {
      info = await AppUpdateService.instance.check();
    } catch (_) {
      return; // لا تحديث إن تعذّر الوصول (إنترنت/Firebase غير متاح)
    }
    if (info == null || !context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: UpdateDialog(info: info!),
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    AppHaptics.medium();
    setState(() => _downloading = true);
    _c.forward(from: 0);
    await _c.forward().orCancel.catchError((_) {});
    final url = widget.info.url.isNotEmpty
        ? widget.info.url
        : 'https://twity-game-hub.pages.dev';
    final uri = Uri.tryParse(url);
    // أمان: لا نفتح إلا روابط HTTPS — الرابط يأتي من Firestore
    if (uri != null && uri.scheme == 'https' && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (mounted && !widget.info.required) {
      await AppUpdateService.instance.markSkipped(widget.info.latestBuild);
    }
    if (mounted) setState(() => _downloading = false);
  }

  Future<void> _later() async {
    await AppUpdateService.instance.markSkipped(widget.info.latestBuild);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    L(0xFF1B2A5E).withOpacity(0.95),
                    L(0xFF0A0F24).withOpacity(0.97),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: L(0xFFFFD54F).withOpacity(0.55), width: 1.4),
                boxShadow: [
                  BoxShadow(
                      color: L(0xFFFFD54F).withOpacity(0.18), blurRadius: 34),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [
                        L(0xFFFFF3C4),
                        L(0xFFFFD54F),
                        L(0xFFB8860B),
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: L(0xFFFFD54F).withOpacity(0.45),
                            blurRadius: 16),
                      ],
                    ),
                    child: Center(
                      child: Text('⬇️', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    widget.info.title.isNotEmpty
                        ? widget.info.title
                        : (widget.info.required
                            ? 'تحديث إجباري!'.tr
                            : 'تحديث جديد متاح!'.tr),
                    style: TextStyle(
                      color: L(0xFFF1F5FF),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.info.notes.isNotEmpty
                        ? widget.info.notes
                        : 'إصدار جديد من یەڵا یاری بميزات وتحسينات جديدة'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: L(0xFF8EA3C8),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 20),
                  // شريط التحميل
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) => FractionallySizedBox(
                          alignment: Alignment.centerRight,
                          widthFactor: _downloading ? _c.value : 0.0,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                L(0xFF7DD3FC),
                                L(0xFF38BDF8),
                                L(0xFFFFD54F),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _downloading ? null : _update,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: L(0xFFFFD54F),
                        foregroundColor: L(0xFF1B0B30),
                        padding: EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _downloading ? 'جارٍ التحديث...'.tr : 'حدّث الآن 🚀'.tr,
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                  if (!widget.info.required) ...[
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: _downloading ? null : _later,
                      child: Text('لاحقاً'.tr,
                          style: TextStyle(color: L(0xFF8EA3C8))),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
