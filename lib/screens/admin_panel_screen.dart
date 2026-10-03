import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../services/store_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../utils/url_helper.dart';
import '../widgets/skin_mockup.dart';
import '../widgets/user_avatar.dart';
import '../l10n/app_lang.dart';

/// لوحة الإدارة والتحكم الكاملة للتطبيق - مرتبطة بسحابة Firebase
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  bool _isAuthenticated = false;
  bool _checking = true;
  String _denyReason = '';

  late TabController _tabController;
  final FirebaseService _firebase = FirebaseService();

  // إعدادات اللعبة
  int _startingChips = 1250;
  int _defaultTurnTimer = 72;
  String _botDifficulty = 'medium';
  bool _maintenanceMode = false;
  String _announcement = 'مرحباً بكم في مجتمع الألعاب الممتعة!'.tr;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadRemoteConfig();
    _checkAdminAccess();
  }

  /// الدخول للوحة مقيّد بالحسابات المسجلة في مجموعة admins فقط
  Future<void> _checkAdminAccess() async {
    final user = AuthService().currentUser;
    if (user == null || user.uid.startsWith('guest_')) {
      setState(() {
        _checking = false;
        _denyReason = 'سجّل دخولك بحساب مدير حقيقي أولاً (ليس حساب ضيف)'.tr;
      });
      return;
    }
    if (!_firebase.isInitialized) {
      setState(() {
        _checking = false;
        _denyReason = 'قاعدة البيانات غير متصلة'.tr;
      });
      return;
    }
    try {
      final doc =
          await _firebase.firestore.collection('admins').doc(user.uid).get();
      setState(() {
        _isAuthenticated = doc.exists;
        _checking = false;
        if (!doc.exists) {
          _denyReason = 'هذا الحساب لا يملك صلاحيات الإدارة'.tr;
        }
      });
    } catch (e) {
      setState(() {
        _checking = false;
        _denyReason = 'تعذّر التحقق من الصلاحيات'.tr;
      });
    }
  }

  Future<void> _loadRemoteConfig() async {
    if (!_firebase.isInitialized) return;
    try {
      final doc = await _firebase.firestore
          .collection('config')
          .doc('game_settings')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _startingChips = data['startingChips'] ?? 1250;
          _defaultTurnTimer = data['defaultTurnTimer'] ?? 72;
          _botDifficulty = data['botDifficulty'] ?? 'medium';
          _maintenanceMode = data['maintenanceMode'] ?? false;
          _announcement = data['announcement'] ?? _announcement;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRemoteConfig() async {
    if (!_firebase.isInitialized) {
      TopNotification.show(context, '⚠️ قاعدة البيانات غير مهيأة بعد'.tr);
      return;
    }
    try {
      await _firebase.firestore.collection('config').doc('game_settings').set({
        'startingChips': _startingChips,
        'defaultTurnTimer': _defaultTurnTimer,
        'botDifficulty': _botDifficulty,
        'maintenanceMode': _maintenanceMode,
        'announcement': _announcement,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppHaptics.heavy();
      if (mounted) {
        TopNotification.show(
            context, '✅ تم حفظ ونشر الإعدادات بنجاح في السحابة!'.tr);
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, 'حدث خطأ أثناء الحفظ: {}'.trp([e]));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D111A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF161C28),
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded,
                  color: Color(0xFF4ADE80), size: 24),
              SizedBox(width: 10),
              Text(
                'لوحة التحكم الإدارية (Admin Panel)'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'فتح لوحة الويب للكمبيوتر (Desktop Dashboard)'.tr,
              icon: const Icon(Icons.open_in_new_rounded,
                  color: Color(0xFF38BDF8)),
              onPressed: () => openAdminWeb(),
            ),
            if (_isAuthenticated)
              IconButton(
                tooltip: 'تسجيل خروج'.tr,
                icon: const Icon(Icons.lock_outline_rounded,
                    color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _isAuthenticated = false;
                    _denyReason = 'تم قفل لوحة الإدارة'.tr;
                  });
                  TopNotification.show(context, 'تم قفل لوحة الإدارة 🔒'.tr);
                },
              ),
          ],
          bottom: _isAuthenticated
              ? TabBar(
                  controller: _tabController,
                  indicatorColor: Color(0xFF4ADE80),
                  labelColor: Color(0xFF4ADE80),
                  unselectedLabelColor: Colors.white60,
                  labelStyle:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  isScrollable: true,
                  tabs: [
                    Tab(
                        icon: Icon(Icons.dashboard_rounded, size: 18),
                        text: 'الإحصائيات'.tr),
                    Tab(
                        icon: Icon(Icons.people_alt_rounded, size: 18),
                        text: 'الحسابات'.tr),
                    Tab(
                        icon: Icon(Icons.report_rounded, size: 18),
                        text: 'البلاغات'.tr),
                    Tab(
                        icon: Icon(Icons.tune_rounded, size: 18),
                        text: 'إعدادات اللعبة'.tr),
                    Tab(
                        icon: Icon(Icons.storefront_rounded, size: 18),
                        text: 'المتجر والسكنات'.tr),
                    Tab(
                        icon: Icon(Icons.workspace_premium_rounded, size: 18),
                        text: 'طلبات VIP'.tr),
                    Tab(
                        icon: Icon(Icons.history_rounded, size: 18),
                        text: 'سجل المباريات'.tr),
                  ],
                )
              : null,
        ),
        body: _isAuthenticated
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildPlayersTab(),
                  _buildReportsTab(),
                  _buildConfigTab(),
                  _buildStoreTab(),
                  _buildVipRequestsTab(),
                  _buildHistoryTab(),
                ],
              )
            : _buildAccessScreen(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // شاشة التحقق من صلاحية الأدمن (دخول حقيقي عبر حساب Firebase)
  // ══════════════════════════════════════════════════════════
  Widget _buildAccessScreen() {
    if (_checking) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF4ADE80)),
            SizedBox(height: 16),
            Text(
              'جارٍ التحقق من صلاحيات الإدارة...'.tr,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x334ADE80), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
                  ),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'منطقة الإدارة الآمنة'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _denyReason.isEmpty
                    ? 'الوصول مقيّد لحسابات المدير المسجلة في مجموعة admins'.tr
                    : _denyReason,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => openAdminWeb(),
                icon: const Icon(Icons.desktop_windows_rounded,
                    size: 16, color: Color(0xFF38BDF8)),
                label: Text(
                  'فتح لوحة الويب للكمبيوتر (Desktop Dashboard) ↗'.tr,
                  style: TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0x5538BDF8)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded,
                    size: 16, color: Colors.white54),
                label: Text(
                  'عودة'.tr,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 1: الإحصائيات العامة (Overview Tab)
  // ══════════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firebase.isInitialized
          ? _firebase.firestore.collection('users').snapshots()
          : const Stream.empty(),
      builder: (context, snapshot) {
        int totalPlayers = 0;
        int totalChips = 0;

        if (snapshot.hasData) {
          totalPlayers = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalChips += (data['chips'] as num?)?.toInt() ?? 0;
          }
        }

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // بطاقات الإحصائيات الرئيسية
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people_alt_rounded,
                    title: 'إجمالي الحسابات المسجلة'.tr,
                    value: '$totalPlayers',
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.monetization_on_rounded,
                    title: 'إجمالي العملات المتداولة'.tr,
                    value: '$totalChips 🪙',
                    color: const Color(0xFFEAB308),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.cloud_done_rounded,
                    title: 'حالة السحابة (Firebase)'.tr,
                    value: _firebase.isInitialized
                        ? 'متصل بنجاح ✅'.tr
                        : 'جاري التهيئة...'.tr,
                    color: const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.language_rounded,
                    title: 'استضافة Cloudflare'.tr,
                    value: 'جاهز للنشر 🌐'.tr,
                    color: const Color(0xFFF97316),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // شريط الإعلانات العاجل المباشر
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x334ADE80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_rounded,
                          color: Color(0xFF4ADE80), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'شريط الإعلانات العام لجميع اللاعبين:'.tr,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _announcement,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 11.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 2: إدارة الحسابات الحقيقية (Users Tab)
  // ══════════════════════════════════════════════════════════
  String _userSearch = '';

  Widget _buildPlayersTab() {
    if (!_firebase.isInitialized) {
      return Center(
        child: Text('قاعدة البيانات غير متصلة'.tr,
            style: TextStyle(color: Colors.white60)),
      );
    }

    return Column(
      children: [
        // شريط البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو اسم المستخدم...'.tr,
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Colors.white38, size: 20),
              filled: true,
              fillColor: const Color(0xFF161C28),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) =>
                setState(() => _userSearch = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // الحسابات الحقيقية المسجلة في التطبيق
            stream: _firebase.firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
              }

              var docs = snapshot.data!.docs;
              if (_userSearch.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name =
                      (data['displayName'] ?? '').toString().toLowerCase();
                  final username =
                      (data['username'] ?? '').toString().toLowerCase();
                  return name.contains(_userSearch) ||
                      username.contains(_userSearch);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Text('لا توجد حسابات مطابقة'.tr,
                      style: TextStyle(color: Colors.white60)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['displayName'] ?? 'لاعب'.tr;
                  final username = data['username'] ?? '';
                  final photo = data['photoUrl'] ?? '';
                  final chips = data['chips'] ?? 0;
                  final rating = data['rating'] ?? 1000;
                  final level = data['level'] ?? 1;
                  final wins = data['wins'] ?? 0;
                  final losses = data['losses'] ?? 0;
                  final isGuest = doc.id.startsWith('guest_');
                  final isBanned = data['isBanned'] ?? false;
                  final vipUntilTs = data['vipUntil'];
                  final isVip = vipUntilTs is Timestamp &&
                      vipUntilTs.toDate().isAfter(DateTime.now());

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161C28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isBanned
                            ? Colors.redAccent.withOpacity(0.7)
                            : const Color(0x22FFFFFF),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // الصورة الرمزية
                            UserAvatar(photoUrl: photo, name: name, size: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (isGuest)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.orange.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text('ضيف'.tr,
                                              style: TextStyle(
                                                  color: Colors.orangeAccent,
                                                  fontSize: 9)),
                                        ),
                                      if (isBanned) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.redAccent,
                                                width: 0.8),
                                          ),
                                          child: Text('محظور'.tr,
                                              style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 10)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text('@$username',
                                      style: const TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded,
                                  color: Color(0xFF4ADE80), size: 20),
                              tooltip: 'تعديل بيانات الحساب'.tr,
                              onPressed: () =>
                                  _showEditUserDialog(doc.id, data),
                            ),
                            IconButton(
                              icon: Icon(
                                isVip
                                    ? Icons.workspace_premium_rounded
                                    : Icons.workspace_premium_outlined,
                                color: isVip
                                    ? const Color(0xFFFFD54F)
                                    : Colors.white38,
                                size: 20,
                              ),
                              tooltip: isVip
                                  ? 'إلغاء اشتراك VIP'.tr
                                  : 'تفعيل VIP لمدة 30 يوماً'.tr,
                              onPressed: () async {
                                await _firebase.firestore
                                    .collection('users')
                                    .doc(doc.id)
                                    .update({
                                  'vipUntil': isVip
                                      ? null
                                      : Timestamp.fromDate(DateTime.now()
                                          .add(const Duration(days: 30))),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                                if (mounted) {
                                  TopNotification.show(
                                    context,
                                    isVip
                                        ? 'تم إلغاء اشتراك VIP'.tr
                                        : 'تم تفعيل VIP لمدة 30 يوماً 👑'.tr,
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                isBanned
                                    ? Icons.lock_open_rounded
                                    : Icons.block_rounded,
                                color:
                                    isBanned ? Colors.green : Colors.redAccent,
                                size: 20,
                              ),
                              tooltip:
                                  isBanned ? 'فك الحظر'.tr : 'حظر الحساب'.tr,
                              onPressed: () {
                                _firebase.firestore
                                    .collection('users')
                                    .doc(doc.id)
                                    .update({'isBanned': !isBanned});
                                TopNotification.show(
                                  context,
                                  isBanned
                                      ? 'تم فك حظر الحساب'.tr
                                      : 'تم حظر الحساب'.tr,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // شريط إحصائيات صغير
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniStat('🪙', '$chips', 'الرصيد'.tr),
                            _miniStat('⭐', '$rating', 'التقييم'.tr),
                            _miniStat('🏆', '$level', 'المستوى'.tr),
                            _miniStat('✅', '$wins', 'فوز'.tr),
                            _miniStat('❌', '$losses', 'خسارة'.tr),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String emoji, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 3),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 3: بلاغات اللاعبين (Reports Tab)
  // ══════════════════════════════════════════════════════════
  Widget _buildReportsTab() {
    if (!_firebase.isInitialized) {
      return Center(
          child: Text('قاعدة البيانات غير متصلة'.tr,
              style: TextStyle(color: Colors.white60)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firebase.firestore
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد بلاغات — كل شيء نظيف! ✅'.tr,
                style: TextStyle(color: Colors.white60)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data() as Map<String, dynamic>;
            final isPending = d['status'] == 'pending';
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPending
                      ? const Color(0xFFEF4444).withOpacity(0.5)
                      : const Color(0x22FFFFFF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                          isPending
                              ? Icons.report_problem_rounded
                              : Icons.check_circle_rounded,
                          color: isPending
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF4ADE80),
                          size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '{}'.trp([d['reason'] ?? 'بلاغ']),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPending
                              ? Colors.red.withOpacity(0.15)
                              : Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPending ? 'معلّق'.tr : 'تمت المعالجة'.tr,
                          style: TextStyle(
                              color: isPending
                                  ? Colors.redAccent
                                  : const Color(0xFF4ADE80),
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'المُبلِغ: {}  ←  المُبلَغ عنه: @{}'.trp(
                        [d['reporterName'] ?? '', d['reportedUsername'] ?? '']),
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                  if ((d['details'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('التفاصيل: {}'.trp([d['details']]),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                  if (isPending)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            doc.reference.update({'status': 'resolved'}),
                        icon: const Icon(Icons.check_rounded,
                            size: 16, color: Color(0xFF4ADE80)),
                        label: Text('تمت المعالجة'.tr,
                            style: TextStyle(
                                color: Color(0xFF4ADE80), fontSize: 11.5)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditUserDialog(String docId, Map<String, dynamic> data) {
    final nameCtrl =
        TextEditingController(text: data['displayName'] ?? data['name'] ?? '');
    final chipsCtrl = TextEditingController(text: '${data['chips'] ?? 0}');
    final ratingCtrl = TextEditingController(text: '${data['rating'] ?? 1000}');
    final levelCtrl = TextEditingController(text: '${data['level'] ?? 1}');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF161C28),
          title: Text('تعديل: {}'.trp([data['displayName'] ?? data['name']]),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: 'الاسم المعروض'.tr,
                      labelStyle: TextStyle(color: Colors.white60)),
                ),
                TextField(
                  controller: chipsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: 'الرصيد (عملات)'.tr,
                      labelStyle: TextStyle(color: Colors.white60)),
                ),
                TextField(
                  controller: ratingCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: 'التقييم (Rating)'.tr,
                      labelStyle: TextStyle(color: Colors.white60)),
                ),
                TextField(
                  controller: levelCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      labelText: 'المستوى (Level)'.tr,
                      labelStyle: TextStyle(color: Colors.white60)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('إلغاء'.tr, style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firebase.firestore
                    .collection('users')
                    .doc(docId)
                    .update({
                  'displayName': nameCtrl.text.trim(),
                  'chips': int.tryParse(chipsCtrl.text) ?? 0,
                  'rating': int.tryParse(ratingCtrl.text) ?? 1000,
                  'level': int.tryParse(levelCtrl.text) ?? 1,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  TopNotification.show(
                      context, 'تم تحديث بيانات الحساب بنجاح ✅'.tr);
                }
              },
              child: Text('حفظ التعديلات'.tr),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 4: إعدادات اللعبة والقواعد (Config Tab)
  // ══════════════════════════════════════════════════════════
  Widget _buildConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // بطاقة وضع الصيانة
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _maintenanceMode
                  ? Colors.orangeAccent
                  : const Color(0x22FFFFFF),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.build_circle_rounded,
                      color: Colors.orangeAccent, size: 24),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('وضع الصيانة (Maintenance Mode)'.tr,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      SizedBox(height: 2),
                      Text('قفل اللعبة مؤقتاً لتحديث النظام'.tr,
                          style:
                              TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _maintenanceMode,
                activeColor: Colors.orangeAccent,
                onChanged: (val) => setState(() => _maintenanceMode = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // الرصيد الابتدائي
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الرصيد الابتدائي للاعبين الجدد (Starting Bakiye):'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [100, 500, 1000, 1250, 2000].map((val) {
                  final isSel = _startingChips == val;
                  return GestureDetector(
                    onTap: () => setState(() => _startingChips = val),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF22C55E)
                            : const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$val',
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // مدة الدور
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مدة مؤقت الدور الافتراضية (Turn Timer):'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [30, 45, 60, 72, 90].map((val) {
                  final isSel = _defaultTurnTimer == val;
                  return GestureDetector(
                    onTap: () => setState(() => _defaultTurnTimer = val),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF22C55E)
                            : const Color(0x22FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${val}s',
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // نص الإعلان العام
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161C28),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نص الإعلان وشريط التنبيهات العاجل:'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _announcement,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0x33000000),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) => _announcement = val,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // زر الحفظ والنشر السحابي
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _saveRemoteConfig,
            icon: const Icon(Icons.cloud_upload_rounded),
            label: Text('حفظ ونشر الإعدادات في السحابة'.tr,
                style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 4: إدارة المتجر والكسنات (Store Tab) - معاينة موك اب
  // ══════════════════════════════════════════════════════════
  Widget _buildStoreTab() {
    return Column(
      children: [
        // زر إضافة تصميم جديد
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _showAddSkinDialog,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text(
                'إضافة تصميم جديد للمتجر (موك اب)'.tr,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),

        // قائمة الكسنات الحالية
        Expanded(
          child: !_firebase.isInitialized
              ? Center(
                  child: Text('قاعدة البيانات غير متصلة'.tr,
                      style: TextStyle(color: Colors.white60)))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firebase.firestore
                      .collection('store_items')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF4ADE80)));
                    }
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'لا توجد كسنات في المتجر بعد — أضف أول تصميم!'.tr,
                          style: TextStyle(color: Colors.white60),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final item = StoreItem.fromDoc(doc);
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161C28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: item.active
                                  ? const Color(0x334ADE80)
                                  : Colors.redAccent.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              // مصغّر الموك اب
                              SizedBox(
                                width: 90,
                                height: 56,
                                child: SkinMockup(
                                  category: item.category,
                                  image: item.imageBase64.isNotEmpty
                                      ? item.provider
                                      : null,
                                  width: 90,
                                  height: 56,
                                  zoom: item.zoom,
                                  offsetX: item.offsetX,
                                  offsetY: item.offsetY,
                                  item: item,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${StoreCategory.label(item.category)} • ${StoreCurrency.icon(item.currency)} ${item.price}',
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: item.active ? 'إخفاء'.tr : 'إظهار'.tr,
                                icon: Icon(
                                  item.active
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: item.active
                                      ? const Color(0xFF4ADE80)
                                      : Colors.white38,
                                ),
                                onPressed: () {
                                  doc.reference
                                      .update({'active': !item.active});
                                },
                              ),
                              IconButton(
                                tooltip: 'حذف'.tr,
                                icon: const Icon(Icons.delete_rounded,
                                    color: Colors.redAccent),
                                onPressed: () => doc.reference.delete(),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// نافذة إضافة تصميم جديد: رفع صورة + معاينة موك اب حية + نشر
  void _showAddSkinDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '500');
    String selectedCategory = StoreCategory.okeyRoom;
    String selectedCurrency = StoreCurrency.chips;
    String? imageBase64;
    bool saving = false;
    double imgZoom = 1.0;
    double imgOffX = 0.0;
    double imgOffY = 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickImage() async {
            try {
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 80,
              );
              if (file == null) return;
              final bytes = await file.readAsBytes();
              setDialogState(() => imageBase64 = base64Encode(bytes));
            } catch (e) {
              if (ctx.mounted) {
                TopNotification.show(ctx, 'تعذر اختيار الصورة: {}'.trp([e]));
              }
            }
          }

          Future<void> save() async {
            if (nameCtrl.text.trim().isEmpty) {
              TopNotification.show(ctx, 'أدخل اسم التصميم أولاً'.tr);
              return;
            }
            if (imageBase64 == null) {
              TopNotification.show(ctx, 'اختر صورة التصميم أولاً'.tr);
              return;
            }
            setDialogState(() => saving = true);
            try {
              await _firebase.firestore.collection('store_items').add({
                'name': nameCtrl.text.trim(),
                'category': selectedCategory,
                'price': int.tryParse(priceCtrl.text) ?? 500,
                'currency': selectedCurrency,
                'imageBase64': imageBase64,
                'active': true,
                'zoom': imgZoom,
                'offsetX': imgOffX,
                'offsetY': imgOffY,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                TopNotification.show(
                    context, 'تم نشر التصميم في المتجر بنجاح! 🎉'.tr);
              }
            } catch (e) {
              setDialogState(() => saving = false);
              if (ctx.mounted) {
                TopNotification.show(ctx, 'فشل النشر: {}'.trp([e]));
              }
            }
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF161C28),
              title: Text(
                'تصميم كسنة جديدة (موك اب)'.tr,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // اختيار الفئة
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: StoreCategory.all.map((cat) {
                          final sel = selectedCategory == cat;
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedCategory = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel
                                    ? const Color(0xFF7C3AED)
                                    : const Color(0x22FFFFFF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: sel
                                      ? const Color(0xFFA78BFA)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(StoreCategory.icon(cat),
                                      size: 14,
                                      color:
                                          sel ? Colors.white : Colors.white54),
                                  const SizedBox(width: 5),
                                  Text(
                                    StoreCategory.label(cat),
                                    style: TextStyle(
                                      color:
                                          sel ? Colors.white : Colors.white70,
                                      fontSize: 11.5,
                                      fontWeight: sel
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // زر رفع الصورة
                      OutlinedButton.icon(
                        onPressed: saving ? null : pickImage,
                        icon: Icon(
                          imageBase64 == null
                              ? Icons.upload_rounded
                              : Icons.check_circle_rounded,
                          color: imageBase64 == null
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF4ADE80),
                          size: 18,
                        ),
                        label: Text(
                          imageBase64 == null
                              ? 'اختيار صورة التصميم'.tr
                              : 'تم اختيار الصورة ✓ — تغييرها'.tr,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0x5538BDF8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // المعاينة الحية على القطعة المختارة (موك اب)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D111A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'معاينة حية على القطعة:'.tr,
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 10.5),
                            ),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onPanUpdate: imageBase64 == null
                                  ? null
                                  : (d) => setDialogState(() {
                                        imgOffX = (imgOffX + d.delta.dx / 150)
                                            .clamp(-1.0, 1.0);
                                        imgOffY = (imgOffY + d.delta.dy / 75)
                                            .clamp(-1.0, 1.0);
                                      }),
                              child: SkinMockup(
                                category: selectedCategory,
                                image: imageBase64 != null
                                    ? MemoryImage(base64Decode(imageBase64!))
                                    : null,
                                width: 300,
                                height: 150,
                                zoom: imgZoom,
                                offsetX: imgOffX,
                                offsetY: imgOffY,
                                item: imageBase64 != null
                                    ? StoreItem(
                                        id: 'admin_preview',
                                        name: 'معاينة'.tr,
                                        category: selectedCategory,
                                        price: 0,
                                        imageBase64: imageBase64!,
                                        zoom: imgZoom,
                                        offsetX: imgOffX,
                                        offsetY: imgOffY,
                                      )
                                    : null,
                              ),
                            ),
                            if (imageBase64 != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.zoom_in_rounded,
                                      color: Colors.white54, size: 16),
                                  Expanded(
                                    child: Slider(
                                      value: imgZoom,
                                      min: 0.6,
                                      max: 3.0,
                                      divisions: 48,
                                      activeColor: const Color(0xFFA78BFA),
                                      onChanged: (v) =>
                                          setDialogState(() => imgZoom = v),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'إعادة الضبط'.tr,
                                    icon: const Icon(Icons.restart_alt_rounded,
                                        color: Colors.white54, size: 18),
                                    onPressed: () => setDialogState(() {
                                      imgZoom = 1.0;
                                      imgOffX = 0;
                                      imgOffY = 0;
                                    }),
                                  ),
                                ],
                              ),
                              Text(
                                'اسحب الصورة لتحريكها على القطعة • حرّك المنزلق للتكبير'
                                    .tr,
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 9.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // الاسم والسعر
                      TextField(
                        controller: nameCtrl,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'اسم التصميم'.tr,
                          labelStyle: TextStyle(color: Colors.white60),
                          hintText: 'مثال: رخام ملكي'.tr,
                          hintStyle: TextStyle(color: Colors.white30),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'السعر'.tr,
                          labelStyle: TextStyle(color: Colors.white60),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // اختيار عملة البيع
                      Row(
                        children: [
                          for (final c in [
                            (StoreCurrency.chips, '🪙 عملات ذهبية'.tr),
                            (StoreCurrency.gems, '💎 مجوهرات زرقاء'.tr),
                          ])
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(
                                    () => selectedCurrency = c.$1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selectedCurrency == c.$1
                                        ? (c.$1 == StoreCurrency.gems
                                            ? const Color(0x3338BDF8)
                                            : const Color(0x33FFD54F))
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selectedCurrency == c.$1
                                          ? (c.$1 == StoreCurrency.gems
                                              ? const Color(0xFF38BDF8)
                                              : const Color(0xFFFFD54F))
                                          : Colors.white12,
                                    ),
                                  ),
                                  child: Text(
                                    c.$2,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selectedCurrency == c.$1
                                          ? Colors.white
                                          : Colors.white54,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  child:
                      Text('إلغاء'.tr, style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.publish_rounded, size: 16),
                  label: Text(saving ? 'جاري النشر...'.tr : 'نشر في المتجر'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 5: سجل المباريات (History Tab)
  // ══════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════
  // التبويب 6: طلبات اشتراك VIP (10$/شهر — تفعيل يدوي بعد الدفع)
  // ══════════════════════════════════════════════════════════
  Widget _buildVipRequestsTab() {
    if (!_firebase.isInitialized) {
      return Center(
          child: Text('قاعدة البيانات غير متصلة'.tr,
              style: TextStyle(color: Colors.white60)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firebase.firestore
          .collection('vip_requests')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد طلبات اشتراك VIP بعد'.tr,
                style: TextStyle(color: Colors.white60)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final d = doc.data() as Map<String, dynamic>;
            final isPending = d['status'] == 'pending';
            final ts = d['createdAt'];
            final created = ts is Timestamp ? ts.toDate() : null;

            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF161C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPending
                      ? Color(0xFFFFD54F).withOpacity(0.5)
                      : Color(0x22FFFFFF),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isPending
                        ? Icons.hourglass_top_rounded
                        : Icons.workspace_premium_rounded,
                    color: isPending ? Color(0xFFFFD54F) : Color(0xFF4ADE80),
                    size: 26,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '{}  @{}'.trp([
                            d['displayName'] ?? 'لاعب',
                            d['username'] ?? ''
                          ]),
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        Text(
                          'اشتراك شهري — {}\$'.trp([d['priceUsd'] ?? 10]) +
                              (created != null
                                  ? '  •  ${created.day}/${created.month}/${created.year}'
                                  : ''),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (isPending) ...[
                    IconButton(
                      tooltip: 'تفعيل VIP — 30 يوماً'.tr,
                      icon: const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF4ADE80), size: 26),
                      onPressed: () => _approveVip(doc, d),
                    ),
                    IconButton(
                      tooltip: 'رفض الطلب'.tr,
                      icon: const Icon(Icons.cancel_rounded,
                          color: Colors.redAccent, size: 26),
                      onPressed: () =>
                          doc.reference.update({'status': 'rejected'}),
                    ),
                  ] else
                    Text(
                      d['status'] == 'approved' ? 'مُفعّل ✓'.tr : 'مرفوض'.tr,
                      style: TextStyle(
                          color: d['status'] == 'approved'
                              ? const Color(0xFF4ADE80)
                              : Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// تفعيل VIP: تحديث vipUntil على المستخدم + وضع الطلب "مقبول"
  Future<void> _approveVip(DocumentSnapshot doc, Map<String, dynamic> d) async {
    final uid = d['uid'] as String?;
    if (uid == null) return;
    try {
      final userRef = _firebase.firestore.collection('users').doc(uid);
      final snap = await userRef.get();
      final data = snap.data();
      // يمدّد من نهاية الاشتراك الحالي إن كان فعّالاً
      DateTime base = DateTime.now();
      final cur = data?['vipUntil'];
      if (cur is Timestamp && cur.toDate().isAfter(base)) {
        base = cur.toDate();
      }
      final isPlus = d['plan'] == 'vipPlus';
      await userRef.update({
        'vipUntil': Timestamp.fromDate(base.add(const Duration(days: 30))),
        'vipTier': isPlus ? 'vipPlus' : 'vip',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await doc.reference.update({'status': 'approved'});
      if (mounted) {
        TopNotification.show(
            context,
            'تم تفعيل {} لـ {} — 30 يوماً 👑'
                .trp([isPlus ? 'VIP+' : 'VIP', d['displayName'] ?? '']));
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, 'تعذر التفعيل: {}'.trp([e]),
            icon: Icons.warning_rounded);
      }
    }
  }

  Widget _buildHistoryTab() {
    if (!_firebase.isInitialized) {
      return Center(
          child: Text('قاعدة البيانات غير متصلة'.tr,
              style: TextStyle(color: Colors.white60)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firebase.firestore
          .collection('game_history')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Text('لا توجد مباريات مسجلة بعد'.tr,
                style: TextStyle(color: Colors.white60)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final winner = data['winner'] ?? 'غير معروف'.tr;
            final winType = data['winType'] ?? 'normal';
            final duration = data['durationSeconds'] ?? 0;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFD54F), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الفائز: {}'.trp([winner]),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                            'نوع الفوز: {} | المدة: {}s'
                                .trp([winType, duration]),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
