import 'package:flutter/material.dart';
import '../okey_models.dart';

/// مكون حجر الأوكي ثلاثي الأبعاد - مطابق تماماً لأحجار الصورة المرجعية
class OkeyTileWidget extends StatelessWidget {
  final OkeyTile? tile;
  final bool isSelected;
  final bool isDragging;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const OkeyTileWidget({
    super.key,
    required this.tile,
    this.isSelected = false,
    this.isDragging = false,
    this.isHighlighted = false,
    this.onTap,
    this.width = 28,
    this.height = 38,
  });


  @override
  Widget build(BuildContext context) {
    if (tile == null) {
      // خانة فارغة - تجويف ناعم داخل الرف الخشبي
      return Container(
        width: width,
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 1.0),
        decoration: BoxDecoration(
          color: const Color(0x18000000),
          borderRadius: BorderRadius.circular(3.5),
          border: Border.all(
            color: const Color(0x22FFFFFF),
            width: 0.6,
          ),
        ),
      );
    }

    final t = tile!;
    final isOkey = t.isRealOkey;
    final isFake = t.isFalseJoker;

    Widget tileWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, isSelected ? -7 : 0, 0),
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        // لون عاجي كلاسيكي مع تدرج إضاءة ناعم
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFDF8),
            Color(0xFFFBF6EA),
            Color(0xFFF3EAD5),
          ],
          stops: [0.0, 0.45, 1.0],
        ),
        borderRadius: BorderRadius.circular(3.5),
        border: Border.all(
          color: isSelected
              ? const Color(0xFFFFD54F)
              : isDragging
                  ? const Color(0xFF60A5FA)
                  : (isHighlighted
                      ? const Color(0xFF10B981)
                      : (isOkey ? const Color(0xFFFFB300) : const Color(0xFFD8CFBA))),
          width: isSelected ? 2.0 : (isHighlighted ? 1.6 : (isOkey ? 1.6 : 0.8)),
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
            blurRadius: isSelected ? 8 : (isDragging ? 10 : (isHighlighted ? 6 : 3.5)),
            offset: Offset(0, isSelected ? 4 : (isDragging ? 5 : 2)),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          alignment: Alignment.center,
          children: [
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
                    style: TextStyle(
                      fontSize: width * 0.52,
                      fontWeight: FontWeight.w900,
                      color: t.color.color,
                      height: 1.0,
                      shadows: [
                        Shadow(
                          color: t.color.color.withOpacity(0.2),
                          blurRadius: 1,
                          offset: const Offset(0.5, 0.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // نقطة دائرية ملونة أسفل الرقم مثل الصورة
                  Container(
                    width: width * 0.14,
                    height: width * 0.14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.color.color,
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
}
