import 'package:flutter/material.dart';
import '../okey_models.dart';
import 'okey_tile_widget.dart';

/// استكانة اللاعب ثلاثية الأبعاد - مطابقة لشكل الحامل الخشبي بالصورة المرجعية
class OkeyIstakaWidget extends StatelessWidget {
  final List<OkeyTile?> rackTiles;
  final int? selectedIndex;
  final bool isTurn;
  final Set<int> highlightedIndices;
  final Function(int slotIndex) onTileTap;
  final Function(int fromSlot, int toSlot)? onTileMove;

  const OkeyIstakaWidget({
    super.key,
    required this.rackTiles,
    required this.selectedIndex,
    this.isTurn = true,
    this.highlightedIndices = const {},
    required this.onTileTap,
    this.onTileMove,
  });


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW = constraints.maxWidth;
        // العرض المحسوب للخانة الواحدة بحيث تتسع الـ 14 خانة بداخل الرف مع هوامش مريحة
        final slotW = ((availableW - 64) / 14).clamp(21.0, 30.0);
        final tileW = slotW - 2.0; // يضمن وجود مساحة 1.0 بكسل لكل جهة دون أي تداخل
        final tileH = tileW * 1.36;

        final innerShelfW = slotW * 14;
        final rackContainerW = innerShelfW + 28.0;
        final totalWidgetW = rackContainerW + 24.0;

        return Center(
          child: SizedBox(
            width: totalWidgetW,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ══════════════════════════════════════════════════════
                // 1. جسم الاستكانة الخشبي مع الحواف والظلال (Rack Stand)
                // ══════════════════════════════════════════════════════
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.7),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFFD4A373).withOpacity(0.15),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF5A2E16),
                            Color(0xFF45220F),
                            Color(0xFF33180A),
                            Color(0xFF241006),
                          ],
                          stops: [0.0, 0.35, 0.75, 1.0],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── اللوح الخلفي العلوي مع نص "YOUR TURN" ──
                          Container(
                            width: double.infinity,
                            height: 20,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF42200E),
                                  Color(0xFF2E1508),
                                ],
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFF1B0B04),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isTurn ? 'YOUR TURN' : 'OPPONENT TURN',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.92),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.8),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ── مساحة الرفين للأحجار ──
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // الصف الأول (العلوي)
                                _buildShelfRow(0, 14, slotW, tileW, tileH),

                                // الحافة الخشبية الفاصلة بين الرفين
                                Container(
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(vertical: 2.5),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF1E0A03),
                                        Color(0xFF6B3A1C),
                                        Color(0xFF8B4D26),
                                        Color(0xFF2C1205),
                                      ],
                                      stops: [0.0, 0.3, 0.7, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(1),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 1.5,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),

                                // الصف الثاني (السفلي)
                                _buildShelfRow(14, 28, slotW, tileW, tileH),
                              ],
                            ),
                          ),

                          // الحافة السفلية للاستكانة (Bottom Lip)
                          Container(
                            height: 4,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF190802),
                                  Color(0xFF38190A),
                                  Color(0xFF190802),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ══════════════════════════════════════════════════════
                // 2. الغطاء الخشبي الجانبي المثلث - يسار
                // ══════════════════════════════════════════════════════
                const Positioned(
                  left: 0,
                  top: 3,
                  bottom: 3,
                  width: 12,
                  child: CustomPaint(
                    painter: _TriangularEndCapPainter(isLeft: true),
                  ),
                ),

                // ══════════════════════════════════════════════════════
                // 3. الغطاء الخشبي الجانبي المثلث - يمين
                // ══════════════════════════════════════════════════════
                const Positioned(
                  right: 0,
                  top: 3,
                  bottom: 3,
                  width: 12,
                  child: CustomPaint(
                    painter: _TriangularEndCapPainter(isLeft: false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShelfRow(int start, int end, double slotW, double tileW, double tileH) {
    return SizedBox(
      height: tileH,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(end - start, (i) {
          final slotIndex = start + i;
          final tile = slotIndex < rackTiles.length ? rackTiles[slotIndex] : null;
          final isSelected = selectedIndex == slotIndex;

          if (tile == null) {
            // خانة فارغة تدعم إسقاط الحجر المسحوب
            return SizedBox(
              width: slotW,
              height: tileH,
              child: Center(
                child: DragTarget<int>(
                  onWillAcceptWithDetails: (details) => true,
                  onAcceptWithDetails: (details) {
                    onTileMove?.call(details.data, slotIndex);
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovering = candidateData.isNotEmpty;
                    return Container(
                      width: tileW,
                      height: tileH,
                      decoration: BoxDecoration(
                        color: isHovering
                            ? const Color(0x334ADE80)
                            : const Color(0x10000000),
                        borderRadius: BorderRadius.circular(3),
                        border: isHovering
                            ? Border.all(color: const Color(0xFF4ADE80), width: 1.2)
                            : null,
                      ),
                    );
                  },
                ),
              ),
            );
          }

          // حجر موجود في الخانة - يدعم السحب والإفلات واللمس
          return SizedBox(
            width: slotW,
            height: tileH,
            child: Center(
              child: DragTarget<int>(
                onWillAcceptWithDetails: (details) => details.data != slotIndex,
                onAcceptWithDetails: (details) {
                  onTileMove?.call(details.data, slotIndex);
                },
                builder: (context, candidateData, rejectedData) {
                  return LongPressDraggable<int>(
                    data: slotIndex,
                    delay: const Duration(milliseconds: 160),
                    hapticFeedbackOnStart: true,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Transform.scale(
                        scale: 1.15,
                        child: OkeyTileWidget(
                          tile: tile,
                          isDragging: true,
                          width: tileW,
                          height: tileH,
                        ),
                      ),
                    ),
                    childWhenDragging: Container(
                      width: tileW,
                      height: tileH,
                      decoration: BoxDecoration(
                        color: const Color(0x22000000),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: const Color(0x22FFFFFF),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: OkeyTileWidget(
                      tile: tile,
                      isSelected: isSelected,
                      isHighlighted: highlightedIndices.contains(slotIndex),
                      width: tileW,
                      height: tileH,
                      onTap: () => onTileTap(slotIndex),
                    ),

                  );
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// رسم الغطاء المثلث الجانبي للحامل الخشبي
class _TriangularEndCapPainter extends CustomPainter {
  final bool isLeft;

  const _TriangularEndCapPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    if (isLeft) {
      path.moveTo(w, 0);
      path.lineTo(w, h);
      path.lineTo(1.5, h * 0.86);
      path.lineTo(1.5, h * 0.18);
    } else {
      path.moveTo(0, 0);
      path.lineTo(0, h);
      path.lineTo(w - 1.5, h * 0.86);
      path.lineTo(w - 1.5, h * 0.18);
    }
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [
          Color(0xFF5A2E16),
          Color(0xFF3D1D0D),
          Color(0xFF220E05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD4A373).withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
