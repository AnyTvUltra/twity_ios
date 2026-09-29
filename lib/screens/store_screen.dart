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
import '../l10n/app_lang.dart';

import '../theme_mode.dart';

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
    _tabController = TabController(length: _categories.length + 1, vsync: this);
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
        if (mounted) TopNotification.show(context, 'تم إلغاء تجهيز الكسنة'.tr);
      } else if (_store.isOwned(item.id)) {
        await _store.equip(item.category, item);
        if (mounted) {
          TopNotification.show(context, 'تم تجهيز "{}" ✅'.trp([item.name]));
        }
      } else {
        final error = await _store.purchase(item);
        if (!mounted) return;
        if (error != null) {
          TopNotification.show(context, error, icon: Icons.warning_rounded);
        } else {
          await _store.equip(item.category, item);
          TopNotification.show(
              context, 'تم شراء وتجهيز "{}" بنجاح! 🎉'.trp([item.name]));
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
        backgroundColor: L(0xFF0A1122),
        body: AppBackground(
          light: true,
          child: SafeArea(
            child: Column(
              children: [
                // ── الترويسة ──
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_rounded,
                            color: LightGlass.text, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'متجر الكسنات 🎨'.tr,
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
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: LightGlass.cardStrong,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: L(0xFFFFD54F).withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🪙', style: TextStyle(fontSize: 13)),
                                SizedBox(width: 4),
                                Text(
                                  formatBalance(user?.chips ?? 0),
                                  style: TextStyle(
                                    color: LightGlass.gold,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 12,
                                  margin: EdgeInsets.symmetric(horizontal: 6),
                                  color: L(0xFFFFFFFF).withOpacity(0.18),
                                ),
                                GemIcon(size: 15),
                                SizedBox(width: 4),
                                Text(
                                  formatBalance(user?.gems ?? 0),
                                  style: TextStyle(
                                    color: L(0xFF7DD3FC),
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

                // ── أقسام المتجر — شريط أيقونات زجاجي قابل للتمرير ──
                SizedBox(
                  height: 64,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (var i = 0; i < _categories.length; i++)
                        _categoryChip(
                          i,
                          StoreCategory.icon(_categories[i]),
                          StoreCategory.label(_categories[i]),
                        ),
                      _categoryChip(
                        _categories.length,
                        Icons.payments_rounded,
                        'شحن الرصيد'.tr,
                        accent: L(0xFFFFD54F),
                      ),
                    ],
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

  /// زر قسم زجاجي: أيقونة + اسم — تدرّج بنفسجي للمحدّد
  Widget _categoryChip(int index, IconData icon, String label,
      {Color accent = const Color(0xFF8B5CF6)}) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final selected = _tabController.index == index;
        return GestureDetector(
          onTap: () {
            AppHaptics.selection();
            _tabController.animateTo(index);
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 180),
            margin: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            padding: EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withOpacity(0.65)],
                    )
                  : null,
              color: selected ? null : L(0xFF141C34),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? accent.withOpacity(0.9)
                    : L(0xFFFFFFFF).withOpacity(0.10),
                width: selected ? 1.3 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: accent.withOpacity(0.35),
                          blurRadius: 12,
                          offset: Offset(0, 3)),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 17, color: selected ? L(0xFFFFFFFF) : L(0xFF94A3B8)),
                SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? L(0xFFFFFFFF) : L(0xFF94A3B8),
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid(String category) {
    final categoryItems =
        _store.items.where((e) => e.category == category && !e.hidden).toList();

    if (categoryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(StoreCategory.icon(category),
                color: LightGlass.textFaint, size: 48),
            SizedBox(height: 12),
            Text(
              'لا توجد كسنات متاحة في هذه الفئة بعد'.tr,
              style: TextStyle(color: LightGlass.textMuted, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'ترقّب التصاميم الجديدة قريباً!'.tr,
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
      itemBuilder: (context, index) => _buildItemCard(categoryItems[index]),
    );
  }

  Widget _buildItemCard(StoreItem item) {
    final owned = _store.isOwned(item.id);
    final equipped = _store.isEquipped(item);
    final user = AuthService().currentUser;
    final locked =
        item.requiredWins > 0 && (user?.wins ?? 0) < item.requiredWins;

    return GestureDetector(
      onTap: () => _showSkinPreview(item),
      child: ClipRRect(
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
                        L(0xFF1E3A5F).withOpacity(0.95),
                        L(0xFF152A4A).withOpacity(0.9),
                      ]
                    : [
                        L(0xFF1B2438).withOpacity(0.85),
                        L(0xFF141C30).withOpacity(0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: equipped ? L(0xFF3B82F6) : LightGlass.border,
                width: equipped ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // معاينة الموك اب + شارة "محدود"
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10, 12, 10, 4),
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  L(0xFFF472B6),
                                  L(0xFFA855F7),
                                ]),
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: [
                                  BoxShadow(
                                      color: L(0xFFA855F7).withOpacity(0.4),
                                      blurRadius: 8),
                                ],
                              ),
                              child: Text(
                                'محدود ⏳'.tr,
                                style: TextStyle(
                                    color: L(0xFFFFFFFF),
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
                              padding: EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: L(0xFF0A1122).withOpacity(0.75),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: L(0xFFFFD54F).withOpacity(0.6)),
                              ),
                              child: Text(
                                '🏆 {} فوزاً'.trp([item.requiredWins]),
                                style: TextStyle(
                                    color: L(0xFFFFD54F),
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
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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
                              GemIcon(size: 13)
                            else
                              Text('🪙', style: TextStyle(fontSize: 11)),
                            SizedBox(width: 3),
                            Text(
                              formatBalance(item.price),
                              style: TextStyle(
                                color: item.currency == StoreCurrency.gems
                                    ? L(0xFF7DD3FC)
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
                SizedBox(height: 8),

                // زر الإجراء
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: (_processing || locked)
                          ? null
                          : () => _handleItemAction(item),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: locked
                            ? L(0xFF1E293B)
                            : equipped
                                ? L(0xFF334155)
                                : owned
                                    ? L(0xFF10B981)
                                    : L(0xFFFFD54F),
                        disabledBackgroundColor: locked ? L(0xFF1E293B) : null,
                        foregroundColor:
                            equipped || owned ? L(0xFFFFFFFF) : L(0xFF1B0B30),
                        disabledForegroundColor: L(0xFF64748B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        locked
                            ? '🔒 يتطلب {} فوزاً'.trp([item.requiredWins])
                            : equipped
                                ? 'مُجهَّزة ✓ — إلغاء'.tr
                                : owned
                                    ? 'تجهيز الكسنة'.tr
                                    : item.price == 0
                                        ? 'مجانية — تجهيز'.tr
                                        : 'شراء وتجهيز'.tr,
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
      ),
    );
  }

  /// معاينة واقعية عند الضغط على أي كسنة — تعرضها على أدوات اللعب
  /// الحقيقية (استكانة/أحجار/طاولة/إطار) قبل الشراء
  void _showSkinPreview(StoreItem item) {
    final owned = _store.isOwned(item.id);
    final equipped = _store.isEquipped(item);
    final user = AuthService().currentUser;
    final locked =
        item.requiredWins > 0 && (user?.wins ?? 0) < item.requiredWins;
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: AppLangController.instance.direction,
        child: Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
          decoration: BoxDecoration(
            color: L(0xFF10172E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: L(0xFF8B5CF6).withOpacity(0.35)),
          ),
          padding: EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: L(0x3DFFFFFF),
                    borderRadius: BorderRadius.circular(4)),
              ),
              SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Text(item.name,
                      style: TextStyle(
                          color: L(0xFFFFFFFF),
                          fontSize: 16,
                          fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis),
                ),
                if (item.limited)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [L(0xFFF472B6), L(0xFFA855F7)]),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('محدود ⏳'.tr,
                        style: TextStyle(
                            color: L(0xFFFFFFFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
              ]),
              SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'هكذا ستبدو على أدواتك داخل اللعبة'.tr,
                  style: TextStyle(color: L(0x8AFFFFFF), fontSize: 11),
                ),
              ),
              SizedBox(height: 14),
              // المسرح — نفس طريقة عرض الاستكانة لكل الفئات
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 190,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [L(0xFF1E2B4D), L(0xFF0A0F22)],
                      radius: 1.1,
                    ),
                  ),
                  child: Center(
                    child: SkinMockup(
                      category: item.category,
                      image: item.imageBase64.isNotEmpty ? item.provider : null,
                      width: double.infinity,
                      height: 190,
                      zoom: item.zoom,
                      offsetX: item.offsetX,
                      offsetY: item.offsetY,
                      effect: item.effect,
                      item: item,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14),
              Row(children: [
                // السعر
                if (!owned)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: L(0xFFFFFFFF).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: L(0x1FFFFFFF)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (item.currency == StoreCurrency.gems)
                        GemIcon(size: 16)
                      else
                        Text('🪙', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 5),
                      Text(formatBalance(item.price),
                          style: TextStyle(
                              color: L(0xFFFFFFFF),
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                    ]),
                  ),
                if (!owned) const SizedBox(width: 10),
                // زر الإجراء
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: (_processing || locked)
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              _handleItemAction(item);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: locked
                            ? L(0xFF1E293B)
                            : equipped
                                ? L(0xFF334155)
                                : owned
                                    ? L(0xFF10B981)
                                    : L(0xFF8B5CF6),
                        disabledBackgroundColor: L(0xFF1E293B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          locked
                              ? '🔒 يتطلب {} فوزاً'.trp([item.requiredWins])
                              : equipped
                                  ? 'مُجهَّزة ✓ — إلغاء'.tr
                                  : owned
                                      ? 'تجهيز الكسنة'.tr
                                      : item.price == 0
                                          ? 'مجانية — تجهيز'.tr
                                          : 'شراء وتجهيز'.tr,
                          style: TextStyle(
                              color: L(0xFFFFFFFF),
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
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
      return Center(
        child: Text('قاعدة البيانات غير متصلة حالياً'.tr,
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
          return Center(child: CircularProgressIndicator(color: L(0xFF38BDF8)));
        }
        final packs = snap.data?.docs ?? [];
        if (packs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.payments_outlined,
                    color: LightGlass.textFaint, size: 48),
                SizedBox(height: 12),
                Text('لا توجد باقات شحن متاحة حالياً'.tr,
                    style:
                        TextStyle(color: LightGlass.textMuted, fontSize: 13)),
                SizedBox(height: 4),
                Text('ترقّب عروض الشحن قريباً!'.tr,
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
    final title = data['title'] ?? 'باقة'.tr;
    final color = isGems ? L(0xFF38BDF8) : L(0xFFFFD54F);

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
                L(0xFF141C30).withOpacity(0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.45), width: 1.2),
          ),
          padding: EdgeInsets.all(14),
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
                            ? [L(0xFFBAE6FD), L(0xFF38BDF8), L(0xFF0369A1)]
                            : [L(0xFFFFF9C4), L(0xFFFFD54F), L(0xFFFF8F00)],
                      ),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.45), blurRadius: 8)
                      ],
                    ),
                    child: Center(
                      child: isGems
                          ? GemIcon(size: 24)
                          : Icon(
                              Icons.monetization_on_rounded,
                              color: L(0xFF7C2D12),
                              size: 22,
                            ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
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
                            SizedBox(width: 3),
                            isGems
                                ? GemIcon(size: 14)
                                : Text('🪙', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Spacer(),
              Row(
                children: [
                  Text(
                    '\$${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)}',
                    style: TextStyle(
                        color: L(0xFF4ADE80),
                        fontWeight: FontWeight.w900,
                        fontSize: 16),
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed:
                        _processing ? null : () => _buyPack(doc.id, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: isGems ? L(0xFF082F49) : L(0xFF451A03),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('شراء'.tr,
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
      TopNotification.show(context, 'سجّل الدخول أولاً لشراء الباقات'.tr,
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
        'packTitle': data['title'] ?? 'باقة'.tr,
        'type': data['type'] ?? 'chips',
        'amount': data['amount'] ?? 0,
        'priceUsd': data['priceUsd'] ?? 0,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        TopNotification.show(
          context,
          'تم إرسال طلب الشراء ✅ سيُضاف رصيدك بعد تأكيد الدفع من الإدارة'.tr,
        );
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, 'تعذر إرسال الطلب: {}'.trp([e]),
            icon: Icons.warning_rounded);
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }
}
