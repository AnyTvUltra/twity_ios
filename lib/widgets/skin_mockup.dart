import 'package:flutter/material.dart';
import '../services/store_service.dart';
import '../games/okey/okey_models.dart';
import '../games/okey/widgets/okey_tile_widget.dart';
import '../games/okey/widgets/okey_istaka_widget.dart';
import '../games/okey/widgets/okey_rack_model_3d.dart';
import '../games/backgammon/widgets/bg_skin_preview.dart';
import 'animated_skin_effect.dart';
import 'skin_image.dart';

/// معاينة موك اب ثلاثية الأبعاد لشكل الكسنة على القطعة المختارة
/// (حجر / طاولة / استكانة / خلفية)
class SkinMockup extends StatelessWidget {
  final String category;
  final ImageProvider? image;
  final double width;
  final double height;

  /// تحويل الصورة: تكبير (1.0) وإزاحة (-1.0 إلى 1.0)
  final double zoom;
  final double offsetX;
  final double offsetY;

  /// تأثير متحرك إجرائي: '' أو 'fire' أو 'ice'
  final String effect;

  /// عنصر المتجر نفسه (اختياري) — لعرض كسنة الحجر الحقيقية في المعاينة
  final StoreItem? item;

  const SkinMockup({
    super.key,
    required this.category,
    this.image,
    this.width = 220,
    this.height = 130,
    this.zoom = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.effect = '',
    this.item,
  });

  bool get _hasSkin => image != null || _effect != SkinEffect.none;

  SkinEffect get _effect => skinEffectFromString(effect);

  /// الخشب الحقيقي قاعدة لكل الفئات ما عدا الأحجار
  bool get _woodBase => category != StoreCategory.tile;

  Widget _skinLayer() =>
      (item?.model3d.isNotEmpty ?? false) && category == StoreCategory.rack
          ? OkeyRack3DModel(modelPath: item!.model3d)
          : _effect != SkinEffect.none
              ? AnimatedSkinLayer(effect: _effect, woodUnderlay: _woodBase)
              : SkinTransformImage(
                  image: image!,
                  zoom: zoom,
                  offsetX: offsetX,
                  offsetY: offsetY,
                );

  @override
  Widget build(BuildContext context) {
    switch (category) {
      case StoreCategory.tile:
        return _buildTileMockup();
      case StoreCategory.table:
        return _buildTableMockup();
      case StoreCategory.rack:
        return _buildRackMockup();
      case StoreCategory.background:
        return _buildBackgroundMockup();
      case StoreCategory.frame:
        return _buildFrameMockup();
      case StoreCategory.chessBoard:
        return _buildChessBoardMockup();
      case StoreCategory.chessPieces:
        return _buildChessPiecesMockup();
      case StoreCategory.bgBoard:
      case StoreCategory.bgCheckers:
        return BgSkinPreview(category: category, itemId: item?.id ?? '');
      default:
        return _buildBackgroundMockup();
    }
  }

  // ══════════════════════════════════════════════════════════
  // موك اب إطار الصورة الشخصية — صورة رمزية + الإطار حولها
  // ══════════════════════════════════════════════════════════
  Widget _buildFrameMockup() {
    final avatarSize = height * 0.52;
    final frameSize = height * 0.74;
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: SizedBox(
          width: frameSize,
          height: frameSize,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // الصورة الرمزية
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child:
                      Text('🀄', style: TextStyle(fontSize: avatarSize * 0.5)),
                ),
              ),
              // الإطار حولها — متحرك (نار/جليد) أو صورة
              if (_effect != SkinEffect.none)
                AnimatedFrameRing(
                    effect: _effect, size: frameSize, woodUnderlay: _woodBase)
              else if (image != null)
                SizedBox(
                  width: frameSize,
                  height: frameSize,
                  child: _skinLayer(),
                )
              else
                Container(
                  width: frameSize,
                  height: frameSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFFD54F), width: 3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // موك اب الحجر — أحجار اللعبة الحقيقية نفسها (OkeyTileWidget)
  // ══════════════════════════════════════════════════════════
  static final _previewTiles = [
    OkeyTile(id: 'pv1', color: OkeyTileColor.red, value: 7),
    OkeyTile(id: 'pv2', color: OkeyTileColor.blue, value: 8),
    OkeyTile(id: 'pv3', color: OkeyTileColor.black, value: 9),
  ];

