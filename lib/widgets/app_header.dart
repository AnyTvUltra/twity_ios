import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'radio_player_widget.dart';


class AppHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onCoinTap;
  final VoidCallback? onGiftTap;
  final VoidCallback? onSettingsTap;

  const AppHeader({
    super.key,
    this.onProfileTap,
    this.onCoinTap,
    this.onGiftTap,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Avatar + Coin Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              GestureDetector(
                onTap: onProfileTap,
                child: _AvatarWidget(),
              ),
              const SizedBox(width: 8),

              // Coin Balance Pill
              GestureDetector(
                onTap: onCoinTap,
                child: _CoinBadgeWidget(),
              ),
            ],
          ),

          // Right side: Radio Button + Gift Icon + Settings Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Radio Button
              GestureDetector(
                onTap: () => RadioPlayerSheet.show(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xE625143E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x40FFD54F), width: 1),
                  ),
                  child: const Center(child: Icon(Icons.radio_rounded, color: Color(0xFFFFD54F), size: 20)),
                ),
              ),
              const SizedBox(width: 8),

              // Gift Box
              GestureDetector(
                onTap: onGiftTap,
                child: _GiftBoxWidget(),
              ),
              const SizedBox(width: 8),

              // Settings Gear
              GestureDetector(
                onTap: onSettingsTap,
                child: _SettingsGearWidget(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _AvatarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService(),
      builder: (context, _) {
        final photo = AuthService().currentUser?.photoUrl ?? '';
        final isEmoji = photo.isNotEmpty && photo.length <= 4;

        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFEEA0),
                Color(0xFFFFD54F),
                Color(0xFFE58E00),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: const Color(0xFFFFD54F).withOpacity(0.35),
                blurRadius: 8,
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: ClipOval(
            child: Container(
              color: const Color(0xFF5B3A82),
              child: isEmoji
                  ? Center(child: Text(photo, style: const TextStyle(fontSize: 20)))
                  : CustomPaint(
                      painter: _BoyAvatarPainter(),
                    ),
            ),
          ),
        );
      },
    );
  }
}


class _BoyAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background circle gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6B4896), Color(0xFF43266B)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawCircle(Offset(w / 2, h / 2), w / 2, bgPaint);

    // Blue shirt
    final shirtPaint = Paint()..color = const Color(0xFF3B82F6);
    final shirtPath = Path()
      ..moveTo(w * 0.15, h)
      ..quadraticBezierTo(w * 0.5, h * 0.68, w * 0.85, h)
      ..close();
    canvas.drawPath(shirtPath, shirtPaint);

    // Neck
    final skinPaint = Paint()..color = const Color(0xFFFFDCB5);
    canvas.drawRect(Rect.fromLTWH(w * 0.4, h * 0.52, w * 0.2, h * 0.2), skinPaint);

    // Face
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.45), width: w * 0.52, height: h * 0.5),
      const Radius.circular(12),
    );
    canvas.drawRRect(faceRect, skinPaint);

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF2C1810);
    canvas.drawCircle(Offset(w * 0.4, h * 0.45), 2.2, eyePaint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.45), 2.2, eyePaint);

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFF9E4733)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(w * 0.43, h * 0.56)
      ..quadraticBezierTo(w * 0.5, h * 0.62, w * 0.57, h * 0.56);
    canvas.drawPath(smilePath, smilePaint);

    // Hair (Dark Brown, trendy anime-like cut)
    final hairPaint = Paint()..color = const Color(0xFF3E2723);
    final hairPath = Path()
      ..moveTo(w * 0.18, h * 0.45)
      ..quadraticBezierTo(w * 0.16, h * 0.18, w * 0.5, h * 0.16)
      ..quadraticBezierTo(w * 0.84, h * 0.18, w * 0.82, h * 0.45)
      ..lineTo(w * 0.72, h * 0.38)
      ..lineTo(w * 0.62, h * 0.32)
      ..lineTo(w * 0.5, h * 0.35)
      ..lineTo(w * 0.38, h * 0.3)
      ..lineTo(w * 0.28, h * 0.38)
      ..close();
    canvas.drawPath(hairPath, hairPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CoinBadgeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.only(left: 4, right: 6),
      decoration: BoxDecoration(
        color: const Color(0xE625143E),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0x40FFD54F),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3D Gold Coin
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF9C4),
                  Color(0xFFFFD54F),
                  Color(0xFFFF8F00),
                ],
              ),
              border: Border.all(color: const Color(0xFFFFF59D), width: 1),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF8F00).withOpacity(0.6),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.star_rounded,
                color: Color(0xFFBF360C),
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Balance Text
          AnimatedBuilder(
            animation: AuthService(),
            builder: (context, _) {
              final chips = AuthService().currentUser?.chips ?? 1500;
              return Text(
                '$chips',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 6),

          // Purple "+" button
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.5),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftBoxWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF2E1B4E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0x33FFD54F),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF3CD),
                    Color(0xFFFFD54F),
                    Color(0xFFFFB300),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vertical red ribbon
                  Container(
                    width: 5,
                    height: 26,
                    color: const Color(0xFFE53935),
                  ),
                  // Horizontal red ribbon
                  Container(
                    width: 26,
                    height: 5,
                    color: const Color(0xFFE53935),
                  ),
                  // Bow on top
                  Positioned(
                    top: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 1),
                        Container(
                          width: 6,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF5350),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Red notification dot at top-right
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF1744),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFFFF1744),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsGearWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4A2B78),
            Color(0xFF311756),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0x33A78BFA),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.settings_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

