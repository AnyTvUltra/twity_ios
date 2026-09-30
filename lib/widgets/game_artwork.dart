import 'dart:math' as math;
import 'package:flutter/material.dart';

class GameArtwork extends StatelessWidget {
  final String gameId;

  const GameArtwork({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    switch (gameId) {
      case 'chess':
        return const _Chess3DArtwork();
      case 'solitaire':
        return const _Solitaire3DArtwork();
      case 'ludo':
        return const _Ludo3DArtwork();
      case 'okey':
        return const _Okey3DArtwork();
      case 'backgammon':
        return const _Backgammon3DArtwork();
      case 'snake':
        return const _SnakeArtwork();
      case 'domino':
        return const _DominoArtwork();
      default:
        return const SizedBox();
    }
  }
}

// ----------------------------------------------------
// 6. SNAKES & LADDERS (الحية والدرج) ARTWORK
// ----------------------------------------------------
class _SnakeArtwork extends StatelessWidget {
  const _SnakeArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // ظل أرضي
        Positioned(
          bottom: 0,
          child: Container(
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 11,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        // لوحة مربعات مائلة — ثري-دي
        Positioned(
          bottom: 6,
          left: 10,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateX(-0.28)
              ..rotateZ(-0.10),
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFCF6E3), Color(0xFFEFE2BC)]),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF33691E), width: 1.8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 8,
                      offset: const Offset(2, 5)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  padding: const EdgeInsets.all(4),
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  children: List.generate(
                      16,
                      (i) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: (i + i ~/ 4) % 2 == 0
                                      ? const [
                                          Color(0xFF9CCC65),
                                          Color(0xFF7CB342)
                                        ]
                                      : const [
                                          Color(0xFFFFF9C4),
                                          Color(0xFFF5E6A8)
                                        ]),
                              borderRadius: BorderRadius.circular(2),
                              border:
                                  Border.all(color: Colors.black12, width: 0.4),
                            ),
                          )),
                ),
              ),
            ),
          ),
        ),
        // سلّم خشبي بسكتين ودرجات — مائل وواقعي
        Positioned(
          bottom: 16,
          right: 24,
          child: Transform.rotate(
            angle: 0.30,
            child: SizedBox(
              width: 20,
              height: 62,
              child: Stack(
                children: [
                  Positioned(left: 1, top: 0, bottom: 0, child: _ladderRail()),
                  Positioned(right: 1, top: 0, bottom: 0, child: _ladderRail()),
                  ...List.generate(
                      4,
                      (i) => Positioned(
                            top: 8.0 + i * 13,
                            left: 3,
                            right: 3,
                            child: Container(
                              height: 3.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF9C6B3F),
                                  Color(0xFF6B4423)
                                ]),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 1.5,
                                      offset: const Offset(0, 1)),
                                ],
                              ),
                            ),
                          )),
                ],
              ),
            ),
          ),
        ),
        // حية كبيرة بظل
        Positioned(
          top: -6,
          left: 34,
          child: Text('🐍',
              style: TextStyle(fontSize: 46, shadows: [
                Shadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(1, 3))
              ])),
        ),
        // نردان
        Positioned(
          bottom: 4,
          right: 4,
          child: Transform.rotate(
            angle: 0.28,
            child: _snakeDie('⚅'),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 34,
          child: Transform.rotate(
            angle: -0.2,
            child: _snakeDie('⚄'),
          ),
        ),
      ],
    );
  }

  Widget _ladderRail() => Container(
        width: 5,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB07D4E), Color(0xFF7A4E28)]),
          borderRadius: BorderRadius.circular(3),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 3,
                offset: const Offset(1, 2)),
          ],
        ),
      );

  Widget _snakeDie(String face) => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFE9E4D8)]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFC7C0AE), width: 0.8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 5,
                offset: const Offset(1.5, 3)),
          ],
        ),
        child: Center(
          child: Text(face,
              style: const TextStyle(
                  fontSize: 16, color: Color(0xFF263238), height: 1)),
        ),
      );
}

