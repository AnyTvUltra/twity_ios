import 'package:flutter/material.dart';
import '../okey_models.dart';
import '../../../services/store_service.dart';
import '../../../widgets/animated_skin_effect.dart';
import '../../../widgets/skin_image.dart';

/// مكون حجر الأوكي ثلاثي الأبعاد - مطابق تماماً لأحجار الصورة المرجعية
class OkeyTileWidget extends StatelessWidget {
  /// وضع الورق (رامي): كل حجر يُرسم كورقة لعب بشعار ورتبة بدل حجر الأوكي.
  /// تضبطه شاشة رامي عند الفتح وتصفّره عند الإغلاق.
  static bool cardMode = false;

  final OkeyTile? tile;
  final bool isSelected;
  final bool isDragging;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final double width;
  final double height;

  /// كسنة معروضة بدل المجهزة — لمعاينات المتجر بنفس شكل اللعبة
  final StoreItem? skinOverride;

  const OkeyTileWidget({
    super.key,
    required this.tile,
    this.isSelected = false,
    this.isDragging = false,
    this.isHighlighted = false,
    this.onTap,
    this.width = 28,
    this.height = 38,
    this.skinOverride,
  });

  @override
  Widget build(BuildContext context) {
    if (tile == null) {
      // خانة فارغة - تجويف زجاجي ناعم داخل الاستكانة
      return Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 1.0),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(4.5),
          border: Border.all(
            color: const Color(0x1AFFFFFF),
            width: 0.6,
          ),
        ),
      );
    }

    final t = tile!;
    if (cardMode) return _buildCard(t);
    final isOkey = t.isRealOkey;
    final isFake = t.isFalseJoker;
    final skinItem =
        skinOverride ?? StoreService().equippedFor(StoreCategory.tile);
    final hasAnimatedSkin =
        skinItem != null && skinEffectOf(skinItem) != SkinEffect.none;

    Widget tileWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, isSelected ? -7 : 0, 0),
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        gradient: skinItem == null
            ? const LinearGradient(
                // عاج فاخر شبه لامع (Premium Ivory Glass)
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFFBF6EA),
                  Color(0xFFF0E5CC),
                ],
                stops: [0.0, 0.45, 1.0],
              )
            : null,
        borderRadius: BorderRadius.circular(4.5),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFD54F)
              : isDragging
                  ? const Color(0xFF60A5FA)
                  : (isHighlighted
                      ? const Color(0xFF10B981)
                      : (isOkey
                          ? const Color(0xFFFFB300)
                          : const Color(0xFFCFC4A4))),
          width:
              isSelected ? 2.0 : (isHighlighted ? 1.6 : (isOkey ? 1.6 : 0.8)),
        ),
        boxShadow: [
          // ظل عمق ثلاثي الأبعاد
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFFD54F).withOpacity(0.55)
                : isDragging
                    ? const Color(0xFF3B82F6).withOpacity(0.5)
                    : (isHighlighted
                        ? const Color(0xFF10B981).withOpacity(0.5)
                        : Colors.black.withOpacity(0.38)),
            blurRadius:
                isSelected ? 8 : (isDragging ? 10 : (isHighlighted ? 6 : 3.5)),
            offset: Offset(0, isSelected ? 4 : (isDragging ? 5 : 2)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // كسنة الحجر مع التحويل (تغطي كامل الوجه) — أو تأثير متحرك
            if (skinItem != null)
              Positioned.fill(
                child: hasAnimatedSkin
                    ? AnimatedSkinLayer(
                        effect: skinEffectOf(skinItem),
                        intensity: isDragging ? 0.6 : (isSelected ? 0.3 : 0),
                      )
                    : SkinTransformImage.fromItem(skinItem),
              ),

            // لمعان علوي خفيف
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: height * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // محتوى الحجر: رقم واضح + نقطة ملونة أسفله
            if (isFake) ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: const Color(0xFFD97706),
                    size: width * 0.46,
                  ),
                  Text(
                    '★',
                    style: TextStyle(
                      fontSize: width * 0.28,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFD97706),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 1),
                  Text(
                    '${t.value}',
                    // الأرقام من خانتين (10-13) أصغر قليلاً فقط لتبقى
                    // سطراً واحداً بلا التفاف — بمقاس قريب من بقية الأرقام
                    softWrap: false,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: width * (t.value >= 10 ? 0.45 : 0.52),
                      fontWeight: FontWeight.w900,
                      // على السكنات المتحركة: بأليت ألوان مضيئة تحافظ على
                      // تمييز لون الحجر (الأسود→فضّي أبيض)
                      color:
                          hasAnimatedSkin ? t.color.brightColor : t.color.color,
                      height: 1.0,
                      shadows: hasAnimatedSkin
                          ? [
                              // هالة ملونة + حدود داكنة = وضوح كامل
                              Shadow(
                                color: t.color.brightColor.withOpacity(0.55),
                                blurRadius: 6,
                              ),
                              const Shadow(
                                color: Color(0xDD000000),
                                blurRadius: 1.5,
                                offset: Offset(0.6, 0.6),
                              ),
                            ]
                          : [
                              Shadow(
                                color: t.color.color.withOpacity(0.2),
                                blurRadius: 1,
                                offset: const Offset(0.5, 0.5),
                              ),
                            ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // نقطة لون الحجر — أكبر وأوضح على السكنات الداكنة
                  Container(
                    width: width * (hasAnimatedSkin ? 0.20 : 0.14),
                    height: width * (hasAnimatedSkin ? 0.20 : 0.14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          hasAnimatedSkin ? t.color.brightColor : t.color.color,
                      border: hasAnimatedSkin
                          ? Border.all(
                              color: Colors.black.withOpacity(0.55), width: 0.8)
                          : null,
                      boxShadow: hasAnimatedSkin
                          ? [
                              BoxShadow(
                                color: t.color.brightColor.withOpacity(0.6),
                                blurRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ],
              ),
            ],

            // شارة الأوكي الذهبي
            if (isOkey)
              Positioned(
                top: 1.5,
                right: 1.5,
                child: Container(
                  padding: const EdgeInsets.all(0.8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB300),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 7,
                  ),
                ),
              ),

            // حافة سفلية غامقة لتعطي بعد ثلاثي الأبعاد
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 2,
              child: Container(
                color: Colors.black.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: tileWidget);
    }
    return tileWidget;
  }

  // ─────────────────────────────────────────────────────────
  //  وضع الورق (رامي): نفس الحجر يُرسم كورقة لعب حقيقية
  // ─────────────────────────────────────────────────────────

  /// شعار الورقة: لون الحجر = شكل الورقة (أحمر♥ أصفر♦ أزرق♠ أسود♣)
  static String suitOf(OkeyTileColor c) {
    switch (c) {
      case OkeyTileColor.red:
        return '♥';
      case OkeyTileColor.yellow:
        return '♦';
      case OkeyTileColor.blue:
        return '♠';
      case OkeyTileColor.black:
        return '♣';
    }
  }

  /// حبر الورقة: القلوب والديناري حمراء، السباتي والبستوني سوداء
  static Color suitInkOf(OkeyTileColor c) =>
      (c == OkeyTileColor.red || c == OkeyTileColor.yellow)
          ? const Color(0xFFCE1B2B)
          : const Color(0xFF1F2430);

  /// رتبة الورقة: 1=A و11=J و12=Q و13=K
  static String rankOf(int v) => switch (v) {
        1 => 'A',
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        _ => '$v',
      };

  Widget _buildCard(OkeyTile t) {
    final isJoker = t.isFalseJoker;
    final ink = suitInkOf(t.color);
    final suit = suitOf(t.color);
    final rank = rankOf(t.value);

    Widget face = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFBF9F2), Color(0xFFEFEADB)],
        ),
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFD54F)
              : isDragging
                  ? const Color(0xFF60A5FA)
                  : isHighlighted
                      ? const Color(0xFF10B981)
                      : isJoker
                          ? const Color(0xFFE11D48)
                          : const Color(0xFFB9B2A0),
          width:
              isSelected ? 2.0 : (isHighlighted ? 1.6 : (isJoker ? 1.3 : 0.8)),
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFFFFD54F).withOpacity(0.55)
                : isDragging
                    ? const Color(0xFF3B82F6).withOpacity(0.5)
                    : (isHighlighted
                        ? const Color(0xFF10B981).withOpacity(0.5)
                        : Colors.black.withOpacity(0.35)),
            blurRadius:
                isSelected ? 8 : (isDragging ? 10 : (isHighlighted ? 6 : 3)),
            offset: Offset(0, isSelected ? 4 : (isDragging ? 5 : 1.5)),
          ),
        ],
      ),
      child: isJoker ? _jokerFace() : _cardFace(rank, suit, ink),
    );

    face = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, isSelected ? -7 : 0, 0),
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      child: face,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: face);
    }
    return face;
  }

  /// وجه ورقة عادية: رتبة+شعار في الزاوية العلوية وشعار كبير بالوسط
  Widget _cardFace(String rank, String suit, Color ink) {
    return Stack(
      children: [
        // ركن علوي يسار: الرتبة فوق الشعار المصغّر
        Positioned(
          top: height * 0.045,
          left: width * 0.08,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rank,
                style: TextStyle(
                  fontSize: width * 0.30,
                  fontWeight: FontWeight.w900,
                  color: ink,
                  height: 1.0,
                ),
              ),
              Text(
                suit,
                style: TextStyle(
                  fontSize: width * 0.26,
                  color: ink,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        // شعار كبير بالوسط
        Center(
          child: Padding(
            padding: EdgeInsets.only(top: height * 0.16),
            child: Text(
              suit,
              style: TextStyle(
                fontSize: width * 0.52,
                color: ink.withOpacity(0.92),
                height: 1.0,
              ),
            ),
          ),
        ),
        // لمعة علوية خفيفة
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height * 0.3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(width * 0.14)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// وجه الجوكر: شريط JOKER عمودي + نجمة
  Widget _jokerFace() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'J',
                style: TextStyle(
                  fontSize: width * 0.24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE11D48),
                  height: 1.05,
                ),
              ),
              Text(
                'O',
                style: TextStyle(
                  fontSize: width * 0.24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE11D48),
                  height: 1.05,
                ),
              ),
              Text(
                'K',
                style: TextStyle(
                  fontSize: width * 0.24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE11D48),
                  height: 1.05,
                ),
              ),
              Text(
                '★',
                style: TextStyle(
                  fontSize: width * 0.22,
                  color: const Color(0xFFF59E0B),
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
