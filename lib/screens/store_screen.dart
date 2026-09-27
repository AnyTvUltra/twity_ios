import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/store_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/app_background.dart';
import '../widgets/skin_mockup.dart';
import '../widgets/gem_icon.dart';
import '../utils/format.dart';

/// متجر الكسنات: أحجار، طاولة، استكانة، خلفية
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StoreService _store = StoreService();
  final FirebaseService _firebase = FirebaseService();
  bool _processing = false;

  static const _categories = StoreCategory.all;

  @override
  void initState() {
    super.initState();
    _store.initialize();
    _tabController =
        TabController(length: _categories.length + 1, vsync: this);
    _store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleItemAction(StoreItem item) async {
    if (_processing) return;
    AppHaptics.medium();
    setState(() => _processing = true);
    try {
      if (_store.isEquipped(item)) {
        await _store.equip(item.category, null);
        if (mounted) TopNotification.show(context, 'تم إلغاء تجهيز الكسنة');
      } else if (_store.isOwned(item.id)) {
        await _store.equip(item.category, item);
        if (mounted) {
          TopNotification.show(context, 'تم تجهيز "${item.name}" ✅');
        }
      } else {
        final error = await _store.purchase(item);
        if (!mounted) return;
        if (error != null) {
          TopNotification.show(context, error, icon: Icons.warning_rounded);
        } else {
          await _store.equip(item.category, item);
          TopNotification.show(
              context, 'تم شراء وتجهيز "${item.name}" بنجاح! 🎉');
        }
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1122),
        body: AppBackground(
          light: true,
          child: SafeArea(
            child: Column(
              children: [
                // ── الترويسة ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: LightGlass.text, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'متجر الكسنات 🎨',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LightGlass.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      // رصيد العملات
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: BackdropFilter(
                          filter:
                              ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: LightGlass.cardStrong,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      const Color(0xFFFFD54F).withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🪙',
                                    style: TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                                Text(
                                  formatBalance(user?.chips ?? 0),
                                  style: const TextStyle(
                                    color: LightGlass.gold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 12,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  color: Colors.white.withOpacity(0.18),
                                ),
                                const GemIcon(size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  formatBalance(user?.gems ?? 0),
                                  style: const TextStyle(
                                    color: Color(0xFF7DD3FC),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
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

                // ── تبويبات الفئات ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: LightGlass.cardSoft,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: LightGlass.border),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: LightGlass.cardStrong,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: LightGlass.accentBlue,
                          unselectedLabelColor: LightGlass.textMuted,
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 12),
                          padding: const EdgeInsets.all(4),
                          tabs: [
                            ..._categories.map((c) => Tab(
                                  icon: Icon(StoreCategory.icon(c), size: 16),
                                  text: StoreCategory.label(c),
                                )),
                            const Tab(
                              icon: Icon(Icons.payments_rounded, size: 16),
                              text: 'شحن الرصيد',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── محتوى المتجر ──
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ..._categories.map(_buildCategoryGrid),
                      _buildTopupTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(String category) {
    final categoryItems = _store.items
        .where((e) => e.category == category && !e.hidden)
        .toList();

    if (categoryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(StoreCategory.icon(category),
                color: LightGlass.textFaint, size: 48),
            const SizedBox(height: 12),
            const Text(
              'لا توجد كسنات متاحة في هذه الفئة بعد',
              style: TextStyle(color: LightGlass.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'ترقّب التصاميم الجديدة قريباً!',
              style: TextStyle(color: LightGlass.textFaint, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: categoryItems.length,
      itemBuilder: (context, index) =>
          _buildItemCard(categoryItems[index]),
    );
  }

  Widget _buildItemCard(StoreItem item) {
    final owned = _store.isOwned(item.id);
    final equipped = _store.isEquipped(item);
    final user = AuthService().currentUser;
    final locked = item.requiredWins > 0 &&
        (user?.wins ?? 0) < item.requiredWins;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: equipped
                  ? [
                      const Color(0xFF1E3A5F).withOpacity(0.95),
                      const Color(0xFF152A4A).withOpacity(0.9),
                    ]
                  : [
                      const Color(0xFF1B2438).withOpacity(0.85),
                      const Color(0xFF141C30).withOpacity(0.7),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: equipped
                  ? const Color(0xFF3B82F6)
                  : LightGlass.border,
              width: equipped ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // معاينة الموك اب + شارة "محدود"
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      SkinMockup(
                        category: item.category,
                        image: item.imageBase64.isNotEmpty
                            ? item.provider
                            : null,
                        width: double.infinity,
                        height: double.infinity,
                        zoom: item.zoom,
                        offsetX: item.offsetX,
                        offsetY: item.offsetY,
                        effect: item.effect,
                        item: item,
                      ),
                      if (item.limited)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFF472B6),
                                Color(0xFFA855F7),
                              ]),
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: [
                                BoxShadow(
                                    color: const Color(0xFFA855F7)
                                        .withOpacity(0.4),
                                    blurRadius: 8),
                              ],
                            ),
                            child: const Text(
                              'محدود ⏳',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      if (item.requiredWins > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1122)
                                  .withOpacity(0.75),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: const Color(0xFFFFD54F)
                                      .withOpacity(0.6)),
                            ),
                            child: Text(
                              '🏆 ${item.requiredWins} فوزاً',
                              style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // الاسم والسعر
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LightGlass.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    if (!owned)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.currency == StoreCurrency.gems)
                            const GemIcon(size: 13)
                          else
                            const Text('🪙', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text(
                            formatBalance(item.price),
                            style: TextStyle(
                              color: item.currency == StoreCurrency.gems
                                  ? const Color(0xFF7DD3FC)
                                  : LightGlass.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // زر الإجراء
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: (_processing || locked)
                        ? null
                        : () => _handleItemAction(item),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: locked
                          ? const Color(0xFF1E293B)
                          : equipped
                              ? const Color(0xFF334155)
                              : owned
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFFD54F),
                      disabledBackgroundColor: locked
                          ? const Color(0xFF1E293B)
                          : null,
                      foregroundColor: equipped || owned
                          ? Colors.white
                          : const Color(0xFF1B0B30),
                      disabledForegroundColor: const Color(0xFF64748B),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      locked
                          ? '🔒 يتطلب ${item.requiredWins} فوزاً'
                          : equipped
                              ? 'مُجهَّزة ✓ — إلغاء'
                              : owned
                                  ? 'تجهيز الكسنة'
                                  : item.price == 0
                                      ? 'مجانية — تجهيز'
                                      : 'شراء وتجهيز',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 11.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // تبويب شحن الرصيد بالمال الحقيقي (باقات + طلبات)
  // ══════════════════════════════════════════════════════════

  Widget _buildTopupTab() {
    if (!_firebase.isInitialized) {
      return const Center(
        child: Text('قاعدة البيانات غير متصلة حالياً',
            style: TextStyle(color: LightGlass.textMuted)),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _firebase.firestore
          .collection('coin_packs')
          .where('active', isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
        }
        final packs = snap.data?.docs ?? [];
        if (packs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.payments_outlined,
                    color: LightGlass.textFaint, size: 48),
                SizedBox(height: 12),
                Text('لا توجد باقات شحن متاحة حالياً',
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 13)),
                SizedBox(height: 4),
                Text('ترقّب عروض الشحن قريباً!',
                    style:
                        TextStyle(color: LightGlass.textFaint, fontSize: 11)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
          ),
          itemCount: packs.length,
          itemBuilder: (context, i) => _buildPackCard(packs[i]),
        );
      },
    );
  }

  Widget _buildPackCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isGems = data['type'] == 'gems';
    final amount = (data['amount'] as num?)?.toInt() ?? 0;
    final price = (data['priceUsd'] as num?)?.toDouble() ?? 0;
    final title = data['title'] ?? 'باقة';
    final color = isGems ? const Color(0xFF38BDF8) : const Color(0xFFFFD54F);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.16),
                const Color(0xFF141C30).withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.45), width: 1.2),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isGems
                            ? const [
                                Color(0xFFBAE6FD),
                                Color(0xFF38BDF8),
                                Color(0xFF0369A1)
                              ]
                            : const [
                                Color(0xFFFFF9C4),
                                Color(0xFFFFD54F),
                                Color(0xFFFF8F00)
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.45), blurRadius: 8)
                      ],
                    ),
                    child: Center(
                      child: isGems
                          ? const GemIcon(size: 24)
                          : const Icon(
                              Icons.monetization_on_rounded,
                              color: Color(0xFF7C2D12),
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                color: LightGlass.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatBalance(amount),
                              style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15),
                            ),
                            const SizedBox(width: 3),
                            isGems
                                ? const GemIcon(size: 14)
                                : const Text('🪙',
                                    style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    '\$${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
                    style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed:
                        _processing ? null : () => _buyPack(doc.id, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: isGems
                          ? const Color(0xFF082F49)
                          : const Color(0xFF451A03),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('شراء',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// إنشاء طلب شراء — يُضاف الرصيد بعد تأكيد الإدارة للدفع
  Future<void> _buyPack(String packId, Map<String, dynamic> data) async {
    final user = AuthService().currentUser;
    if (user == null) {
      TopNotification.show(context, 'سجّل الدخول أولاً لشراء الباقات',
          icon: Icons.warning_rounded);
      return;
    }
    if (_processing) return;
    AppHaptics.medium();
    setState(() => _processing = true);
    try {
      await _firebase.firestore.collection('orders').add({
        'uid': user.uid,
        'username': user.username,
        'displayName': user.displayName,
        'packId': packId,
        'packTitle': data['title'] ?? 'باقة',
        'type': data['type'] ?? 'chips',
        'amount': data['amount'] ?? 0,
        'priceUsd': data['priceUsd'] ?? 0,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        TopNotification.show(
          context,
          'تم إرسال طلب الشراء ✅ سيُضاف رصيدك بعد تأكيد الدفع من الإدارة',
        );
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, 'تعذر إرسال الطلب: $e',
            icon: Icons.warning_rounded);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
