import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import 'animated_skin_effect.dart';
import 'skin_image.dart';

/// صورة المستخدم الشخصية — تدعم الإيموجي وروابط http وصور Base64 المرفوعة
/// وإطار الكسنة المجهّز من المتجر (فئة frame)
class UserAvatar extends StatelessWidget {
  final String photoUrl;
  final double size;
  final String name;

  /// عرض إطار الكسنة المجهّز للمستخدم الحالي حول الصورة
  final bool showEquippedFrame;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    this.size = 44,
    this.name = '',
    this.showEquippedFrame = false,
  });

  /// هل القيمة صورة مرفوعة (Base64 data URI)؟
  static bool isDataUri(String photo) => photo.startsWith('data:image');

  /// هل القيمة رابط صورة؟
  static bool isNetworkImage(String photo) =>
      photo.startsWith('http://') || photo.startsWith('https://');

  Widget _buildContent() {
    // صورة مرفوعة من الاستوديو
    if (isDataUri(photoUrl)) {
      try {
        final bytes = base64Decode(photoUrl.split(',').last);
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      } catch (_) {}
    }
    // رابط صورة
    if (isNetworkImage(photoUrl)) {
      return Image.network(photoUrl, fit: BoxFit.cover);
    }
    // إيموجي
    if (photoUrl.isNotEmpty && photoUrl.length <= 4) {
      return Center(
        child: Text(photoUrl, style: TextStyle(fontSize: size * 0.48)),
      );
    }
    // الحرف الأول من الاسم
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '🀄',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFEEA0), Color(0xFFFFD54F), Color(0xFFE58E00)],
        ),
      ),
      padding: EdgeInsets.all(size * 0.06),
      child: ClipOval(
        child: Container(
          color: const Color(0xFF5B3A82),
          child: _buildContent(),
        ),
      ),
    );

    if (!showEquippedFrame) return avatar;

    return AnimatedBuilder(
      animation: Listenable.merge([StoreService(), AuthService()]),
      builder: (context, _) {
        final frame = StoreService().equippedFor(StoreCategory.frame);
        if (frame == null ||
            (frame.imageBase64.isEmpty && frame.effect.isEmpty)) {
          return avatar;
        }
        // الإطار يحيط بالصورة — يمتد خارج حدودها قليلاً
        final outer = size * 1.30;
        final effect = skinEffectOf(frame);
        return SizedBox(
          width: outer,
          height: outer,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Center(child: avatar),
              IgnorePointer(
                child: effect != SkinEffect.none
                    ? AnimatedFrameRing(effect: effect, size: outer)
                    : SizedBox(
                        width: outer,
                        height: outer,
                        child: SkinTransformImage(
                          image: frame.provider,
                          zoom: frame.zoom,
                          offsetX: frame.offsetX,
                          offsetY: frame.offsetY,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
