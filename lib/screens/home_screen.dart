import 'package:flutter/material.dart';
import '../models.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/app_background.dart';
import '../widgets/app_header.dart';
import '../widgets/title_banner.dart';
import '../widgets/game_card.dart';
import '../widgets/more_games_banner.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/announcement_banner.dart';
import 'game_screen.dart';
import 'achievements_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'okey_rules_screen.dart';
import 'store_screen.dart';
import '../l10n/app_lang.dart';
import '../theme_mode.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentNavIndex = 0;

  // Stagger animation controller for entrance effects
  late AnimationController _staggerController;
  late Animation<double> _headerAnimation;
  late Animation<double> _titleAnimation;
  late List<Animation<double>> _cardAnimations;
  late Animation<double> _bannerAnimation;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Header slides in first (0.0 → 0.25)
    _headerAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
    );

    // Title banner fades in (0.08 → 0.38)
    _titleAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.08, 0.38, curve: Curves.easeOutCubic),
    );

    // 5 game cards stagger one by one (0.15 → 0.85)
    _cardAnimations = List.generate(GamesData.games.length, (i) {
      final start = 0.15 + (i * 0.10);
      final end = (start + 0.22).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerController,
        curve: Interval(start, end, curve: Curves.easeOutBack),
      );
    });

    // Banner at the end (0.65 → 1.0)
    _bannerAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOutCubic),
    );

    // Start the stagger animation
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  void _navigateToGame(String gameId) {
    AppHaptics.medium();
    // ألعاب قيد التطوير — تظهر بطاقتها للتشويق وتُفعَّل لاحقاً
    if (gameId == 'snake' || gameId == 'domino') {
      _showNotice('هذه اللعبة قيد التطوير — قريباً! 🚧'.tr,
          icon: Icons.construction_rounded);
      return;
    }
    final Widget destination =
        gameId == 'okey' ? const OkeyRulesScreen() : GameScreen(gameId: gameId);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.08);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return FadeTransition(
            opacity: animation,
            child:
                SlideTransition(position: animation.drive(tween), child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  void _showNotice(String message, {IconData? icon}) {
    TopNotification.show(context, message, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: L(0xFF160926),
      body: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Tab Screens with IndexedStack for 60fps instant switching & state preservation
            IndexedStack(
              index: _currentNavIndex,
              children: [
                // Tab 0: Home / Games Hub
                _buildGamesTab(),
                // Tab 1: Achievements & Rewards
                const AchievementsScreen(),
                // Tab 2: Chat & Rooms
                const ChatScreen(),
                // Tab 3: Profile & Stats
                const ProfileScreen(),
              ],
            ),

            // Floating Bottom Navigation Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: BottomNavBar(
                  currentIndex: _currentNavIndex,
                  onIndexChanged: (index) {
                    AppHaptics.selection();
                    setState(() => _currentNavIndex = index);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an animated game card with slide-up + fade-in entrance
  Widget _buildAnimatedCard({
    required Animation<double> animation,
    required GameModel game,
    double? cardWidth,
    double? cardHeight,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.isCompleted) return child!;
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: RepaintBoundary(
        child: GameCard(
          game: game,
          width: cardWidth,
          height: cardHeight ?? 220,
          onTap: () => _navigateToGame(game.id),
        ),
      ),
    );
  }

  Widget _buildGamesTab() {
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header with slide-down entrance
            AnimatedBuilder(
              animation: _headerAnimation,
              builder: (context, child) {
                if (_headerAnimation.isCompleted) return child!;
                return Transform.translate(
                  offset: Offset(0, -20 * (1 - _headerAnimation.value)),
                  child: Opacity(
                    opacity: _headerAnimation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: RepaintBoundary(
                child: AppHeader(
                  onProfileTap: () {
                    AppHaptics.selection();
                    setState(() => _currentNavIndex = 3);
                  },
                  onCoinTap: () =>
                      _showNotice('رصيدك الحالي: 1250 عملة ذهبية!'.tr),
                  onStoreTap: () {
                    AppHaptics.selection();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StoreScreen()),
                    );
                  },
                ),
              ),
            ),

            // Main Scrollable Content with smooth physics
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                padding: const EdgeInsets.only(bottom: 95),
                child: Column(
                  children: [
                    // Title Banner with fade-in + scale entrance
                    AnimatedBuilder(
                      animation: _titleAnimation,
                      builder: (context, child) {
                        if (_titleAnimation.isCompleted) return child!;
                        return Transform.scale(
                          scale: 0.85 + (0.15 * _titleAnimation.value),
                          child: Opacity(
                            opacity: _titleAnimation.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        );
                      },
                      child: const RepaintBoundary(
                        child: TitleBanner(),
                      ),
                    ),

                    // إعلان الإدارة المباشر — يظهر فقط إذا نُشر من لوحة الأدمن
                    const AnnouncementBanner(),

                    const SizedBox(height: 14),

                    // ----------------------------------------------------
                    // GAME CARDS (2 + 2 + 1 Layout) Fully Responsive with Expanded
                    // ----------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final gap =
                                  constraints.maxWidth < 380 ? 10.0 : 16.0;
                              final cardWidth =
                                  (constraints.maxWidth - gap) / 2;
                              final cardHeight =
                                  (cardWidth * 1.24).clamp(194.0, 260.0);
                              Widget card(int index) => SizedBox(
                                    width: cardWidth,
                                    child: _buildAnimatedCard(
                                      animation: _cardAnimations[index],
                                      game: GamesData.games[index],
                                      cardWidth: cardWidth,
                                      cardHeight: cardHeight,
                                    ),
                                  );
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      card(0),
                                      SizedBox(width: gap),
                                      card(1),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      card(2),
                                      SizedBox(width: gap),
                                      card(3),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      card(4),
                                      SizedBox(width: gap),
                                      card(5),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  Center(child: card(6)),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bottom More Games Banner with fade-in entrance
                    AnimatedBuilder(
                      animation: _bannerAnimation,
                      builder: (context, child) {
                        if (_bannerAnimation.isCompleted) return child!;
                        return Opacity(
                          opacity: _bannerAnimation.value.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset:
                                Offset(0, 15 * (1 - _bannerAnimation.value)),
                            child: child,
                          ),
                        );
                      },
                      child: RepaintBoundary(
                        child: MoreGamesBanner(
                          onTap: () =>
                              _showNotice('ألعاب جديدة قادمة قريباً! 🎮'.tr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom AnimatedBuilder that extends AnimatedWidget
/// (kept for compatibility with existing game_card.dart usage)
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
