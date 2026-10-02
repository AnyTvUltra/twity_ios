import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/store_service.dart';
import '../../../widgets/animated_skin_effect.dart';
import '../../../widgets/skin_image.dart';
import 'okey_tile_widget.dart';

enum OpponentPosition { top, left, right }

/// حامل أحجار الخصم — نفس تصميم استكانة اللاعب الحالي تماماً
/// (خامة/كسنة، شريط زجاجي علوي، صفّا رف بفاصل معدني، قاعدة) لكن بمقياس
/// أصغر، وموضوع على سطح الطاولة بمنظور 3D حقيقي:
///   position (مقعد اللاعب) → rotation (اتجاه الوجه نحو المقعد) + tilt
///   (استلقاء على مستوى الطاولة).
/// المقعد العلوي يواجه أعلى الشاشة، والجانبيان يواجهان حافتيهما —
/// المشاهد في الأسفل يرى أحجارهم مقلوبة من زاويته، وهذا هو المطلوب.
class OkeyOpponentIstaka extends StatelessWidget {
  final OpponentPosition position;
  final int tileCount;
  final bool isTurn;

  /// كسنة الاستكانة — تُطبق على استكانات الخصوم أيضاً
  final StoreItem? rackItem;

  /// عرض الحجر الواحد داخل الحامل — يضبط مقياس الحامل كاملاً
  final double tileW;

  const OkeyOpponentIstaka({
    super.key,
    required this.position,
    this.tileCount = 14,
    this.isTurn = false,
    this.rackItem,
    this.tileW = 13.0,
  });

  /// زاوية مقعد اللاعب على الشاشة — اتجاه وجه الحامل والأحجار نحو مقعده.
  /// يُستخدم نفس النظام للبيرات: viewerSeat → seatAngle.
  static double seatAngleOf(OpponentPosition p) {
    switch (p) {
      case OpponentPosition.top:
        return math.pi;
      case OpponentPosition.left:
        return math.pi / 2;
      case OpponentPosition.right:
        return -math.pi / 2;
    }
  }

  Widget _skinOrWood() {
    if (rackItem != null) {
      final eff = skinEffectOf(rackItem);
      if (eff != SkinEffect.none) {
        return AnimatedSkinLayer(
            effect: eff, intensity: 0.1, woodUnderlay: true);
      }
      return SkinTransformImage.fromItem(rackItem!);
    }
    // الافتراضي: خامة الخشب الحقيقية — نفس استكانة اللاعب الحالي
    return SkinTransformImage.fromItem(StoreService.defaultWoodItem);
  }

