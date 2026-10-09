import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../games/okey/okey_rules.dart';
import '../services/auth_service.dart';
import '../services/broadcast_service.dart';
import '../services/social_service.dart';
import 'okey_game_screen.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/user_avatar.dart';
import '../l10n/app_lang.dart';

// ══════════════════════════════════════════════════════════════
// لوحة ألوان الدردشة — زجاج كحلي داكن بلمسات سماوية/بنفسجية
// ══════════════════════════════════════════════════════════════
class _C {
  static const bgTop = Color(0xFF0B1230);
  static const bgBot = Color(0xFF050817);
  static const card = Color(0xFF141C38);
  static const cardHi = Color(0xFF1B2550);
  static const border = Color(0x1FFFFFFF);
  static const text = Color(0xFFF1F5FF);
  static const dim = Color(0xFF8EA3C8);
  static const faint = Color(0xFF5B6B8E);
  static const cyan = Color(0xFF38BDF8);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF43F5E);
  static const gold = Color(0xFFFFD54F);
  static const accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// وقت مختصر لقائمة المحادثات: ساعة اليوم، "أمس"، أو التاريخ
String _shortTime(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return _hhmm(t);
  if (diff == 1) return 'أمس'.tr;
  return '${t.day}/${t.month}';
}

/// يفتح صفحة المحادثة الكاملة مع لاعب
void openDirectChat(BuildContext context, AppUser otherUser) {
  AppHaptics.selection();
  final myUid = AuthService().currentUser?.uid ?? '';
  SocialService().markConversationRead(
      SocialService().getConversationId(myUid, otherUser.uid), myUid);
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => DirectChatModal(otherUser: otherUser),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic))
            .animate(a),
        child: child,
      ),
    ),
  ));
}

/// شارة عدد حمراء صغيرة
Widget _countBadge(int n, {double size = 18}) => Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: _C.red,
        borderRadius: BorderRadius.circular(size),
        boxShadow: [
          BoxShadow(color: _C.red.withValues(alpha: 0.5), blurRadius: 6)
        ],
      ),
      child: Center(
        child: Text(n > 99 ? '99+' : '$n',
            style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.55,
                fontWeight: FontWeight.w900)),
      ),
    );

/// زر حبّة صغيرة (قبول/رفض/مراسلة)
Widget _pill(
    {required IconData icon,
    String? label,
    required Color color,
    bool filled = false,
    required VoidCallback onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 34,
      padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 12),
      width: label == null ? 34 : null,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: filled ? 1 : 0.45)),
        boxShadow: filled
            ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: filled ? Colors.white : color, size: 17),
          if (label != null) ...[
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: filled ? Colors.white : color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900)),
          ],
        ],
      ),
    ),
  );
}

/// بطاقة زجاجية داكنة موحّدة
Widget _card(
    {required Widget child,
    EdgeInsets padding = const EdgeInsets.all(12),
    EdgeInsets margin = EdgeInsets.zero,
    bool highlight = false,
    VoidCallback? onTap}) {
  return Padding(
    padding: margin,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: _C.cyan.withValues(alpha: 0.08),
        highlightColor: Colors.white.withValues(alpha: 0.03),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: highlight
                  ? [_C.cardHi, const Color(0xFF16204A)]
                  : [_C.card, const Color(0xFF10172E)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: highlight ? _C.cyan.withValues(alpha: 0.35) : _C.border),
          ),
          child: child,
        ),
      ),
    ),
  );
}

/// عنوان قسم صغير بخط متلاشٍ
Widget _sectionTitle(String text, {int? count, Color color = _C.cyan}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                color: _C.text, fontSize: 13.5, fontWeight: FontWeight.w900)),
        if (count != null && count > 0) ...[
          const SizedBox(width: 8),
          _countBadge(count),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                color.withValues(alpha: 0.35),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    ),
  );
}

