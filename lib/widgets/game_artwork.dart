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
    // لوحة 5×5 مائلة + سلّم خشبي + حية مرسومة بتدرّج + نردان
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 170,
        height: 116,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 30,
              top: 4,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateX(0.42)
                  ..rotateZ(-0.06),
                child: Container(
                  width: 106,
                  height: 106,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: const Color(0xFF14532D), width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 8)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: CustomPaint(painter: _SnakeBoardArtPainter()),
                  ),
                ),
              ),
            ),
            // النردان
            Positioned(right: 6, bottom: 4, child: _die(5, 0.3)),
            Positioned(right: 30, bottom: 0, child: _die(3, -0.25)),
          ],
        ),
      ),
    );
  }

  Widget _die(int n, double angle) {
    const pips = {
      3: [0, 4, 8],
      5: [0, 2, 4, 6, 8],
    };
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 26,
        height: 26,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFE2DED3)]),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 6,
                offset: const Offset(1.5, 3.5)),
          ],
        ),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: List.generate(
            9,
            (i) => Center(
              child: (pips[n] ?? const []).contains(i)
                  ? Container(
                      width: 4.2,
                      height: 4.2,
                      decoration: const BoxDecoration(
                          color: Color(0xFFDC2626), shape: BoxShape.circle),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// رسام لوحة الحية والدرج الصغيرة للبطاقة
class _SnakeBoardArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const n = 5;
    final c = size.width / n;
    const tiles = [
      Color(0xFFFDE68A),
      Color(0xFF86EFAC),
      Color(0xFF93C5FD),
      Color(0xFFFCA5A5),
    ];
    for (var r = 0; r < n; r++) {
      for (var col = 0; col < n; col++) {
        canvas.drawRect(Rect.fromLTWH(col * c, r * c, c, c),
            Paint()..color = tiles[(r + col) % tiles.length]);
      }
    }

    // السلّم الخشبي: سكّتان ودرجات
    final rail = Paint()
      ..color = const Color(0xFF8B5A2B)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final a1 = Offset(c * 0.7, c * 4.6), b1 = Offset(c * 2.3, c * 0.5);
    final a2 = Offset(c * 1.3, c * 4.8), b2 = Offset(c * 2.9, c * 0.7);
    canvas.drawLine(a1, b1, rail);
    canvas.drawLine(a2, b2, rail);
    final rung = Paint()
      ..color = const Color(0xFFB07D4E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < 6; i++) {
      final t = i / 6;
      canvas.drawLine(Offset.lerp(a1, b1, t)!, Offset.lerp(a2, b2, t)!, rung);
    }

    // الحية: منحنى S متدرّج الألوان مع رأس وعينين
    final path = Path()
      ..moveTo(c * 4.4, c * 0.6)
      ..cubicTo(c * 2.6, c * 1.2, c * 5.0, c * 2.6, c * 3.4, c * 3.2)
      ..cubicTo(c * 2.2, c * 3.7, c * 3.6, c * 4.6, c * 2.6, c * 4.7);
    final body = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF16A34A), Color(0xFF84CC16), Color(0xFF15803D)],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = c * 0.42
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = c * 0.48
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, body);
    // نقوش ظهر الحية
    final spots = Paint()..color = const Color(0xFFFDE047);
    for (final m in path.computeMetrics()) {
      for (var d = c * 0.6; d < m.length - c * 0.5; d += c * 0.7) {
        final p = m.getTangentForOffset(d)!.position;
        canvas.drawCircle(p, c * 0.07, spots);
      }
    }
    final head = Offset(c * 4.4, c * 0.6);
    canvas.drawCircle(head, c * 0.3, Paint()..color = const Color(0xFF15803D));
    canvas.drawCircle(head + Offset(-c * 0.1, -c * 0.08), c * 0.07,
        Paint()..color = Colors.white);
    canvas.drawCircle(head + Offset(c * 0.1, -c * 0.08), c * 0.07,
        Paint()..color = Colors.white);
    canvas.drawCircle(head + Offset(-c * 0.1, -c * 0.08), c * 0.035,
        Paint()..color = Colors.black);
    canvas.drawCircle(head + Offset(c * 0.1, -c * 0.08), c * 0.035,
        Paint()..color = Colors.black);
    // اللسان
    canvas.drawLine(
        head + Offset(-c * 0.25, c * 0.1),
        head + Offset(-c * 0.5, c * 0.22),
        Paint()
          ..color = const Color(0xFFEF4444)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ----------------------------------------------------
// 7. DOMINOES (دومينو) ARTWORK
// ----------------------------------------------------
class _DominoArtwork extends StatelessWidget {
  const _DominoArtwork();

  @override
  Widget build(BuildContext context) {
    // سلسلة دومينو على قماش أخضر + قطعتان واقفتان بالأمام
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 170,
        height: 116,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // قماش بيضاوي
            Positioned(
              bottom: 2,
              child: Container(
                width: 164,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(82, 29)),
                  gradient: const RadialGradient(
                    colors: [Color(0xFF16A34A), Color(0xFF14532D)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 6)),
                  ],
                ),
              ),
            ),
            // سلسلة مستلقية
            Positioned(
              bottom: 22,
              left: 14,
              child: Transform.rotate(
                  angle: -0.08, child: _domino(6, 4, horizontal: true)),
            ),
            Positioned(
              bottom: 26,
              left: 76,
              child: Transform.rotate(
                  angle: -0.08, child: _domino(4, 2, horizontal: true)),
            ),
            // قطعتان واقفتان
            Positioned(
              bottom: 30,
              right: 30,
              child: Transform.rotate(angle: 0.16, child: _domino(5, 5)),
            ),
            Positioned(
              bottom: 22,
              right: 58,
              child: Transform.rotate(angle: -0.12, child: _domino(3, 1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _domino(int a, int b, {bool horizontal = false}) {
    final w = horizontal ? 62.0 : 32.0;
    final h = horizontal ? 32.0 : 62.0;
    final halves = [_half(a), _divider(horizontal), _half(b)];
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFAF6EC), Color(0xFFE6DCC4)],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCFC3A5), width: 0.8),
        boxShadow: [
          const BoxShadow(
              color: Color(0xFFB8A882), offset: Offset(0, 2.5), blurRadius: 0),
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 6,
              offset: const Offset(1, 4)),
        ],
      ),
      child: horizontal ? Row(children: halves) : Column(children: halves),
    );
  }

  Widget _divider(bool horizontal) => Container(
        width: horizontal ? 1.4 : 22,
        height: horizontal ? 22 : 1.4,
        color: const Color(0xFF9A8A66),
      );

  Widget _half(int n) {
    const dots = {
      1: [4],
      2: [0, 8],
      3: [0, 4, 8],
      4: [0, 2, 6, 8],
      5: [0, 2, 4, 6, 8],
      6: [0, 2, 3, 5, 6, 8],
    };
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: List.generate(
            9,
            (i) => Center(
              child: (dots[n] ?? const []).contains(i)
                  ? Container(
                      width: 4.6,
                      height: 4.6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0xFF374151), Color(0xFF0F172A)],
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
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

  // مروحة أحجار فوق استكانة خشبية: (رقم، لون، زاوية، إزاحة X، أوكي؟)
  static const _fan = [
    (7, Color(0xFFF03E3E), -0.30, -46.0, false),
    (8, Color(0xFF2B7FFF), -0.12, -18.0, false),
    (9, Color(0xFFF2A900), 0.08, 12.0, false),
    (0, Color(0xFFF59E0B), 0.28, 42.0, true),
  ];

  @override
  Widget build(BuildContext context) {
    // لوحة تصميم ثابتة 170×116 تُكبَّر لتملأ مساحة البطاقة كاملة
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 170,
        height: 116,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // هالة ذهبية خلف المروحة
            Positioned(
              top: 6,
              child: Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withOpacity(0.28),
                      blurRadius: 34,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            // الاستكانة الخشبية
            Positioned(
              bottom: 6,
              child: Container(
                width: 160,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFB57A45),
                      Color(0xFF8A5229),
                      Color(0xFF5E3417)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD9A066), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: Align(
                  alignment: const Alignment(0, -0.35),
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
            for (final f in _fan)
              Positioned(
                bottom: 22,
                left: 85 - 20 + f.$4,
                child: Transform.rotate(
                  angle: f.$3,
                  alignment: Alignment.bottomCenter,
                  child: _tile(f.$1, f.$2, okey: f.$5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tile(int value, Color ink, {bool okey = false}) {
    return Container(
      width: 40,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFBF6EA), Color(0xFFEADCBB)],
        ),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
            color: okey ? const Color(0xFFFFB300) : const Color(0xFFD6C9A6),
            width: okey ? 1.6 : 0.9),
        boxShadow: [
          // سماكة عاجية سفلية + ظل أرضي
          const BoxShadow(
              color: Color(0xFFB9A57A), offset: Offset(0, 3), blurRadius: 0),
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 7,
              offset: const Offset(1, 5)),
          if (okey)
            BoxShadow(
                color: const Color(0xFFFFD54F).withOpacity(0.55),
                blurRadius: 12),
        ],
      ),
      child: okey
          ? const Center(
              child: Icon(Icons.star_rounded,
                  color: Color(0xFFF59E0B),
                  size: 30,
                  shadows: [
                    Shadow(
                        color: Color(0x99FFFFFF),
                        offset: Offset(0, 1),
                        blurRadius: 0),
                  ]),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$value',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: ink,
                      height: 1,
                      shadows: const [
                        Shadow(
                            color: Color(0xBFFFFFFF),
                            offset: Offset(0, 1.2),
                            blurRadius: 0),
                      ],
                    )),
                const SizedBox(height: 4),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
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