// ----------------------------------------------------
// 7. DOMINOES (دومينو) ARTWORK
// ----------------------------------------------------
class _DominoArtwork extends StatelessWidget {
  const _DominoArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // ظل أرضي ناعم
        Positioned(
          bottom: 0,
          child: Container(
            width: 108,
            height: 20,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
          ),
        ),
        // قطعة مسطّحة بالخلف (عمق)
        Positioned(
          bottom: 24,
          left: 20,
          child: Transform.rotate(
            angle: -1.35,
            child: _buildDominoTile(top: 2, bottom: 4, dim: true),
          ),
        ),
        // قطعة واقفة خلفية مائلة
        Positioned(
          bottom: 12,
          left: 30,
          child: Transform.rotate(
            angle: -0.22,
            child: _buildDominoTile(top: 1, bottom: 3),
          ),
        ),
        // قطعة واقفة أمامية
        Positioned(
          bottom: 8,
          right: 26,
          child: Transform.rotate(
            angle: 0.14,
            child: _buildDominoTile(top: 6, bottom: 6),
          ),
        ),
        // لمعة ضوئية خفيفة
        Positioned(
          top: 6,
          right: 40,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Colors.white.withOpacity(0.55),
                Colors.white.withOpacity(0.0),
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDominoTile(
      {required int top, required int bottom, bool dim = false}) {
    const dots = {
      1: [4],
      2: [0, 8],
      3: [0, 4, 8],
      4: [0, 2, 6, 8],
      5: [0, 2, 4, 6, 8],
      6: [0, 2, 3, 5, 6, 8],
    };
    Widget half(int n) => SizedBox(
          width: 30,
          height: 29,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            padding: const EdgeInsets.all(3),
            children: List.generate(
                9,
                (i) => Center(
                      child: (dots[n] ?? const []).contains(i)
                          ? Container(
                              width: 5.5,
                              height: 5.5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dim
                                    ? const Color(0xFF8B93A8)
                                    : const Color(0xFF1F2937),
                                boxShadow: dim
                                    ? null
                                    : [
                                        const BoxShadow(
                                            color: Colors.white,
                                            blurRadius: 1,
                                            offset: Offset(-0.5, -0.5))
                                      ],
                              ),
                            )
                          : const SizedBox(),
                    )),
          ),
        );
    return Container(
      width: 36,
      height: 66,
      decoration: BoxDecoration(
        // تدرّج عاجي مع حافة سفلية أغمق = إحساس ثري-دي
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dim
              ? const [Color(0xFFEFF1F5), Color(0xFFD4D9E3)]
              : const [Color(0xFFFFFEF9), Color(0xFFFFFBEB), Color(0xFFEAD9B0)],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: dim ? const Color(0xFFB9C0CF) : const Color(0xFFC9B98F),
            width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 7,
              offset: const Offset(2, 4)),
          // حافة مضيئة داخلية
          const BoxShadow(
              color: Colors.white24, blurRadius: 2, offset: Offset(-1, -1)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          half(top),
          Container(
              height: 1.6,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  (dim ? const Color(0xFFAEB5C4) : const Color(0xFF9A7B4F))
                      .withOpacity(0.0),
                  dim ? const Color(0xFFAEB5C4) : const Color(0xFF9A7B4F),
                  (dim ? const Color(0xFFAEB5C4) : const Color(0xFF9A7B4F))
                      .withOpacity(0.0),
                ]),
              )),
          half(bottom),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 1. CHESS 3D ARTWORK (User Provided High-Res 3D Artwork - Enlarged)
// ----------------------------------------------------
class _Chess3DArtwork extends StatelessWidget {
  const _Chess3DArtwork();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Ground Contact Shadow under board
          Positioned(
            bottom: 0,
            child: Container(
              width: 110,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // High-Res Chess 3D Artwork scaled up to fill the card
          Transform.scale(
            scale: 1.42,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Image.asset(
                'assets/images/chess_art.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 2. SOLITAIRE 3D ARTWORK
// ----------------------------------------------------
class _Solitaire3DArtwork extends StatelessWidget {
  const _Solitaire3DArtwork();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Green Felt Surface Glow
        Positioned(
          bottom: 4,
          child: Container(
            width: 110,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),

        // Fanned Cards
        Positioned(
          bottom: 12,
          child: SizedBox(
            width: 140,
            height: 80,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                _buildCard(
                    angle: -18,
                    offsetX: -34,
                    value: '10',
                    suit: '♣',
                    isRed: false),
                _buildCard(
                    angle: -7,
                    offsetX: -12,
                    value: 'Q',
                    suit: '♦',
                    isRed: true),
                _buildCard(
                    angle: 6, offsetX: 12, value: 'K', suit: '♥', isRed: true),
                _buildCard(
                    angle: 18,
                    offsetX: 34,
                    value: 'A',
                    suit: '♠',
                    isRed: false,
                    isAce: true),
              ],
            ),
          ),
        ),

        // Deck Box on the side
        Positioned(
          bottom: 6,
          right: 4,
          child: Container(
            width: 28,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF22C55E),
                  Color(0xFF15803D),
                  Color(0xFF14532D)
                ],
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.stars_rounded,
                color: Color(0xFFFFD54F),
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required double angle,
    required double offsetX,
    required String value,
    required String suit,
    required bool isRed,
    bool isAce = false,
  }) {
    return Transform.translate(
      offset: Offset(offsetX, 0),
      child: Transform.rotate(
        angle: angle * math.pi / 180,
        child: Container(
          width: 44,
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(1, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: isRed
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF1F2937),
                        height: 1,
                      ),
                    ),
                    Text(
                      suit,
                      style: TextStyle(
                        fontSize: 8,
                        color: isRed
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF1F2937),
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Text(
                  suit,
                  style: TextStyle(
                    fontSize: isAce ? 24 : 18,
                    color: isRed
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF111827),
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
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

// ----------------------------------------------------
// 3. LUDO 3D ARTWORK (User Provided High-Res Pawns Artwork)
// ----------------------------------------------------
class _Ludo3DArtwork extends StatelessWidget {
  const _Ludo3DArtwork();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft Ground Contact Shadow
          Positioned(
            bottom: 2,
            child: Container(
              width: 86,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // High-Res Ludo Pawns Artwork
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Image.asset(
              'assets/images/ludo_art.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// 4. OKEY (كونكان) 3D ARTWORK
// ----------------------------------------------------
class _Okey3DArtwork extends StatelessWidget {
  const _Okey3DArtwork();

  @override
  Widget build(BuildContext context) {
    // شعار الأوكي الرسمي — معروض كبيراً مع توهّج ذهبي وظل ناعم
    return Center(
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withOpacity(0.30),
              blurRadius: 26,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/okey_logo.png',
          width: 196,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// 5. BACKGAMMON (طاولي) 3D ARTWORK (User Provided High-Res Artwork)
// ----------------------------------------------------
class _Backgammon3DArtwork extends StatelessWidget {
  const _Backgammon3DArtwork();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0x66FFD54F),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.5),
          child: Image.asset(
            'assets/images/backgammon_art.jpg',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
