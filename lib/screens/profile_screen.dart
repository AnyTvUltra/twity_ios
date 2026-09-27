import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/rewards_service.dart';
import '../services/social_service.dart';
import '../utils/haptics.dart';
import '../utils/format.dart';
import '../widgets/gem_icon.dart';
import '../utils/top_notification.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _bgTop = Color(0xFF0A0F24);
  static const _bgMid = Color(0xFF080C1C);
  static const _bgBot = Color(0xFF04060F);
  static const _neonBlue = Color(0xFF3B82F6);
  static const _cyan = Color(0xFF38BDF8);
  static const _gold = Color(0xFFFFD54F);
  static const _emerald = Color(0xFF34D399);
  static const _pink = Color(0xFFF472B6);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  void _showAvatarPicker(BuildContext context) {
    AppHaptics.selection();
    final avatars = [
      '🧑‍💼', '👑', '🦁', '🦅', '🥷', '🧙‍♂️', '🚀', '🎯', '🌟', '💎', '🔥', '🀄'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF2152150), Color(0xF20A0F24)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
              border:
                  Border.all(color: const Color(0x33FFFFFF), width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('اختر صورتك الرمزية',
                    style: TextStyle(
                        color: _textWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () async {
                      AppHaptics.medium();
                      try {
                        final file = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 256,
                          maxHeight: 256,
                          imageQuality: 72,
                        );
                        if (file == null) return;
                        final bytes = await file.readAsBytes();
                        final uri =
                            'data:image/jpeg;base64,${base64Encode(bytes)}';
                        await AuthService().updateProfile(photoUrl: uri);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          TopNotification.show(
                              context, 'تم رفع صورتك الشخصية بنجاح! 📷');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          TopNotification.show(
                              context, 'تعذر رفع الصورة: $e');
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFFE082),
                          _gold,
                          Color(0xFFE8A820),
                        ]),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFFFE9A8), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                              color: _gold.withOpacity(0.35),
                              blurRadius: 14),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_rounded,
                              color: Color(0xFF1B0B30), size: 19),
                          SizedBox(width: 8),
                          Text('رفع صورة من الاستوديو',
                              style: TextStyle(
                                  color: Color(0xFF1B0B30),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                    height: 1,
                    color: const Color(0x1FFFFFFF)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: avatars.map((emoji) {
                    return GestureDetector(
                      onTap: () async {
                        AppHaptics.medium();
                        await AuthService().updateProfile(photoUrl: emoji);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          TopNotification.show(context,
                              'تم تحديث الصورة الشخصية بنجاح! $emoji');
                        }
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(colors: [
                            Color(0xFF26335E),
                            Color(0xFF131B36),
                          ]),
                          border: Border.all(
                              color: _gold.withOpacity(0.6), width: 1.4),
                          boxShadow: [
                            BoxShadow(
                                color: _gold.withOpacity(0.2),
                                blurRadius: 10),
                          ],
                        ),
                        child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 26))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSupportTicketDialog(BuildContext context) {
    AppHaptics.medium();
    String category = 'اقتراح تحسين';
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: LightGlass.cardStrong,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.support_agent_rounded,
                  color: _gold, size: 24),
              SizedBox(width: 8),
              Text('المساعدة والاقتراحات 🎫',
                  style: TextStyle(
                      color: LightGlass.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نوع التذكرة:',
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: LightGlass.cardStrong,
                  style: const TextStyle(
                      color: LightGlass.text, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: LightGlass.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: [
                    'اقتراح تحسين',
                    'مشكلة تقنية في اللعبة',
                    'استفسار عن العملات',
                    'أخرى'
                  ]
                      .map((s) =>
                          DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('عنوان الموضوع:',
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: subjectController,
                  style: const TextStyle(
                      color: LightGlass.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'مثال: اقتراح إضافة وضع لعب جديد...',
                    hintStyle: const TextStyle(
                        color: LightGlass.textFaint, fontSize: 12),
                    filled: true,
                    fillColor: LightGlass.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('التفاصيل:',
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  style: const TextStyle(
                      color: LightGlass.text, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText:
                        'اشرح تفاصيل اقتراحك أو المشكلة التي واجهتك بالتفصيل...',
                    hintStyle: const TextStyle(
                        color: LightGlass.textFaint, fontSize: 12),
                    filled: true,
                    fillColor: LightGlass.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء',
                  style: TextStyle(color: LightGlass.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: const Color(0xFF1B0B30),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final user = AuthService().currentUser;
                if (user == null ||
                    subjectController.text.trim().isEmpty ||
                    messageController.text.trim().isEmpty) {
                  return;
                }
                await SocialService().submitSupportTicket(
                  uid: user.uid,
                  username: user.username,
                  subject: subjectController.text.trim(),
                  message: messageController.text.trim(),
                  category: category,
                );
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  TopNotification.show(
                    context,
                    'تم إرسال تذكرتك بنجاح! سيتم الرد عليك من قبل فريق الدعم.',
                    icon: Icons.check_circle_rounded,
                  );
                }
              },
              child: const Text('إرسال التذكرة 🚀',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUsernameDialog(BuildContext context) {
    AppHaptics.selection();
    final controller = TextEditingController(
        text: AuthService().currentUser?.username ?? '');
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: LightGlass.cardStrong,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('تغيير اسم المستخدم الفريد',
              style: TextStyle(
                  color: LightGlass.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: LightGlass.text),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.alternate_email_rounded,
                      color: _gold),
                  hintText: 'اسم المستخدم الجديد',
                  errorText: error,
                  filled: true,
                  fillColor: LightGlass.inputFill,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء',
                    style: TextStyle(color: LightGlass.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF1B0B30)),
              onPressed: () async {
                final input = controller.text.trim();
                final ok = await AuthService().updateUsername(input);
                if (ok) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    TopNotification.show(
                        context, 'تم تغيير اسم المستخدم إلى @$input!');
                  }
                } else {
                  setDialogState(
                      () => error = 'الاسم غير متوفر أو قصير جداً');
                }
              },
              child: const Text('حفظ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgMid, _bgBot],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _ProfileDecorPainter())),
          SafeArea(
            bottom: false,
            child: AnimatedBuilder(
              animation: AuthService(),
              builder: (context, _) {
                final user = AuthService().currentUser;
                final isGuest = user?.email.isEmpty ?? true;
                final totalMatches = (user?.wins ?? 0) + (user?.losses ?? 0);
                final winRate = totalMatches > 0
                    ? (((user?.wins ?? 0) / totalMatches) * 100)
                        .toStringAsFixed(1)
                    : '0.0';

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    children: [
                      // ═══ الهيدر ═══
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'الملف الشخصي',
                                style: TextStyle(
                                  color: _textWhite,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                        color: Color(0x33FFFFFF),
                                        blurRadius: 10),
                                  ],
                                ),
                              ),
                            ),
                            _glassIcon(
                                Icons.help_outline_rounded, _gold,
                                () => _showSupportTicketDialog(context)),
                            const SizedBox(width: 8),
                            _glassIcon(Icons.logout_rounded, _textDim,
                                () async {
                              AppHaptics.medium();
                              await AuthService().signOut();
                            }),
                          ],
                        ),
                      ),

                      // ═══ بطاقة اللاعب الرئيسية ═══
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF1B2A5E)
                                        .withOpacity(0.55),
                                    const Color(0xFF101838)
                                        .withOpacity(0.45),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(30),
                                border: Border.all(
                                    color: _gold.withOpacity(0.45),
                                    width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                      color: _gold.withOpacity(0.14),
                                      blurRadius: 26,
                                      spreadRadius: -4),
                                  BoxShadow(
                                      color:
                                          Colors.black.withOpacity(0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8)),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // انعكاس ضوئي علوي
                                  Positioned(
                                    top: 0,
                                    left: 30,
                                    right: 30,
                                    height: 1.5,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.white
                                                .withOpacity(0.35),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Row(
                                        children: [
                                          // الصورة الرمزية الذهبية
                                          GestureDetector(
                                            onTap: () =>
                                                _showAvatarPicker(
                                                    context),
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Container(
                                                  decoration:
                                                      BoxDecoration(
                                                    shape:
                                                        BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: _gold
                                                            .withOpacity(
                                                                0.45),
                                                        blurRadius: 20,
                                                        spreadRadius:
                                                            -2,
                                                      ),
                                                    ],
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .all(3),
                                                    decoration:
                                                        BoxDecoration(
                                                      shape: BoxShape
                                                          .circle,
                                                      border: Border.all(
                                                          color: _gold,
                                                          width: 2),
                                                    ),
                                                    child: UserAvatar(
                                                      photoUrl: user
                                                              ?.photoUrl ??
                                                          '',
                                                      name: user
                                                              ?.displayName ??
                                                          '',
                                                      size: 72,
                                                      showEquippedFrame:
                                                          true,
                                                    ),
                                                  ),
                                                ),
                                                Positioned(
                                                  bottom: -2,
                                                  right: -2,
                                                  child: Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration:
                                                        BoxDecoration(
                                                      shape: BoxShape
                                                          .circle,
                                                      gradient:
                                                          const LinearGradient(
                                                              colors: [
                                                            Color(
                                                                0xFFFFE082),
                                                            _gold,
                                                          ]),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFF0A0F24),
                                                          width: 2),
                                                      boxShadow: [
                                                        BoxShadow(
                                                            color: _gold
                                                                .withOpacity(
                                                                    0.5),
                                                            blurRadius:
                                                                8),
                                                      ],
                                                    ),
                                                    child: const Icon(
                                                        Icons
                                                            .edit_rounded,
                                                        size: 12,
                                                        color: Color(
                                                            0xFF1B0B30)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),

                                          // المعلومات
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  user?.displayName ??
                                                      'لاعب',
                                                  style: const TextStyle(
                                                      color: _textWhite,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight
                                                              .w900),
                                                ),
                                                const SizedBox(
                                                    height: 2),
                                                GestureDetector(
                                                  onTap: () =>
                                                      _showEditUsernameDialog(
                                                          context),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize
                                                            .min,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          '@${user?.username ?? ''}',
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: const TextStyle(
                                                              color:
                                                                  _gold,
                                                              fontSize:
                                                                  12.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w800),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          width: 4),
                                                      const Icon(
                                                          Icons
                                                              .edit_rounded,
                                                          color:
                                                              _textDim,
                                                          size: 13),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(
                                                    height: 7),
                                                // شارة التوثيق الزجاجية
                                                Container(
                                                  padding:
                                                      const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                              9,
                                                          vertical:
                                                              3.5),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: _emerald
                                                        .withOpacity(
                                                            0.12),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                                10),
                                                    border: Border.all(
                                                        color: _emerald
                                                            .withOpacity(
                                                                0.55),
                                                        width: 1),
                                                    boxShadow: [
                                                      BoxShadow(
                                                          color: _emerald
                                                              .withOpacity(
                                                                  0.15),
                                                          blurRadius:
                                                              8),
                                                    ],
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize
                                                            .min,
                                                    children: [
                                                      Icon(
                                                          isGuest
                                                              ? Icons
                                                                  .person_outline_rounded
                                                              : Icons
                                                                  .verified_rounded,
                                                          color:
                                                              _emerald,
                                                          size: 12),
                                                      const SizedBox(
                                                          width: 4),
                                                      Text(
                                                        isGuest
                                                            ? 'حساب ضيف'
                                                            : 'حساب Google موثق ✓',
                                                        style: const TextStyle(
                                                            color:
                                                                _emerald,
                                                            fontSize:
                                                                10,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w800),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 16),
                                      Container(
                                          height: 1,
                                          color: const Color(
                                              0x1FFFFFFF)),
                                      const SizedBox(height: 14),

                                      // ═══ الإحصائيات المصغرة ═══
                                      Row(
                                        children: [
                                          _miniStat(
                                              'العملات',
                                              formatBalance(
                                                  user?.chips ?? 0),
                                              _gold,
                                              icon: const Icon(
                                                  Icons
                                                      .paid_rounded,
                                                  color: _gold,
                                                  size: 17)),
                                          _miniStat(
                                              'الجواهر',
                                              formatBalance(
                                                  user?.gems ?? 0),
                                              _cyan,
                                              icon: const GemIcon(
                                                  size: 15)),
                                          _miniStat(
                                              'التقييم',
                                              '${user?.rating ?? 1200}',
                                              const Color(
                                                  0xFF60A5FA),
                                              icon: const Icon(
                                                  Icons
                                                      .star_rounded,
                                                  color: Color(
                                                      0xFF60A5FA),
                                                  size: 17)),
                                          _miniStat(
                                              'المستوى',
                                              '${user?.level ?? 1}',
                                              _gold,
                                              icon: const Icon(
                                                  Icons
                                                      .emoji_events_rounded,
                                                  color: _gold,
                                                  size: 17)),
                                          _miniStat(
                                              'نسبة الفوز',
                                              '$winRate%',
                                              _pink,
                                              icon: const Icon(
                                                  Icons
                                                      .local_fire_department_rounded,
                                                  color: _pink,
                                                  size: 17)),
                                          _miniStat(
                                              'الرتبة',
                                              '${Ranks.of(user?.rating ?? 1200).emoji} ${Ranks.of(user?.rating ?? 1200).name}',
                                              Color(Ranks.of(
                                                      user?.rating ??
                                                          1200)
                                                  .color),
                                              icon: Icon(
                                                  Icons
                                                      .military_tech_rounded,
                                                  color: Color(Ranks
                                                          .of(user?.rating ??
                                                              1200)
                                                      .color),
                                                  size: 17)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ═══ الإحالة والإهداء 🤝 ═══
                      const _SocialRewardsCard(),
                      const SizedBox(height: 18),

                      // ═══ قائمة الإعدادات الزجاجية ═══
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: 14, sigmaY: 14),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0x2E141C3C),
                                borderRadius:
                                    BorderRadius.circular(26),
                                border: Border.all(
                                    color: const Color(0x26FFFFFF),
                                    width: 1),
                              ),
                              child: Column(
                                children: [
                                  _SettingsTile(
                                    icon:
                                        Icons.headset_mic_rounded,
                                    iconColor: _gold,
                                    title:
                                        'المساعدة والاقتراحات (فتح تذكرة دعم)',
                                    subtitle:
                                        'تواصل مباشرة مع إدارة التطبيق للاقتراحات والمشاكل',
                                    onTap: () =>
                                        _showSupportTicketDialog(
                                            context),
                                  ),
                                  _glassDivider(),
                                  _SettingsTile(
                                    icon: Icons.badge_rounded,
                                    iconColor: _neonBlue,
                                    title:
                                        'تغيير اسم المستخدم الفريد',
                                    subtitle:
                                        'اختر اسماً فريداً ليجدك أصدقاؤك بسهولة',
                                    onTap: () =>
                                        _showEditUsernameDialog(
                                            context),
                                  ),
                                  _glassDivider(),
                                  _SettingsTile(
                                    icon: Icons
                                        .photo_library_rounded,
                                    iconColor: _pink,
                                    title: 'اختيار صورة شخصية',
                                    subtitle:
                                        'رمز تعبيري مميز يظهر للجميع على طاولات اللعب',
                                    onTap: () =>
                                        _showAvatarPicker(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0x26FFFFFF), width: 1),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color,
      {required Widget icon}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: color.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.10), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style:
                    const TextStyle(color: _textDim, fontSize: 9.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassDivider() {
    return Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: const Color(0x14FFFFFF));
  }
}

/// صف إعدادات قابل للضغط بتأثير Scale/Glow
class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: _pressed ? 0.9 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                          color: widget.iconColor.withOpacity(0.15),
                          blurRadius: 14),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: widget.iconColor.withOpacity(0.4),
                        width: 1),
                    boxShadow: [
                      BoxShadow(
                          color:
                              widget.iconColor.withOpacity(0.15),
                          blurRadius: 8),
                    ],
                  ),
                  child: Icon(widget.icon,
                      color: widget.iconColor, size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                            color: Color(0xFFF1F5FF),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                            color: Color(0xFF8EA3C8),
                            fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: widget.iconColor.withOpacity(0.6),
                    size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDecorPainter extends CustomPainter {
  const _ProfileDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color color, double o) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [color.withOpacity(o), Colors.transparent],
            ).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    glow(Offset(size.width * 0.85, size.height * 0.05),
        size.width * 0.55, const Color(0xFF2540A0), 0.30);
    glow(Offset(size.width * 0.05, size.height * 0.35),
        size.width * 0.45, const Color(0xFF7C5CFF), 0.14);
    glow(Offset(size.width * 0.5, size.height * 1.05),
        size.width * 0.65, const Color(0xFF8A6400), 0.14);

    // أقواس هندسية ذهبية شفافة في الأسفل
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      arcPaint.color =
          const Color(0xFFFFD54F).withOpacity(0.04 + i * 0.013);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 1.15),
          width: size.width * (0.9 + i * 0.35),
          height: size.height * (0.35 + i * 0.14),
        ),
        3.6,
        5.0,
        false,
        arcPaint,
      );
    }

    // خطوط نيلية شفافة في الأعلى
    final linePaint = Paint()
      ..color = const Color(0xFF9DB7FF).withOpacity(0.03)
      ..strokeWidth = 1.0;
    for (double y = size.height * 0.12;
        y < size.height * 0.4;
        y += size.height * 0.09) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(_ProfileDecorPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════
// بطاقة الإحالة والإهداء — كود الدعوة + إرسال عملات لصديق
// ══════════════════════════════════════════════════════════════
class _SocialRewardsCard extends StatelessWidget {
  const _SocialRewardsCard();

  static const _gold = Color(0xFFFFD54F);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);
  static const _cyan = Color(0xFF38BDF8);

  Future<void> _redeemReferral(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF141C34),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: _cyan.withOpacity(0.4))),
          title: const Text('استبدال كود الإحالة',
              style: TextStyle(
                  color: _textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: _textWhite),
            decoration: InputDecoration(
              hintText: 'اسم المستخدم لصديقك',
              hintStyle: const TextStyle(color: _textDim, fontSize: 12),
              filled: true,
              fillColor: const Color(0x2E141C3C),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء', style: TextStyle(color: _textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _cyan,
                  foregroundColor: const Color(0xFF082F49)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('استبدال',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final res = await AuthService().redeemReferral(ctrl.text);
    if (context.mounted) {
      TopNotification.show(context, res['message'] as String,
          icon: res['success'] == true
              ? Icons.handshake_rounded
              : Icons.warning_rounded);
    }
  }

  Future<void> _sendGift(BuildContext context) async {
    final userCtrl = TextEditingController();
    final chipsCtrl = TextEditingController(text: '500');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF141C34),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: _gold.withOpacity(0.4))),
          title: const Text('🎁 إرسال هدية لصديق',
              style: TextStyle(
                  color: _textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: _textWhite),
                decoration: InputDecoration(
                  labelText: 'اسم المستخدم (@username)',
                  labelStyle: const TextStyle(color: _textDim, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0x2E141C3C),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: chipsCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: _textWhite),
                decoration: InputDecoration(
                  labelText: 'العملات 🪙 (50 — 10000)',
                  labelStyle: const TextStyle(color: _textDim, fontSize: 12),
                  filled: true,
                  fillColor: const Color(0x2E141C3C),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء', style: TextStyle(color: _textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: const Color(0xFF1B0B30)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('أرسل 🎁',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final chips = int.tryParse(chipsCtrl.text.trim()) ?? 0;
    final res = await AuthService().sendGift(userCtrl.text, chips);
    if (context.mounted) {
      TopNotification.show(context, res['message'] as String,
          icon: res['success'] == true
              ? Icons.card_giftcard_rounded
              : Icons.warning_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = AuthService().referralCode ?? '—';
    final alreadyReferred = AuthService().currentUser?.referredBy != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x2E141C3C),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _cyan.withOpacity(0.35), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🤝', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('ادعُ أصدقاءك واكسبوا معاً',
                        style: TextStyle(
                            color: _textWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'صديقك يُدخل كودك ← هو +300🪙 وأنت +500🪙 تصلك عند دخوله',
                  style: TextStyle(color: _textDim, fontSize: 10.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          AppHaptics.light();
                          await Clipboard.setData(ClipboardData(text: code));
                          if (context.mounted) {
                            TopNotification.show(
                                context, 'نُسخ كودك: $code 📋');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: _cyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: _cyan.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.copy_rounded,
                                  color: _cyan, size: 15),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'كودك: @$code',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _cyan,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: alreadyReferred
                          ? () {
                              TopNotification.show(context,
                                  'استخدمت كود إحالة مسبقاً ✅');
                            }
                          : () => _redeemReferral(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: alreadyReferred
                              ? const Color(0x2EFFFFFF)
                              : _gold.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: alreadyReferred
                                  ? Colors.white24
                                  : _gold.withOpacity(0.5)),
                        ),
                        child: Text(
                          alreadyReferred ? 'مفعّل ✓' : 'عندي كود صديق',
                          style: TextStyle(
                              color:
                                  alreadyReferred ? _textDim : _gold,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _sendGift(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _gold.withOpacity(0.9),
                        const Color(0xFFE8A820),
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: _gold.withOpacity(0.3),
                            blurRadius: 10),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '🎁 أرسل عملات هدية لصديق',
                        style: TextStyle(
                            color: Color(0xFF1B0B30),
                            fontSize: 12,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
