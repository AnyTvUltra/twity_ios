import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../okey_models.dart';
import '../../../services/store_service.dart';
import '../../../widgets/animated_skin_effect.dart';
import '../../../widgets/skin_image.dart';
import 'okey_tile_widget.dart';
import 'okey_rack_model_3d.dart';

/// استكانة اللاعب ثلاثية الأبعاد - مطابقة لشكل الحامل الخشبي بالصورة المرجعية
class OkeyIstakaWidget extends StatelessWidget {
  final List<OkeyTile?> rackTiles;
  final int? selectedIndex;
  final bool isTurn;
  final Set<int> highlightedIndices;
  final Function(int slotIndex) onTileTap;
  final Function(int fromSlot, int toSlot)? onTileMove;

  /// معامل تكبير المشهد (FittedBox) ليظهر الحجر المسحوب بنفس حجمه على الشاشة
  final double dragScaleX;
  final double dragScaleY;

  /// دوران المشهد (عندما تكون الشاشة عمودية والمشهد مُدار 90°)
  final int feedbackQuarterTurns;

  /// كسنة الاستكانة (اختيارية) — تغطي كامل الجسم مع دعم التكبير والإزاحة
  final StoreItem? rackItem;

  OkeyIstakaWidget({
    super.key,
    required this.rackTiles,
    required this.selectedIndex,
    this.isTurn = true,
    this.highlightedIndices = const {},
    required this.onTileTap,
    this.onTileMove,
    this.dragScaleX = 1.0,
    this.dragScaleY = 1.0,
    this.feedbackQuarterTurns = 0,
    this.rackItem,
  });

  /// صناديق العرض لكل خانة — لحساب نصف الخانة عند الإفلات
  final Map<int, RenderBox?> _lastSlotBoxes = {};

