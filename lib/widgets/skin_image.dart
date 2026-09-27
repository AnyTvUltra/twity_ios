import 'package:flutter/material.dart';
import '../services/store_service.dart';

/// صورة كسنة مع دعم التكبير والإزاحة (تُقص داخل الحدود)
/// zoom: 1.0 = يغطي المساحة، أعلى = تكبير
/// offsetX/offsetY: إزاحة من المنتصف بمدى -1.0 إلى 1.0
class SkinTransformImage extends StatelessWidget {
  final ImageProvider image;
  final double zoom;
  final double offsetX;
  final double offsetY;

  const SkinTransformImage({
    super.key,
    required this.image,
    this.zoom = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });

  /// من عنصر متجر مباشرة
  factory SkinTransformImage.fromItem(StoreItem item, {Key? key}) {
    return SkinTransformImage(
      key: key,
      image: item.provider,
      zoom: item.zoom,
      offsetX: item.offsetX,
      offsetY: item.offsetY,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : constraints.biggest.width;
        final h = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : constraints.biggest.height;
        if (w <= 0 || h <= 0) return const SizedBox.shrink();
        return ClipRect(
          child: OverflowBox(
            minWidth: w,
            maxWidth: w,
            minHeight: h,
            maxHeight: h,
            child: Transform.translate(
              offset: Offset(offsetX * w / 2, offsetY * h / 2),
              child: Transform.scale(
                scale: zoom.clamp(0.5, 5.0),
                child: Image(
                  image: image,
                  width: w,
                  height: h,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
