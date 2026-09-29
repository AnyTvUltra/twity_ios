import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/broadcast_service.dart';
import '../services/social_service.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/app_background.dart';
import '../widgets/user_avatar.dart';
import '../l10n/app_lang.dart';

import '../theme_mode.dart';

/// شاشة الدردشة والأصدقاء — تصميم زجاجي أبيض
/// تبويبان: الرسائل (محادثات حقيقية بعدّاد غير مقروء) / الأصدقاء (طلبات + بحث)
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

  void _openChat(AppUser otherUser) {
    AppHaptics.selection();
    final myUid = AuthService().currentUser?.uid ?? '';
    SocialService().markConversationRead(
        SocialService().getConversationId(myUid, otherUser.uid), myUid);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DirectChatModal(otherUser: otherUser),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';

    return AppBackground(
      light: true,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── الترويسة ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الدردشة والأصدقاء 💬'.tr,
                    style: TextStyle(
                        color: LightGlass.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900),
                  ),
                  Row(
                    children: [
                      // جرس الإشعارات (طلبات الصداقة + الرسائل غير المقروءة)
                      _NotificationBell(onOpenChat: _openChat),
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: L(0x3310B981),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: L(0xFF10B981), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: L(0xFF10B981), size: 8),
                            SizedBox(width: 5),
                            Text('أونلاين'.tr,
                                style: TextStyle(
                                    color: L(0xFF047857),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── مبدّل التبويبات ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: LightGlass.cardSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: LightGlass.border),
                    ),
                    child: Row(
                      children: [
                        _tabButton(0, Icons.chat_bubble_rounded, 'الرسائل'.tr),
                        _tabButton(1, Icons.people_alt_rounded, 'الأصدقاء'.tr),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 88),
                child: _selectedTab == 0
                    ? _buildMessengerTab(myUid)
                    : _buildFriendsTab(myUid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, String label) {
    final sel = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: sel ? LightGlass.cardStrong : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel
                ? [
                    BoxShadow(
                        color: L(0xFF000000).withOpacity(0.08),
                        blurRadius: 8,
                        offset: Offset(0, 2))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: sel ? LightGlass.accentBlue : LightGlass.textMuted,
                  size: 16),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: sel ? LightGlass.text : LightGlass.textMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // تبويب الرسائل — محادثات حقيقية من Firestore
  // ══════════════════════════════════════════════════════════
  Widget _buildMessengerTab(String myUid) {
    return StreamBuilder<List<ConversationSummary>>(
      stream: SocialService().getConversationsStream(myUid),
      builder: (context, snapshot) {
        final convs = snapshot.data ?? [];

        if (convs.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 90),
            physics: BouncingScrollPhysics(),
            children: [
              _glassCard(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: LightGlass.textFaint, size: 48),
                    SizedBox(height: 12),
                    Text('لا توجد محادثات بعد'.tr,
                        style: TextStyle(
                            color: LightGlass.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                    SizedBox(height: 6),
                    Text(
                      'ابحث عن أصدقاء من تبويب "الأصدقاء" وابدأ محادثتك الأولى!'
                          .tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: LightGlass.textMuted,
                          fontSize: 12,
                          height: 1.4),
                    ),
                    SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LightGlass.accent,
                        foregroundColor: L(0xFFFFFFFF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_search_rounded, size: 18),
                      label: Text('البحث عن أصدقاء'.tr,
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => setState(() => _selectedTab = 1),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
          physics: const BouncingScrollPhysics(),
          itemCount: convs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final c = convs[index];
            return _conversationTile(c);
          },
        );
      },
    );
  }

  Widget _conversationTile(ConversationSummary c) {
    final hasUnread = c.unreadCount > 0;
    final time =
        '${c.lastTime.hour.toString().padLeft(2, '0')}:${c.lastTime.minute.toString().padLeft(2, '0')}';

    return _glassCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: _avatar(c.otherPhoto, c.otherName, radius: 23),
        title: Text(c.otherName,
            style: TextStyle(
                color: LightGlass.text,
                fontWeight: hasUnread ? FontWeight.w900 : FontWeight.bold,
                fontSize: 14)),
        subtitle: Text(
          c.lastMessage.isEmpty ? '@${c.otherUsername}' : c.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: hasUnread ? LightGlass.textSoft : LightGlass.textMuted,
              fontSize: 12,
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time,
                style: TextStyle(color: LightGlass.textFaint, fontSize: 10)),
            SizedBox(height: 4),
            if (hasUnread)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: L(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${c.unreadCount}',
                    style: TextStyle(
                        color: L(0xFFFFFFFF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900)),
              )
            else
              Icon(Icons.chat_bubble_outline_rounded,
                  color: LightGlass.textFaint, size: 16),
          ],
        ),
        onTap: () => _openChat(AppUser(
          uid: c.otherUid,
          email: '',
          displayName: c.otherName,
          username: c.otherUsername,
          photoUrl: c.otherPhoto,
        )),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // تبويب الأصدقاء — طلبات واردة + بحث + قائمة الأصدقاء
  // ══════════════════════════════════════════════════════════
  Widget _buildFriendsTab(String myUid) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── طلبات الصداقة الواردة ──
        StreamBuilder<List<FriendRequest>>(
          stream: SocialService().getIncomingRequestsStream(myUid),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('طلبات الصداقة الواردة'.tr,
                        style: TextStyle(
                            color: LightGlass.text,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: L(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${requests.length}',
                          style: TextStyle(
                              color: L(0xFFFFFFFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ...requests.map((r) => _glassCard(
                      padding: EdgeInsets.all(10),
                      margin: EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _avatar(r.fromPhoto, r.fromName, radius: 21),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.fromName,
                                    style: TextStyle(
                                        color: LightGlass.text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                Text('@{} يريد إضافتك'.trp([r.fromUsername]),
                                    style: TextStyle(
                                        color: LightGlass.textMuted,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          // قبول
                          IconButton(
                            icon: Icon(Icons.check_circle_rounded,
                                color: L(0xFF10B981), size: 28),
                            tooltip: 'قبول'.tr,
                            onPressed: () async {
                              AppHaptics.medium();
                              await SocialService().acceptFriendRequest(r.id);
                              if (mounted) {
                                TopNotification.show(context,
                                    'أصبح {} صديقك! 🤝'.trp([r.fromName]),
                                    icon: Icons.check_circle);
                              }
                            },
                          ),
                          // رفض
                          IconButton(
                            icon: Icon(Icons.cancel_rounded,
                                color: L(0xFFEF4444), size: 26),
                            tooltip: 'رفض'.tr,
                            onPressed: () async {
                              AppHaptics.light();
                              await SocialService().declineFriendRequest(r.id);
                            },
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],
            );
          },
        ),

        // ── البحث ──
        TextField(
          controller: _searchController,
          style: TextStyle(color: LightGlass.text, fontSize: 14),
          decoration: InputDecoration(
            prefixIcon:
                Icon(Icons.search_rounded, color: LightGlass.accentBlue),
            hintText: 'ابحث باسم المستخدم الفريد (مثال: okey_king)...'.tr,
            hintStyle: TextStyle(color: LightGlass.textFaint, fontSize: 12),
            filled: true,
            fillColor: LightGlass.cardStrong,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: LightGlass.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: LightGlass.accentBlue, width: 1.4)),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: LightGlass.textMuted, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          onChanged: _performSearch,
        ),
        SizedBox(height: 16),

        // ── نتائج البحث ──
        if (_isSearching)
          Center(child: CircularProgressIndicator(color: LightGlass.accentBlue))
        else if (_searchResults.isNotEmpty) ...[
          Text('نتائج البحث:'.tr,
              style: TextStyle(
                  color: LightGlass.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          // نحتاج حالة الطلبات الصادرة + الأصدقاء لعرض الزر الصحيح
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
                      final isMe = user.uid == myUid;
                      final isFriend = friendUids.contains(user.uid);
                      final isPending = outgoing.contains(user.uid);
                      return _searchResultTile(
                          user, isMe, isFriend, isPending, myUid);
                    }).toList(),
                  );
                },
              );
            },
          ),
          Divider(color: LightGlass.borderDim, height: 24),
        ],

        // ── قائمة أصدقائي ──
        Text('قائمة أصدقائي:'.tr,
            style: TextStyle(
                color: LightGlass.textSoft,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        StreamBuilder<List<Map<String, dynamic>>>(
          stream: SocialService().getFriendsStream(myUid),
          builder: (context, snapshot) {
            final friends = snapshot.data ?? [];
            if (friends.isEmpty) {
              return _glassCard(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'لم تُضِف أصدقاء بعد. ابحث عنهم أعلاه وأرسل طلب صداقة!'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: LightGlass.textMuted, fontSize: 12),
                  ),
                ),
              );
            }

            return Column(
              children: friends.map((f) {
                final friendUser = AppUser(
                  uid: f['uid'],
                  email: '',
                  displayName: f['displayName'] ?? 'صديق'.tr,
                  username: f['username'] ?? '',
                  photoUrl: f['photoUrl'] ?? '',
                );
                return _glassCard(
                  padding: EdgeInsets.all(10),
                  margin: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      _avatar(friendUser.photoUrl, friendUser.displayName,
                          radius: 21),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(friendUser.displayName,
                                style: TextStyle(
                                    color: LightGlass.text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text('@${friendUser.username}',
                                style: TextStyle(
                                    color: LightGlass.accentBlue,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline_rounded,
                            color: LightGlass.accentBlue, size: 20),
                        tooltip: 'مراسلة'.tr,
                        onPressed: () => _openChat(friendUser),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded,
                            color: LightGlass.textMuted, size: 20),
                        color: LightGlass.cardStrong,
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                              value: 'delete',
                              child: Text('🗑️ حذف من الأصدقاء'.tr,
                                  style: TextStyle(color: LightGlass.text))),
                          PopupMenuItem(
                              value: 'report',
                              child: Text('🚨 إبلاغ للإدارة'.tr,
                                  style: TextStyle(color: L(0xFFDC2626)))),
                          PopupMenuItem(
                              value: 'block',
                              child: Text('🚫 حظر اللاعب'.tr,
                                  style: TextStyle(color: L(0xFFDC2626)))),
                        ],
                        onSelected: (val) async {
                          if (val == 'delete') {
                            await SocialService()
                                .removeFriend(myUid, friendUser.uid);
                            if (mounted) {
                              TopNotification.show(context, 'تم حذف الصديق'.tr);
                            }
                          }
                          if (val == 'report') {
                            _showReportDialog(friendUser);
                          }
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

  Widget _searchResultTile(
      AppUser user, bool isMe, bool isFriend, bool isPending, String myUid) {
    return _glassCard(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _avatar(user.photoUrl, user.displayName, radius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName,
                    style: TextStyle(
                        color: LightGlass.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Text('@${user.username}',
                    style:
                        TextStyle(color: LightGlass.accentBlue, fontSize: 11)),
                Text('تقييم {} • مستوى {}'.trp([user.rating, user.level]),
                    style:
                        TextStyle(color: LightGlass.textFaint, fontSize: 10.5)),
              ],
            ),
          ),
          if (!isMe) ...[
            // زر الإضافة حسب الحالة
            if (isFriend)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('صديقك ✓'.tr,
                    style: TextStyle(
                        color: L(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              )
            else if (isPending)
              TextButton.icon(
                onPressed: () async {
                  await SocialService().cancelFriendRequest(myUid, user.uid);
                },
                icon: Icon(Icons.hourglass_top_rounded,
                    color: LightGlass.textMuted, size: 15),
                label: Text('تم الإرسال — إلغاء'.tr,
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 10.5)),
              )
            else
              IconButton(
                icon: Icon(Icons.person_add_rounded,
                    color: L(0xFF10B981), size: 22),
                tooltip: 'إرسال طلب صداقة'.tr,
                onPressed: () async {
                  AppHaptics.selection();
                  final me = AuthService().currentUser;
                  if (me == null) return;
                  final error =
                      await SocialService().sendFriendRequest(me, user);
                  if (!mounted) return;
                  if (error != null) {
                    TopNotification.show(context, error,
                        icon: Icons.info_outline_rounded);
                  } else {
                    TopNotification.show(context,
                        'أُرسل طلب الصداقة إلى @{} 📨'.trp([user.username]),
                        icon: Icons.send_rounded);
                  }
                },
              ),
            IconButton(
              icon: Icon(Icons.chat_bubble_outline_rounded,
                  color: LightGlass.accentBlue, size: 20),
              tooltip: 'مراسلة'.tr,
              onPressed: () => _openChat(user),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: LightGlass.textMuted, size: 20),
              color: LightGlass.cardStrong,
              itemBuilder: (ctx) => [
                PopupMenuItem(
                    value: 'report',
                    child: Text('🚨 إبلاغ للإدارة'.tr,
                        style: TextStyle(color: L(0xFFDC2626)))),
                PopupMenuItem(
                    value: 'block',
                    child: Text('🚫 حظر اللاعب'.tr,
                        style: TextStyle(color: LightGlass.text))),
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
  }

  // ── عناصر مساعدة ──

  Widget _glassCard(
      {required Widget child,
      EdgeInsets padding = const EdgeInsets.all(12),
      EdgeInsets margin = EdgeInsets.zero}) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: LightGlass.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LightGlass.border),
              boxShadow: [
                BoxShadow(
                    color: L(0xFF64748B).withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _avatar(String photo, String name, {double radius = 22}) {
    final isEmoji = photo.isNotEmpty && photo.length <= 4;
    Widget content;
    if (UserAvatar.isDataUri(photo)) {
      try {
        content = ClipOval(
          child: Image.memory(
            base64Decode(photo.split(',').last),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        content = _initial(name, radius);
      }
    } else if (UserAvatar.isNetworkImage(photo)) {
      content = ClipOval(
        child: Image.network(photo,
            width: radius * 2, height: radius * 2, fit: BoxFit.cover),
      );
    } else if (isEmoji) {
      content = Text(photo, style: TextStyle(fontSize: radius));
    } else {
      content = _initial(name, radius);
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [L(0xFF60A5FA), L(0xFF3B82F6)]),
        border: Border.all(color: L(0xFFFFFFFF), width: 1.5),
        boxShadow: [
          BoxShadow(color: L(0xFF3B82F6).withOpacity(0.25), blurRadius: 6)
        ],
      ),
      child: Center(child: content),
    );
  }

  Widget _initial(String name, double radius) => Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'P',
        style: TextStyle(
            color: L(0xFFFFFFFF),
            fontWeight: FontWeight.w900,
            fontSize: radius * 0.8),
      );

  // ── الحوارات (إبلاغ/حظر) بنمط فاتح ──

  void _showReportDialog(AppUser targetUser) {
    AppHaptics.medium();
    String selectedReason = 'سلوك مسيء أو غير لائق'.tr;
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: LightGlass.cardStrong,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: L(0xFFEF4444), width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.report_problem_rounded,
                  color: L(0xFFEF4444), size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'إبلاغ عن @{}'.trp([targetUser.username]),
                  style: TextStyle(
                      color: LightGlass.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
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
                Text('اختر سبب البلاغ:'.tr,
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 12)),
                SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: LightGlass.cardStrong,
                  style: TextStyle(color: LightGlass.text, fontSize: 13),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: LightGlass.inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
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
                SizedBox(height: 12),
                Text('تفاصيل إضافية (اختياري):'.tr,
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 12)),
                SizedBox(height: 6),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  style: TextStyle(color: LightGlass.text, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'اكتب ما حدث للمساعدة في مراجعة البلاغ...'.tr,
                    hintStyle:
                        TextStyle(color: LightGlass.textFaint, fontSize: 12),
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
              child: Text('إلغاء'.tr,
                  style: TextStyle(color: LightGlass.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: L(0xFFDC2626),
                foregroundColor: L(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                    'تم إرسال البلاغ للإدارة بنجاح! سيتم التحقق واتخاذ الإجراء اللازم.'
                        .tr,
                    icon: Icons.shield_rounded,
                  );
                }
              },
              child: Text('إرسال البلاغ'.tr),
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
        backgroundColor: LightGlass.cardStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حظر اللاعب'.tr,
            style:
                TextStyle(color: LightGlass.text, fontWeight: FontWeight.bold)),
        content: Text(
          'هل أنت متأكد من حظر @{}؟ لن يتمكن من مراسلتك أو اللعب معك مرة أخرى.'
              .trp([targetUser.username]),
          style:
              TextStyle(color: LightGlass.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                Text('إلغاء'.tr, style: TextStyle(color: LightGlass.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: L(0xFFDC2626),
              foregroundColor: L(0xFFFFFFFF),
            ),
            onPressed: () async {
              final myUid = AuthService().currentUser?.uid;
              if (myUid != null) {
                await SocialService()
                    .blockUser(myUid, targetUser.uid, 'حظر من المستخدم'.tr);
              }
              if (mounted) {
                Navigator.of(ctx).pop();
                TopNotification.show(context, 'تم حظر اللاعب بنجاح'.tr,
                    icon: Icons.block_rounded);
              }
            },
            child: Text('نعم، حظر'.tr),
          ),
        ],
      ),
    );
  }
}

/// جرس الإشعارات في أعلى شاشة الدردشة — عدّاد طلبات الصداقة + الرسائل غير المقروءة
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: LightGlass.card,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: LightGlass.border),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.notifications_rounded,
                            color: LightGlass.accent, size: 20),
                        if (total > 0)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: EdgeInsets.all(3),
                              constraints:
                                  BoxConstraints(minWidth: 15, minHeight: 15),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: L(0xFFEF4444),
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
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// نافذة الإشعارات: طلبات الصداقة الواردة + المحادثات غير المقروءة
class NotificationsSheet extends StatelessWidget {
  final void Function(AppUser)? onOpenChat;

  const NotificationsSheet({super.key, this.onOpenChat});

  static void show(BuildContext context, {void Function(AppUser)? onOpenChat}) {
    BroadcastService.instance.markAllSeen();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationsSheet(onOpenChat: onOpenChat),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: BoxDecoration(
        color: LightGlass.cardStrong,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: LightGlass.border),
      ),
      child: Column(
        children: [
          SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: LightGlass.textFaint,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.notifications_rounded,
                    color: LightGlass.accent, size: 20),
                SizedBox(width: 8),
                Text('الإشعارات'.tr,
                    style: TextStyle(
                        color: LightGlass.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
              children: [
                // إشعارات الإدارة (آخر الرسائل العامة)
                StreamBuilder<List<BroadcastMessage>>(
                  stream: BroadcastService.instance.recentStream(),
                  builder: (context, snap) {
                    final items = (snap.data ?? [])
                        .where((b) => b.body.isNotEmpty)
                        .toList();
                    if (items.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('من الإدارة 📢'.tr,
                            style: TextStyle(
                                color: LightGlass.textSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        ...items.take(3).map((b) => Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  L(0xFFFFD54F).withOpacity(0.14),
                                  LightGlass.card,
                                ]),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: L(0xFFFFD54F).withOpacity(0.35)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('📢', style: TextStyle(fontSize: 18)),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(b.title,
                                            style: TextStyle(
                                                color: LightGlass.text,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800)),
                                        SizedBox(height: 2),
                                        Text(b.body,
                                            style: TextStyle(
                                                color: LightGlass.textMuted,
                                                fontSize: 11.5,
                                                height: 1.4)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),

                // طلبات الصداقة
                StreamBuilder<List<FriendRequest>>(
                  stream: SocialService().getIncomingRequestsStream(myUid),
                  builder: (context, snap) {
                    final requests = snap.data ?? [];
                    if (requests.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('طلبات صداقة:'.tr,
                            style: TextStyle(
                                color: LightGlass.textSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        ...requests.map((r) => Container(
                              margin: EdgeInsets.only(bottom: 8),
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: LightGlass.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: LightGlass.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_add_alt_1_rounded,
                                      color: LightGlass.accentBlue, size: 22),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '{} (@{}) أرسل لك طلب صداقة'
                                          .trp([r.fromName, r.fromUsername]),
                                      style: TextStyle(
                                          color: LightGlass.text,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.check_circle_rounded,
                                        color: L(0xFF10B981), size: 26),
                                    onPressed: () => SocialService()
                                        .acceptFriendRequest(r.id),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.cancel_rounded,
                                        color: L(0xFFEF4444), size: 24),
                                    onPressed: () => SocialService()
                                        .declineFriendRequest(r.id),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),

                // الرسائل غير المقروءة
                StreamBuilder<List<ConversationSummary>>(
                  stream: SocialService().getConversationsStream(myUid),
                  builder: (context, snap) {
                    final unreadConvs = (snap.data ?? [])
                        .where((c) => c.unreadCount > 0)
                        .toList();
                    if (unreadConvs.isEmpty) {
                      // لا شيء على الإطلاق؟
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('لا توجد إشعارات جديدة 🎉'.tr,
                              style: TextStyle(
                                  color: LightGlass.textMuted, fontSize: 12.5)),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('رسائل غير مقروءة:'.tr,
                            style: TextStyle(
                                color: LightGlass.textSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 6),
                        ...unreadConvs.map((c) => ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              leading: Icon(Icons.mark_chat_unread_rounded,
                                  color: LightGlass.accentBlue),
                              title: Text(c.otherName,
                                  style: TextStyle(
                                      color: LightGlass.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(c.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: LightGlass.textMuted,
                                      fontSize: 11)),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: L(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${c.unreadCount}',
                                    style: TextStyle(
                                        color: L(0xFFFFFFFF),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900)),
                              ),
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
                            )),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة الدردشة المباشرة — زجاج أبيض
class DirectChatModal extends StatefulWidget {
  final AppUser otherUser;

  const DirectChatModal({super.key, required this.otherUser});

  @override
  State<DirectChatModal> createState() => _DirectChatModalState();
}

class _DirectChatModalState extends State<DirectChatModal> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // تصفير غير المقروء عند فتح المحادثة
    final myUid = AuthService().currentUser?.uid ?? '';
    SocialService().markConversationRead(
        SocialService().getConversationId(myUid, widget.otherUser.uid), myUid);
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

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService().currentUser?.uid ?? '';
    final convId =
        SocialService().getConversationId(myUid, widget.otherUser.uid);

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: LightGlass.cardStrong,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: LightGlass.border),
          ),
          child: Column(
            children: [
              // الترويسة
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: LightGlass.cardStrong,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  border:
                      Border(bottom: BorderSide(color: LightGlass.borderDim)),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      photoUrl: widget.otherUser.photoUrl,
                      name: widget.otherUser.displayName,
                      size: 40,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.otherUser.displayName,
                              style: TextStyle(
                                  color: LightGlass.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              '@{} • متصل الآن 🟢'
                                  .trp([widget.otherUser.username]),
                              style: TextStyle(
                                  color: L(0xFF047857), fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: LightGlass.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // الرسائل
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
                            Text('👋', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 8),
                            Text(
                                'ابدأ محادثتك مع {}!'
                                    .trp([widget.otherUser.displayName]),
                                style: TextStyle(
                                    color: LightGlass.textMuted, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      physics: const BouncingScrollPhysics(),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.isMe;

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              gradient: isMe
                                  ? LinearGradient(
                                      colors: [L(0xFF475569), L(0xFF334155)])
                                  : null,
                              color: isMe ? null : LightGlass.card,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: isMe
                                    ? Radius.circular(16)
                                    : Radius.circular(4),
                                bottomRight: isMe
                                    ? Radius.circular(4)
                                    : Radius.circular(16),
                              ),
                              border: Border.all(
                                  color: isMe
                                      ? L(0x40FFD54F)
                                      : LightGlass.borderDim,
                                  width: 0.8),
                              boxShadow: [
                                BoxShadow(
                                    color: L(0xFF000000).withOpacity(0.06),
                                    blurRadius: 6,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(msg.text,
                                    style: TextStyle(
                                        color: isMe
                                            ? L(0xFFFFFFFF)
                                            : LightGlass.text,
                                        fontSize: 13.5)),
                                SizedBox(height: 2),
                                Text(
                                  '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      color: isMe
                                          ? L(0x8AFFFFFF)
                                          : LightGlass.textFaint,
                                      fontSize: 9.5),
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

              // حقل الإدخال
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightGlass.cardStrong,
                  border: Border(top: BorderSide(color: LightGlass.borderDim)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style:
                            TextStyle(color: LightGlass.text, fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالة...'.tr,
                          hintStyle: TextStyle(
                              color: LightGlass.textFaint, fontSize: 13),
                          filled: true,
                          fillColor: LightGlass.inputFill,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                            colors: [L(0xFF60A5FA), L(0xFF3B82F6)]),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.send_rounded,
                            color: L(0xFFFFFFFF), size: 20),
                        onPressed: _sendMessage,
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
}
