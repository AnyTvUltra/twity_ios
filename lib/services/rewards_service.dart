import 'dart:math' as math;
import '../l10n/app_lang.dart';

/// نوع الجائزة: عملات 🪙 أو جواهر (شذر) 💎 أو سكن 🎨
enum RewardType { chips, gems, skin }

/// تعريف جائزة يومية داخل الشريط الأسبوعي
class DailyReward {
  final RewardType type;
  final int amount;
  final String skinId;

  const DailyReward._(this.type, this.amount, this.skinId);
  const DailyReward.chips(int amount) : this._(RewardType.chips, amount, '');
  const DailyReward.gems(int amount) : this._(RewardType.gems, amount, '');
  const DailyReward.skin(String skinId) : this._(RewardType.skin, 0, skinId);
}

/// مقطع من عجلة الحظ اليومية
class WheelSegment {
  final String label;
  final String emoji;
  final RewardType type;
  final int amount;
  final int weight;
  final int color;

  const WheelSegment({
    required this.label,
    required this.emoji,
    required this.type,
    required this.amount,
    required this.weight,
    required this.color,
  });
}

/// منطق المكافآت اليومية: الشريط الأسبوعي الدوّار + عجلة الحظ
/// جوائز الأسبوع تتبدل كل أسبوع (4 خطط دوّارة)
class RewardsService {
  RewardsService._();

  /// رقم الأسبوع الدوّار — يتغير كل 7 أيام
  static int get weekIndex {
    final days = DateTime.now().millisecondsSinceEpoch ~/
        const Duration(days: 7).inMilliseconds;
    return days % _weeklyPlans.length;
  }

  /// مجمّع السكنات المجانية للجوائز (يُستبدل برصيد جواهر إن كان مملوكاً)
  static const List<String> rewardSkinPool = [
    'builtin_rack_walnut',
    'builtin_rack_oak',
    'builtin_rack_ebony',
    'builtin_rack_steel',
    'builtin_rack_copper',
    'builtin_rack_carpet_red',
    'builtin_rack_carpet_navy',
    'builtin_tile_frost',
    'builtin_tile_neon',
    'builtin_frame_ice',
    'builtin_frame_fire',
  ];

  /// تعويض بالجواهر عند امتلاك السكن مسبقاً
  static const int skinFallbackGems = 18;

  // ══════════════════════════════════════════════════════
  // الشريط الأسبوعي — 4 خطط تتعاقب (كل أسبوع جوائز جديدة)
  // ══════════════════════════════════════════════════════
  static const List<List<DailyReward>> _weeklyPlans = [
    // الأسبوع الذهبي
    [
      DailyReward.chips(350),
      DailyReward.gems(5),
      DailyReward.chips(500),
      DailyReward.gems(8),
      DailyReward.chips(700),
      DailyReward.gems(10),
      DailyReward.skin('builtin_rack_walnut'),
    ],
    // أسبوع الجواهر
    [
      DailyReward.chips(400),
      DailyReward.gems(6),
      DailyReward.chips(550),
      DailyReward.skin('builtin_tile_frost'),
      DailyReward.chips(800),
      DailyReward.gems(12),
      DailyReward.skin('builtin_rack_oak'),
    ],
    // أسبوع الثروة
    [
      DailyReward.chips(350),
      DailyReward.gems(8),
      DailyReward.chips(600),
      DailyReward.gems(10),
      DailyReward.chips(750),
      DailyReward.skin('builtin_rack_steel'),
      DailyReward.chips(1500),
    ],
    // الأسبوع الملكي
    [
      DailyReward.chips(450),
      DailyReward.gems(7),
      DailyReward.chips(650),
      DailyReward.gems(12),
      DailyReward.chips(900),
      DailyReward.gems(15),
      DailyReward.skin('builtin_rack_copper'),
    ],
  ];

  /// جوائز الأسبوع الحالي (7 أيام)
  static List<DailyReward> get currentWeekRewards => _weeklyPlans[weekIndex];

