import 'package:flutter/material.dart';
import '../theme.dart';
import '../models.dart';
import '../utils/top_notification.dart';
import '../widgets/game_artwork.dart';
import '../widgets/app_background.dart';
import 'okey_game_screen.dart';

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _selectedMode = 0;
  int _selectedBet = 500;

  final List<String> _modes = ['أونلاين', 'مع صديق', 'ضد الذكاء الاصطناعي'];
  final List<int> _bets = [100, 250, 500, 1000, 2500];

  @override
  Widget build(BuildContext context) {
    final game = GamesData.getGame(widget.gameId);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xE625143E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0x40FFD54F),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    // Game Title in Top Bar
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),

                    // Coin display
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xE625143E),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: const Color(0x40FFD54F),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '💰',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(width: 4),
                          Text(
                            '1250',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),

                      // Large 3D Artwork Hero Card
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          gradient: game.gradient,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: game.borderColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: game.glowColor.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: GameArtwork(gameId: game.id),
                              ),
                            ),
                            if (game.hasCrown)
                              const Positioned(
                                top: 10,
                                right: 14,
                                child: Text('👑', style: TextStyle(fontSize: 26)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Game Title & Tagline
                      Text(
                        game.title,
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: AppColors.goldDark,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        game.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mode Selection
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'اختر نمط اللعب:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(_modes.length, (index) {
                          final isSel = _selectedMode == index;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: index == 0 ? 0 : 4,
                                right: index == _modes.length - 1 ? 0 : 4,
                              ),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedMode = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel ? const Color(0xFF6D28D9) : const Color(0xE625143E),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFFA78BFA) : const Color(0x33A78BFA),
                                      width: isSel ? 1.8 : 1,
                                    ),
                                    boxShadow: isSel
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF6D28D9).withOpacity(0.5),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _modes[index],
                                      style: TextStyle(
                                        color: isSel ? Colors.white : AppColors.textMuted,
                                        fontSize: 12.5,
                                        fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Bet Selection
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'قيمة الرهان (عملات):',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _bets.map((bet) {
                            final isSel = _selectedBet == bet;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _selectedBet = bet),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: isSel
                                        ? const LinearGradient(
                                            colors: [Color(0xFFFFB300), Color(0xFFE65100)],
                                          )
                                        : null,
                                    color: isSel ? null : const Color(0xE625143E),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel ? const Color(0xFFFFD54F) : const Color(0x33FFD54F),
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('💰', style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$bet',
                                        style: TextStyle(
                                          color: isSel ? Colors.white : AppColors.gold,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // "العب الآن" (Play Now) Big Button
                      GestureDetector(
                        onTap: () {
                          if (widget.gameId == 'okey') {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const OkeyGameScreen()),
                            );
                          } else {
                            TopNotification.show(
                              context,
                              'جاري بدء لعبة ${game.title}... بالتوفيق!',
                              icon: Icons.play_circle_filled_rounded,
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFF7A45),
                                Color(0xFFFF3D00),
                                Color(0xFFD82800),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(27),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.8),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3D00).withOpacity(0.55),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'العب الآن',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
