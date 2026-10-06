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

  /// وضع الغرفة: بلا جسم خشبي/شريط/قاعدة — يُرسم صفّا الأحجار فقط
  /// فوق استكانة مرسومة في صورة المشهد، مع الحفاظ على كل منطق السحب
  final bool ghostMode;

  /// حاشية التقاط حول منطقة الرف (وضع الغرفة): الإصبع يسبق الحجر
  /// المرئي خارج مستطيل الرف أثناء السحب السريع — بهذه الحاشية يبقى
  /// الإفلات داخل هدف الرف فيُحسب لأقرب خانة بدل أن يرتد الحجر مكانه
  final EdgeInsets hitPad;

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
    this.ghostMode = false,
    this.hitPad = EdgeInsets.zero,
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
        if (ghostMode) {
          // وضع الغرفة: صفّا أحجار فقط فوق استكانة الصورة — الصف العلوي
          // قاعدته على أرضية اللوح الغائر والسفلي مرفوعاً قليلاً فوق
          // الشريط الأمامي. hitPad يوسّع منطقة الالتقاط حول الرف دون
          // تغيير مواضع الأحجار. الحجر أعرض من الخانة → تداخل طبيعي
          // نفس المعادلة تتكرر في _rackSlotCenter بالشاشة — أي تعديل
          // هنا يجب أن ينعكس هناك
          final innerW = availableW - hitPad.horizontal;
          final innerH = constraints.maxHeight - hitPad.vertical;
          final gSlotW = ((innerW - 24) / 14).clamp(20.0, 40.0);
          final gTileW = gSlotW * 1.28;
          final gTileH = gTileW * 1.10;
          // قاعدة الصف العلوي = 0.758 من ارتفاع الصورة (أرضية اللوح
          // الغائر) وقاعدة السفلي = 0.912 (فوق الشريط المزخرف مرفوعة
          // قليلاً) — أعلى منطقة الاستكانة = 0.600 وأسفلها = 0.935
          const topBaseFromBottom = (0.935 - 0.758) / 0.335;
          const botBaseFromBottom = (0.935 - 0.912) / 0.335;
          // حدّ الصفين = منتصف الفجوة المرئية بين الصفّين — الإفلات
          // يُحسب لأقرب صفٍّ يقع تحت مركز الحجر لا لخطٍّ اعتباطي
          final row0BaseY = innerH * (1 - topBaseFromBottom);
          final row1BaseY = innerH * (1 - botBaseFromBottom);
          final rowSplit = (row0BaseY + (row1BaseY - gTileH)) / 2;
          return _buildDropArea(
            slotW: gSlotW,
            tileW: gTileW,
            tileH: gTileH,
            x0: (innerW - gSlotW * 14) / 2,
            rowSplit: rowSplit,
            hitPad: hitPad,
            child: SizedBox(
              width: innerW,
              height: innerH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: innerH * topBaseFromBottom,
                    child: Center(
                        child: _buildShelfRow(0, 14, gSlotW, gTileW, gTileH)),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: innerH * botBaseFromBottom,
                    child: Center(
                        child: _buildShelfRow(14, 28, gSlotW, gTileW, gTileH)),
                  ),
                ],
              ),
            ),
          );
        }
        // العرض المحسوب للخانة الواحدة بحيث تتسع الـ 14 خانة بداخل الرف مع هوامش مريحة
        final slotW = ((availableW - 64) / 14).clamp(24.0, 40.0);
        final tileW =
            slotW - 2.0; // يضمن وجود مساحة 1.0 بكسل لكل جهة دون أي تداخل
        final tileH = tileW * 1.28;

        final innerShelfW = slotW * 14;
        final rackContainerW = innerShelfW + 28.0;
        final totalWidgetW = rackContainerW + 24.0;

        return Center(
          child: _buildDropArea(
            slotW: slotW,
            tileW: tileW,
            tileH: tileH,
            // حدّ الصفين = منتصف الفاصل المعدني بينهما (أقرب صف لمركز الحجر)
            rowSplit: 25.0 + tileH + 4.5 / 2,
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
                                        : SkinTransformImage.fromItem(
                                            rackItem!))
                                    : SkinTransformImage.fromItem(
                                        StoreService.defaultWoodItem),
                          ),
                          // تعتيم خفيف فوق الكسنة/الخشب
                          if (rackItem == null || rackItem!.model3d.isEmpty)
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
                                    colors:
                                        (rackItem?.model3d.isNotEmpty ?? false)
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
                                      color: (rackItem?.model3d.isNotEmpty ??
                                              false)
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
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 2.5),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors:
                                              (rackItem?.model3d.isNotEmpty ??
                                                      false)
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
                                        boxShadow: (rackItem
                                                    ?.model3d.isNotEmpty ??
                                                false)
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

  /// آخر لحظة انتهى فيها سحب — تُكبت الضغطات خلال 300ms بعده حتى لا
  /// يُفسَّر رفع الإصبع كضغطة تُحدِّد الحجر المُفلت للتوّ (فكان يبدو
  /// كأن السحب يحدّد الحجر تلقائياً وتبديل مكانه أو رميه يتم بالخطأ)
  static DateTime _lastDragEnd = DateTime.fromMillisecondsSinceEpoch(0);

  static void _noteDragEnd() => _lastDragEnd = DateTime.now();

  void _handleTap(int slotIndex) {
    if (DateTime.now().difference(_lastDragEnd) <
        const Duration(milliseconds: 300)) {
      return;
    }
    onTileTap(slotIndex);
  }

  /// صندوق محتوى الرف الداخلي (داخل حاشية الالتقاط) — إحداثيات
  /// الخانات محسوبة من حدوده، بينما هدف السحب أكبر منه بحاشية hitPad
  static final GlobalKey _rackInnerKey = GlobalKey();
  static RenderBox? get _rackBox =>
      _rackInnerKey.currentContext?.findRenderObject() as RenderBox?;

  /// نسبة ارتفاع الحجر فوق الإصبع أثناء السحب — صغيرة حتى يبقى
  /// الحجر قريباً من الإصبع والإفلات دقيقاً ومباشراً
  static const double dragLiftFactor = 0.18;
  static const double _dragLiftFactor = dragLiftFactor;

  /// مركز الحجر الظاهر على الشاشة أثناء السحب — details.offset في
  /// DragTarget هو الزاوية العليا-اليسرى لصندوق الـfeedback نفسه
  /// (_lastOffset = الإصبع − الـanchor)، والرفع عن الإصبع مشمول أصلاً
  /// في الـanchor — فالمركز الظاهر = الزاوية + نصف حجم الصندوق
  Offset _dragCenter(Offset feedbackTopLeft, double tileW, double tileH) =>
      feedbackTopLeft +
      (feedbackQuarterTurns.isOdd
          ? Offset(tileH / 2, tileW / 2)
          : Offset(tileW / 2, tileH / 2));

  /// يحوّل موضع الحجر إلى خانة (أو -1 = فوق الرف، أي على الطاولة)
  /// rowSplit = الحد العمودي بين الصفّين بإحداثيات الرف الداخلية
  int _slotAt(Offset global, int fromSlot, double slotW,
      {bool raw = false, double x0 = 27.0, double rowSplit = 0}) {
    final box = _rackBox;
    if (box == null || !box.attached) return fromSlot;
    final local = box.globalToLocal(global);
    // فوق الرف = فوق حاشية الالتقاط العلوية كلها (خارجها يتولاها هدف
    // الطاولة) — الإفلات داخل الحاشية يُحسب للصف العلوي لا رمياً بالخطأ
    if (local.dy < -10 - hitPad.top) return -1;
    final row = local.dy < rowSplit ? 0 : 1;
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
    double x0 = 27.0,
    double rowSplit = 0,
    EdgeInsets hitPad = EdgeInsets.zero,
  }) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onMove: (details) {
        final d = details.data;
        final s = _slotAt(_dragCenter(details.offset, tileW, tileH),
            OkeyDrag.isRackTile(d) ? d : -99, slotW,
            raw: !OkeyDrag.isRackTile(d), x0: x0, rowSplit: rowSplit);
        final v = (s < 0 || s == d) ? null : s;
        if (_hoverSlot.value != v) _hoverSlot.value = v;
      },
      onLeave: (_) {
        _hoverSlot.value = null;
      },
      onAcceptWithDetails: (details) {
        _hoverSlot.value = null;
        final d = details.data;
        final center = _dragCenter(details.offset, tileW, tileH);
        if (!OkeyDrag.isRackTile(d)) {
          // الكتلة: الـfeedback صفٌّ من الأحجار بحاشية — مركز الحجر
          // المضغوط يحسب من موضعه داخل الصف لا من نصف الصندوق
          Offset eval = center;
          if (OkeyDrag.isGroup(d)) {
            const pad = 3.0, gap = 1.0;
            final gi = d - OkeyDrag.groupBase;
            final idx = _groupForSlot(gi)
                .indexWhere((t) => identical(t, rackTiles[gi]));
            eval = details.offset +
                Offset(pad + gap + idx * (tileW + gap * 2) + tileW / 2,
                    pad + tileH / 2);
          }
          final s =
              _slotAt(eval, -99, slotW, raw: true, x0: x0, rowSplit: rowSplit);
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
        final s = _slotAt(center, d, slotW, x0: x0, rowSplit: rowSplit);
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
      // Hit padding: يوسّع منطقة الالتقاط حول محتوى الرف — الخانة
      // تُحسب من الصندوق الداخلي المُفتاح فيبقى التعيين دقيقاً
      builder: (context, _, __) => Padding(
        padding: hitPad,
        child: SizedBox(key: _rackInnerKey, child: child),
      ),
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
      onDragEnd: (_) {
        _hoverSlot.value = null;
        _noteDragEnd();
      },
      // الحجر المضغوط يبقى تحت الإصبع، والكتلة ممتدة حوله
      dragAnchorStrategy: (d, c, p) => Offset(
          pad + gap + indexInGroup * (tileW + gap * 2) + tileW / 2,
          pad + tileH / 2 + tileH * dragScaleY * _dragLiftFactor),
      feedback: Material(
        color: Colors.transparent,
        child: Transform(
          alignment: Alignment.topLeft,
          transform: Matrix4.diagonal3Values(dragScaleX, dragScaleY, 1),
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
            // وضع الغرفة: بلا تظليل أخضر — الاستكانة في الصورة تبقى
            // نظيفة، ومعاينة النزول تقتصر على إزاحة الأحجار المجاورة
            final hoverGlow = isHovering && !ghostMode;

            if (tile == null) {
              // خانة فارغة — تتوهج عندما تكون هي مكان النزول
              return SizedBox(
                width: slotW,
                height: tileH,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    width: hoverGlow ? slotW : tileW,
                    height: tileH,
                    decoration: BoxDecoration(
                      color: hoverGlow
                          ? const Color(0x334ADE80)
                          : const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: hoverGlow
                            ? const Color(0xFF4ADE80)
                            : const Color(0x1AFFFFFF),
                        width: hoverGlow ? 1.2 : 0.5,
                      ),
                    ),
                  ),
                ),
              );
            }

            // الكتلة المتجاورة — تُرفع كاملة بالضغط المطوّل
            final groupTiles = _groupForSlot(slotIndex);
            final groupStart =
                slotIndex - groupTiles.indexWhere((t) => identical(t, tile));
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
                      onDragStarted: () {
                        HapticFeedback.selectionClick();
                      },
                      onDragEnd: (_) {
                        _hoverSlot.value = null;
                        _noteDragEnd();
                      },
                      // الحجر يتوسط الإصبع ويرتفع فوقه قليلاً ليبقى ظاهراً
                      dragAnchorStrategy: (Draggable<Object> draggable,
                          BuildContext context, Offset position) {
                        if (feedbackQuarterTurns.isOdd) {
                          return Offset(tileH / 2, tileW / 2);
                        }
                        return Offset(tileW / 2,
                            tileH / 2 + tileH * dragScaleY * _dragLiftFactor);
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
                                dragScaleX, dragScaleY, 1),
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
                              onTap: () => _handleTap(slotIndex),
                            )
                          : OkeyTileWidget(
                              tile: tile,
                              isSelected: isSelected,
                              isHighlighted:
                                  highlightedIndices.contains(slotIndex),
                              width: tileW,
                              height: tileH,
                              onTap: () => _handleTap(slotIndex),
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
