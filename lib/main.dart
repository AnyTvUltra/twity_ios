import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/okey_lobby_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/radio_service.dart';
import 'services/store_service.dart';
import 'services/broadcast_service.dart';
import 'services/game_settings_service.dart';
import 'widgets/connectivity_gate.dart';
import 'widgets/maintenance_gate.dart';
import 'widgets/update_dialog.dart';
import 'utils/top_notification.dart';
import 'l10n/app_lang.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLangController.instance.load();
  await FirebaseService().initialize();
  AuthService().initialize();
  StoreService().initialize();
  RadioService().init();
  RadioService().initialize();
  GameSettingsService().initialize();

  // إشعارات الإدارة — شريط متحرك من الأعلى، وتبقى قابلة للعرض من جرس الإشعارات
  BroadcastService.instance.initialize((title, body) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    TopNotification.show(
      ctx,
      '$title\n$body',
      icon: Icons.notifications_active_rounded,
    );
  });

  runApp(const GameHubApp());
}

class GameHubApp extends StatefulWidget {
  const GameHubApp({super.key});

  @override
  State<GameHubApp> createState() => _GameHubAppState();
}

class _GameHubAppState extends State<GameHubApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLangController.instance.addListener(_onLangChanged);
    // فحص التحديث بعد أول إطار — لا يظهر أي حوار إن كان التطبيق محدثاً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null) UpdateDialog.showIfNeeded(ctx);
    });
  }

  /// حضور online/offline مرتبط بدورة حياة التطبيق
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final online = state == AppLifecycleState.resumed;
    try {
      AuthService().setOnlinePresence(online);
    } catch (_) {}
  }

  void _onLangChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLangController.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Yalla Yari - یەڵا یاری'.tr,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
      ),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF160926),
        fontFamily: 'AppArabicFont',
        fontFamilyFallback: const [
          'AppArabicFont',
          '-apple-system',
          'BlinkMacSystemFont',
          'Geeza Pro',
          'Damascus',
          'Arial Hebrew',
          'Cairo',
          'Segoe UI',
          'Tahoma',
          'sans-serif',
        ],
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD54F),
          secondary: Color(0xFFD946EF),
          surface: Color(0xFF25143E),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: AppLangController.instance.direction,
          // بوابة الإنترنت تغلف كل الشاشات — بلا اتصال تظهر شاشة حظر
          child: ConnectivityGate(child: child ?? const SizedBox()),
        );
      },
      home: _AuthGate(),
      routes: {
        '/home': (context) => HomeScreen(),
        '/games/chess': (context) => GameScreen(gameId: 'chess'),
        '/games/solitaire': (context) => GameScreen(gameId: 'solitaire'),
        '/games/okey': (context) => OkeyLobbyScreen(),
        '/games/backgammon': (context) =>
            const GameScreen(gameId: 'backgammon'),
        '/admin': (context) => const AdminPanelScreen(),
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _authAvailable = true;

  AuthService? get _authOrNull {
    try {
      return AuthService();
    } catch (_) {
      return null; // Firebase غير متاح (اختبارات أو فشل التهيئة)
    }
  }

  @override
  void initState() {
    super.initState();
    final auth = _authOrNull;
    if (auth == null) {
      _authAvailable = false;
      return;
    }
    auth.addListener(_onAuthChange);
  }

  void _onAuthChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _authOrNull?.removeListener(_onAuthChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_authAvailable && (_authOrNull?.isAuthenticated ?? false)) {
      // وضع الصيانة يُطبَّق بعد الدخول — شاشة الدخول تبقى متاحة للمدير
      return const MaintenanceGate(child: HomeScreen());
    }
    return AuthScreen(onAuthenticated: () {});
  }
}
