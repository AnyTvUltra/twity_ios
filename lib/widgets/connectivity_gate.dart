import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../utils/net_probe_stub.dart'
    if (dart.library.io) '../utils/net_probe_io.dart';

/// بوابة الإنترنت — تغلف التطبيق كله: بلا اتصال تظهر شاشة حظر صارمة
/// لا يمكن تجاوزها، وعند عودة الاتصال يعود التطبيق تلقائياً.
class ConnectivityGate extends StatefulWidget {
  final Widget child;
  const ConnectivityGate({super.key, required this.child});

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _probeTimer;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _check();
    try {
      _sub = Connectivity().onConnectivityChanged.listen((_) => _check());
    } catch (_) {
      // المنصّة لا تدعم الإضافة (اختبارات) — نفترض الاتصال
    }
    // فحص دوري حقيقي كل 10 ثوانٍ (الواجهة قد تكون متصلة بلا إنترنت فعلي)
    _probeTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.every((r) => r == ConnectivityResult.none)) {
        _setOnline(false);
        return;
      }
      // الواجهة متصلة — تحقق فعلي من الوصول للإنترنت (فحص DNS سريع)
      final reachable = await probeInternet();
      _setOnline(reachable);
    } catch (_) {
      // بيئة اختبار بلا قنوات — لا نمنع التطبيق
      _setOnline(true);
    }
  }

  void _setOnline(bool v) {
    if (v != _online && mounted) setState(() => _online = v);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _probeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_online) return widget.child;
    return const _OfflineScreen();
  }
}

class _OfflineScreen extends StatelessWidget {
  const _OfflineScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withOpacity(0.12),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.4),
                      width: 1.5),
                ),
                child: const Icon(Icons.wifi_off_rounded,
                    color: Color(0xFFEF4444), size: 56),
              ),
              const SizedBox(height: 24),
              Text('لا يوجد اتصال بالإنترنت'.tr,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                'هذه اللعبة تحتاج اتصالاً بالإنترنت.\nفعّل Wi-Fi أو بيانات الهاتف وسيستأنف التطبيق تلقائياً.'
                    .tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFB8C4DC), fontSize: 13.5, height: 1.7),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFFFFD54F)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
