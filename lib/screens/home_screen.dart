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
import 'game_screen.dart';
import 'achievements_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'okey_lobby_screen.dart';


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
    _cardAnimations = List.generate(5, (i) {
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
    final Widget destination = gameId == 'okey' ? const OkeyLobbyScreen() : GameScreen(gameId: gameId);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.08);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: animation.drive(tween), child: child),
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
      backgroundColor: const Color(0xFF160926),
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
          height: 205,
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
                  onCoinTap: () => _showNotice('رصيدك الحالي: 1250 عملة ذهبية!'),
                  onGiftTap: () {
                    AppHaptics.medium();
                    setState(() => _currentNavIndex = 1);
                  },
                  onSettingsTap: () => _showNotice('الإعدادات قيد التطوير'),
                ),
              ),
            ),

            // Main Scrollable Content with smooth physics
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
                    const SizedBox(height: 14),

                    // ----------------------------------------------------
                    // GAME CARDS (2 + 2 + 1 Layout) Fully Responsive with Expanded
                    // ----------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          // Row 1: Chess & Solitaire
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimations[0],
                                  game: GamesData.games[0],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimations[1],
                                  game: GamesData.games[1],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Row 2: Ludo & Okey
                          Row(
                            children: [
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimations[2],
                                  game: GamesData.games[2],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildAnimatedCard(
                                  animation: _cardAnimations[3],
                                  game: GamesData.games[3],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Row 3: Backgammon (centered at 50% width)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = (constraints.maxWidth - 14) / 2;
                              return Center(
                                child: SizedBox(
                                  width: cardWidth,
                                  child: _buildAnimatedCard(
                                    animation: _cardAnimations[4],
                                    game: GamesData.games[4],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
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
                            offset: Offset(0, 15 * (1 - _bannerAnimation.value)),
                            child: child,
                          ),
                        );
                      },
                      child: RepaintBoundary(
                        child: MoreGamesBanner(
                          onTap: () => _showNotice('ألعاب جديدة قادمة قريباً! 🎮'),
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