/// خلفية الدردشة: تدرّج كحلي + هالات ناعمة
class _ChatBackground extends StatelessWidget {
  final Widget child;
  const _ChatBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_C.bgTop, _C.bgBot],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _GlowPainter())),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color color, double o) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: o),
              Colors.transparent,
            ]).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    glow(Offset(size.width * 0.9, size.height * 0.02), size.width * 0.6,
        const Color(0xFF2563EB), 0.28);
    glow(Offset(size.width * 0.05, size.height * 0.45), size.width * 0.5,
        const Color(0xFF7C3AED), 0.14);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════════════════════════════════
// شاشة الدردشة والأصدقاء
// ══════════════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await SocialService().searchUsers(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _openChat(AppUser otherUser) => openDirectChat(context, otherUser);

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';

    return _ChatBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── الترويسة ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الدردشة'.tr,
                            style: const TextStyle(
                                color: _C.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text('محادثاتك وأصدقاؤك في مكان واحد'.tr,
                            style:
                                const TextStyle(color: _C.dim, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  _NotificationBell(onOpenChat: _openChat),
                ],
              ),
            ),

            // ── مبدّل التبويبات بمؤشر منزلق ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: StreamBuilder<List<ConversationSummary>>(
                stream: SocialService().getConversationsStream(myUid),
                builder: (context, cs) {
                  final unread =
                      (cs.data ?? []).fold<int>(0, (s, c) => s + c.unreadCount);
                  return StreamBuilder<List<FriendRequest>>(
                    stream: SocialService().getIncomingRequestsStream(myUid),
                    builder: (context, rs) =>
                        _tabs(unread, rs.data?.length ?? 0),
                  );
                },
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                child: _selectedTab == 0
                    ? KeyedSubtree(
                        key: const ValueKey('msgs'),
                        child: _buildMessengerTab(myUid))
                    : KeyedSubtree(
                        key: const ValueKey('friends'),
                        child: _buildFriendsTab(myUid)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(int unread, int requests) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: _selectedTab == 0
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _C.accent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _C.violet.withValues(alpha: 0.4),
                        blurRadius: 12),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              _tabButton(0, Icons.chat_bubble_rounded, 'الرسائل'.tr, unread),
              _tabButton(1, Icons.people_alt_rounded, 'الأصدقاء'.tr, requests),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label, int badge) {
    final sel = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          setState(() => _selectedTab = index);
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? Colors.white : _C.dim, size: 17),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: sel ? Colors.white : _C.dim,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              _countBadge(badge, size: 17),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // تبويب الرسائل
  // ══════════════════════════════════════════════════════════
  Widget _buildMessengerTab(String myUid) {
    return StreamBuilder<List<ConversationSummary>>(
      stream: SocialService().getConversationsStream(myUid),
      builder: (context, snapshot) {
        final convs = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
          physics: const BouncingScrollPhysics(),
          children: [
            // صف الأصدقاء السريع — اضغط على صديق لمراسلته فوراً
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: SocialService().getFriendsStream(myUid),
              builder: (context, fs) {
                final friends = fs.data ?? [];
                if (friends.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: 86,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: friends.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final u = _friendUser(friends[i]);
                        return GestureDetector(
                          onTap: () => _openChat(u),
                          child: SizedBox(
                            width: 62,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _C.accent,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _C.bgTop),
                                    child: UserAvatar(
                                        photoUrl: u.photoUrl,
                                        name: u.displayName,
                                        size: 48),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(u.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _C.dim,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            if (convs.isEmpty)
              _emptyState(
                icon: Icons.forum_rounded,
                title: 'لا توجد محادثات بعد'.tr,
                subtitle:
                    'ابحث عن أصدقاء من تبويب "الأصدقاء" وابدأ محادثتك الأولى!'
                        .tr,
                action: 'البحث عن أصدقاء'.tr,
                onAction: () => setState(() => _selectedTab = 1),
              )
            else ...[
              _sectionTitle('المحادثات'.tr),
              for (final c in convs) _conversationTile(c),
            ],
          ],
        );
      },
    );
  }

  Widget _emptyState(
      {required IconData icon,
      required String title,
      required String subtitle,
      String? action,
      VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                _C.cyan.withValues(alpha: 0.18),
                _C.violet.withValues(alpha: 0.18),
              ]),
              border: Border.all(color: _C.cyan.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: _C.cyan, size: 44),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: _C.text, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: _C.dim, fontSize: 12, height: 1.5)),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  gradient: _C.accent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: _C.violet.withValues(alpha: 0.4),
                        blurRadius: 14),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_search_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(action,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _conversationTile(ConversationSummary c) {
    final hasUnread = c.unreadCount > 0;
    final user = AppUser(
      uid: c.otherUid,
      email: '',
      displayName: c.otherName,
      username: c.otherUsername,
      photoUrl: c.otherPhoto,
    );
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      highlight: hasUnread,
      onTap: () => _openChat(user),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hasUnread ? _C.accent : null,
              color: hasUnread ? null : Colors.white.withValues(alpha: 0.08),
            ),
            child:
                UserAvatar(photoUrl: c.otherPhoto, name: c.otherName, size: 48),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _C.text,
                        fontWeight:
                            hasUnread ? FontWeight.w900 : FontWeight.w700,
                        fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(
                  c.lastMessage.isEmpty ? '@${c.otherUsername}' : c.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: hasUnread ? const Color(0xFFCBD5E1) : _C.dim,
                      fontSize: 12,
                      fontWeight:
                          hasUnread ? FontWeight.w700 : FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_shortTime(c.lastTime),
                  style: TextStyle(
                      color: hasUnread ? _C.cyan : _C.faint,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (hasUnread)
                _countBadge(c.unreadCount, size: 20)
              else
                const Icon(Icons.done_all_rounded, color: _C.faint, size: 16),
            ],
          ),
        ],
      ),
    );
  }

  AppUser _friendUser(Map<String, dynamic> f) => AppUser(
        uid: f['uid'],
        email: '',
        displayName: f['displayName'] ?? 'صديق'.tr,
        username: f['username'] ?? '',
        photoUrl: f['photoUrl'] ?? '',
      );

  // ══════════════════════════════════════════════════════════
  // تبويب الأصدقاء — بحث + طلبات واردة + قائمة الأصدقاء
  // ══════════════════════════════════════════════════════════
  Widget _buildFriendsTab(String myUid) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── البحث ──
        Container(
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: _C.text, fontSize: 14),
            cursorColor: _C.cyan,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: _C.cyan),
              hintText: 'ابحث باسم المستخدم الفريد (مثال: okey_king)...'.tr,
              hintStyle: const TextStyle(color: _C.faint, fontSize: 12),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: _C.dim, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
            ),
            onChanged: _performSearch,
          ),
        ),
        const SizedBox(height: 14),

        // ── نتائج البحث ──
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: _C.cyan)),
          )
        else if (_searchResults.isNotEmpty) ...[
          _sectionTitle('نتائج البحث'.tr, color: _C.violet),
          StreamBuilder<Set<String>>(
            stream: SocialService().getOutgoingRequestsStream(myUid),
            builder: (context, outSnap) {
              final outgoing = outSnap.data ?? {};
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream: SocialService().getFriendsStream(myUid),
                builder: (context, frSnap) {
                  final friendUids = (frSnap.data ?? [])
                      .map((f) => f['uid'] as String)
                      .toSet();
                  return Column(
                    children: _searchResults.map((user) {
                      return _searchResultTile(
                          user,
                          user.uid == myUid,
                          friendUids.contains(user.uid),
                          outgoing.contains(user.uid),
                          myUid);
                    }).toList(),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
        ],

        // ── طلبات الصداقة الواردة ──
        StreamBuilder<List<FriendRequest>>(
          stream: SocialService().getIncomingRequestsStream(myUid),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _sectionTitle('طلبات الصداقة الواردة'.tr,
                    count: requests.length, color: _C.gold),
                for (final r in requests) _requestTile(r),
                const SizedBox(height: 6),
              ],
            );
          },
        ),

        // ── قائمة أصدقائي ──
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SocialService().getFriendsStream(myUid),
          builder: (context, snapshot) {
            final friends = snapshot.data ?? [];
            // حضور الأصدقاء — استعلام جماعي واحد على أول 30 صديقاً
            return StreamBuilder<Map<String, Map<String, dynamic>>>(
              stream: SocialService().friendsPresenceStream(
                  friends.map((f) => f['uid'].toString()).toList()),
              builder: (context, ps) {
                final presence = ps.data ?? const {};
                return Column(
                  children: [
                    _sectionTitle('أصدقائي'.tr, count: null, color: _C.green),
                    if (friends.isEmpty)
                      _emptyState(
                        icon: Icons.group_add_rounded,
                        title: 'لم تُضِف أصدقاء بعد'.tr,
                        subtitle:
                            'لم تُضِف أصدقاء بعد. ابحث عنهم أعلاه وأرسل طلب صداقة!'
                                .tr,
                      )
                    else
                      for (final f in friends)
                        _friendTile(_friendUser(f), myUid, presence[f['uid']]),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _requestTile(FriendRequest r) {
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      highlight: true,
      child: Row(
        children: [
          UserAvatar(photoUrl: r.fromPhoto, name: r.fromName, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.fromName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5)),
                Text('@{} يريد إضافتك'.trp([r.fromUsername]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _C.dim, fontSize: 11)),
              ],
            ),
          ),
          _pill(
            icon: Icons.check_rounded,
            label: 'قبول'.tr,
            color: _C.green,
            filled: true,
            onTap: () async {
              AppHaptics.medium();
              await SocialService().acceptFriendRequest(r.id);
              if (mounted) {
                TopNotification.show(
                    context, 'أصبح {} صديقك! 🤝'.trp([r.fromName]),
                    icon: Icons.check_circle);
              }
            },
          ),
          const SizedBox(width: 6),
          _pill(
            icon: Icons.close_rounded,
            color: _C.red,
            onTap: () async {
              AppHaptics.light();
              await SocialService().declineFriendRequest(r.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _friendTile(AppUser u, String myUid,
      [Map<String, dynamic>? presence]) {
    final playing = (presence?['activeRoom'] ?? '').toString().isNotEmpty;
    final online = presence?['isOnline'] == true;
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => _openChat(u),
      child: Row(
        children: [
          Stack(
            children: [
              UserAvatar(photoUrl: u.photoUrl, name: u.displayName, size: 46),
              if (presence != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: playing
                          ? const Color(0xFFC084FC)
                          : online
                              ? _C.green
                              : const Color(0xFF64748B),
                      border: Border.all(color: _C.bgTop, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                Text('@${u.username}',
                    style: const TextStyle(color: _C.cyan, fontSize: 11)),
                if (playing)
                  Text('يلعب الآن 🎮'.tr,
                      style: const TextStyle(
                          color: Color(0xFFC084FC),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (playing && (presence?['activeGame'] ?? '') == 'okey')
            _pill(
                icon: Icons.visibility_rounded,
                color: const Color(0xFFC084FC),
                onTap: () => _spectateRoom(presence!['activeRoom'].toString())),
          _pill(
              icon: Icons.chat_bubble_rounded,
              color: _C.cyan,
              onTap: () => _openChat(u)),
          _menu(u, myUid, isFriend: true),
        ],
      ),
    );
  }

  /// دخول غرفة الصديق كمشاهد
  void _spectateRoom(String roomId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OkeyGameScreen(
        rules: OkeyRules.turkish,
        roomId: roomId,
        spectate: true,
      ),
    ));
  }

  Widget _menu(AppUser u, String myUid, {required bool isFriend}) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, color: _C.dim, size: 20),
      color: const Color(0xFF1B2342),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _C.border)),
      itemBuilder: (ctx) => [
        if (isFriend)
          PopupMenuItem(
              value: 'delete',
              child: Text('🗑️ حذف من الأصدقاء'.tr,
                  style: const TextStyle(color: _C.text))),
        PopupMenuItem(
            value: 'report',
            child: Text('🚨 إبلاغ للإدارة'.tr,
                style: const TextStyle(color: Color(0xFFFCA5A5)))),
        PopupMenuItem(
            value: 'block',
            child: Text('🚫 حظر اللاعب'.tr,
                style: const TextStyle(color: Color(0xFFFCA5A5)))),
      ],
      onSelected: (val) async {
        if (val == 'delete') {
          await SocialService().removeFriend(myUid, u.uid);
          if (mounted) TopNotification.show(context, 'تم حذف الصديق'.tr);
        }
        if (val == 'report') _showReportDialog(u);
        if (val == 'block') _showBlockDialog(u);
      },
    );
  }

  Widget _searchResultTile(
      AppUser user, bool isMe, bool isFriend, bool isPending, String myUid) {
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          UserAvatar(photoUrl: user.photoUrl, name: user.displayName, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                Text('@${user.username}',
                    style: const TextStyle(color: _C.cyan, fontSize: 11)),
                Text('تقييم {} • مستوى {}'.trp([user.rating, user.level]),
                    style: const TextStyle(color: _C.faint, fontSize: 10.5)),
              ],
            ),
          ),
          if (!isMe) ...[
            if (isFriend)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text('صديقك ✓'.tr,
                    style: const TextStyle(
                        color: _C.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
              )
            else if (isPending)
              _pill(
                icon: Icons.hourglass_top_rounded,
                label: 'إلغاء'.tr,
                color: _C.dim,
                onTap: () =>
                    SocialService().cancelFriendRequest(myUid, user.uid),
              )
            else
              _pill(
                icon: Icons.person_add_rounded,
                color: _C.green,
                filled: true,
                onTap: () async {
                  AppHaptics.selection();
                  final me = AuthService().currentUser;
                  if (me == null) return;
                  final error =
                      await SocialService().sendFriendRequest(me, user);
                  if (!mounted) return;
                  TopNotification.show(
                      context,
                      error ??
                          'أُرسل طلب الصداقة إلى @{} 📨'.trp([user.username]),
                      icon: error != null
                          ? Icons.info_outline_rounded
                          : Icons.send_rounded);
                },
              ),
            const SizedBox(width: 6),
            _pill(
                icon: Icons.chat_bubble_rounded,
                color: _C.cyan,
                onTap: () => _openChat(user)),
            _menu(user, myUid, isFriend: false),
          ],
        ],
      ),
    );
  }

  // ── الحوارات (إبلاغ/حظر) ──

  Widget _dialogShell({
    required Color accent,
    required IconData icon,
    required String title,
    required Widget body,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF18214A), Color(0xFF0C1230)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.15),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(child: SingleChildScrollView(child: body)),
            const SizedBox(height: 14),
            Row(children: actions),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _C.faint, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      );

  Widget _dialogBtn(String label, Color color, VoidCallback onTap,
      {bool filled = true}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: filled ? color : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: filled ? color : Colors.white.withValues(alpha: 0.15)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: filled ? Colors.white : _C.dim,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
        ),
      ),
    );
  }

  void _showReportDialog(AppUser targetUser) {
    AppHaptics.medium();
    String selectedReason = 'سلوك مسيء أو غير لائق'.tr;
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => _dialogShell(
          accent: _C.red,
          icon: Icons.report_problem_rounded,
          title: 'إبلاغ عن @{}'.trp([targetUser.username]),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('اختر سبب البلاغ:'.tr,
                  style: const TextStyle(color: _C.dim, fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedReason,
                dropdownColor: const Color(0xFF1B2342),
                style: const TextStyle(color: _C.text, fontSize: 13),
                decoration: _fieldDeco(null),
                items: [
                  'سلوك مسيء أو غير لائق'.tr,
                  'غش وتلاعب في اللعبة'.tr,
                  'اسم مستخدم أو صورة مسيئة'.tr,
                  'رسائل مزعجة أو سبام'.tr,
                  'أخرى'.tr,
                ]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: 12),
              Text('تفاصيل إضافية (اختياري):'.tr,
                  style: const TextStyle(color: _C.dim, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: detailsController,
                maxLines: 3,
                style: const TextStyle(color: _C.text, fontSize: 12.5),
                decoration:
                    _fieldDeco('اكتب ما حدث للمساعدة في مراجعة البلاغ...'.tr),
              ),
            ],
          ),
          actions: [
            _dialogBtn('إلغاء'.tr, _C.dim, () => Navigator.of(ctx).pop(),
                filled: false),
            const SizedBox(width: 10),
            _dialogBtn('إرسال البلاغ'.tr, const Color(0xFFDC2626), () async {
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
                if (ctx.mounted) Navigator.of(ctx).pop();
                TopNotification.show(
                  this.context,
                  'تم إرسال البلاغ للإدارة بنجاح! سيتم التحقق واتخاذ الإجراء اللازم.'
                      .tr,
                  icon: Icons.shield_rounded,
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(AppUser targetUser) {
    AppHaptics.heavy();
    showDialog(
      context: context,
      builder: (ctx) => _dialogShell(
        accent: _C.red,
        icon: Icons.block_rounded,
        title: 'حظر اللاعب'.tr,
        body: Text(
          'هل أنت متأكد من حظر @{}؟ لن يتمكن من مراسلتك أو اللعب معك مرة أخرى.'
              .trp([targetUser.username]),
          style: const TextStyle(color: _C.dim, fontSize: 13, height: 1.5),
        ),
        actions: [
          _dialogBtn('إلغاء'.tr, _C.dim, () => Navigator.of(ctx).pop(),
              filled: false),
          const SizedBox(width: 10),
          _dialogBtn('نعم، حظر'.tr, const Color(0xFFDC2626), () async {
            final myUid = AuthService().currentUser?.uid;
            if (myUid != null) {
              await SocialService()
                  .blockUser(myUid, targetUser.uid, 'حظر من المستخدم'.tr);
            }
            if (mounted) {
              if (ctx.mounted) Navigator.of(ctx).pop();
              TopNotification.show(this.context, 'تم حظر اللاعب بنجاح'.tr,
                  icon: Icons.block_rounded);
            }
          }),
        ],
      ),
    );
  }
}

/// جرس الإشعارات في ترويسة الدردشة
class _NotificationBell extends StatelessWidget {
  final void Function(AppUser) onOpenChat;
  const _NotificationBell({required this.onOpenChat});

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
            final total = reqCount + unread;
            return GestureDetector(
              onTap: () {
                AppHaptics.selection();
                NotificationsSheet.show(context, onOpenChat: onOpenChat);
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _C.border),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_rounded,
                        color: _C.cyan, size: 22),
                    if (total > 0)
                      Positioned(top: -4, right: -4, child: _countBadge(total)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// نافذة الإشعارات — ورقة زجاجية داكنة بأقسام وبطاقات أنيقة
// ══════════════════════════════════════════════════════════════
class NotificationsSheet extends StatelessWidget {
  final void Function(AppUser)? onOpenChat;

  const NotificationsSheet({super.key, this.onOpenChat});

  static void show(BuildContext context, {void Function(AppUser)? onOpenChat}) {
    BroadcastService.instance.markAllSeen();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      // بلا مستمع مخصص (من الترويسة الرئيسية) تُفتح صفحة المحادثة مباشرة
      builder: (ctx) => NotificationsSheet(
          onOpenChat: onOpenChat ?? (u) => openDirectChat(context, u)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF18214A).withValues(alpha: 0.97),
                const Color(0xFF080C1E).withValues(alpha: 0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: _C.cyan.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              // الترويسة
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _C.accent,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                              color: _C.violet.withValues(alpha: 0.45),
                              blurRadius: 14),
                        ],
                      ),
                      child: const Icon(Icons.notifications_active_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الإشعارات'.tr,
                              style: const TextStyle(
                                  color: _C.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                          Text('آخر التنبيهات والطلبات والرسائل'.tr,
                              style:
                                  const TextStyle(color: _C.dim, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: _C.dim, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<BroadcastMessage>>(
                  stream: BroadcastService.instance.recentStream(),
                  builder: (context, bSnap) {
                    return StreamBuilder<List<FriendRequest>>(
                      stream: SocialService().getIncomingRequestsStream(myUid),
                      builder: (context, rSnap) {
                        return StreamBuilder<List<ConversationSummary>>(
                          stream: SocialService().getConversationsStream(myUid),
                          builder: (context, cSnap) {
                            final admin = (bSnap.data ?? [])
                                .where((b) => b.body.isNotEmpty)
                                .take(3)
                                .toList();
                            final requests = rSnap.data ?? [];
                            final unread = (cSnap.data ?? [])
                                .where((c) => c.unreadCount > 0)
                                .toList();
                            if (admin.isEmpty &&
                                requests.isEmpty &&
                                unread.isEmpty) {
                              return _empty();
                            }
                            return ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              children: [
                                if (admin.isNotEmpty) ...[
                                  _sectionTitle('من الإدارة'.tr,
                                      color: _C.gold),
                                  for (final b in admin) _adminTile(b),
                                  const SizedBox(height: 6),
                                ],
                                if (requests.isNotEmpty) ...[
                                  _sectionTitle('طلبات صداقة'.tr,
                                      count: requests.length, color: _C.green),
                                  for (final r in requests) _requestTile(r),
                                  const SizedBox(height: 6),
                                ],
                                if (unread.isNotEmpty) ...[
                                  _sectionTitle('رسائل غير مقروءة'.tr,
                                      count: unread.fold<int>(
                                          0, (s, c) => s + c.unreadCount)),
                                  for (final c in unread)
                                    _messageTile(context, c),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                _C.cyan.withValues(alpha: 0.16),
                _C.violet.withValues(alpha: 0.16),
              ]),
              border: Border.all(color: _C.cyan.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: _C.cyan, size: 48),
          ),
          const SizedBox(height: 16),
          Text('لا توجد إشعارات جديدة 🎉'.tr,
              style: const TextStyle(
                  color: _C.text, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text('كل شيء محدّث — سنخبرك عند وصول جديد'.tr,
              style: const TextStyle(color: _C.dim, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _iconChip(IconData icon, Color color) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Icon(icon, color: color, size: 20),
      );

  Widget _adminTile(BroadcastMessage b) {
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconChip(Icons.campaign_rounded, _C.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.title,
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(b.body,
                    style: const TextStyle(
                        color: _C.dim, fontSize: 12, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestTile(FriendRequest r) {
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          UserAvatar(photoUrl: r.fromPhoto, name: r.fromName, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.fromName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                Text('أرسل لك طلب صداقة'.tr,
                    style: const TextStyle(color: _C.dim, fontSize: 11)),
              ],
            ),
          ),
          _pill(
            icon: Icons.check_rounded,
            color: _C.green,
            filled: true,
            onTap: () => SocialService().acceptFriendRequest(r.id),
          ),
          const SizedBox(width: 6),
          _pill(
            icon: Icons.close_rounded,
            color: _C.red,
            onTap: () => SocialService().declineFriendRequest(r.id),
          ),
        ],
      ),
    );
  }

  Widget _messageTile(BuildContext context, ConversationSummary c) {
    return _card(
      margin: const EdgeInsets.only(bottom: 10),
      highlight: true,
      onTap: () {
        Navigator.of(context).pop();
        onOpenChat?.call(AppUser(
          uid: c.otherUid,
          email: '',
          displayName: c.otherName,
          username: c.otherUsername,
          photoUrl: c.otherPhoto,
        ));
      },
      child: Row(
        children: [
          UserAvatar(photoUrl: c.otherPhoto, name: c.otherName, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.otherName,
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                Text(c.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _C.dim, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_shortTime(c.lastTime),
                  style: const TextStyle(color: _C.cyan, fontSize: 10)),
              const SizedBox(height: 4),
              _countBadge(c.unreadCount, size: 19),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// صفحة المحادثة المباشرة — صفحة كاملة بفقاعات متدرجة
// ══════════════════════════════════════════════════════════════
class DirectChatModal extends StatefulWidget {
  final AppUser otherUser;

  const DirectChatModal({super.key, required this.otherUser});

  @override
  State<DirectChatModal> createState() => _DirectChatModalState();
}

class _DirectChatModalState extends State<DirectChatModal> {
  final TextEditingController _msgController = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    // تصفير غير المقروء عند فتح المحادثة
    final myUid = AuthService().currentUser?.uid ?? '';
    SocialService().markConversationRead(
        SocialService().getConversationId(myUid, widget.otherUser.uid), myUid);
    _msgController.addListener(() {
      final has = _msgController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

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
      senderUsername: myUser.username,
      senderPhoto: myUser.photoUrl,
      receiverUid: widget.otherUser.uid,
      receiverName: widget.otherUser.displayName,
      receiverUsername: widget.otherUser.username,
      receiverPhoto: widget.otherUser.photoUrl,
      text: text,
    );
  }

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final d = DateTime(t.year, t.month, t.day);
    final diff = DateTime(now.year, now.month, now.day).difference(d).inDays;
    if (diff == 0) return 'اليوم'.tr;
    if (diff == 1) return 'أمس'.tr;
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';
    final convId =
        SocialService().getConversationId(myUid, widget.otherUser.uid);

    return Scaffold(
      backgroundColor: _C.bgBot,
      body: _ChatBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── الترويسة ──
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
                decoration: BoxDecoration(
                  color: _C.card.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _C.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _C.text, size: 19),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, gradient: _C.accent),
                      child: UserAvatar(
                        photoUrl: widget.otherUser.photoUrl,
                        name: widget.otherUser.displayName,
                        size: 42,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.otherUser.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _C.text,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900)),
                          Text('@${widget.otherUser.username}',
                              style: const TextStyle(
                                  color: _C.cyan, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── الرسائل ──
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: SocialService().getMessagesStream(convId, myUid),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? [];
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _C.cyan.withValues(alpha: 0.1),
                                border: Border.all(
                                    color: _C.cyan.withValues(alpha: 0.3)),
                              ),
                              child: const Center(
                                  child: Text('👋',
                                      style: TextStyle(fontSize: 40))),
                            ),
                            const SizedBox(height: 14),
                            Text(
                                'ابدأ محادثتك مع {}!'
                                    .trp([widget.otherUser.displayName]),
                                style: const TextStyle(
                                    color: _C.dim, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    // القائمة معكوسة — أحدث رسالة في الأسفل دائماً
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      physics: const BouncingScrollPhysics(),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final idx = messages.length - 1 - i;
                        final msg = messages[idx];
                        final prev = idx > 0 ? messages[idx - 1] : null;
                        final next = idx < messages.length - 1
                            ? messages[idx + 1]
                            : null;
                        final newDay = prev == null ||
                            prev.timestamp.day != msg.timestamp.day ||
                            prev.timestamp.month != msg.timestamp.month;
                        // فقاعات متتالية من نفس المرسل تتلاصق
                        final groupedNext =
                            next != null && next.isMe == msg.isMe;
                        return Column(
                          children: [
                            if (newDay)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_dayLabel(msg.timestamp),
                                      style: const TextStyle(
                                          color: _C.dim,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ),
                            _bubble(context, msg, groupedNext),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // ── حقل الإدخال العائم ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _C.card,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: _C.border),
                        ),
                        child: TextField(
                          controller: _msgController,
                          minLines: 1,
                          maxLines: 4,
                          cursorColor: _C.cyan,
                          style: const TextStyle(color: _C.text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'اكتب رسالة...'.tr,
                            hintStyle:
                                const TextStyle(color: _C.faint, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 13),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _hasText ? _C.accent : null,
                          color: _hasText
                              ? null
                              : Colors.white.withValues(alpha: 0.08),
                          boxShadow: _hasText
                              ? [
                                  BoxShadow(
                                      color: _C.violet.withValues(alpha: 0.5),
                                      blurRadius: 14),
                                ]
                              : null,
                        ),
                        child: Icon(Icons.send_rounded,
                            color: _hasText ? Colors.white : _C.faint,
                            size: 21),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, ChatMessage msg, bool groupedNext) {
    final isMe = msg.isMe;
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: 2, bottom: groupedNext ? 2 : 8),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF7C3AED)],
                )
              : null,
          color: isMe ? null : _C.cardHi,
          borderRadius: BorderRadius.only(
            topLeft: r,
            topRight: r,
            bottomLeft: isMe || groupedNext ? r : tail,
            bottomRight: !isMe || groupedNext ? r : tail,
          ),
          border: isMe ? null : Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
                color: (isMe ? _C.violet : Colors.black)
                    .withValues(alpha: isMe ? 0.25 : 0.2),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg.text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.35)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_hhmm(msg.timestamp),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 9.5)),
                if (isMe) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.done_all_rounded,
                      size: 13, color: Colors.white.withValues(alpha: 0.7)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
