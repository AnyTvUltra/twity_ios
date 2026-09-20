import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/game_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/okey_lobby_screen.dart';
import 'services/firebase_service.dart';
import 'services/auth_service.dart';
import 'services/radio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService().initialize();
  AuthService().initialize();
  RadioService().init();
  runApp(const GameHubApp());
}

class GameHubApp extends StatelessWidget {
  const GameHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مجموعة الألعاب الممتعة',
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