  Widget _buildTileMockup() {
    final tileW = (width * 0.19).clamp(24.0, 34.0);
    final tileH = tileW * 1.42;
    const tilts = [-0.07, 0.0, 0.07];
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Transform.rotate(
              angle: tilts[i],
              child: OkeyTileWidget(
                tile: _previewTiles[i],
                skinOverride: item,
                width: tileW,
                height: tileH,
              ),
            ),
          );
        }),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // موك اب الطاولة — إطار خشبي سميك + سطح الكسنة بمنظور
  // ══════════════════════════════════════════════════════════
  Widget _buildTableMockup() {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // الإطار الخشبي الخارجي (شبه منحرف أكبر)
            ClipPath(
              clipper: _TrapezoidClipper(inset: 0),
              child: Container(
                width: width * 0.94,
                height: height * 0.82,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF6B3A1C),
                      Color(0xFF4A2410),
                      Color(0xFF2C1205),
                    ],
                  ),
                ),
              ),
            ),
            // سطح اللعب (الكسنة) بشبه منحرف أصغر
            ClipPath(
              clipper: _TrapezoidClipper(inset: 0.09),
              child: SizedBox(
                width: width * 0.94,
                height: height * 0.82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_hasSkin)
                      _skinLayer()
                    else
                      SkinTransformImage.fromItem(StoreService.defaultWoodItem),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.10),
                            Colors.transparent,
                            Colors.black.withOpacity(0.35),
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // أحجار صغيرة على الطاولة للإحساس بالعمق
            Positioned(
              top: height * 0.26,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _miniTile(OkeyTileColor.red, 5),
                  const SizedBox(width: 3),
                  _miniTile(OkeyTileColor.blue, 6),
                  const SizedBox(width: 3),
                  _miniTile(OkeyTileColor.black, 7),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _miniId = 0;
  Widget _miniTile(OkeyTileColor c, int v) {
    return OkeyTileWidget(
      tile: OkeyTile(id: 'mt${_miniId++}', color: c, value: v),
      width: 13,
      height: 18,
    );
  }

  // ══════════════════════════════════════════════════════════
  // موك اب الاستكانة — الاستكانة الحقيقية من اللعبة مصغّرة
  // (نفس ودجت OkeyIstakaWidget: لوح علوي + صفّان + فاصل + شفة + أغطية)
  // ══════════════════════════════════════════════════════════
  Widget _buildRackMockup() {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 660,
              height: 160,
              child: IgnorePointer(
                child: OkeyIstakaWidget(
                  rackTiles: _demoRackTiles(),
                  selectedIndex: null,
                  isTurn: true,
                  rackItem: item,
                  onTileTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// توزيعة أحجار تجريبية واقعية — مجموعات متناثرة بفجوات كاللعبة
  List<OkeyTile?> _demoRackTiles() {
    OkeyTile mk(int i, OkeyTileColor c, int v) =>
        OkeyTile(id: 'demo_$i', color: c, value: v);
    final tiles = List<OkeyTile?>.filled(28, null);
    // الصف العلوي: سلسلة زرقاء + مجموعة ثُلاثية + أحجار متفرقة
    tiles[0] = mk(0, OkeyTileColor.blue, 3);
    tiles[1] = mk(1, OkeyTileColor.blue, 4);
    tiles[2] = mk(2, OkeyTileColor.blue, 5);
    tiles[4] = mk(4, OkeyTileColor.red, 7);
    tiles[5] = mk(5, OkeyTileColor.black, 7);
    tiles[6] = mk(6, OkeyTileColor.yellow, 7);
    tiles[8] = mk(8, OkeyTileColor.red, 11);
    tiles[10] = mk(10, OkeyTileColor.black, 2);
    tiles[11] = mk(11, OkeyTileColor.black, 3);
    tiles[13] = mk(13, OkeyTileColor.yellow, 9);
    // الصف السفلي: سلسلة صفراء + مجموعة رُباعية + متفرقات
    tiles[14] = mk(14, OkeyTileColor.yellow, 10);
    tiles[15] = mk(15, OkeyTileColor.yellow, 11);
    tiles[16] = mk(16, OkeyTileColor.yellow, 12);
    tiles[18] = mk(18, OkeyTileColor.red, 5);
    tiles[19] = mk(19, OkeyTileColor.blue, 5);
    tiles[20] = mk(20, OkeyTileColor.black, 5);
    tiles[21] = mk(21, OkeyTileColor.yellow, 5);
    tiles[23] = mk(23, OkeyTileColor.red, 1);
    tiles[24] = mk(24, OkeyTileColor.red, 2);
    tiles[26] = mk(26, OkeyTileColor.blue, 13);
    return tiles;
  }

  // ══════════════════════════════════════════════════════════
  // موك اب لوحة الشطرنج — رقعة 8×8 حقيقية + الكسنة على الخانات الداكنة
  // ══════════════════════════════════════════════════════════
  Widget _buildChessBoardMockup() {
    final side = height.clamp(60.0, 200.0);
    return Center(
      child: Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(fit: StackFit.expand, children: [
            // الرقعة — الخانات الداكنة تلبس الكسنة
            Column(children: [
              for (var r = 0; r < 8; r++)
                Expanded(
                  child: Row(children: [
                    for (var c = 0; c < 8; c++)
                      Expanded(
                        child: Container(
                          color: (r + c).isEven
                              ? const Color(0xFFEBD9B4)
                              : const Color(0xFF769656),
                          child: (r + c).isOdd && _hasSkin
                              ? Opacity(opacity: 0.55, child: _skinLayer())
                              : null,
                        ),
                      ),
                  ]),
                ),
            ]),
            // لمعة زجاجية
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.14),
                    Colors.transparent,
                    Colors.black.withOpacity(0.18),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // موك اب أحجار الشطرنج — قطع ملوّنة بألوان الكسنة فوق شريط رقعة
  // ══════════════════════════════════════════════════════════
  Widget _buildChessPiecesMockup() {
    const glyphs = ['♜', '♞', '♝', '♛'];
    final accent = item == null
        ? const Color(0xFFEBD9B4)
        : skinAccentColor(skinEffectOf(item));
    return Center(
      child: Container(
        width: width * 0.86,
        height: height * 0.62,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B2438), Color(0xFF0E1526)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < glyphs.length; i++)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: height * 0.34,
                    height: height * 0.34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        accent.withOpacity(0.9),
                        accent.withOpacity(0.35),
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withOpacity(0.4), blurRadius: 10),
                      ],
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Center(
                      child: Text(glyphs[i],
                          style: TextStyle(
                              fontSize: height * 0.19,
                              color: Colors.white,
                              shadows: const [
                                Shadow(color: Colors.black54, blurRadius: 4)
                              ])),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // موك اب الخلفية — مشهد كامل مصغّر: خلفية + طاولة + استكانة
  // ══════════════════════════════════════════════════════════
  Widget _buildBackgroundMockup() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasSkin)
              _skinLayer()
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFF17171B), Color(0xFF030509)],
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.45),
                  ],
                ),
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                // طاولة مصغّرة بمنظور
                ClipPath(
                  clipper: _TrapezoidClipper(inset: 0.06),
                  child: Container(
                    width: width * 0.55,
                    height: height * 0.42,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF6B3A1C), Color(0xFF2C1205)],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: width * 0.42,
                        height: height * 0.26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E5C38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ),
                // استكانة مصغّرة أسفل المشهد
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: width * 0.5,
                    height: height * 0.16,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A2E16), Color(0xFF241006)],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 5),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// قصّ شبه منحرف لمحاكاة منظور الطاولة
class _TrapezoidClipper extends CustomClipper<Path> {
  final double inset;

  const _TrapezoidClipper({this.inset = 0});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final t = w * 0.14 + w * inset;
    final b = w * inset * 0.4;
    return Path()
      ..moveTo(t, 0)
      ..lineTo(w - t, 0)
      ..lineTo(w - b, h)
      ..lineTo(b, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant _TrapezoidClipper oldClipper) =>
      oldClipper.inset != inset;
}

/// أغطية جانبية مثلثة لنهايات الاستكانة (مظهر ثلاثي الأبعاد)
class _EndCapPainter extends CustomPainter {
  final bool isLeft;
  const _EndCapPainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    final path = Path();
    if (isLeft) {
      path.moveTo(0, size.height * 0.3);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, size.height * 0.3);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    }
    path.close();
    p.shader = LinearGradient(
      begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
      colors: const [Color(0xFF6B3A1E), Color(0xFF2B1407)],
    ).createShader(Offset.zero & size);
    canvas.drawPath(path, p);
    p
      ..shader = null
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF1A0C04);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_EndCapPainter oldDelegate) => false;
}
