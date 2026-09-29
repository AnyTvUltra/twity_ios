import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/broadcast_service.dart';
import '../services/social_service.dart';
import '../screens/chat_screen.dart';
import 'radio_player_widget.dart';
import 'user_avatar.dart';
import 'gem_icon.dart';
import '../utils/format.dart';
import '../theme_mode.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onCoinTap;
  final VoidCallback? onStoreTap;

  const AppHeader({
    super.key,
    this.onProfileTap,
    this.onCoinTap,
    this.onStoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  SizedBox(width: 8),

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
                  // Store Button
                  GestureDetector(
                    onTap: onStoreTap,
                    child: _HeaderGlassButton(
                      child: Icon(Icons.storefront_rounded,
                          color: L(0xFFA78BFA), size: 20),
                    ),
                  ),
                  SizedBox(width: 8),

                  // Radio Button
                  GestureDetector(
                    onTap: () => RadioPlayerSheet.show(context),
                    child: _HeaderGlassButton(
                      child: Icon(Icons.radio_rounded,
                          color: L(0xFFFFD76A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Notifications Bell (طلبات الصداقة + الرسائل غير المقروءة)
                  GestureDetector(
                    onTap: () => NotificationsSheet.show(context),
                    child: const _HeaderGlassButton(
                      child: _NotificationBellWidget(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderGlassButton extends StatelessWidget {
  final Widget child;

  const _HeaderGlassButton({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: UiTheme.transition,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: UiTheme.instance.isLight
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      L(0xFFFFFFFF).withOpacity(0.20),
                      L(0xFF6C63FF).withOpacity(0.10),
                      L(0xFF07142F).withOpacity(0.34),
                    ],
                  ),
            color: UiTheme.instance.isLight ? L(0xFFFFFFFF) : null,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
                color: UiTheme.instance.isLight
                    ? L(0xFFE4E9F2)
                    : L(0xFFFFFFFF).withOpacity(0.26)),
            boxShadow: UiTheme.instance.isLight
                ? [
                    BoxShadow(
                      color: L(0xFF111B3A).withOpacity(0.08),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: L(0xFF719BFF).withOpacity(0.12),
                      blurRadius: 12,
                    ),
                  ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _AvatarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final photo = user?.photoUrl ?? '';
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: L(0xFF000000).withOpacity(0.4),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
          BoxShadow(
            color: L(0xFFFFD54F).withOpacity(0.35),
            blurRadius: 8,
          ),
        ],
      ),
      child: UserAvatar(
        photoUrl: photo,
        name: user?.displayName ?? '',
        size: 44,
        showEquippedFrame: true,
      ),
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
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [L(0xFF6B4896), L(0xFF43266B)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawCircle(Offset(w / 2, h / 2), w / 2, bgPaint);

    // Blue shirt
    final shirtPaint = Paint()..color = L(0xFF3B82F6);
    final shirtPath = Path()
      ..moveTo(w * 0.15, h)
      ..quadraticBezierTo(w * 0.5, h * 0.68, w * 0.85, h)
      ..close();
    canvas.drawPath(shirtPath, shirtPaint);

    // Neck
    final skinPaint = Paint()..color = L(0xFFFFDCB5);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.4, h * 0.52, w * 0.2, h * 0.2), skinPaint);

    // Face
    final faceRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.45), width: w * 0.52, height: h * 0.5),
      const Radius.circular(12),
    );
    canvas.drawRRect(faceRect, skinPaint);

    // Eyes
    final eyePaint = Paint()..color = L(0xFF2C1810);
    canvas.drawCircle(Offset(w * 0.4, h * 0.45), 2.2, eyePaint);
    canvas.drawCircle(Offset(w * 0.6, h * 0.45), 2.2, eyePaint);

    // Smile
    final smilePaint = Paint()
      ..color = L(0xFF9E4733)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(w * 0.43, h * 0.56)
      ..quadraticBezierTo(w * 0.5, h * 0.62, w * 0.57, h * 0.56);
    canvas.drawPath(smilePath, smilePaint);

    // Hair (Dark Brown, trendy anime-like cut)
    final hairPaint = Paint()..color = L(0xFF3E2723);
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
    final day = UiTheme.instance.isLight;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: UiTheme.transition,
          height: 36,
          padding: EdgeInsets.only(left: 4, right: 6),
          decoration: BoxDecoration(
            gradient: day
                ? null
                : LinearGradient(
                    colors: [
                      L(0xFFFFFFFF).withOpacity(0.16),
                      L(0xFF182B59).withOpacity(0.46),
                    ],
                  ),
            color: day ? L(0xFFFFFFFF) : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: L(0xFFFFD76A).withOpacity(day ? 0.7 : 0.52),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: day
                    ? L(0xFF111B3A).withOpacity(0.08)
                    : L(0xFF000000).withOpacity(0.35),
                blurRadius: 6,
                offset: Offset(0, 2),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      L(0xFFFFF9C4),
                      L(0xFFFFD54F),
                      L(0xFFFF8F00),
                    ],
                  ),
                  border: Border.all(color: L(0xFFFFF59D), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: L(0xFFFF8F00).withOpacity(0.6),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.star_rounded,
                    color: L(0xFFBF360C),
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
                    formatBalance(chips),
                    style: TextStyle(
                      color: day ? L(0xFF111B3A) : L(0xFFFFFFFF),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                      shadows: day
                          ? null
                          : [
                              Shadow(
                                color: L(0x73000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                    ),
                  );
                },
              ),

              SizedBox(width: 6),

              // Purple "+" button
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [L(0xFF8B5CF6), L(0xFF6D28D9)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: L(0xFF8B5CF6).withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.add,
                    color: L(0xFFFFFFFF),
                    size: 14,
                  ),
                ),
              ),

              // فاصل + عداد المجوهرات 💎
              Container(
                width: 1,
                height: 18,
                margin: EdgeInsets.symmetric(horizontal: 6),
                color: day ? L(0x1F111B3A) : L(0xFFFFFFFF).withOpacity(0.18),
              ),
              const GemIcon(size: 20),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: AuthService(),
                builder: (context, _) {
                  final gems = AuthService().currentUser?.gems ?? 25;
                  return Text(
                    formatBalance(gems),
                    style: TextStyle(
                      color: day ? L(0xFF2F8EF5) : L(0xFF7DD3FC),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.5,
                      shadows: day
                          ? null
                          : [
                              Shadow(
                                color: L(0x73000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBellWidget extends StatelessWidget {
  const _NotificationBellWidget();

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';
    return StreamBuilder<List<FriendRequest>>(
      stream: SocialService().getIncomingRequestsStream(myUid),
      builder: (context, reqSnap) {
        final reqCount = reqSnap.data?.length ?? 0;
        return StreamBuilder<List<ConversationSummary>>(
          stream: SocialService().getConversationsStream(myUid),
          builder: (context, convSnap) {
            final unread =
                (convSnap.data ?? []).fold<int>(0, (s, c) => s + c.unreadCount);
            return ValueListenableBuilder<int>(
              valueListenable: BroadcastService.instance.unreadCount,
              builder: (context, broadcastUnread, _) {
                final total = reqCount + unread + broadcastUnread;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_rounded,
                        color: UiTheme.instance.isLight
                            ? L(0xFF111B3A)
                            : L(0xFFFFFFFF),
                        size: 20),
                    if (total > 0)
                      Positioned(
                        top: -4,
                        right: -5,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          constraints:
                              BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: L(0xFFFF1744),
                            border:
                                Border.all(color: L(0xFFFFFFFF), width: 1.2),
                            boxShadow: [
                              BoxShadow(color: L(0xFFFF1744), blurRadius: 4),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              total > 9 ? '9+' : '$total',
                              style: TextStyle(
                                  color: L(0xFFFFFFFF),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
