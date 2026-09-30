import 'dart:ui';
import 'package:flutter/material.dart';
import '../models.dart';
import '../utils/format.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/game_artwork.dart';
import '../widgets/gem_icon.dart';
import '../services/auth_service.dart';
import 'okey_game_screen.dart';
import 'chess_game_screen.dart';
import 'backgammon_game_screen.dart';
import '../games/snake/snake_screen.dart';
import '../games/ludo/ludo_screen.dart';
import '../games/domino/domino_screen.dart';
import '../games/solitaire/solitaire_screen.dart';
import '../l10n/app_lang.dart';

class GameScreen extends StatefulWidget {
  final String gameId;

  const GameScreen({super.key, required this.gameId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _selectedMode = 0;
  int _selectedBet = 500;

  final List<String> _modes = [
    'أونلاين'.tr,
    'مع صديق'.tr,
    'ضد الذكاء الاصطناعي'.tr
  ];
  final List<int> _bets = [100, 250, 500, 1000, 2500];

  static const _bgTop = Color(0xFF0A0F24);
  static const _bgMid = Color(0xFF070B18);
  static const _bgBot = Color(0xFF04060F);
  static const _neonBlue = Color(0xFF3B82F6);
  static const _cyan = Color(0xFF38BDF8);
  static const _gold = Color(0xFFFFD54F);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  @override
  Widget build(BuildContext context) {
    final game = GamesData.getGame(widget.gameId);
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: _bgBot,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgMid, _bgBot],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ═══ الهيدر الزجاجي ═══
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    _glassIcon(Icons.arrow_back_ios_new_rounded, _textDim,
                        () => Navigator.of(context).pop()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        game.title,
                        style: const TextStyle(
                          color: _textWhite,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    // رصيد اللاعب في كبسولة زجاجية
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x3A16204A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0x33FFFFFF), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(
                                formatBalance(user?.chips ?? 0),
                                style: const TextStyle(
                                    color: _gold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5),
                              ),
                              Container(
                                width: 1,
                                height: 13,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 7),
                                color: const Color(0x33FFFFFF),
                              ),
                              const GemIcon(size: 13),
                              const SizedBox(width: 4),
                              Text(
                                formatBalance(user?.gems ?? 0),
                                style: const TextStyle(
                                    color: _cyan,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ═══ المحتوى ═══
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // بطاقة العمل الفني الزجاجية
                      ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            height: 190,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0x401B2A5E),
                                  const Color(0x2A101838),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                  color: const Color(0x33FFFFFF), width: 1.1),
                              boxShadow: [
                                BoxShadow(
                                    color: _neonBlue.withOpacity(0.15),
                                    blurRadius: 26,
                                    spreadRadius: -6),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: GameArtwork(gameId: game.id),
                                  ),
                                ),
                                if (game.hasCrown)
                                  const Positioned(
                                    top: 10,
                                    right: 14,
                                    child: Text('👑',
                                        style: TextStyle(fontSize: 26)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // العنوان + الوصف
                      Text(
                        game.title,
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Color(0x66FFB300), blurRadius: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        game.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _textDim,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // اختيار نمط اللعب
                      _sectionTitle('اختر نمط اللعب:'.tr),
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
                                onTap: () {
                                  AppHaptics.selection();
                                  setState(() => _selectedMode = index);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  decoration: BoxDecoration(
                                    gradient: isSel
                                        ? const LinearGradient(colors: [
                                            Color(0xFF3B82F6),
                                            Color(0xFF1D4ED8),
                                          ])
                                        : null,
                                    color:
                                        isSel ? null : const Color(0x2E141C3C),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSel
                                          ? _neonBlue
                                          : const Color(0x26FFFFFF),
                                      width: isSel ? 1.6 : 1,
                                    ),
                                    boxShadow: isSel
                                        ? [
                                            BoxShadow(
                                              color:
                                                  _neonBlue.withOpacity(0.35),
                                              blurRadius: 12,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _modes[index],
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isSel ? Colors.white : _textDim,
                                        fontSize: 11.5,
                                        fontWeight: isSel
                                            ? FontWeight.w900
                                            : FontWeight.w600,
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

                      // اختيار الرهان
                      _sectionTitle('قيمة الرهان (عملات):'.tr),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _bets.map((bet) {
                            final isSel = _selectedBet == bet;
                            return Padding(
                              padding: const EdgeInsets.only(left: 9),
                              child: GestureDetector(
                                onTap: () {
                                  AppHaptics.selection();
                                  setState(() => _selectedBet = bet);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 9),
                                  decoration: BoxDecoration(
                                    gradient: isSel
                                        ? const LinearGradient(colors: [
                                            Color(0xFFFFE082),
                                            _gold,
                                            Color(0xFFE8A820),
                                          ])
                                        : null,
                                    color:
                                        isSel ? null : const Color(0x2E141C3C),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSel
                                          ? const Color(0xFFFFE9A8)
                                          : const Color(0x26FFFFFF),
                                      width: isSel ? 1.5 : 1,
                                    ),
                                    boxShadow: isSel
                                        ? [
                                            BoxShadow(
                                              color: _gold.withOpacity(0.4),
                                              blurRadius: 12,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🪙',
                                          style: TextStyle(fontSize: 13)),
                                      const SizedBox(width: 5),
                                      Text(
                                        formatBalance(bet),
                                        style: TextStyle(
                                          color: isSel
                                              ? const Color(0xFF1B0B30)
                                              : _gold,
                                          fontWeight: FontWeight.w900,
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
                      const SizedBox(height: 30),

                      // زر "العب الآن" الذهبي
                      GestureDetector(
                        onTap: () {
                          AppHaptics.medium();
                          if (widget.gameId == 'okey') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => OkeyGameScreen()),
                            );
                          } else if (widget.gameId == 'chess') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => ChessGameScreen(
                                        vsAI: _selectedMode != 1,
                                        bet: _selectedBet,
                                      )),
                            );
                          } else if (widget.gameId == 'backgammon') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => BackgammonGameScreen(
                                        vsAI: _selectedMode != 1,
                                        bet: _selectedMode == 1
                                            ? 0
                                            : _selectedBet,
                                      )),
                            );
                          } else if (widget.gameId == 'snake') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => SnakeGameScreen(
                                        vsAI: _selectedMode != 1,
                                        bet: _selectedMode == 1
                                            ? 0
                                            : _selectedBet,
                                      )),
                            );
                          } else if (widget.gameId == 'ludo') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => LudoGameScreen(
                                        vsAI: _selectedMode != 1,
                                        bet: _selectedMode == 1
                                            ? 0
                                            : _selectedBet,
                                      )),
                            );
                          } else if (widget.gameId == 'domino') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => DominoGameScreen(
                                        vsAI: _selectedMode != 1,
                                        bet: _selectedMode == 1
                                            ? 0
                                            : _selectedBet,
                                      )),
                            );
                          } else if (widget.gameId == 'solitaire') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => SolitaireGameScreen(
                                        bet: _selectedMode == 1
                                            ? 0
                                            : _selectedBet,
                                      )),
                            );
                          } else {
                            TopNotification.show(
                              context,
                              'جاري بدء لعبة {}... بالتوفيق!'.trp([game.title]),
                              icon: Icons.play_circle_filled_rounded,
                            );
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFFFE082),
                                _gold,
                                Color(0xFFE8A820),
                                Color(0xFFB8860B),
                              ],
                              stops: [0.0, 0.35, 0.75, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: const Color(0xFFFFE9A8), width: 1.4),
                            boxShadow: [
                              BoxShadow(
                                  color: _gold.withOpacity(0.4),
                                  blurRadius: 22,
                                  spreadRadius: -2),
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 0,
                                left: 30,
                                right: 30,
                                height: 13,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withOpacity(0.5),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      color: Color(0xFF1B0B30), size: 26),
                                  SizedBox(width: 8),
                                  Text(
                                    'العب الآن'.tr,
                                    style: TextStyle(
                                      color: Color(0xFF1B0B30),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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

  Widget _sectionTitle(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(colors: [
                Colors.transparent,
                _neonBlue.withOpacity(0.8),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: _textWhite,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x26FFFFFF), width: 1),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
  }
}
