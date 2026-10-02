import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_service.dart';
import 'auth_service.dart';
import '../l10n/app_lang.dart';

/// فئات الكسنات المتاحة في المتجر
class StoreCategory {
  static const String tile = 'tile';
  static const String table = 'table';
  static const String rack = 'rack';
  static const String background = 'background';
  static const String frame = 'frame';
  static const String chessBoard = 'chessBoard';
  static const String chessPieces = 'chessPieces';
  static const String bgBoard = 'bgBoard';
  static const String bgCheckers = 'bgCheckers';
  // غرفة الكونكان — تصميم المشهد الكامل (نفس تخطيط الصورة المرجعية)
  static const String okeyRoom = 'okeyRoom';

  static const List<String> all = [
    tile,
    table,
    rack,
    background,
    frame,
    chessBoard,
    chessPieces,
    bgBoard,
    bgCheckers,
    okeyRoom,
  ];

  static String label(String category) {
    switch (category) {
      case tile:
        return 'الأحجار'.tr;
      case table:
        return 'الطاولة'.tr;
      case rack:
        return 'الاستكانة'.tr;
      case background:
        return 'الخلفية'.tr;
      case frame:
        return 'إطار الصورة'.tr;
      case chessBoard:
        return 'لوحة الشطرنج'.tr;
      case chessPieces:
        return 'أحجار الشطرنج'.tr;
      case bgBoard:
        return 'لوح الطاولي'.tr;
      case bgCheckers:
        return 'أحجار الطاولي'.tr;
      case okeyRoom:
        return 'غرفة الكونكان'.tr;
      default:
        return category;
    }
  }

  static IconData icon(String category) {
    switch (category) {
      case tile:
        return Icons.grid_view_rounded;
      case table:
        return Icons.table_restaurant_rounded;
      case rack:
        return Icons.view_column_rounded;
      case background:
        return Icons.wallpaper_rounded;
      case frame:
        return Icons.account_circle_rounded;
      case chessBoard:
        return Icons.grid_4x4_rounded;
      case chessPieces:
        return Icons.castle_rounded;
      case bgBoard:
        return Icons.view_week_rounded;
      case bgCheckers:
        return Icons.radio_button_checked_rounded;
      case okeyRoom:
        return Icons.meeting_room_rounded;
      default:
        return Icons.category_rounded;
    }
  }
}

/// عنصر كسنة في المتجر - الصورة مخزنة كـ Base64 داخل Firestore
/// عملة الدفع في المتجر: عملات ذهبية 🪙 أو مجوهرات زرقاء 💎
class StoreCurrency {
  static const String chips = 'chips';
  static const String gems = 'gems';

  static String icon(String c) => c == gems ? '💎' : '🪙';
  static String label(String c) => c == gems ? 'مجوهرات'.tr : 'عملات'.tr;
}

class StoreItem {
  final String id;
  final String name;
  final String category;
  final int price;
  final String currency;
  final String imageBase64;
  final bool active;

  /// تحويل الصورة على القطعة: تكبير (1.0-4.0) وإزاحة (-1.0 إلى 1.0)
  final double zoom;
  final double offsetX;
  final double offsetY;

  /// تأثير متحرك إجرائي: '' أو 'fire' أو 'ice'
  /// العناصر ذات التأثير تُرسم متحركة بدل/فوق الصورة
  final String effect;

  /// مسار نموذج ثلاثي الأبعاد GLB مدمج (للاستكانة مثلاً) — '' = لا يوجد
  final String model3d;

  /// مخفي من شبكة المتجر (عناصر نظام/مكافآت مثل إطار VIP)
  final bool hidden;

  /// إصدار موسمي محدود — يعرض شارة "محدود ⏳"
  final bool limited;

  /// أدنى عدد انتصارات لفتح الشراء — 0 = بدون قفل
  final int requiredWins;

  Uint8List? _bytes;
  ImageProvider? _provider;

  StoreItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.currency = StoreCurrency.chips,
    required this.imageBase64,
    this.active = true,
    this.zoom = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.effect = '',
    this.model3d = '',
    this.hidden = false,
    this.limited = false,
    this.requiredWins = 0,
  });

  /// عنصر مدمج بالتطبيق (وليس من لوحة الأدمن)
  bool get isBuiltin => id.startsWith('builtin_');

  factory StoreItem.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoreItem(
      id: doc.id,
      name: data['name'] ?? 'كسنة'.tr,
      category: data['category'] ?? StoreCategory.tile,
      price: (data['price'] as num?)?.toInt() ?? 0,
      currency: data['currency'] == StoreCurrency.gems
          ? StoreCurrency.gems
          : StoreCurrency.chips,
      imageBase64: data['imageBase64'] ?? '',
      active: data['active'] ?? true,
      zoom: (data['zoom'] as num?)?.toDouble() ?? 1.0,
      offsetX: (data['offsetX'] as num?)?.toDouble() ?? 0.0,
      offsetY: (data['offsetY'] as num?)?.toDouble() ?? 0.0,
      effect: (data['effect'] as String?) ?? '',
      model3d: (data['model3d'] as String?) ?? '',
      hidden: data['hidden'] ?? false,
      limited: data['limited'] ?? false,
      requiredWins: (data['requiredWins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'price': price,
      'currency': currency,
      'imageBase64': imageBase64,
      'active': active,
      'zoom': zoom,
      'offsetX': offsetX,
      'offsetY': offsetY,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// مسار أصل مدمج — عندما يكون imageBase64 بالصيغة 'asset:path/to/file'
  bool get isAssetImage => imageBase64.startsWith('asset:');
  String get assetPath => imageBase64.substring(6);

  Uint8List get bytes => _bytes ??= base64Decode(imageBase64);

  ImageProvider get provider {
    final p = _provider;
    if (p != null) return p;
    final ImageProvider created = isAssetImage
        ? AssetImage(assetPath) as ImageProvider
        : MemoryImage(bytes);
    _provider = created;
    return created;
  }
}

/// خدمة المتجر: جلب الكسنات، الشراء، التجهيز، وكاش الصور
class StoreService extends ChangeNotifier {
  static final StoreService _instance = StoreService._internal();
  factory StoreService() => _instance;
  StoreService._internal();

  final FirebaseService _firebase = FirebaseService();

  /// عناصر مدمجة بالتطبيق — إطارات وكسنات متحركة إجرائية (نار/جليد)
  /// تظهر دائماً في المتجر دون حاجة لرفع صور من لوحة الأدمن
  static List<StoreItem> _builtinItems() => [
        // ── إطارات متحركة ──
        StoreItem(
          id: 'builtin_frame_fire',
          name: 'إطار النار المتحرك'.tr,
          category: StoreCategory.frame,
          price: 60,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'fire',
        ),
        StoreItem(
          id: 'builtin_frame_ice',
          name: 'إطار الجليد المتحرك'.tr,
          category: StoreCategory.frame,
          price: 60,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ice',
        ),
        // ── إطار VIP الذهبي — يُجهَّز تلقائياً للمشتركين (مخفي عن المتجر) ──
        StoreItem(
          id: 'builtin_frame_vip_gold',
          name: 'إطار VIP الذهبي'.tr,
          category: StoreCategory.frame,
          price: 0,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'gold',
          hidden: true,
        ),
        // ── استكانات متحركة ──
        StoreItem(
          id: 'builtin_rack_fire',
          name: 'استكانة النار الحية'.tr,
          category: StoreCategory.rack,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'fire',
        ),
        StoreItem(
          id: 'builtin_rack_ice',
          name: 'استكانة الجليد الحية'.tr,
          category: StoreCategory.rack,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ice',
        ),
        // ── استكانات متحركة جديدة — عنصرية ──
        StoreItem(
          id: 'builtin_rack_lava',
          name: 'استكانة اللافا الحية'.tr,
          category: StoreCategory.rack,
          price: 55,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'lava',
        ),
        StoreItem(
          id: 'builtin_rack_blaze',
          name: 'استكانة النار الملكية'.tr,
          category: StoreCategory.rack,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'blaze',
        ),
        StoreItem(
          id: 'builtin_rack_frost',
          name: 'استكانة الصقيع المتجمد'.tr,
          category: StoreCategory.rack,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'frost',
        ),
        StoreItem(
          id: 'builtin_rack_storm',
          name: 'استكانة البرق العاصف'.tr,
          category: StoreCategory.rack,
          price: 55,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'storm',
        ),
        // ── استكانات متحركة جديدة — فاخرة ──
        StoreItem(
          id: 'builtin_rack_gold',
          name: 'استكانة الذهب السائل'.tr,
          category: StoreCategory.rack,
          price: 60,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'gold',
        ),
        StoreItem(
          id: 'builtin_rack_crystal',
          name: 'استكانة الكريستال البنفسجي'.tr,
          category: StoreCategory.rack,
          price: 55,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'crystal',
        ),
        StoreItem(
          id: 'builtin_rack_neon',
          name: 'استكانة النيون النعناعي'.tr,
          category: StoreCategory.rack,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'neon',
        ),
        // ── استكانات متحركة جديدة — طبيعية ──
        StoreItem(
          id: 'builtin_rack_galaxy',
          name: 'استكانة السديم الكوني'.tr,
          category: StoreCategory.rack,
          price: 60,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'galaxy',
        ),
        StoreItem(
          id: 'builtin_rack_ocean',
          name: 'استكانة المحيط الليلي'.tr,
          category: StoreCategory.rack,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ocean',
        ),
        StoreItem(
          id: 'builtin_rack_aurora',
          name: 'استكانة شفق أورورا'.tr,
          category: StoreCategory.rack,
          price: 55,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'aurora',
        ),
        // ── استكانات متحركة جديدة — أسطورية ──
        StoreItem(
          id: 'builtin_rack_dragon',
          name: 'استكانة عرش التنين'.tr,
          category: StoreCategory.rack,
          price: 65,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'dragon',
        ),
        StoreItem(
          id: 'builtin_rack_ember',
          name: 'استكانة الجمر الخالد'.tr,
          category: StoreCategory.rack,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ember',
        ),
        // ── إصدارات موسمية محدودة ⏳ ──
        StoreItem(
          id: 'builtin_rack_winter_royal',
          name: 'استكانة الشتاء الملكي ⏳'.tr,
          category: StoreCategory.rack,
          price: 65,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'frost',
          limited: true,
        ),
        StoreItem(
          id: 'builtin_tile_eid_flames',
          name: 'أحجار ألسنة العيد ⏳'.tr,
          category: StoreCategory.tile,
          price: 55,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ember',
          limited: true,
        ),
        // ── أسطورية مقفولة بالإنجازات 🏆 ──
        StoreItem(
          id: 'builtin_rack_legend_100',
          name: 'استكانة الأسطورة — 100 فوز 🏆'.tr,
          category: StoreCategory.rack,
          price: 0,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'dragon',
          requiredWins: 100,
        ),
        StoreItem(
          id: 'builtin_table_legend_50',
          name: 'طاولة البطلة — 50 فوزاً 🏆'.tr,
          category: StoreCategory.table,
          price: 0,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'galaxy',
          requiredWins: 50,
        ),
        // ── استكانة أوبسيديان منصهر (تصميم ثري دي مجاني للتجربة) ──
        StoreItem(
          id: 'builtin_rack_obsidian',
          name: 'استكانة الأوبسيديان المنصهر'.tr,
          category: StoreCategory.rack,
          price: 0,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/molten_obsidian_rack.jpg',
          zoom: 1.0,
          model3d: 'assets/models/okey/rack_molten_obsidian.glb',
        ),
        // ── استكانات خشبية ──
        StoreItem(
          id: 'builtin_rack_walnut',
          name: 'استكانة الجوز الملكي'.tr,
          category: StoreCategory.rack,
          price: 800,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/rack_walnut.jpg',
        ),
        StoreItem(
          id: 'builtin_rack_oak',
          name: 'استكانة البلوط الفاتح'.tr,
          category: StoreCategory.rack,
          price: 800,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/rack_oak.jpg',
        ),
        StoreItem(
          id: 'builtin_rack_ebony',
          name: 'استكانة الأبنوس الداكن'.tr,
          category: StoreCategory.rack,
          price: 1000,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/rack_ebony.jpg',
        ),
        // ── استكانات صاجية ──
        StoreItem(
          id: 'builtin_rack_steel',
          name: 'استكانة الصاج الفضي'.tr,
          category: StoreCategory.rack,
          price: 1200,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/rack_steel.jpg',
        ),
        StoreItem(
          id: 'builtin_rack_copper',
          name: 'استكانة النحاس الدافئ'.tr,
          category: StoreCategory.rack,
          price: 1200,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/rack_copper.jpg',
        ),
        // ── استكانات مفروشات مزخرفة ──
        StoreItem(
          id: 'builtin_rack_carpet_red',
          name: 'استكانة السجاد الملكي'.tr,
          category: StoreCategory.rack,
          price: 1500,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/rack_carpet_red.jpg',
        ),
        StoreItem(
          id: 'builtin_rack_carpet_navy',
          name: 'استكانة السجاد الكحلي'.tr,
          category: StoreCategory.rack,
          price: 1500,
          currency: StoreCurrency.chips,
          imageBase64: 'asset:assets/skins/rack_carpet_navy.jpg',
        ),
        // ── أحجار متحركة ──
        StoreItem(
          id: 'builtin_tile_fire',
          name: 'أحجار اللهب الحية'.tr,
          category: StoreCategory.tile,
          price: 40,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'fire',
        ),
        StoreItem(
          id: 'builtin_tile_ice',
          name: 'أحجار الصقيع الحية'.tr,
          category: StoreCategory.tile,
          price: 40,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ice',
        ),
        // ── أحجار متحركة جديدة ──
        StoreItem(
          id: 'builtin_tile_lava',
          name: 'أحجار اللافا الحية'.tr,
          category: StoreCategory.tile,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'lava',
        ),
        StoreItem(
          id: 'builtin_tile_blaze',
          name: 'أحجار النار الملكية'.tr,
          category: StoreCategory.tile,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'blaze',
        ),
        StoreItem(
          id: 'builtin_tile_frost',
          name: 'أحجار الصقيع المتجمد'.tr,
          category: StoreCategory.tile,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'frost',
        ),
        StoreItem(
          id: 'builtin_tile_storm',
          name: 'أحجار البرق العاصف'.tr,
          category: StoreCategory.tile,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'storm',
        ),
        StoreItem(
          id: 'builtin_tile_gold',
          name: 'أحجار الذهب السائل'.tr,
          category: StoreCategory.tile,
          price: 55,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'gold',
        ),
        StoreItem(
          id: 'builtin_tile_crystal',
          name: 'أحجار الكريستال البنفسجي'.tr,
          category: StoreCategory.tile,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'crystal',
        ),
        StoreItem(
          id: 'builtin_tile_neon',
          name: 'أحجار النيون النعناعي'.tr,
          category: StoreCategory.tile,
          price: 40,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'neon',
        ),
        StoreItem(
          id: 'builtin_tile_galaxy',
          name: 'أحجار السديم الكوني'.tr,
          category: StoreCategory.tile,
          price: 55,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'galaxy',
        ),
        StoreItem(
          id: 'builtin_tile_ocean',
          name: 'أحجار المحيط الليلي'.tr,
          category: StoreCategory.tile,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ocean',
        ),
        StoreItem(
          id: 'builtin_tile_aurora',
          name: 'أحجار شفق أورورا'.tr,
          category: StoreCategory.tile,
          price: 50,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'aurora',
        ),
        StoreItem(
          id: 'builtin_tile_dragon',
          name: 'أحجار عرش التنين'.tr,
          category: StoreCategory.tile,
          price: 60,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'dragon',
        ),
        StoreItem(
          id: 'builtin_tile_ember',
          name: 'أحجار الجمر الخالد'.tr,
          category: StoreCategory.tile,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ember',
        ),
        // ── طاولات متحركة ──
        StoreItem(
          id: 'builtin_table_fire',
          name: 'طاولة اللهب الحية'.tr,
          category: StoreCategory.table,
          price: 70,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'fire',
        ),
        StoreItem(
          id: 'builtin_table_ice',
          name: 'طاولة الجليد الحية'.tr,
          category: StoreCategory.table,
          price: 70,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ice',
        ),
        StoreItem(
          id: 'builtin_table_lava',
          name: 'طاولة اللافا الحية'.tr,
          category: StoreCategory.table,
          price: 75,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'lava',
        ),
        StoreItem(
          id: 'builtin_table_blaze',
          name: 'طاولة النار الملكية'.tr,
          category: StoreCategory.table,
          price: 70,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'blaze',
        ),
        StoreItem(
          id: 'builtin_table_frost',
          name: 'طاولة الصقيع المتجمد'.tr,
          category: StoreCategory.table,
          price: 70,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'frost',
        ),
        StoreItem(
          id: 'builtin_table_storm',
          name: 'طاولة البرق العاصف'.tr,
          category: StoreCategory.table,
          price: 75,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'storm',
        ),
        StoreItem(
          id: 'builtin_table_gold',
          name: 'طاولة الذهب السائل'.tr,
          category: StoreCategory.table,
          price: 80,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'gold',
        ),
        StoreItem(
          id: 'builtin_table_crystal',
          name: 'طاولة الكريستال البنفسجي'.tr,
          category: StoreCategory.table,
          price: 75,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'crystal',
        ),
        StoreItem(
          id: 'builtin_table_neon',
          name: 'طاولة النيون النعناعي'.tr,
          category: StoreCategory.table,
          price: 65,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'neon',
        ),
        StoreItem(
          id: 'builtin_table_galaxy',
          name: 'طاولة السديم الكوني'.tr,
          category: StoreCategory.table,
          price: 80,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'galaxy',
        ),
        StoreItem(
          id: 'builtin_table_ocean',
          name: 'طاولة المحيط الليلي'.tr,
          category: StoreCategory.table,
          price: 70,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ocean',
        ),
        StoreItem(
          id: 'builtin_table_aurora',
          name: 'طاولة شفق أورورا'.tr,
          category: StoreCategory.table,
          price: 75,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'aurora',
        ),
        StoreItem(
          id: 'builtin_table_dragon',
          name: 'طاولة عرش التنين'.tr,
          category: StoreCategory.table,
          price: 85,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'dragon',
        ),
        StoreItem(
          id: 'builtin_table_ember',
          name: 'طاولة الجمر الخالد'.tr,
          category: StoreCategory.table,
          price: 70,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'ember',
        ),
        // ── سكنات الطاولي: ألواح + مجموعات أحجار ──
        for (final b in [
          ('ebony', 'لوح الأبنوس الذهبي'.tr, 3500, StoreCurrency.chips),
          ('teak', 'لوح الصاج الطبيعي'.tr, 2500, StoreCurrency.chips),
          ('felt', 'لوح الكازينو الأخضر'.tr, 3000, StoreCurrency.chips),
          ('pearl', 'لوح الصدف الملكي'.tr, 45, StoreCurrency.gems),
          ('fire', 'لوح الحمم النارية'.tr, 70, StoreCurrency.gems),
          ('ice', 'لوح الجليد القطبي'.tr, 70, StoreCurrency.gems),
          ('neon', 'لوح النيون الليلي'.tr, 60, StoreCurrency.gems),
          ('galaxy', 'لوح المجرة الكونية'.tr, 90, StoreCurrency.gems),
        ])
          StoreItem(
            id: 'builtin_bgboard_${b.$1}',
            name: b.$2,
            category: StoreCategory.bgBoard,
            price: b.$3,
            currency: b.$4,
            imageBase64: '',
          ),
        for (final c in [
          ('wood', 'أحجار القيقب والجوز'.tr, 2000, StoreCurrency.chips),
          ('teak', 'أحجار الصاج والأبنوس'.tr, 2500, StoreCurrency.chips),
          ('marble', 'أحجار الرخام الفاخر'.tr, 3500, StoreCurrency.chips),
          ('gold', 'أحجار الذهب والفضة'.tr, 50, StoreCurrency.gems),
          ('fire', 'أحجار الجمر الناري'.tr, 65, StoreCurrency.gems),
          ('ice', 'أحجار الكريستال الجليدي'.tr, 65, StoreCurrency.gems),
          ('neon', 'أحجار النيون المتوهج'.tr, 55, StoreCurrency.gems),
          ('gem', 'أحجار الياقوت والزمرد'.tr, 80, StoreCurrency.gems),
        ])
          StoreItem(
            id: 'builtin_bgcheckers_${c.$1}',
            name: c.$2,
            category: StoreCategory.bgCheckers,
            price: c.$3,
            currency: c.$4,
            imageBase64: '',
          ),
        // ── استكانات خشبية بمسامير نحاسية (رسوم إجرائية، بلا صور) ──
        StoreItem(
          id: 'builtin_rack_wood_oak',
          name: 'استكانة البلوط بالمسامير'.tr,
          category: StoreCategory.rack,
          price: 40,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'wood',
        ),
        StoreItem(
          id: 'builtin_rack_wood_walnut',
          name: 'استكانة الجوز بالمسامير'.tr,
          category: StoreCategory.rack,
          price: 40,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'walnut',
        ),
        StoreItem(
          id: 'builtin_rack_wood_mahogany',
          name: 'استكانة الماهوجني بالمسامير'.tr,
          category: StoreCategory.rack,
          price: 45,
          currency: StoreCurrency.gems,
          imageBase64: '',
          effect: 'mahogany',
        ),
        // ── إطارات بروفايل جديدة — تصاميم متحركة متنوعة ──
        for (final f in [
          ('storm', 'إطار العاصفة البرّاقة'.tr, 55),
          ('galaxy', 'إطار السديم البنفسجي'.tr, 65),
          ('aurora', 'إطار الشفق القطبي'.tr, 55),
          ('neon', 'إطار النيون النعناعي'.tr, 50),
          ('dragon', 'إطار التنين الذهبي'.tr, 75),
          ('ember', 'إطار الجمر الخالد'.tr, 50),
          ('crystal', 'إطار الكريستال البنفسجي'.tr, 55),
          ('ocean', 'إطار المحيط الليلي'.tr, 55),
          ('lava', 'إطار اللافا الملتهب'.tr, 60),
          ('blaze', 'إطار النار الملكية'.tr, 60),
        ])
          StoreItem(
            id: 'builtin_frame_${f.$1}',
            name: f.$2,
            category: StoreCategory.frame,
            price: f.$3,
            currency: StoreCurrency.gems,
            imageBase64: '',
            effect: f.$1,
          ),
      ];

  /// الكتالوج الكامل المعروض: غرف الكونكان أولاً ثم كل العناصر
  /// المدمجة ما عدا كسنات الاستكانة/الأحجار/الخلفية — حُذفت لأن
  /// مشهد الغرفة الموحّد يغطي دورها كلها في شاشة اللعب
  static List<StoreItem> _catalogItems() => [
        ..._roomItems(),
        for (final e in _builtinItems())
          if (e.category != StoreCategory.rack &&
              e.category != StoreCategory.tile &&
              e.category != StoreCategory.background)
            e,
      ];

  /// تصاميم غرفة الكونكان — مشاهد كاملة (1024×436) بنفس تخطيط
  /// الغرفة الافتراضية فتعمل عليها مناطق اللعب المحسوبة نفسها —
  /// جهّز أي منها ليستبدل غرفة اللعب بأكملها فوراً
  static List<StoreItem> _roomItems() => [
        for (final r in [
          (
            'classic',
            'الغرفة الكوردية الكلاسيكية'.tr,
            0,
            StoreCurrency.chips,
            'assets/images/okey_room.png'
          ),
          (
            'gold',
            'غرفة الذهب الملكي'.tr,
            3000,
            StoreCurrency.chips,
            'assets/images/rooms/room_gold.png'
          ),
          (
            'teal',
            'غرفة الفيروز'.tr,
            3000,
            StoreCurrency.chips,
            'assets/images/rooms/room_teal.png'
          ),
          (
            'glass',
            'غرفة الكريستال'.tr,
            35,
            StoreCurrency.gems,
            'assets/images/rooms/room_glass.png'
          ),
          (
            'silver',
            'غرفة الصاج الفضي'.tr,
            3500,
            StoreCurrency.chips,
            'assets/images/rooms/room_silver.png'
          ),
          (
            'amber',
            'غرفة العنبر'.tr,
            3500,
            StoreCurrency.chips,
            'assets/images/rooms/room_amber.png'
          ),
          (
            'green',
            'الغرفة الخضراء'.tr,
            2500,
            StoreCurrency.chips,
            'assets/images/rooms/room_green.jpg'
          ),
          (
            'navy',
            'الغرفة الكحلية'.tr,
            2500,
            StoreCurrency.chips,
            'assets/images/rooms/room_navy.jpg'
          ),
          (
            'emerald',
            'غرفة الزمرد الملكية'.tr,
            40,
            StoreCurrency.gems,
            'assets/images/rooms/room_emerald.png'
          ),
          (
            'beige',
            'غرفة الرمال'.tr,
            2500,
            StoreCurrency.chips,
            'assets/images/rooms/room_beige.png'
          ),
          (
            'bronze',
            'الغرفة البرونزية'.tr,
            30,
            StoreCurrency.gems,
            'assets/images/rooms/room_bronze.jpg'
          ),
        ])
          StoreItem(
            id: 'builtin_room_${r.$1}',
            name: r.$2,
            category: StoreCategory.okeyRoom,
            price: r.$3,
            currency: r.$4,
            imageBase64: 'asset:${r.$5}',
          ),
      ];

  List<StoreItem> _items = _catalogItems();
  List<StoreItem> get items => _items;

  StreamSubscription<QuerySnapshot>? _itemsSub;
  StreamSubscription? _authSub;
  VoidCallback? _authListener;

  /// كاش الصور المفكوكة للرسام (CustomPainter) حسب معرف العنصر
  final Map<String, ui.Image> _uiImageCache = {};

  /// عنصر خامة الخشب الحقيقية الافتراضية — قاعدة الطاولة والاستكانة
  /// وطبقة الحبيبات تحت السكنات المتحركة
  static final StoreItem defaultWoodItem = StoreItem(
    id: 'sys_wood_base',
    name: 'خشب افتراضي'.tr,
    category: StoreCategory.rack,
    price: 0,
    imageBase64: 'asset:assets/skins/wood_premium.jpg',
  );

  /// صورة الخشب المفكوكة — تُملأ عبر [ensureWoodBase]
  ui.Image? defaultWoodImage;

  /// يفك صورة الخشب الافتراضية مرة واحدة ويُعلم المستمعين
  Future<void> ensureWoodBase() async {
    if (defaultWoodImage != null) return;
    defaultWoodImage = await _decodeUiImage(defaultWoodItem);
    if (defaultWoodImage != null) notifyListeners();
  }

  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    if (!_firebase.isInitialized) return;

    _itemsSub = _firebase.firestore
        .collection('store_items')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      _items = [
        ..._catalogItems(),
        ...snapshot.docs.map((doc) => StoreItem.fromDoc(doc)),
      ];
      _warmImageCache();
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Store items stream error: $e');
    });

    // إعادة فك صور الكسنات المجهزة عند تغير المستخدم
    _authListener = () => _warmImageCache();
    AuthService().addListener(_authListener!);
  }

  // ══════════════════════════════════════════════════════
  // الملكية والتجهيز
  // ══════════════════════════════════════════════════════

  bool isOwned(String itemId) {
    final user = AuthService().currentUser;
    return user?.ownedSkins.contains(itemId) ?? false;
  }

  /// اسم عنصر بالمعرف — لرسائل الجوائز والإشعارات
  String? itemName(String itemId) {
    try {
      return _items.firstWhere((e) => e.id == itemId).name;
    } catch (_) {
      return null;
    }
  }

  /// الكسنة المجهزة حالياً لفئة معينة (أو null للافتراضي)
  StoreItem? equippedFor(String category) {
    final user = AuthService().currentUser;
    final id = user?.equippedSkins[category];
    if (id == null) return null;
    try {
      return _items.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// مزود صورة الكسنة المجهزة لفئة معينة
  ImageProvider? equippedProvider(String category) =>
      equippedFor(category)?.provider;

  /// صورة مفكوكة ui.Image للرسام ثنائي الأبعاد (الطاولة)
  ui.Image? equippedUiImage(String category) {
    final item = equippedFor(category);
    if (item == null) return null;
    return _uiImageCache[item.id];
  }

  /// صورة ui.Image مفكوكة لعنصر محدد (للرسام)
  ui.Image? uiImageOf(StoreItem item) => _uiImageCache[item.id];

  /// شراء كسنة من المتجر (بالعملات 🪙 أو الجواهر 💎 حسب العنصر)
  Future<String?> purchase(StoreItem item) async {
    final user = AuthService().currentUser;
    if (user == null) return 'يرجى تسجيل الدخول أولاً'.tr;
    if (isOwned(item.id)) return 'تمتلك هذه الكسنة بالفعل'.tr;
    if (item.requiredWins > 0 && user.wins < item.requiredWins) {
      return 'كسنة أسطورية مقفلة! تحتاج {} فوزاً 🏆 (عندك {})'
          .trp([item.requiredWins, user.wins]);
    }

    final isGems = item.currency == StoreCurrency.gems;
    final balance = isGems ? user.gems : user.chips;
    if (balance < item.price) {
      return 'رصيدك غير كافٍ! تحتاج {} {}'
          .trp([item.price, isGems ? '💎' : '🪙']);
    }

    final paid = isGems
        ? await AuthService().adjustGems(-item.price)
        : await AuthService().adjustChips(-item.price);
    if (!paid) return 'فشل خصم الرصيد، حاول مرة أخرى'.tr;

    final owned = {...user.ownedSkins, item.id}.toList();
    await AuthService().updateSkinData(ownedSkins: owned);
    return null;
  }

  /// تجهيز كسنة مملوكة (أو إلغاء التجهيز بإرسال null)
  Future<void> equip(String category, StoreItem? item) async {
    final user = AuthService().currentUser;
    if (user == null) return;
    if (item != null && !isOwned(item.id)) return;

    final map = Map<String, String>.from(user.equippedSkins);
    if (item == null) {
      map.remove(category);
    } else {
      map[category] = item.id;
    }
    await AuthService().updateSkinData(equippedSkins: map);

    if (item != null) await _decodeUiImage(item);
    notifyListeners();
  }

  bool isEquipped(StoreItem item) {
    final user = AuthService().currentUser;
    return user?.equippedSkins[item.category] == item.id;
  }

  // ══════════════════════════════════════════════════════
  // كاش الصور المفكوكة للرسام
  // ══════════════════════════════════════════════════════

  Future<void> _warmImageCache() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    for (final id in user.equippedSkins.values) {
      try {
        final item = _items.firstWhere((e) => e.id == id);
        await _decodeUiImage(item);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<ui.Image?> _decodeUiImage(StoreItem item) async {
    if (_uiImageCache.containsKey(item.id)) return _uiImageCache[item.id];
    if (item.imageBase64.isEmpty) return null; // عناصر التأثيرات بلا صورة
    try {
      final Uint8List data = item.isAssetImage
          ? (await rootBundle.load(item.assetPath)).buffer.asUint8List()
          : item.bytes;
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      _uiImageCache[item.id] = frame.image;
      return frame.image;
    } catch (e) {
      debugPrint('Error decoding skin image: $e');
      return null;
    }
  }

  /// فك صورة بيانات خام (لمعاينة الموك اب في لوحة الأدمن)
  Future<ui.Image?> decodeRaw(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      debugPrint('Error decoding raw image: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _itemsSub?.cancel();
    _authSub?.cancel();
    if (_authListener != null) {
      AuthService().removeListener(_authListener!);
    }
    super.dispose();
  }
}
