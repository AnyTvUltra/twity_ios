import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/app_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedTab = 0; // 0: Messenger Chats, 1: Friends & Search
  final TextEditingController _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _isSearching = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await SocialService().searchUsers(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _openChatDialog(AppUser otherUser) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DirectChatModal(otherUser: otherUser),
    );
  }

  void _showReportDialog(AppUser targetUser) {
    AppHaptics.medium();
    String selectedReason = 'سلوك مسيء أو غير لائق';
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF24143D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.report_problem_rounded, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إبلاغ عن @${targetUser.username}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر سبب البلاغ:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: const Color(0xFF1B0B30),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: [
                    'سلوك مسيء أو غير لائق',
                    'غش وتلاعب في اللعبة',
                    'اسم مستخدم أو صورة مسيئة',
                    'رسائل مزعجة أو سبام',
                    'أخرى',
                  ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text('تفاصيل إضافية (اختياري):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'اكتب ما حدث للمساعدة في مراجعة البلاغ...',
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
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final myUser = AuthService().currentUser;
                if (myUser != null) {
                  await SocialService().reportUser(
                    reporterUid: myUser.uid,
                    reporterName: myUser.displayName,
                    reportedUid: targetUser.uid,
                    reportedUsername: targetUser.username,
                    reason: selectedReason,
                    details: detailsController.text.trim(),
                  );
                }
                if (mounted) {
                  Navigator.of(ctx).pop();
                  TopNotification.show(
                    context,
                    'تم إرسال البلاغ للإدارة بنجاح! سيتم التحقق واتخاذ الإجراء اللازم.',
                    icon: Icons.shield_rounded,
                  );
                }
              },
              child: const Text('إرسال البلاغ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(AppUser targetUser) {
    AppHaptics.heavy();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF24143D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حظر اللاعب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'هل أنت متأكد من حظر @${targetUser.username}؟ لن يتمكن من مراسلتك أو اللعب معك مرة أخرى.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final myUid = AuthService().currentUser?.uid;
              if (myUid != null) {
                await SocialService().blockUser(myUid, targetUser.uid, 'حظر من المستخدم');
              }
              if (mounted) {
                Navigator.of(ctx).pop();
                TopNotification.show(context, 'تم حظر اللاعب بنجاح', icon: Icons.block_rounded);
              }
            },
            child: const Text('نعم، حظر'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الدردشة والأصدقاء 💬',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x334ADE80),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF4ADE80), width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Color(0xFF4ADE80), size: 8),
                        SizedBox(width: 5),
                        Text('أونلاين', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF26143F),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _selectedTab = 0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? const Color(0xFF5B21B6) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_rounded,
                                  color: _selectedTab == 0 ? const Color(0xFFFFD54F) : Colors.white60, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'الرسائل (Messenger)',
                                style: TextStyle(
                                  color: _selectedTab == 0 ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _selectedTab = 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? const Color(0xFF5B21B6) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_alt_rounded,
                                  color: _selectedTab == 1 ? const Color(0xFFFFD54F) : Colors.white60, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'الأصدقاء والبحث',
                                style: TextStyle(
                                  color: _selectedTab == 1 ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: _selectedTab == 0 ? _buildMessengerTab() : _buildFriendsAndSearchTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessengerTab() {
    final myUid = AuthService().currentUser?.uid ?? '';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SocialService().getFriendsStream(myUid),
      builder: (context, snapshot) {
        final friends = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
          physics: const BouncingScrollPhysics(),
          children: [
            // Active Friends Horizontal Avatars Bar
            if (friends.isNotEmpty) ...[
              const Text('الأصدقاء المتصلون:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 75,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final f = friends[index];
                    return GestureDetector(
                      onTap: () {
                        _openChatDialog(AppUser(
                          uid: f['uid'],
                          email: '',
                          displayName: f['displayName'] ?? 'صديق',
                          username: f['username'] ?? '',
                          photoUrl: f['photoUrl'] ?? '',
                        ));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 14),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                                    border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.person, color: Colors.white, size: 24),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF10B981),
                                      border: Border.all(color: const Color(0xFF160926), width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              f['displayName'] ?? '',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 24),
            ],

            const Text('المحادثات المباشرة:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            if (friends.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0x332E174D),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white30, size: 48),
                    const SizedBox(height: 12),
                    const Text('لا توجد محادثات بعد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    const Text(
                      'ابحث عن أصدقاء عبر اسم المستخدم الفريد من تبويب "الأصدقاء والبحث" وابدأ محادثتك الأولى!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD54F),
                        foregroundColor: const Color(0xFF1B0B30),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_search_rounded, size: 18),
                      label: const Text('البحث عن أصدقاء الآن', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _selectedTab = 1),
                    ),
                  ],
                ),
              )
            else
              ...friends.map((f) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24143D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                      ),
                      child: const Center(child: Icon(Icons.person, color: Colors.white, size: 22)),
                    ),
                    title: Text(f['displayName'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('@${f['username'] ?? ''}', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11.5)),
                    trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFFFD54F), size: 20),
                    onTap: () {
                      _openChatDialog(AppUser(
                        uid: f['uid'],
                        email: '',
                        displayName: f['displayName'] ?? 'صديق',
                        username: f['username'] ?? '',
                        photoUrl: f['photoUrl'] ?? '',
                      ));
                    },
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildFriendsAndSearchTab() {
    final myUid = AuthService().currentUser?.uid ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      physics: const BouncingScrollPhysics(),
      children: [
        // Search Input
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFFD54F)),
            hintText: 'ابحث باسم المستخدم الفريد (مثال: okey_king)...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF26143F),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: _performSearch,
        ),
        const SizedBox(height: 16),

        // Search Results
        if (_isSearching)
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD54F)))
        else if (_searchResults.isNotEmpty) ...[
          const Text('نتائج البحث:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._searchResults.map((user) {
            final isMe = user.uid == myUid;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF24143D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x33FFD54F)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFFEC4899), Color(0xFFBE185D)]),
                    ),
                    child: const Center(child: Icon(Icons.person, color: Colors.white, size: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('@${user.username}', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11)),
                        Text('تقييم ${user.rating} • مستوى ${user.level}', style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  if (!isMe) ...[
                    IconButton(
                      icon: const Icon(Icons.person_add_rounded, color: Color(0xFF10B981), size: 22),
                      tooltip: 'إضافة صديق',
                      onPressed: () async {
                        AppHaptics.selection();
                        await SocialService().addFriend(myUid, user);
                        if (mounted) {
                          TopNotification.show(context, 'تمت إضافة @${user.username} إلى أصدقائك! 🤝', icon: Icons.check_circle);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFFFD54F), size: 20),
                      tooltip: 'مراسلة',
                      onPressed: () => _openChatDialog(user),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white60, size: 20),
                      color: const Color(0xFF1B0B30),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'report', child: Text('🚨 إبلاغ للإدارة', style: TextStyle(color: Color(0xFFEF4444)))),
                        const PopupMenuItem(value: 'block', child: Text('🚫 حظر اللاعب', style: TextStyle(color: Colors.white70))),
                      ],
                      onSelected: (val) {
                        if (val == 'report') _showReportDialog(user);
                        if (val == 'block') _showBlockDialog(user);
                      },
                    ),
                  ],
                ],
              ),
            );
          }),
          const Divider(color: Colors.white12, height: 24),
        ],

        // Friends List
        const Text('قائمة أصدقائي:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SocialService().getFriendsStream(myUid),
          builder: (context, snapshot) {
            final friends = snapshot.data ?? [];
            if (friends.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'لم تقم بإضافة أصدقاء بعد. استخدم شريط البحث أعلاه لإيجاد أصدقائك!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              );
            }

            return Column(
              children: friends.map((f) {
                final friendUser = AppUser(
                  uid: f['uid'],
                  email: '',
                  displayName: f['displayName'] ?? 'صديق',
                  username: f['username'] ?? '',
                  photoUrl: f['photoUrl'] ?? '',
                );

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24143D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                        ),
                        child: const Center(child: Icon(Icons.person, color: Colors.white, size: 22)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(friendUser.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('@${friendUser.username}', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFFFD54F), size: 20),
                        tooltip: 'شات',
                        onPressed: () => _openChatDialog(friendUser),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white60, size: 20),
                        color: const Color(0xFF1B0B30),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'delete', child: Text('🗑️ حذف من الأصدقاء', style: TextStyle(color: Colors.white70))),
                          const PopupMenuItem(value: 'report', child: Text('🚨 إبلاغ للإدارة', style: TextStyle(color: Color(0xFFEF4444)))),
                          const PopupMenuItem(value: 'block', child: Text('🚫 حظر اللاعب', style: TextStyle(color: Color(0xFFEF4444)))),
                        ],
                        onSelected: (val) async {
                          if (val == 'delete') {
                            await SocialService().removeFriend(myUid, friendUser.uid);
                            if (mounted) TopNotification.show(context, 'تم حذف الصديق');
                          }
                          if (val == 'report') _showReportDialog(friendUser);
                          if (val == 'block') _showBlockDialog(friendUser);
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/// نافذة الدردشة المباشرة بتصميم شات ماسنجر الاحترافي
class _DirectChatModal extends StatefulWidget {
  final AppUser otherUser;

  const _DirectChatModal({required this.otherUser});

  @override
  State<_DirectChatModal> createState() => _DirectChatModalState();
}

class _DirectChatModalState extends State<_DirectChatModal> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final myUser = AuthService().currentUser;
    if (myUser == null) return;

    _msgController.clear();
    AppHaptics.light();

    await SocialService().sendMessage(
      senderUid: myUser.uid,
      senderName: myUser.displayName,
      receiverUid: widget.otherUser.uid,
      receiverName: widget.otherUser.displayName,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';
    final convId = SocialService().getConversationId(myUid, widget.otherUser.uid);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1E0E35),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF281446),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
                  ),
                  child: const Center(child: Icon(Icons.person, color: Colors.white, size: 22)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.otherUser.displayName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('@${widget.otherUser.username} • متصل الآن 🟢', style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Messages Stream
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: SocialService().getMessagesStream(convId, myUid),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('👋', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text('ابدأ محادثتك مع ${widget.otherUser.displayName}!', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  physics: const BouncingScrollPhysics(),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.isMe;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)])
                              : const LinearGradient(colors: [Color(0xFF2E1B4E), Color(0xFF24153E)]),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                          ),
                          border: Border.all(color: isMe ? const Color(0x60FFD54F) : Colors.white12, width: 0.8),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                            const SizedBox(height: 2),
                            Text(
                              '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message Input Field
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFF281446),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFFFD54F), size: 24),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
