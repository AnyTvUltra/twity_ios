import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/app_background.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showAvatarPicker(BuildContext context) {
    AppHaptics.selection();
    final avatars = ['🧑‍💼', '👑', '🦁', '🦅', '🥷', '🧙‍♂️', '🚀', '🎯', '🌟', '💎', '🔥', '🀄'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF24143D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('اختر صورتك الرمزية', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: avatars.map((emoji) {
                return GestureDetector(
                  onTap: () async {
                    AppHaptics.medium();
                    await AuthService().updateProfile(photoUrl: emoji);
                    Navigator.of(ctx).pop();
                    TopNotification.show(context, 'تم تحديث الصورة الشخصية بنجاح! $emoji');
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B1E6D),
                      border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                    ),
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
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
          backgroundColor: const Color(0xFF24143D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2),
          ),
          title: const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: Color(0xFFFFD54F), size: 24),
              SizedBox(width: 8),
              Text('المساعدة والاقتراحات 🎫', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نوع التذكرة:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: const Color(0xFF1B0B30),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: ['اقتراح تحسين', 'مشكلة تقنية في اللعبة', 'استفسار عن العملات', 'أخرى']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('عنوان الموضوع:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: subjectController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'مثال: اقتراح إضافة وضع لعب جديد...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('التفاصيل:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'اشرح تفاصيل اقتراحك أو المشكلة التي واجهتك بالتفصيل...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD54F),
                foregroundColor: const Color(0xFF1B0B30),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final user = AuthService().currentUser;
                if (user == null || subjectController.text.trim().isEmpty || messageController.text.trim().isEmpty) {
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
              child: const Text('إرسال التذكرة 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUsernameDialog(BuildContext context) {
    AppHaptics.selection();
    final controller = TextEditingController(text: AuthService().currentUser?.username ?? '');
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF24143D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تغيير اسم المستخدم الفريد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFFFFD54F)),
                  hintText: 'اسم المستخدم الجديد',
                  errorText: error,
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء', style: TextStyle(color: Colors.white60))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: const Color(0xFF1B0B30)),
              onPressed: () async {
                final input = controller.text.trim();
                final ok = await AuthService().updateUsername(input);
                if (ok) {
                  Navigator.of(ctx).pop();
                  TopNotification.show(context, 'تم تغيير اسم المستخدم إلى @$input!');
                } else {
                  setDialogState(() => error = 'الاسم غير متوفر أو قصير جداً');
                }
              },
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: AuthService(),
          builder: (context, _) {
            final user = AuthService().currentUser;
            final isGuest = user?.email.isEmpty ?? true;
            final totalMatches = (user?.wins ?? 0) + (user?.losses ?? 0);
            final winRate = totalMatches > 0 ? (((user?.wins ?? 0) / totalMatches) * 100).toStringAsFixed(1) : '0.0';

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                children: [
                  // Top Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الملف الشخصي',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        Row(
                          children: [
                            // Support ticket button
                            IconButton(
                              icon: const Icon(Icons.help_outline_rounded, color: Color(0xFFFFD54F), size: 24),
                              tooltip: 'المساعدة والدعم',
                              onPressed: () => _showSupportTicketDialog(context),
                            ),
                            // Logout button
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 22),
                              tooltip: 'تسجيل الخروج',
                              onPressed: () async {
                                AppHaptics.medium();
                                await AuthService().signOut();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Hero Profile Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B1E6D), Color(0xFF241242), Color(0xFF1E0E38)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0x60FFD54F), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFFFD54F).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar
                              GestureDetector(
                                onTap: () => _showAvatarPicker(context),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFEEA0), Color(0xFFFFB300), Color(0xFFE58E00)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(color: const Color(0xFFFFB300).withOpacity(0.5), blurRadius: 10),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: ClipOval(
                                        child: Container(
                                          color: const Color(0xFF5B3A82),
                                          child: Center(
                                            child: Text(
                                              user?.photoUrl.isNotEmpty == true && user!.photoUrl.length <= 4
                                                  ? user.photoUrl
                                                  : '🀄',
                                              style: const TextStyle(fontSize: 34),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xFFFFD54F),
                                        ),
                                        child: const Icon(Icons.edit, size: 12, color: Color(0xFF160926)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.displayName ?? 'لاعب',
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    GestureDetector(
                                      onTap: () => _showEditUsernameDialog(context),
                                      child: Row(
                                        children: [
                                          Text(
                                            '@${user?.username ?? ''}',
                                            style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 12.5, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.edit_rounded, color: Colors.white38, size: 13),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0x334ADE80),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isGuest ? 'حساب ضيف' : 'حساب Google موثق ✔',
                                            style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white12, height: 26),

                          // Stats Cards
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('العملات', '${user?.chips ?? 0}', '🪙', const Color(0xFFFFD54F)),
                              _buildStatItem('التقييم', '${user?.rating ?? 1200}', '⭐', const Color(0xFF60A5FA)),
                              _buildStatItem('المستوى', '${user?.level ?? 1}', '🏆', const Color(0xFF34D399)),
                              _buildStatItem('نسبة الفوز', '$winRate%', '🔥', const Color(0xFFF472B6)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Menu Options Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF24143D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.support_agent_rounded, color: Color(0xFFFFD54F)),
                            title: const Text('المساعدة والاقتراحات (فتح تذكرة دعم)', style: TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: const Text('تواصل مباشرة مع إدارة التطبيق للاقتراحات والمشاكل', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 15),
                            onTap: () => _showSupportTicketDialog(context),
                          ),
                          const Divider(color: Colors.white10, height: 1),
                          ListTile(
                            leading: const Icon(Icons.badge_rounded, color: Color(0xFF60A5FA)),
                            title: const Text('تغيير اسم المستخدم الفريد', style: TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: const Text('اختر اسماً فريداً ليجدك أصدقاؤك بسهولة', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 15),
                            onTap: () => _showEditUsernameDialog(context),
                          ),
                          const Divider(color: Colors.white10, height: 1),
                          ListTile(
                            leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFEC4899)),
                            title: const Text('اختيار صورة شخصية', style: TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: const Text('رمز تعبيري مميز يظهر للجميع على طاولات اللعب', style: TextStyle(color: Colors.white38, fontSize: 11)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 15),
                            onTap: () => _showAvatarPicker(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String emoji, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