  /// عدد أيام الشهر الحالي (28..31)
  static int get daysInCurrentMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month + 1, 0).day;
  }

  /// تقويم المكافأة اليومية للشهر الحالي — جائزة لكل يوم من أيامه:
  /// عملات متصاعدة، جواهر كل 5 أيام، سكن كل 7 أيام (يتبدل كل شهر)،
  /// وجائزة كبرى في آخر يوم من الشهر
  static List<DailyReward> get currentMonthRewards {
    final month = DateTime.now().month;
    final len = daysInCurrentMonth;
    return List.generate(len, (i) {
      final d = i + 1;
      if (d == len) return const DailyReward.chips(5000);
      if (d % 7 == 0) {
        return DailyReward.skin(
            rewardSkinPool[(month * 4 + d ~/ 7) % rewardSkinPool.length]);
      }
      if (d % 5 == 0) return DailyReward.gems(3 + (d ~/ 5) * 2);
      return DailyReward.chips(((300 + (d - 1) * 40) / 50).round() * 50);
    });
  }

  /// سكن العجلة لهذا الأسبوع — يدور مع الأسابيع
  static String get wheelSkinThisWeek =>
      rewardSkinPool[weekIndex % rewardSkinPool.length];

  // ══════════════════════════════════════════════════════
  // عجلة الحظ اليومية — الحظ مركّز على الأموال 🪙
  // جواهر قليلة 💎 وسكن نادر جداً 🎨 (~3%)
  // ══════════════════════════════════════════════════════
  static List<WheelSegment> wheel = [
    WheelSegment(
        label: '150',
        emoji: '🪙',
        type: RewardType.chips,
        amount: 150,
        weight: 24,
        color: 0xFFFFC837),
    WheelSegment(
        label: '5',
        emoji: '💎',
        type: RewardType.gems,
        amount: 5,
        weight: 7,
        color: 0xFF38BDF8),
    WheelSegment(
        label: '500',
        emoji: '🪙',
        type: RewardType.chips,
        amount: 500,
        weight: 14,
        color: 0xFFFF9F43),
    WheelSegment(
        label: '12',
        emoji: '💎',
        type: RewardType.gems,
        amount: 12,
        weight: 4,
        color: 0xFF818CF8),
    WheelSegment(
        label: '250',
        emoji: '🪙',
        type: RewardType.chips,
        amount: 250,
        weight: 26,
        color: 0xFFFFD54F),
    WheelSegment(
        label: 'سكن!'.tr,
        emoji: '🎨',
        type: RewardType.skin,
        amount: 0,
        weight: 3,
        color: 0xFFC084FC),
    WheelSegment(
        label: '350',
        emoji: '🪙',
        type: RewardType.chips,
        amount: 350,
        weight: 20,
        color: 0xFFFBBF24),
    WheelSegment(
        label: '8',
        emoji: '💎',
        type: RewardType.gems,
        amount: 8,
        weight: 6,
        color: 0xFF7DD3FC),
  ];

  /// اختيار مقطع العجلة موزوناً بالاحتمالات — يعيد فهرس المقطع
  static int pickWheelIndex([math.Random? rng]) {
    final r = rng ?? math.Random();
    int total = 0;
    for (final s in wheel) {
      total += s.weight;
    }
    int roll = r.nextInt(total);
    for (int i = 0; i < wheel.length; i++) {
      roll -= wheel[i].weight;
      if (roll < 0) return i;
    }
    return 0;
  }

  /// مضاعف كبار الشخصيات: +25% على مكافآت العملات والجواهر
  static int vipBoost(int amount) => (amount * 1.25).round();

  /// مضاعف VIP+: +50% على مكافآت العملات والجواهر
  static int vipPlusBoost(int amount) => (amount * 1.5).round();

  // ══════════════════════════════════════════════════════
  // صندوق الغنائم اليومي المجاني — نفس منطق العجلة
  // (أموال غالباً، جواهر قليلاً، سكن نادراً)
  // ══════════════════════════════════════════════════════
  static List<WheelSegment> lootBox = [
    WheelSegment(
        label: '100',
        emoji: '🪙',
        type: RewardType.chips,
        amount: 100,
        weight: 30,
        color: 0xFFFFC837),
    WheelSegment(
        label: '3',
        emoji: '💎',
        type: RewardType.gems,
        amount: 3,
        weight: 9,
        color: 0xFF38BDF8),
    WheelSegment(
        label: '200',
        emoji: '🪙',
        type: RewardType.chips,
        amount: 200,
        weight: 26,
        color: 0xFFFF9F43),
    WheelSegment(
        label: '6',
        emoji: '💎',
        type: RewardType.gems,
        amount: 6,
        weight: 5,
        color: 0xFF818CF8),
    WheelSegment(
        label: '75',
        emoji: '🪙',
        type: RewardType.chips,
        amount: 75,
        weight: 30,
        color: 0xFFFFD54F),
    WheelSegment(
        label: 'سكن!'.tr,
        emoji: '🎨',
        type: RewardType.skin,
        amount: 0,
        weight: 3,
        color: 0xFFC084FC),
  ];

  /// اختيار جائزة الصندوق موزوناً — يعيد فهرس الجائزة
  static int pickLootBoxIndex([math.Random? rng]) {
    final r = rng ?? math.Random();
    int total = 0;
    for (final s in lootBox) {
      total += s.weight;
    }
    int roll = r.nextInt(total);
    for (int i = 0; i < lootBox.length; i++) {
      roll -= lootBox[i].weight;
      if (roll < 0) return i;
    }
    return 0;
  }

  /// سكن الصندوق لهذا الأسبوع (من المجمّع نفسه لكن بإزاحة مختلفة)
  static String get lootBoxSkinThisWeek =>
      rewardSkinPool[(weekIndex + 3) % rewardSkinPool.length];
}

// ══════════════════════════════════════════════════════════════
// نظام الرتب — تُحسب تلقائياً من التقييم (Rating)
// ══════════════════════════════════════════════════════════════
class PlayerRank {
  final String name;
  final String emoji;
  final int color;
  final int minRating;

  const PlayerRank(this.name, this.emoji, this.color, this.minRating);
}

class Ranks {
  Ranks._();

  static List<PlayerRank> tiers = [
    PlayerRank('برونزي'.tr, '🥉', 0xFFB45309, 0),
    PlayerRank('فضي'.tr, '🥈', 0xFF94A3B8, 1000),
    PlayerRank('ذهبي'.tr, '🥇', 0xFFFFD54F, 1200),
    PlayerRank('بلاتينيوم'.tr, '💠', 0xFF38BDF8, 1400),
    PlayerRank('ماسي'.tr, '💎', 0xFF818CF8, 1600),
    PlayerRank('أسطوري'.tr, '👑', 0xFFC084FC, 1800),
  ];

  /// رتبة اللاعب الحالية حسب تقييمه
  static PlayerRank of(int rating) {
    PlayerRank rank = tiers.first;
    for (final t in tiers) {
      if (rating >= t.minRating) rank = t;
    }
    return rank;
  }

  /// الرتبة التالية + النقاط المتبقية لها (null إن أسطوري)
  static ({PlayerRank? next, int toGo}) progress(int rating) {
    for (final t in tiers) {
      if (rating < t.minRating) {
        return (next: t, toGo: t.minRating - rating);
      }
    }
    return (next: null, toGo: 0);
  }
}
