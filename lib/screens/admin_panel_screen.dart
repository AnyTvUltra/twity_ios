import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../utils/url_helper.dart';

/// لوحة الإدارة والتحكم الكاملة للتطبيق - مرتبطة بسحابة Firebase
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  bool _isAuthenticated = false;
  final TextEditingController _pinController = TextEditingController();
  String _pinError = '';

  late TabController _tabController;
  final FirebaseService _firebase = FirebaseService();

  // إعدادات اللعبة
  int _startingChips = 1250;
  int _defaultTurnTimer = 72;
  String _botDifficulty = 'medium';
  bool _maintenanceMode = false;
  String _announcement = 'مرحباً بكم في مجتمع الألعاب الممتعة!';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRemoteConfig();
  }

  Future<void> _loadRemoteConfig() async {
    if (!_firebase.isInitialized) return;
    try {
      final doc = await _firebase.firestore.collection('config').doc('game_settings').get();
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
      TopNotification.show(context, '⚠️ قاعدة البيانات غير مهيأة بعد');
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
        TopNotification.show(context, '✅ تم حفظ ونشر الإعدادات بنجاح في السحابة!');
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, 'حدث خطأ أثناء الحفظ: $e');
      }
    }
  }

  void _verifyPin() {
    // الرمز الافتراضي: 123456 أو admin2026
    final pin = _pinController.text.trim();
    if (pin == '123456' || pin == 'admin2026') {
      AppHaptics.medium();
      setState(() {
        _isAuthenticated = true;
        _pinError = '';
      });
    } else {
      AppHaptics.heavy();
      setState(() {
        _pinError = 'رمز المرور غير صحيح! الرمز الافتراضي هو: 123456';
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
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
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF4ADE80), size: 24),
              SizedBox(width: 10),
              Text(
                'لوحة التحكم الإدارية (Admin Panel)',
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
              tooltip: 'فتح لوحة الويب للكمبيوتر (Desktop Dashboard)',
              icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF38BDF8)),
              onPressed: () => openAdminWeb(),
            ),
            if (_isAuthenticated)
              IconButton(
                tooltip: 'تسجيل خروج',
                icon: const Icon(Icons.lock_outline_rounded, color: Colors.redAccent),
                onPressed: () {
                  setState(() => _isAuthenticated = false);
                  TopNotification.show(context, 'تم قفل لوحة الإدارة 🔒');
                },
              ),
          ],
          bottom: _isAuthenticated
              ? TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF4ADE80),
                  labelColor: const Color(0xFF4ADE80),
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'الإحصائيات'),
                    Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'اللاعبين'),
                    Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'إعدادات اللعبة'),
                    Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'سجل المباريات'),
                  ],
                )
              : null,
        ),
        body: _isAuthenticated ? TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildPlayersTab(),
            _buildConfigTab(),
            _buildHistoryTab(),
          ],
        ) : _buildLoginScreen(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // شاشة تسجيل دخول الإدارة بـ PIN
  // ══════════════════════════════════════════════════════════
  Widget _buildLoginScreen() {
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
                    colors: [Color(0xFF22C55E), Color(0xFF15803D)],
                  ),
                ),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 16),
              const Text(
                'منطقة الإدارة الآمنة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'أدخل رمز المرور السري للوصول إلى لوحة التحكم',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'رمز المرور',
                  hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 0),
                  filled: true,
                  fillColor: const Color(0x33000000),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x33FFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF4ADE80), width: 1.5),
                  ),
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
              if (_pinError.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _pinError,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _verifyPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'الرمز الافتراضي: 123456 أو admin2026',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => openAdminWeb(),
                icon: const Icon(Icons.desktop_windows_rounded, size: 16, color: Color(0xFF38BDF8)),
                label: const Text(
                  'فتح لوحة الويب للكمبيوتر (Desktop Dashboard) ↗',
                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0x5538BDF8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          ? _firebase.firestore.collection('players').snapshots()
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
                    title: 'إجمالي اللاعبين',
                    value: '$totalPlayers',
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.monetization_on_rounded,
                    title: 'إجمالي الرصيد المتداول',
                    value: '$totalChips Bakiye',
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
                    title: 'حالة السحابة (Firebase)',
                    value: _firebase.isInitialized ? 'متصل بنجاح ✅' : 'جاري التهيئة...',
                    color: const Color(0xFF22C55E),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.language_rounded,
                    title: 'استضافة Cloudflare',
                    value: 'جاهز للنشر 🌐',
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
                  const Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: Color(0xFF4ADE80), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'شريط الإعلانات العام لجميع اللاعبين:',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
            style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 2: إدارة اللاعبين (Players Tab)
  // ══════════════════════════════════════════════════════════
  Widget _buildPlayersTab() {
    if (!_firebase.isInitialized) {
      return const Center(
        child: Text('قاعدة البيانات غير متصلة', style: TextStyle(color: Colors.white60)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firebase.firestore.collection('players').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline_rounded, color: Colors.white30, size: 48),
                const SizedBox(height: 12),
                const Text('لا يوجد لاعبين مسجلين بعد في قاعدة البيانات', style: TextStyle(color: Colors.white60)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddPlayerDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة لاعب تجريبي'),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'لاعب';
            final chips = data['chips'] ?? 0;
            final rating = data['rating'] ?? 1000;
            final level = data['level'] ?? 1;
            final isBanned = data['isBanned'] ?? false;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF161C28),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBanned ? Colors.redAccent : const Color(0x22FFFFFF),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2E384D),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'P',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (isBanned) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.redAccent, width: 0.8),
                                ),
                                child: const Text('محظور', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المستوى: $level | التقييم: $rating | الرصيد: $chips Bakiye',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Color(0xFF4ADE80)),
                    tooltip: 'تعديل بيانات اللاعب',
                    onPressed: () => _showEditPlayerDialog(doc.id, data),
                  ),
                  IconButton(
                    icon: Icon(
                      isBanned ? Icons.lock_open_rounded : Icons.block_rounded,
                      color: isBanned ? Colors.green : Colors.redAccent,
                    ),
                    tooltip: isBanned ? 'فك الحظر' : 'حظر اللاعب',
                    onPressed: () {
                      _firebase.firestore.collection('players').doc(doc.id).update({
                        'isBanned': !isBanned,
                      });
                      TopNotification.show(
                        context,
                        isBanned ? 'تم فك حظر اللاعب' : 'تم حظر اللاعب',
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddPlayerDialog() {
    final nameCtrl = TextEditingController(text: 'Player 1');
    final chipsCtrl = TextEditingController(text: '1250');
    final ratingCtrl = TextEditingController(text: '1300');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF161C28),
          title: const Text('إضافة لاعب جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'اسم اللاعب', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: chipsCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'الرصيد الابتدائي', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: ratingCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'التقييم', labelStyle: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final id = 'player_${DateTime.now().millisecondsSinceEpoch}';
                await _firebase.firestore.collection('players').doc(id).set({
                  'id': id,
                  'name': nameCtrl.text.trim(),
                  'chips': int.tryParse(chipsCtrl.text) ?? 1250,
                  'rating': int.tryParse(ratingCtrl.text) ?? 1300,
                  'level': 1,
                  'wins': 0,
                  'losses': 0,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) TopNotification.show(context, 'تمت إضافة اللاعب بنجاح ✅');
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPlayerDialog(String docId, Map<String, dynamic> data) {
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final chipsCtrl = TextEditingController(text: '${data['chips'] ?? 0}');
    final ratingCtrl = TextEditingController(text: '${data['rating'] ?? 1000}');
    final levelCtrl = TextEditingController(text: '${data['level'] ?? 1}');

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF161C28),
          title: Text('تعديل: ${data['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'اسم اللاعب', labelStyle: TextStyle(color: Colors.white60)),
                ),
                TextField(
                  controller: chipsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'الرصيد (Bakiye)', labelStyle: TextStyle(color: Colors.white60)),
                ),
                TextField(
                  controller: ratingCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'التقييم (Rating)', labelStyle: TextStyle(color: Colors.white60)),
                ),
                TextField(
                  controller: levelCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'المستوى (Level)', labelStyle: TextStyle(color: Colors.white60)),
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
              onPressed: () async {
                await _firebase.firestore.collection('players').doc(docId).update({
                  'name': nameCtrl.text.trim(),
                  'chips': int.tryParse(chipsCtrl.text) ?? 0,
                  'rating': int.tryParse(ratingCtrl.text) ?? 1000,
                  'level': int.tryParse(levelCtrl.text) ?? 1,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) TopNotification.show(context, 'تم تحديث بيانات اللاعب بنجاح ✅');
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 3: إعدادات اللعبة والقواعد (Config Tab)
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
              color: _maintenanceMode ? Colors.orangeAccent : const Color(0x22FFFFFF),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.build_circle_rounded, color: Colors.orangeAccent, size: 24),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('وضع الصيانة (Maintenance Mode)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 2),
                      Text('قفل اللعبة مؤقتاً لتحديث النظام', style: TextStyle(color: Colors.white60, fontSize: 11)),
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
              const Text('الرصيد الابتدائي للاعبين الجدد (Starting Bakiye):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [100, 500, 1000, 1250, 2000].map((val) {
                  final isSel = _startingChips == val;
                  return GestureDetector(
                    onTap: () => setState(() => _startingChips = val),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF22C55E) : const Color(0x22FFFFFF),
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
              const Text('مدة مؤقت الدور الافتراضية (Turn Timer):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [30, 45, 60, 72, 90].map((val) {
                  final isSel = _defaultTurnTimer == val;
                  return GestureDetector(
                    onTap: () => setState(() => _defaultTurnTimer = val),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF22C55E) : const Color(0x22FFFFFF),
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
              const Text('نص الإعلان وشريط التنبيهات العاجل:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _announcement,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0x33000000),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            label: const Text('حفظ ونشر الإعدادات في السحابة', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // التبويب 4: سجل المباريات (History Tab)
  // ══════════════════════════════════════════════════════════
  Widget _buildHistoryTab() {
    if (!_firebase.isInitialized) {
      return const Center(child: Text('قاعدة البيانات غير متصلة', style: TextStyle(color: Colors.white60)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firebase.firestore
          .collection('game_history')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF4ADE80)));
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('لا توجد مباريات مسجلة بعد', style: TextStyle(color: Colors.white60)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final winner = data['winner'] ?? 'غير معروف';
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
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD54F), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الفائز: $winner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('نوع الفوز: $winType | المدة: ${duration}s', style: const TextStyle(color: Colors.white60, fontSize: 11)),
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
