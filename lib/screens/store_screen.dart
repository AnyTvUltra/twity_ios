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
import '../widgets/coin_icon.dart';
import '../utils/format.dart';
import '../l10n/app_lang.dart';

/// متجر الكسنات: أحجار، طاولة، استكانة، خلفية
class StoreScreen extends StatefulWidget {
  /// يفتح المتجر مباشرة على تبويب شحن الرصيد (من زر + في الترويسة)
  final bool openTopup;

  const StoreScreen({super.key, this.openTopup = false});

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
    _tabController = TabController(
        length: _categories.length + 1,
        vsync: this,
        initialIndex: widget.openTopup ? _categories.length : 0);
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
                                const CoinIcon(size: 15),
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
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
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
                        accent: const Color(0xFFFFD54F),
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
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withOpacity(0.65)],
                    )
                  : null,
              color: selected ? null : const Color(0xFF141C34),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? accent.withOpacity(0.9)
                    : Colors.white.withOpacity(0.10),
                width: selected ? 1.3 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: accent.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 3)),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 17,
                    color: selected ? Colors.white : const Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF94A3B8),
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
            const SizedBox(height: 12),
            Text(
              'لا توجد كسنات متاحة في هذه الفئة بعد'.tr,
              style: TextStyle(color: LightGlass.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 4),
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
      cacheExtent: 600,
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

    // بلا BackdropFilter لكل بطاقة: كان يعيد التمويه كل إطار خلف السكنات
    // المتحركة فيتقطع التمرير — RepaintBoundary يعزل كل بطاقة
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _showSkinPreview(item),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
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
                color: equipped ? const Color(0xFF3B82F6) : LightGlass.border,
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
                              child: Text(
                                'محدود ⏳'.tr,
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
                                color:
                                    const Color(0xFF0A1122).withOpacity(0.75),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: const Color(0xFFFFD54F)
                                        .withOpacity(0.6)),
                              ),
                              child: Text(
                                '🏆 {} فوزاً'.trp([item.requiredWins]),
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
                              const CoinIcon(size: 13),
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
                        disabledBackgroundColor:
                            locked ? const Color(0xFF1E293B) : null,
                        foregroundColor: equipped || owned
                            ? Colors.white
                            : const Color(0xFF1B0B30),
                        disabledForegroundColor: const Color(0xFF64748B),
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
            color: const Color(0xFF10172E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border:
                Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: Text(item.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis),
                ),
                if (item.limited)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFF472B6), Color(0xFFA855F7)]),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text('محدود ⏳'.tr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
              ]),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'هكذا ستبدو على أدواتك داخل اللعبة'.tr,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
              const SizedBox(height: 14),
              // المسرح — نفس طريقة عرض الاستكانة لكل الفئات
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 190,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xFF1E2B4D), Color(0xFF0A0F22)],
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
              const SizedBox(height: 14),
              Row(children: [
                // السعر
                if (!owned)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (item.currency == StoreCurrency.gems)
                        const GemIcon(size: 16)
                      else
                        const CoinIcon(size: 16),
                      const SizedBox(width: 5),
                      Text(formatBalance(item.price),
                          style: const TextStyle(
                              color: Colors.white,
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
                            ? const Color(0xFF1E293B)
                            : equipped
                                ? const Color(0xFF334155)
                                : owned
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF8B5CF6),
                        disabledBackgroundColor: const Color(0xFF1E293B),
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
                          style: const TextStyle(
                              color: Colors.white,
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

  /// باقات الشحن الافتراضية — تُعرض عندما لا تنشر الإدارة باقات خاصة
  static const List<_Pack> _defaultPacks = [
    _Pack('builtin_coins_1', 'حفنة عملات', false, 5000, 0, 0.99),
    _Pack('builtin_coins_2', 'كيس عملات', false, 15000, 10, 2.99),
    _Pack('builtin_coins_3', 'صندوق عملات', false, 30000, 20, 4.99,
        badge: 'الأكثر شعبية'),
    _Pack('builtin_coins_4', 'خزنة عملات', false, 70000, 30, 9.99),
    _Pack('builtin_coins_5', 'كنز العملات', false, 160000, 40, 19.99,
        badge: 'أفضل قيمة'),
    _Pack('builtin_coins_6', 'ثروة ملكية', false, 450000, 60, 49.99),
    _Pack('builtin_gems_1', 'حفنة جواهر', true, 50, 0, 0.99),
    _Pack('builtin_gems_2', 'كيس جواهر', true, 160, 10, 2.99),
    _Pack('builtin_gems_3', 'صندوق جواهر', true, 300, 20, 4.99,
        badge: 'الأكثر شعبية'),
    _Pack('builtin_gems_4', 'خزنة جواهر', true, 650, 30, 9.99),
    _Pack('builtin_gems_5', 'كنز الجواهر', true, 1400, 40, 19.99,
        badge: 'أفضل قيمة'),
    _Pack('builtin_gems_6', 'تاج الجواهر', true, 3800, 60, 49.99),
  ];

  bool _topupGems = false;

  Widget _buildTopupTab() {
    final stream = _firebase.isInitialized
        ? _firebase.firestore
            .collection('coin_packs')
            .where('active', isEqualTo: true)
            .snapshots()
        : const Stream<QuerySnapshot>.empty();
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final remote = [
          for (final d in snap.data?.docs ?? <QueryDocumentSnapshot>[])
            _Pack.fromDoc(d),
        ];
        // باقات الإدارة إن وُجدت، وإلا الباقات الافتراضية الكاملة
        final all = remote.isNotEmpty ? remote : _defaultPacks;
        final packs = all.where((p) => p.gems == _topupGems).toList();
        final user = AuthService().currentUser;

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══ بطاقة الرصيد ═══
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2A1F5C), Color(0xFF12224A)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.14)),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.25),
                          blurRadius: 24,
                          spreadRadius: -6),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _balanceTile(
                          const CoinIcon(size: 30),
                          formatBalance(user?.chips ?? 0),
                          'عملات'.tr,
                          const Color(0xFFFFD54F),
                        ),
                      ),
                      Container(
                          width: 1,
                          height: 44,
                          color: Colors.white.withOpacity(0.12)),
                      Expanded(
                        child: _balanceTile(
                          const GemIcon(size: 30),
                          formatBalance(user?.gems ?? 0),
                          'جواهر'.tr,
                          const Color(0xFF7DD3FC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ═══ مبدّل العملات / الجواهر ═══
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141C34),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      _segment(false, 'عملات'.tr, const CoinIcon(size: 18)),
                      _segment(true, 'جواهر'.tr, const GemIcon(size: 18)),
                    ],
                  ),
                ),
              ),
            ),

            // ═══ الباقات ═══
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.74,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _packCard(packs[i], i),
                  childCount: packs.length,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        color: Color(0xFF4ADE80), size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'يُضاف الرصيد بعد تأكيد الدفع من الإدارة'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: LightGlass.textMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _balanceTile(Widget icon, String value, String label, Color color) {
    return Column(
      children: [
        icon,
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: LightGlass.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _segment(bool gems, String label, Widget icon) {
    final sel = _topupGems == gems;
    final color = gems ? const Color(0xFF38BDF8) : const Color(0xFFFFB300);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() => _topupGems = gems);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: sel
                ? LinearGradient(colors: [color.withOpacity(0.9), color])
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: sel
                ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: sel ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  /// بطاقة باقة: رسم كومة عملات/جواهر يكبر مع الباقة، الكمية، شارة
  /// المكافأة، وزر السعر
  Widget _packCard(_Pack p, int tier) {
    final color = p.gems ? const Color(0xFF38BDF8) : const Color(0xFFFFC107);
    final highlighted = p.badge != null;
    final count = (tier + 1).clamp(1, 6);
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withOpacity(highlighted ? 0.28 : 0.16),
              const Color(0xFF111A33),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: color.withOpacity(highlighted ? 0.85 : 0.35),
              width: highlighted ? 1.6 : 1),
          boxShadow: highlighted
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 18)]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
              child: Column(
                children: [
                  // كومة العملات/الجواهر المرسومة
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: 96,
                        height: 70,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 80,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: color.withOpacity(0.35),
                                      blurRadius: 24),
                                ],
                              ),
                            ),
                            for (var k = 0; k < count; k++)
                              Positioned(
                                bottom: (k ~/ 3) * 16.0 + (k % 3 == 1 ? 6 : 0),
                                left: 18.0 + (k % 3) * 20 + (k ~/ 3) * 10,
                                child: p.gems
                                    ? const GemIcon(size: 30)
                                    : const CoinIcon(size: 28),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    formatBalance(p.amount),
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(color: color.withOpacity(0.5), blurRadius: 10)
                        ]),
                  ),
                  Text(
                    p.title.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: LightGlass.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  if (p.bonus > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF4ADE80).withOpacity(0.5)),
                      ),
                      child: Text(
                        '+{}% مجاناً'.trp([p.bonus]),
                        style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _processing ? null : () => _buyPack(p.id, p.toMap()),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF4ADE80),
                          Color(0xFF16A34A),
                        ]),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF16A34A).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3)),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '\$${p.price.toStringAsFixed(p.price == p.price.roundToDouble() ? 0 : 2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (highlighted)
              Positioned(
                top: -9,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFF472B6), Color(0xFFA855F7)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      p.badge!.tr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
          ],
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

/// باقة شحن رصيد (عملات أو جواهر)
class _Pack {
  final String id;
  final String title;
  final bool gems;
  final int amount;
  final int bonus;
  final double price;
  final String? badge;

  const _Pack(
      this.id, this.title, this.gems, this.amount, this.bonus, this.price,
      {this.badge});

  factory _Pack.fromDoc(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Pack(
      doc.id,
      (d['title'] ?? 'باقة') as String,
      d['type'] == 'gems',
      (d['amount'] as num?)?.toInt() ?? 0,
      (d['bonus'] as num?)?.toInt() ?? 0,
      (d['priceUsd'] as num?)?.toDouble() ?? 0,
      badge: d['badge'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': gems ? 'gems' : 'chips',
        'amount': amount,
        'priceUsd': price,
      };
}