  /// أحجار الكتلة المتجاورة التي تحتوي الخانة (لحمل الـ Per كاملاً)
  List<OkeyTile> _groupForSlot(int slotIndex) {
    final rowStart = slotIndex < 14 ? 0 : 14;
    int i = slotIndex;
    while (i > rowStart && rackTiles[i - 1] != null) {
      i--;
    }
    int j = slotIndex;
    while (j < rowStart + 13 && rackTiles[j + 1] != null) {
      j++;
    }
    final out = <OkeyTile>[];
    for (var k = i; k <= j; k++) {
      final t = rackTiles[k];
      if (t != null) out.add(t);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW = constraints.maxWidth;
        // العرض المحسوب للخانة الواحدة بحيث تتسع الـ 14 خانة بداخل الرف مع هوامش مريحة
        final slotW = ((availableW - 64) / 14).clamp(24.0, 40.0);
        final tileW =
            slotW - 2.0; // يضمن وجود مساحة 1.0 بكسل لكل جهة دون أي تداخل
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                      width: 1.0,
                    ),
                    boxShadow: [
                      // عمق + إضاءة محيطية زجاجية خافتة
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: const Color(0xFF3FF5A8).withOpacity(0.08),
                        blurRadius: 14,
                        spreadRadius: -2,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.08),
                        blurRadius: 1,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        // الكسنة تغطي كامل جسم الاستكانة (أو الخشب الافتراضي)
                        // — إن كان للكسنة نموذج GLB ثلاثي الأبعاد يُعرض النموذج نفسه
                        Positioned.fill(
                          child: rackItem != null &&
                                  rackItem!.model3d.isNotEmpty
                              ? OkeyRack3DModel(modelPath: rackItem!.model3d)
                              : rackItem != null
                                  ? (skinEffectOf(rackItem) != SkinEffect.none
                                      ? AnimatedSkinLayer(
                                          effect: skinEffectOf(rackItem),
                                          woodUnderlay: true)
                                      : SkinTransformImage.fromItem(rackItem!))
                                  : SkinTransformImage.fromItem(
                                      StoreService.defaultWoodItem),
                        ),
                        // تعتيم خفيف فوق الكسنة/الخشب
                        if (rackItem == null ||
                            rackItem!.model3d.isEmpty)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(0.12),
                            ),
                          ),
                        Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── اللوح الخلفي العلوي — شريط زجاجي ──
                          Container(
                            width: double.infinity,
                            height: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: (rackItem?.model3d.isNotEmpty ?? false)
                                    ? const [
                                        Color(0x00000000),
                                        Color(0x00000000),
                                      ]
                                    : const [
                                        Color(0x2FFFFFFF),
                                        Color(0x14FFFFFF),
                                      ],
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: (rackItem?.model3d.isNotEmpty ?? false)
                                      ? const Color(0x00000000)
                                      : const Color(0x338FA8E8),
                                  width: 1.0,
                                ),
                              ),
                            ),
                          ),

                          // ── مساحة الرفين للأحجار ──
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // الصف الأول (العلوي)
                                _buildShelfRow(0, 14, slotW, tileW, tileH),

                                // الفاصل المعدني بين الرفين — Glass Metal
                                Container(
                                  height: 4,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 2.5),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors:
                                          (rackItem?.model3d.isNotEmpty ?? false)
                                              ? const [
                                                  Color(0x00000000),
                                                  Color(0x00000000),
                                                  Color(0x00000000),
                                                  Color(0x00000000),
                                                ]
                                              : const [
                                                  Color(0xFF0A0F22),
                                                  Color(0xFF5C6FA6),
                                                  Color(0xFF9FB4E8),
                                                  Color(0xFF1A2444),
                                                ],
                                      stops: const [0.0, 0.3, 0.7, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow:
                                        (rackItem?.model3d.isNotEmpty ?? false)
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.5),
                                                  blurRadius: 1.5,
                                                  offset: const Offset(0, 1),
                                                ),
                                                BoxShadow(
                                                  color: const Color(0xFF8FA8E8)
                                                      .withOpacity(0.12),
                                                  blurRadius: 3,
                                                  spreadRadius: -1,
                                                ),
                                              ],
                                  ),
                                ),

                                // الصف الثاني (السفلي)
                                _buildShelfRow(14, 28, slotW, tileW, tileH),
                              ],
                            ),
                          ),

                          // الشفة السفلية — معدن زجاجي داكن
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors:
                                    (rackItem?.model3d.isNotEmpty ?? false)
                                        ? const [
                                            Color(0x00000000),
                                            Color(0x00000000),
                                            Color(0x00000000),
                                          ]
                                        : const [
                                            Color(0xFF0A0F22),
                                            Color(0xFF3A4A7A),
                                            Color(0xFF0A0F22),
                                          ],
                              ),
                            ),
                          ),
                        ],
                        ),
                      ],
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

  Widget _buildShelfRow(
      int start, int end, double slotW, double tileW, double tileH) {
    return SizedBox(
      height: tileH,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(end - start, (i) {
          final slotIndex = start + i;
          final tile =
              slotIndex < rackTiles.length ? rackTiles[slotIndex] : null;
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
                      width: slotW,
                      height: tileH,
                      color: Colors.transparent,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: isHovering ? slotW : tileW,
                          height: tileH,
                          decoration: BoxDecoration(
                            color: isHovering
                                ? const Color(0x334ADE80)
                                : const Color(0x14FFFFFF),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: isHovering
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0x1AFFFFFF),
                              width: isHovering ? 1.2 : 0.5,
                            ),
                          ),
                        ),
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
                  // إدراج قبل/بعد الحجر حسب نصف الخانة الذي أفلتّ عليه
                  // — بدون إزاحة الأحجار المجاورة بعيداً
                  final rowEnd = end - 1;
                  var target = slotIndex;
                  final box = _lastSlotBoxes[slotIndex];
                  if (box != null && box.attached) {
                    final local = box.globalToLocal(details.offset);
                    if (local.dx > box.size.width / 2 &&
                        slotIndex + 1 <= rowEnd) {
                      target = slotIndex + 1;
                    }
                  }
                  if (target == details.data) target = slotIndex;
                  onTileMove?.call(details.data, target);
                },
                builder: (context, candidateData, rejectedData) {
                  _lastSlotBoxes[slotIndex] =
                      context.findRenderObject() as RenderBox?;
                  final draggedFrom =
                      candidateData.isEmpty ? null : candidateData.first;
                  final hoverOffset = draggedFrom == null
                      ? 0.0
                      : (draggedFrom < slotIndex
                          ? -slotW * 0.38
                          : slotW * 0.38);
                  // حمل الـ Per كاملاً: إن كان الحجر ضمن مجموعة مميّزة اسحبها كلها
                  final groupTiles = highlightedIndices.contains(slotIndex)
                      ? _groupForSlot(slotIndex)
                      : null;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.translationValues(hoverOffset, 0, 0),
                    child: Draggable<int>(
                      data: slotIndex,
                      onDragStarted: () =>
                          HapticFeedback.selectionClick(),
                      // الحجر يرتفع قليلاً فوق الإصبع ولا يتداخل معه
                      dragAnchorStrategy: (Draggable<Object> draggable,
                          BuildContext context, Offset position) {
                        final w = tileW * dragScaleX * 1.08;
                        final h = tileH * dragScaleY * 1.08;
                        if (feedbackQuarterTurns.isOdd) {
                          // بعد التدوير: العرض المعروض = الارتفاع والعكس
                          return Offset(h / 2, w + 8);
                        }
                        return Offset(w / 2, h + 8);
                      },
                      feedback: Material(
                        color: Colors.transparent,
                        elevation: 10,
                        borderRadius: BorderRadius.circular(4),
                        child: RotatedBox(
                          quarterTurns: feedbackQuarterTurns,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.diagonal3Values(
                                dragScaleX * 1.08, dragScaleY * 1.08, 1),
                            child: groupTiles != null && groupTiles.length > 1
                                ? Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xCC10B981),
                                      borderRadius:
                                          BorderRadius.circular(5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: groupTiles
                                          .map((t) => Padding(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 1),
                                                child: OkeyTileWidget(
                                                  tile: t,
                                                  isDragging: true,
                                                  width: tileW,
                                                  height: tileH,
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  )
                                : OkeyTileWidget(
                                    tile: tile,
                                    isDragging: true,
                                    width: tileW,
                                    height: tileH,
                                  ),
                          ),
                        ),
                      ),
                      childWhenDragging: Container(
                        width: tileW,
                        height: tileH,
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0x33FFFFFF),
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
          Color(0xFF22305A),
          Color(0xFF141E3C),
          Color(0xFF080D1E),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, paint);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8FA8E8).withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
