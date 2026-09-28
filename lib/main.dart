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
import 'widgets/update_dialog.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService().initialize();
  AuthService().initialize();
  StoreService().initialize();
  RadioService().init();
  RadioService().initialize();

  // إشعارات الإدارة — تظهر كحوار منبثق عند وصول رسالة جديدة
  BroadcastService.instance.initialize((title, body) {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF141C34),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                  color: const Color(0xFFFFD54F).withOpacity(0.5))),
          title: Text(title,
              style: const TextStyle(
                  color: Color(0xFFF1F5FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          content: Text(body,
              style: const TextStyle(
                  color: Color(0xFFB8C4DC), fontSize: 13, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('حسناً',
                  style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  });

  runApp(const GameHubApp());
}

class GameHubApp extends StatefulWidget {
  const GameHubApp({super.key});

  @override
  State<GameHubApp> createState() => _GameHubAppState();
}

class _GameHubAppState extends State<GameHubApp> {
  @override
  void initState() {
    super.initState();
    // فحص التحديث بعد أول إطار — لا يظهر أي حوار إن كان التطبيق محدثاً
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey.currentContext;
      if (ctx != null) UpdateDialog.showIfNeeded(ctx);
    });
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Yalla Yari - یەڵا یاری',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      home: const _AuthGate(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/games/chess': (context) => const GameScreen(gameId: 'chess'),
        '/games/solitaire': (context) => const GameScreen(gameId: 'solitaire'),
        '/games/ludo': (context) => const GameScreen(gameId: 'ludo'),
        '/games/okey': (context) => const OkeyLobbyScreen(),
        '/games/backgammon': (context) => const GameScreen(gameId: 'backgammon'),
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
  @override
  void initState() {
    super.initState();
    AuthService().addListener(_onAuthChange);
  }

  void _onAuthChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AuthService().removeListener(_onAuthChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().isAuthenticated) {
      return const HomeScreen();
    }
    return AuthScreen(onAuthenticated: () {});
  }
}
