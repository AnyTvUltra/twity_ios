import 'package:flutter/material.dart';

/// نص يُستبدل فيه كل إيموجي 🪙 بعملة [CoinIcon] الذهبية — يبقى النص
/// المترجم كما هو ويختفي اختلاف لون الإيموجي بين الأجهزة
Widget coinText(String text,
    {TextStyle? style, double? coinSize, TextAlign? textAlign, int? maxLines}) {
  final parts = text.split('🪙');
  final size = coinSize ?? ((style?.fontSize ?? 13) * 1.05);
  return Text.rich(
    TextSpan(children: [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: CoinIcon(size: size),
            ),
          ),
        TextSpan(text: parts[i]),
      ],
    ]),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: maxLines != null ? TextOverflow.ellipsis : null,
  );
}

/// العملة الذهبية الموحّدة في التطبيق — نفس عملة شريط الرصيد العلوي.
/// تُستخدم بدل إيموجي 🪙 الذي يظهر رصاصياً على بعض الأجهزة
class CoinIcon extends StatelessWidget {
  final double size;

  const CoinIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFF8F00)],
        ),
        border: Border.all(
            color: const Color(0xFFFFF59D), width: size < 18 ? 0.7 : 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withValues(alpha: 0.55),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: Center(
        child: Icon(Icons.star_rounded,
            color: const Color(0xFFBF360C), size: size * 0.62),
      ),
    );
  }
}
