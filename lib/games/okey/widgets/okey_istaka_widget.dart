import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../okey_models.dart';
import '../../../services/store_service.dart';
import '../../../widgets/animated_skin_effect.dart';
import '../../../widgets/skin_image.dart';
import 'okey_tile_widget.dart';
import 'okey_joker_tile.dart';
import 'okey_rack_model_3d.dart';

/// ترميز ما يُسحب في مشهد الأوكي (قيمة الـ Draggable)
class OkeyDrag {
  OkeyDrag._();

  /// حجر من رزمة السحب
  static const int deck = -1;

  /// آخر حجر رماه اللاعب الأيسر
  static const int leftPile = -2;

  /// كتلة كاملة من الرف: groupBase + خانة أي حجر فيها
  static const int groupBase = 100;

  static bool isRackTile(int d) => d >= 0 && d < 28;
  static bool isGroup(int d) => d >= groupBase && d < groupBase + 28;
}

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

  const OkeyIstakaWidget({
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
    this.onDropAboveRack,
    this.onDrawToSlot,
    this.onGroupMove,
  });

  /// إفلات الحجر فوق الرف (على الطاولة) — يُستخدم للرمي
  final void Function(int slot, Offset dropGlobal)? onDropAboveRack;

  /// سحب حجر من الرزمة/كومة اليسار وإفلاته في خانة محددة
  final void Function(int source, int toSlot)? onDrawToSlot;

  /// نقل كتلة كاملة (ضغط مطوّل) إلى خانة جديدة
  final void Function(int anySlot, int toSlot)? onGroupMove;

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
          child: _buildDropArea(
            slotW: slotW,
            tileW: tileW,
            tileH: tileH,
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
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════
  // الإفلات: هدف واحد يغطي الرف كاملاً — تُحسب الخانة الأقرب من موضع
  // الحجر المرسوم (لا من إصبعك) فيُقبل الإفلات في أي مكان على الرف
  // ══════════════════════════════════════════════════════

  /// الخانة المستهدفة أثناء السحب (لمعاينة مكان النزول)
  static final ValueNotifier<int?> _hoverSlot = ValueNotifier<int?>(null);

  /// صندوق الرف المعروض (للتحويل من إحداثيات الشاشة)
  static RenderBox? _rackBox;

  /// مركز الحجر المرسوم على الشاشة من موضع الـ feedback
  Offset _dragCenter(Offset feedbackTopLeft, double tileW, double tileH) =>
      feedbackTopLeft +
      (feedbackQuarterTurns.isOdd
          ? Offset(tileH / 2, tileW / 2)
          : Offset(tileW / 2, tileH / 2));

  /// يحوّل موضع الحجر إلى خانة (أو -1 = فوق الرف، أي على الطاولة)
  int _slotAt(Offset global, int fromSlot, double slotW, double tileH,
      {bool raw = false}) {
    final box = _rackBox;
    if (box == null || !box.attached) return fromSlot;
    final local = box.globalToLocal(global);
    // بداية الأحجار داخل الرف: هامش 12 + حشوة 14 + حد 1 / الشريط العلوي 20 + 4 + حد 1
    const x0 = 27.0;
    const y0 = 25.0;
    if (local.dy < y0 - tileH * 0.45) return -1;
    final row = local.dy < y0 + tileH + 4.5 ? 0 : 1;
    final p = ((local.dx - x0) / slotW).clamp(0.0, 13.999);
    final col = p.floor();
    final slot = row * 14 + col;
    if (slot == fromSlot || raw) return slot;
    // خانة مشغولة: إدراج قبل/بعد الحجر حسب نصفها
    if (rackTiles[slot] != null && p - col > 0.5 && col < 13) {
      final next = slot + 1;
      return next == fromSlot ? slot : next;
    }
    return slot;
  }

  Widget _buildDropArea({
    required Widget child,
    required double slotW,
    required double tileW,
    required double tileH,
  }) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        final d = details.data;
        final s = _slotAt(_dragCenter(details.offset, tileW, tileH),
            OkeyDrag.isRackTile(d) ? d : -99, slotW, tileH,
            raw: !OkeyDrag.isRackTile(d));
        final v = (s < 0 || s == d) ? null : s;
        if (_hoverSlot.value != v) _hoverSlot.value = v;
      },
      onLeave: (_) => _hoverSlot.value = null,
      onAcceptWithDetails: (details) {
        _hoverSlot.value = null;
        final d = details.data;
        final center = _dragCenter(details.offset, tileW, tileH);
        if (!OkeyDrag.isRackTile(d)) {
          final s = _slotAt(center, -99, slotW, tileH, raw: true);
          if (OkeyDrag.isGroup(d)) {
            if (s >= 0) {
              HapticFeedback.lightImpact();
              onGroupMove?.call(d - OkeyDrag.groupBase, s);
            } else {
              onDropAboveRack?.call(d, details.offset);
            }
          } else if (s >= 0) {
            HapticFeedback.lightImpact();
            onDrawToSlot?.call(d, s);
          }
          return;
        }
        final s = _slotAt(center, d, slotW, tileH);
        if (s < 0) {
          // الحجر فوق الرف (على الطاولة) — يُعامل كرمي
          onDropAboveRack?.call(details.data, details.offset);
          return;
        }
        if (s != details.data) {
          HapticFeedback.lightImpact();
          onTileMove?.call(details.data, s);
        }
      },
      builder: (context, _, __) {
        _rackBox = context.findRenderObject() as RenderBox?;
        return child;
      },
    );
  }

  /// ضغط مطوّل على حجر ضمن كتلة (2+) يرفع الكتلة كاملة لنقلها
  Widget _groupDraggable({
    required int slotIndex,
    required List<OkeyTile> groupTiles,
    required int indexInGroup,
    required double tileW,
    required double tileH,
    required Widget child,
  }) {
    if (groupTiles.length < 2) return child;
    const pad = 3.0, gap = 1.0;
    return LongPressDraggable<int>(
      data: OkeyDrag.groupBase + slotIndex,
      delay: const Duration(milliseconds: 320),
      hapticFeedbackOnStart: true,
      onDragEnd: (_) => _hoverSlot.value = null,
      // الحجر المضغوط يبقى تحت الإصبع، والكتلة ممتدة حوله
      dragAnchorStrategy: (d, c, p) => Offset(
          pad + gap + indexInGroup * (tileW + gap * 2) + tileW / 2,
          pad + tileH / 2 + tileH * dragScaleY * 0.28),
      feedback: Material(
        color: Colors.transparent,
        child: Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.diagonal3Values(
              dragScaleX * 1.04, dragScaleY * 1.04, 1),
          child: Container(
            padding: const EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: const Color(0xCC10B981),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 14,
                    offset: Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in groupTiles)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: gap),
                    child: OkeyTileWidget(
                        tile: t, isDragging: true, width: tileW, height: tileH),
                  ),
              ],
            ),
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _buildShelfRow(
      int start, int end, double slotW, double tileW, double tileH) {
    return SizedBox(
      height: tileH,
      child: ValueListenableBuilder<int?>(
        valueListenable: _hoverSlot,
        builder: (context, hover, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(end - start, (i) {
            final slotIndex = start + i;
            final tile =
                slotIndex < rackTiles.length ? rackTiles[slotIndex] : null;
            final isSelected = selectedIndex == slotIndex;
            final isHovering = hover == slotIndex;

            if (tile == null) {
              // خانة فارغة — تتوهج عندما تكون هي مكان النزول
              return SizedBox(
                width: slotW,
                height: tileH,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
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
            }

            // الكتلة المتجاورة — تُرفع كاملة بالضغط المطوّل
            final groupTiles = _groupForSlot(slotIndex);
            final groupStart = slotIndex -
                groupTiles.indexWhere((t) => identical(t, tile));
            // الحجر في خانة النزول يُزاح قليلاً ليفسح مكاناً للإدراج
            final hoverOffset = isHovering ? slotW * 0.38 : 0.0;
            return SizedBox(
              width: slotW,
              height: tileH,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  transform: Matrix4.translationValues(hoverOffset, 0, 0),
                  child: _groupDraggable(
                    slotIndex: slotIndex,
                    groupTiles: groupTiles,
                    indexInGroup: slotIndex - groupStart,
                    tileW: tileW,
                    tileH: tileH,
                    child: Draggable<int>(
                    data: slotIndex,
                    onDragStarted: () => HapticFeedback.selectionClick(),
                    onDragEnd: (_) => _hoverSlot.value = null,
                    // الحجر يتوسط الإصبع ويرتفع فوقه قليلاً ليبقى ظاهراً
                    dragAnchorStrategy: (Draggable<Object> draggable,
                        BuildContext context, Offset position) {
                      if (feedbackQuarterTurns.isOdd) {
                        return Offset(tileH / 2, tileW / 2);
                      }
                      return Offset(
                          tileW / 2, tileH / 2 + tileH * dragScaleY * 0.28);
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
                          child: OkeyTileWidget(
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
                    // الجوكر يظهر مقلوباً (أبيض) — لمسة تكشفه ثانيتين
                    child: tile.isRealOkey
                        ? OkeyJokerTile(
                            tile: tile,
                            isSelected: isSelected,
                            isHighlighted:
                                highlightedIndices.contains(slotIndex),
                            width: tileW,
                            height: tileH,
                            onTap: () => onTileTap(slotIndex),
                          )
                        : OkeyTileWidget(
                            tile: tile,
                            isSelected: isSelected,
                            isHighlighted:
                                highlightedIndices.contains(slotIndex),
                            width: tileW,
                            height: tileH,
                            onTap: () => onTileTap(slotIndex),
                          ),
                  ),
                  ),
                ),
              ),
            );
          }),
        ),
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