  @override
  Widget build(BuildContext context) {
    // نفس ترتيب التحويل المستخدم للبيرات: تدوير ز-مستوٍ للمقعد أولاً ثم
    // ميلان X داخل إطار الحجر → بعد الدوران يستلقي الحامل على الطاولة
    // وحافته العلوية تنحسر عن المشاهد باتجاه مقعد صاحبه (منظور طبيعي)
    final rack = _buildRack();
    return Transform.rotate(
      angle: seatAngleOf(position),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0016)
          ..rotateX(0.38),
        child: rack,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  جسم الحامل — نفس بنية استكانة اللاعب الحالي بمقياس مصغّر
  // ─────────────────────────────────────────────────────────────
  Widget _buildRack() {
    final tileH = tileW * 1.36;
    final rowCount = (tileCount / 2).ceil().clamp(1, 7);
    final restCount = (tileCount - rowCount).clamp(0, 7);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: tileW * 0.28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isTurn ? const Color(0xFF4ADE80) : const Color(0x338FA8E8),
          width: isTurn ? 1.4 : 0.9,
        ),
        boxShadow: [
          // ظل الحامل على سطح الطاولة — عمق واتجاه مثل استكانة اللاعب
          BoxShadow(
            color: Colors.black.withOpacity(0.60),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: const Color(0xFF3FF5A8).withOpacity(0.07),
            blurRadius: 10,
            spreadRadius: -2,
          ),
          if (isTurn)
            BoxShadow(
              color: const Color(0xFF4ADE80).withOpacity(0.45),
              blurRadius: 15,
              spreadRadius: 0.5,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            // الكسنة/الخشب يغطي كامل الجسم — نفس طبقة استكانة اللاعب
            Positioned.fill(child: _skinOrWood()),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.12)),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── اللوح الخلفي العلوي — شريط زجاجي + بيانات ──
                Container(
                  height: tileW * 0.62,
                  padding: EdgeInsets.symmetric(horizontal: tileW * 0.42),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x2FFFFFFF), Color(0x14FFFFFF)],
                    ),
                    border: Border(
                      bottom: BorderSide(color: Color(0x338FA8E8), width: 0.8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        OkeyTileWidget.cardMode
                            ? '🃏 $tileCount'
                            : '🀄 $tileCount',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: tileW * 0.42,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      if (isTurn)
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: tileW * 0.3, vertical: tileW * 0.08),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'SIRA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: tileW * 0.36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              height: 1,
                            ),
                          ),
                        )
                      else
                        Text(
                          OkeyTileWidget.cardMode ? 'RUMMY' : 'OKEY',
                          style: TextStyle(
                            color: const Color(0xFF8FA8E8).withOpacity(0.62),
                            fontSize: tileW * 0.38,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            height: 1,
                          ),
                        ),
                    ],
                  ),
                ),

                // ── مساحة الرفين: أحجار مقلوبة بوجه الطاولة ──
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: tileW * 0.55, vertical: tileW * 0.16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _shelfRow(rowCount, tileW, tileH),
                      // الفاصل المعدني بين الرفين — نفس تدرّج استكانة اللاعب
                      Container(
                        height: tileW * 0.16,
                        margin: EdgeInsets.symmetric(vertical: tileW * 0.10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF0A0F22),
                              Color(0xFF5C6FA6),
                              Color(0xFF9FB4E8),
                              Color(0xFF5C6FA6),
                              Color(0xFF0A0F22),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.45),
                                blurRadius: 1.5,
                                offset: const Offset(0, 1)),
                          ],
                        ),
                      ),
                      _shelfRow(restCount, tileW, tileH),
                    ],
                  ),
                ),

                // ── قاعدة الحامل — شفة خشبية سفلية ──
                Container(
                  height: tileW * 0.30,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x14000000), Color(0x33000000)],
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0x1F8FA8E8), width: 0.7),
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

  /// صف أحجار مقلوبة داخل تجويف الرف الزجاجي
  Widget _shelfRow(int count, double tileW, double tileH) {
    return Container(
      height: tileH + 4,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x8C060A18), Color(0x8C040815)],
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (_) => Padding(
            padding: EdgeInsets.symmetric(horizontal: tileW * 0.06),
            child: _backTile(tileW, tileH),
          ),
        ),
      ),
    );
  }

  /// ظهر حجر/ورقة واحدة — يطابق مظهر ظهور الأحجار على الطاولة
  Widget _backTile(double w, double h) {
    if (OkeyTileWidget.cardMode) {
      // ظهر الورقة الكحلي (رامي) — نفس نمط _cardBack في شاشة اللعب
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2B4C8C), Color(0xFF1A2F5E), Color(0xFF101E42)],
          ),
          borderRadius: BorderRadius.circular(w * 0.14),
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 0.9),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 2,
                offset: const Offset(0, 1.5)),
          ],
        ),
        child: Center(
          child: Container(
            width: w * 0.55,
            height: w * 0.55,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54, width: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Text(
                '◆',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: w * 0.3,
                    height: 1),
              ),
            ),
          ),
        ),
      );
    }
    // ظهر الحجر العاجي (أوكي/كونكان) — نفس مظهر _tileBack
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFDF5), Color(0xFFEDE0C4), Color(0xFFD6C29E)],
        ),
        borderRadius: BorderRadius.circular(w * 0.12),
        border: Border.all(color: const Color(0xFFC4B28F), width: 0.7),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 2,
              offset: const Offset(0, 1.5)),
        ],
      ),
      child: Center(
        child: Container(
          width: w * 0.42,
          height: w * 0.42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFB89A62).withOpacity(0.7), width: 0.8),
          ),
        ),
      ),
    );
  }
}
