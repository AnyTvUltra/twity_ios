import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/game_settings_service.dart';
import '../theme_mode.dart';

/// بوابة وضع الصيانة — إذا فعّلها الأدمن من لوحة التحكم تُغلق اللعبة
/// لجميع اللاعبين (ما عدا المدير نفسه) وتظهر رسالة صيانة لحظياً.
class MaintenanceGate extends StatefulWidget {
  final Widget child;
  final bool isAdmin;
  const MaintenanceGate({super.key, required this.child, this.isAdmin = false});

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  bool _isAdmin = false;
  bool _checkedAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    if (widget.isAdmin) {
      if (mounted)
        setState(() {
          _isAdmin = true;
          _checkedAdmin = true;
        });
      return;
    }
    try {
      final uid = AuthService().currentUser?.uid;
      final fb = FirebaseService();
      if (uid == null || !fb.isInitialized) {
        if (mounted) setState(() => _checkedAdmin = true);
        return;
      }
      final doc = await fb.firestore.collection('admins').doc(uid).get();
      if (mounted) {
        setState(() {
          _isAdmin = doc.exists;
          _checkedAdmin = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _checkedAdmin = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GameSettingsService(),
      builder: (context, _) {
        final maintenance =
            GameSettingsService().maintenanceMode && !_isAdmin && _checkedAdmin;
        if (maintenance) return const _MaintenanceScreen();
        return widget.child;
      },
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    final gs = GameSettingsService();
    return Scaffold(
      backgroundColor: L(0xFF0A0E1F),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: L(0xFFFFA726).withOpacity(0.12),
                  border: Border.all(
                      color: L(0xFFFFA726).withOpacity(0.4), width: 1.5),
                ),
                child: Icon(Icons.build_circle_rounded,
                    color: L(0xFFFFA726), size: 56),
              ),
              SizedBox(height: 24),
              Text('صيانة مؤقتة 🛠️'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              Text(
                gs.announcement.isNotEmpty
                    ? gs.announcement
                    : 'نجري تحديثات لتحسين تجربتك — عد بعد قليل!'.tr,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: L(0xFFB8C4DC), fontSize: 14, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
