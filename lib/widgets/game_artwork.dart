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
      default:
        return const SizedBox();
    }
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
                _buildCard(angle: -18, offsetX: -34, value: '10', suit: '♣', isRed: false),
                _buildCard(angle: -7, offsetX: -12, value: 'Q', suit: '♦', isRed: true),
                _buildCard(angle: 6, offsetX: 12, value: 'K', suit: '♥', isRed: true),
                _buildCard(angle: 18, offsetX: 34, value: 'A', suit: '♠', isRed: false, isAce: true),
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
                colors: [Color(0xFF22C55E), Color(0xFF15803D), Color(0xFF14532D)],
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
                        color: isRed ? const Color(0xFFDC2626) : const Color(0xFF1F2937),
                        height: 1,
                      ),
                    ),
                    Text(
                      suit,
                      style: TextStyle(
                        fontSize: 8,
                        color: isRed ? const Color(0xFFDC2626) : const Color(0xFF1F2937),
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
                    color: isRed ? const Color(0xFFDC2626) : const Color(0xFF111827),
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
    return Stack(
      alignment: Alignment.center,
      children: [
        // Wooden Istaka
        Positioned(
          bottom: 8,
          child: Container(
            width: 124,
            height: 22,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF8D5B36),
                  Color(0xFF633D20),
                  Color(0xFF452712),
                ],
              ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFA67148), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),

        // Numbered Tiles
        Positioned(
          bottom: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOkeyTile('7', const Color(0xFF2563EB)),
              const SizedBox(width: 2),
              _buildOkeyTile('8', const Color(0xFFDC2626)),
              const SizedBox(width: 2),
              _buildOkeyTile('9', const Color(0xFF16A34A)),
              const SizedBox(width: 2),
              _buildOkeyTile('10', const Color(0xFFEA580C)),
              const SizedBox(width: 2),
              _buildOkeyTile('11', const Color(0xFF2563EB)),
            ],
          ),
        ),

        // Dice on the side
        Positioned(
          bottom: 3,
          right: 12,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '⚂',
                style: TextStyle(fontSize: 10, color: Colors.black, height: 1),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOkeyTile(String num, Color numColor) {
    return Container(
      width: 19,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            num,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: numColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: numColor,
            ),
          ),
        ],
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
