import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/rewards_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../l10n/app_lang.dart';

/// لوحة المكافآت اليومية الكاملة:
/// شريط الهدايا الأسبوعي (جوائز متنوعة تتبدل كل أسبوع)
/// + شريط اشتراك VIP أسفله + بطاقة عجلة الحظ اليومية
class DailyRewardsPanel extends StatelessWidget {
  const DailyRewardsPanel({super.key});

  static const _gold = Color(0xFFFFD54F);
  static const _emerald = Color(0xFF34D399);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService(),
      builder: (context, _) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _WeeklyStrip(),
          SizedBox(height: 12),
          _VipStrip(),
          SizedBox(height: 12),
          // صندوق الغنائم وعجلة الحظ جنباً إلى جنب — بطاقتا
          // استعراض برسم مخصص بدل أيقونة إيموجي
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _LootBoxCard()),
                SizedBox(width: 12),
                Expanded(child: _WheelCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 1) الشريط الأسبوعي — 7 أيام بجوائز متنوعة تتبدل كل أسبوع
// ══════════════════════════════════════════════════════════════
class _WeeklyStrip extends StatelessWidget {
  const _WeeklyStrip();

  Future<void> _claim(BuildContext context) async {
    AppHaptics.medium();
    final res = await AuthService().claimDailyGift();
    if (context.mounted) {
      TopNotification.show(
        context,
        res['message'] as String,
        icon: res['success'] == true
            ? Icons.card_giftcard_rounded
            : Icons.lock_clock_rounded,
      );
    }
  }

  String _rewardEmoji(DailyReward r) {
    switch (r.type) {
      case RewardType.chips:
        return '🪙';
      case RewardType.gems:
        return '💎';
      case RewardType.skin:
        return '🎨';
    }
  }

  String _rewardLabel(DailyReward r) {
    switch (r.type) {
      case RewardType.skin:
        return 'سكن!'.tr;
      default:
        return '+${r.amount}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final lastClaim = user?.lastDailyGiftClaim;
    final now = DateTime.now();
    final rewards = RewardsService.currentWeekRewards;

    bool claimable =
        lastClaim == null || now.difference(lastClaim).inHours >= 24;
    int remH = 0, remM = 0;
    if (!claimable) {
      final diff = now.difference(lastClaim);
      remH = math.max(0, 23 - diff.inHours);
      remM = math.max(0, 59 - (diff.inMinutes % 60));
    }

    final streak = user?.dailyGiftStreak ?? 0;
    final targetIndex = claimable ? (streak % 7) : ((streak - 1).clamp(0, 6));
    final isVip = user?.isVip ?? false;
    final weekNames = [
      'الأسبوع الذهبي ✨'.tr,
      'أسبوع الجواهر 💎'.tr,
      'أسبوع الثروة 🪙'.tr,
      'الأسبوع الملكي 👑'.tr,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1B2A5E).withOpacity(0.5),
                  const Color(0xFF101838).withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              // التوهج الذهبي يظهر فقط عندما تكون هدية اليوم جاهزة للاستلام
              border: Border.all(
                  color: claimable
                      ? DailyRewardsPanel._gold.withOpacity(0.45)
                      : Colors.white.withOpacity(0.12),
                  width: 1.2),
              boxShadow: claimable
                  ? [
                      BoxShadow(
                          color: DailyRewardsPanel._gold.withOpacity(0.13),
                          blurRadius: 22,
                          spreadRadius: -4),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text('🎁', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الهدايا اليومية'.tr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: DailyRewardsPanel._textWhite,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '{} — جوائز جديدة كل أسبوع'.trp(
                                      [weekNames[RewardsService.weekIndex]]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: DailyRewardsPanel._textDim,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (claimable
                                ? DailyRewardsPanel._emerald
                                : DailyRewardsPanel._gold)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: (claimable
                                  ? DailyRewardsPanel._emerald
                                  : DailyRewardsPanel._gold)
                              .withOpacity(0.5),
                          width: 0.9,
                        ),
                      ),
                      child: Text(
                        claimable
                            ? 'جاهزة للاستلام! 🎉'.tr
                            : 'متبقي: {}س {}د'.trp([remH, remM]),
                        style: TextStyle(
                          color: claimable
                              ? DailyRewardsPanel._emerald
                              : DailyRewardsPanel._gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final isPast =
                        !claimable ? index <= targetIndex : index < targetIndex;
                    final isCurrent = claimable && index == targetIndex;
                    final reward = rewards[index];
                    final isSkin = reward.type == RewardType.skin;
                    final emoji = _rewardEmoji(reward);
                    final label = _rewardLabel(reward);

                    return GestureDetector(
                      onTap: isCurrent
                          ? () => _claim(context)
                          : () {
                              if (isPast) {
                                TopNotification.show(
                                    context,
                                    'تم استلام هدية اليوم {} بالفعل!'
                                        .trp([index + 1]),
                                    icon: Icons.check_circle_rounded);
                              } else {
                                TopNotification.show(
                                    context,
                                    'هذه الهدية مقفلة! تفتح بعد إتمام الأيام السابقة'
                                        .tr,
                                    icon: Icons.lock_rounded);
                              }
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 42,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isCurrent
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFFE082),
                                    DailyRewardsPanel._gold,
                                    Color(0xFFE8A820),
                                  ],
                                )
                              : null,
                          color: isPast
                              ? DailyRewardsPanel._emerald.withOpacity(0.18)
                              : (isCurrent ? null : const Color(0x2E141C3C)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? const Color(0xFFFFE9A8)
                                : (isPast
                                    ? DailyRewardsPanel._emerald
                                        .withOpacity(0.7)
                                    : const Color(0x26FFFFFF)),
                            width: isCurrent ? 1.6 : 1,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: DailyRewardsPanel._gold
                                        .withOpacity(0.5),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'يوم {}'.trp([index + 1]),
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xFF1B0B30)
                                    : DailyRewardsPanel._textDim,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPast ? '✔' : (isCurrent ? '🎁' : emoji),
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    isPast ? DailyRewardsPanel._emerald : null,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isPast ? '' : label,
                              maxLines: 1,
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xFF1B0B30)
                                    : isSkin
                                        ? const Color(0xFFC084FC)
                                        : reward.type == RewardType.gems
                                            ? const Color(0xFF7DD3FC)
                                            : DailyRewardsPanel._gold,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                if (isVip) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      user?.isVipPlus == true
                          ? '👑 VIP+: مكافآتك معزّزة +50%'.tr
                          : '👑 VIP: مكافآتك معزّزة +25%'.tr,
                      style: const TextStyle(
                        color: DailyRewardsPanel._gold,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                // حماية السلسلة — انقطعت خلال آخر 4 أيام؟ استرجعها بـ10💎
                if (AuthService().canRestoreStreak) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      AppHaptics.medium();
                      final res = await AuthService().buyStreakProtection();
                      if (context.mounted) {
                        TopNotification.show(
                          context,
                          res['message'] as String,
                          icon: res['success'] == true
                              ? Icons.local_fire_department_rounded
                              : Icons.warning_rounded,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFF7F1D1D),
                          Color(0xFF450A0A),
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFB923C).withOpacity(0.6)),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFFB923C).withOpacity(0.25),
                              blurRadius: 10),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔥', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 6),
                          Text(
                            'سلسلتك انقطعت! استرجعها الآن بـ10💎'.tr,
                            style: TextStyle(
                                color: Color(0xFFFED7AA),
                                fontSize: 11,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 2) شريط اشتراك VIP — 10$ شهرياً
// ══════════════════════════════════════════════════════════════
class _VipStrip extends StatelessWidget {
  const _VipStrip();

  Future<void> _subscribe(BuildContext context) async {
    AppHaptics.medium();
    final confirm = await showDialog<Object?>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF141C34),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side:
                  BorderSide(color: DailyRewardsPanel._gold.withOpacity(0.5))),
          title: Row(
            children: [
              Text('👑', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Text('اشتراك VIP'.tr,
                  style: TextStyle(
                      color: DailyRewardsPanel._textWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('👑 VIP — 10\$ شهرياً:'.tr,
                  style: TextStyle(
                      color: DailyRewardsPanel._gold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              _VipPerk('🎡 لفتان يومياً على العجلة'.tr),
              _VipPerk('🪙 +25% على مكافآت الهدايا'.tr),
              _VipPerk('�️ إطار VIP الذهبي تلقائياً'.tr),
              SizedBox(height: 12),
              Text('💎 VIP+ — 20\$ شهرياً:'.tr,
                  style: TextStyle(
                      color: Color(0xFFC084FC),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 6),
              _VipPerk('🎡 3 لفات يومياً على العجلة'.tr),
              _VipPerk('🪙 +50% على مكافآت الهدايا'.tr),
              _VipPerk('⚡ أولوية قصوى في الدعم'.tr),
              SizedBox(height: 10),
              Text(
                'سيتم التفعيل خلال 24 ساعة بعد تأكيد الدفع من الإدارة.'.tr,
                style:
                    TextStyle(color: DailyRewardsPanel._textDim, fontSize: 11),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('إلغاء'.tr,
                  style: TextStyle(color: DailyRewardsPanel._textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DailyRewardsPanel._gold,
                foregroundColor: const Color(0xFF1B0B30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('VIP — 10\$',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC084FC),
                foregroundColor: const Color(0xFF2E1065),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop('plus'),
              child: const Text('VIP+ — 20\$',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );

    if (confirm == null || confirm == false || !context.mounted) {
      return;
    }
    final res = await AuthService()
        .submitVipRequest(plan: confirm == 'plus' ? 'vipPlus' : 'vip');
    if (context.mounted) {
      TopNotification.show(
        context,
        res['message'] as String,
        icon: res['success'] == true
            ? Icons.workspace_premium_rounded
            : Icons.warning_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final isVip = user?.isVip ?? false;
    final isVipPlus = user?.isVipPlus ?? false;
    final vipUntil = user?.vipUntil;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isVip
                    ? [
                        const Color(0xFF4A3200).withOpacity(0.85),
                        const Color(0xFF2A1E00).withOpacity(0.8),
                      ]
                    : [
                        const Color(0xFF2A1A4E).withOpacity(0.75),
                        const Color(0xFF1A1040).withOpacity(0.7),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: DailyRewardsPanel._gold.withOpacity(0.55), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: DailyRewardsPanel._gold.withOpacity(0.15),
                    blurRadius: 18,
                    spreadRadius: -4),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF3C4),
                        DailyRewardsPanel._gold,
                        Color(0xFFB8860B),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: DailyRewardsPanel._gold.withOpacity(0.45),
                          blurRadius: 10),
                    ],
                  ),
                  child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVipPlus
                            ? 'اشتراك VIP+ الشهري'.tr
                            : 'اشتراك VIP الشهري'.tr,
                        style: TextStyle(
                          color: DailyRewardsPanel._textWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVip && vipUntil != null
                            ? 'عضويتك فعّالة حتى {}/{} — لفتان يومياً + مكافآت +25% 👑'
                                .trp([vipUntil.day, vipUntil.month])
                            : 'لفّتان يومياً + مكافآت +25% + شارة ملكية — 10\$ فقط'
                                .tr,
                        maxLines: 2,
                        style: TextStyle(
                          color: isVip
                              ? DailyRewardsPanel._gold
                              : DailyRewardsPanel._textDim,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isVip)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: DailyRewardsPanel._emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: DailyRewardsPanel._emerald.withOpacity(0.6)),
                    ),
                    child: Text(
                      'مُفعّل ✓'.tr,
                      style: TextStyle(
                          color: DailyRewardsPanel._emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w900),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: () => _subscribe(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFFE082),
                          DailyRewardsPanel._gold,
                          Color(0xFFE8A820),
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: DailyRewardsPanel._gold.withOpacity(0.4),
                              blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        'اشترك 10\$'.tr,
                        style: TextStyle(
                            color: Color(0xFF1B0B30),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900),
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
}

class _VipPerk extends StatelessWidget {
  final String text;
  const _VipPerk(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
            color: DailyRewardsPanel._textWhite,
            fontSize: 12.5,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 3) بطاقة عجلة الحظ اليومية — بطاقة استعراض عمودية برسم مخصص
// ══════════════════════════════════════════════════════════════
class _WheelCard extends StatelessWidget {
  const _WheelCard();

  @override
  Widget build(BuildContext context) {
    final spinsLeft = AuthService().wheelSpinsRemaining;
    final isVip = AuthService().currentUser?.isVip ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF16436B).withOpacity(0.55),
                const Color(0xFF0B1B33).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: const Color(0xFF38BDF8).withOpacity(0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF38BDF8).withOpacity(0.15),
                  blurRadius: 18,
                  spreadRadius: -4),
            ],
          ),
          child: Column(
            children: [
              // عجلة مرسومة بحافة ذهبية ومقاطع ملوّنة
              SizedBox(
                height: 74,
                child: CustomPaint(
                  size: const Size(74, 74),
                  painter: const _MiniWheelPainter(),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'عجلة الحظ اليومية'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DailyRewardsPanel._textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spinsLeft > 0
                    ? 'عندك {} {}'
                        .trp([spinsLeft, spinsLeft == 1 ? 'لفة' : 'لفات'])
                    : 'عُد غداً!{}'.trp([isVip ? '' : ' VIP = لفتان']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DailyRewardsPanel._textDim,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  AppHaptics.medium();
                  if (AuthService().currentUser == null) {
                    TopNotification.show(context, 'سجّل الدخول أولاً!'.tr,
                        icon: Icons.warning_rounded);
                    return;
                  }
                  if (spinsLeft <= 0) {
                    TopNotification.show(
                        context, 'استخدمت لفات اليوم! عُد غداً 🎡'.tr,
                        icon: Icons.lock_clock_rounded);
                    return;
                  }
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const DailyWheelDialog(),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: spinsLeft > 0
                        ? const LinearGradient(colors: [
                            Color(0xFF7DD3FC),
                            Color(0xFF38BDF8),
                            Color(0xFF0284C7),
                          ])
                        : null,
                    color: spinsLeft > 0 ? null : const Color(0x2EFFFFFF),
                    borderRadius: BorderRadius.circular(13),
                    border: spinsLeft > 0
                        ? Border.all(color: const Color(0xFFBAE6FD), width: 0.8)
                        : null,
                    boxShadow: spinsLeft > 0
                        ? [
                            BoxShadow(
                                color:
                                    const Color(0xFF38BDF8).withOpacity(0.45),
                                blurRadius: 12),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      spinsLeft > 0 ? 'أدر الآن'.tr : 'انتهت'.tr,
                      style: TextStyle(
                          color: spinsLeft > 0
                              ? const Color(0xFF082F49)
                              : DailyRewardsPanel._textDim,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900),
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
}

// ══════════════════════════════════════════════════════════════
// 3b) بطاقة صندوق الغنائم اليومي — بطاقة استعراض عمودية بصندوق مرسوم
// ══════════════════════════════════════════════════════════════
class _LootBoxCard extends StatelessWidget {
  const _LootBoxCard();

  Future<void> _open(BuildContext context) async {
    AppHaptics.medium();
    if (AuthService().currentUser == null) {
      TopNotification.show(context, 'سجّل الدخول أولاً!'.tr,
          icon: Icons.warning_rounded);
      return;
    }
    if (!AuthService().canClaimLootBox) {
      TopNotification.show(context, 'الصندوق يتجدد غداً ⏳'.tr,
          icon: Icons.lock_clock_rounded);
      return;
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LootBoxDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = AuthService().canClaimLootBox;
    const purple = Color(0xFFC084FC);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF4A1D6B).withOpacity(0.55),
                const Color(0xFF1A0B33).withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: purple.withOpacity(0.5), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: purple.withOpacity(0.15),
                  blurRadius: 18,
                  spreadRadius: -4),
            ],
          ),
          child: Column(
            children: [
              // صندوق كنز خشبي بأحزمة ذهبية — يتوهج عندما يُتاح فتحه
              SizedBox(
                height: 74,
                child: CustomPaint(
                  size: const Size(84, 74),
                  painter: _ChestPainter(glow: canOpen),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'صندوق الغنائم اليومي'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DailyRewardsPanel._textWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                canOpen ? 'مجاني — افتحه الآن!'.tr : 'يتجدد كل 24 ساعة ⏳'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: DailyRewardsPanel._textDim,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _open(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: canOpen
                        ? const LinearGradient(colors: [
                            Color(0xFFE9D5FF),
                            purple,
                            Color(0xFF9333EA),
                          ])
                        : null,
                    color: canOpen ? null : const Color(0x2EFFFFFF),
                    borderRadius: BorderRadius.circular(13),
                    border: canOpen
                        ? Border.all(color: const Color(0xFFE9D5FF), width: 0.8)
                        : null,
                    boxShadow: canOpen
                        ? [
                            BoxShadow(
                                color: purple.withOpacity(0.45),
                                blurRadius: 12),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      canOpen ? 'افتح مجاناً'.tr : 'غداً'.tr,
                      style: TextStyle(
                          color: canOpen
                              ? const Color(0xFF2E1065)
                              : DailyRewardsPanel._textDim,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900),
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
}

// ══════════════════════════════════════════════════════════════
// رسّامات البطاقات
// ══════════════════════════════════════════════════════════════

/// صندوق كنز خشبي بأحزمة ذهبية وقفل — يتوهج إذا كان فتحه متاحاً،
/// وعند [openT]>0 يدور الغطاء للخلف ويتصاعد شعاع ضوء من الداخل
class _ChestPainter extends CustomPainter {
  final bool glow;
  final double openT;
  const _ChestPainter({this.glow = false, this.openT = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 84, size.height / 74);

    final wood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF9C6A34), Color(0xFF7A4E22), Color(0xFF54300F)],
      ).createShader(const Rect.fromLTWH(0, 0, 84, 74));
    final lidWood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF8A5A2A), Color(0xFF6B401C), Color(0xFF4A2A10)],
      ).createShader(const Rect.fromLTWH(0, 0, 84, 74));
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFE9A8), Color(0xFFFFB300), Color(0xFF8B5E00)],
      ).createShader(const Rect.fromLTWH(0, 0, 84, 74));

    // ظل أرضي
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(42, 66), width: 66, height: 8),
      Paint()..color = Colors.black.withOpacity(0.42),
    );

    // توهج خلف الصندوق عندما يكون فتحه متاحاً
    if (glow) {
      canvas.drawCircle(
        const Offset(42, 34),
        36,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFC084FC).withOpacity(0.34),
            Colors.transparent,
          ]).createShader(
              Rect.fromCircle(center: const Offset(42, 34), radius: 36)),
      );
    }

    // شعاع الضوء المتصاعد عند الفتح
    if (openT > 0) {
      final beam = Path()
        ..moveTo(26, 30)
        ..lineTo(58, 30)
        ..lineTo(70, 2)
        ..lineTo(14, 2)
        ..close();
      canvas.drawPath(
        beam,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              const Color(0xFFFFE9A8).withOpacity(0.65 * openT),
              const Color(0xFFFFE9A8).withOpacity(0.0),
            ],
          ).createShader(const Rect.fromLTWH(0, 2, 84, 30)),
      );
      // بريقان جانبيان
      for (final s in [
        const Offset(20, 12),
        const Offset(62, 8),
        const Offset(46, 4),
      ]) {
        canvas.drawCircle(s, 1.6 * openT,
            Paint()..color = const Color(0xFFFFF3C4).withOpacity(openT));
      }
    }

    // جسم الصندوق
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 32, 44, 32), const Radius.circular(5));
    canvas.drawRRect(body, wood);
    // تظليل جانبي + حافة ضوء علوية
    canvas.drawRect(const Rect.fromLTWH(58, 33, 5, 30),
        Paint()..color = Colors.black.withOpacity(0.22));
    canvas.drawRect(const Rect.fromLTWH(21, 33, 42, 2),
        Paint()..color = Colors.white.withOpacity(0.18));
    // الأحزمة الذهبية
    canvas.drawRect(const Rect.fromLTWH(29, 32, 5, 32), gold);
    canvas.drawRect(const Rect.fromLTWH(50, 32, 5, 32), gold);
    // خط أسفل داكن
    canvas.drawRect(const Rect.fromLTWH(20, 60, 44, 4),
        Paint()..color = Colors.black.withOpacity(0.25));

    // القفل الذهبي
    final lock = RRect.fromRectAndRadius(
        const Rect.fromLTWH(36.5, 34, 11, 12), const Radius.circular(3));
    canvas.drawRRect(lock, gold);
    canvas.drawRRect(
        lock,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0xFF3E2C00));
    canvas.drawCircle(
        const Offset(42, 39), 1.7, Paint()..color = const Color(0xFF3E2C00));

    // الغطاء — مغلق أو يدور للخلف حول مفصلته اليسرى
    final lidT = Curves.easeOutBack.transform(openT.clamp(0.0, 1.0));
    canvas.save();
    if (lidT > 0) {
      canvas.translate(20, 32);
      canvas.rotate(-1.05 * lidT);
      canvas.translate(-20, -32);
    }
    final lid = RRect.fromRectAndRadius(
        const Rect.fromLTWH(16, 16, 52, 17), const Radius.circular(7));
    canvas.drawRRect(lid, lidWood);
    // أحزمة الغطاء
    canvas.drawRect(const Rect.fromLTWH(29, 16, 5, 17), gold);
    canvas.drawRect(const Rect.fromLTWH(50, 16, 5, 17), gold);
    // حافة ضوء على الغطاء
    canvas.drawRect(const Rect.fromLTWH(18, 17, 48, 2.4),
        Paint()..color = Colors.white.withOpacity(0.22));
    canvas.drawRRect(
        lid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.black.withOpacity(0.35));
    canvas.restore();

    // داخل الصندوق متوهج عند الفتح
    if (openT > 0) {
      canvas.drawRect(const Rect.fromLTWH(22, 32, 40, 8),
          Paint()..color = const Color(0xFFFFE9A8).withOpacity(0.7 * openT));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChestPainter old) =>
      old.glow != glow || old.openT != openT;
}

/// عجلة حظ مصغّرة — مقاطع ملوّنة وإطار ذهبي بمصابيح صغيرة
class _MiniWheelPainter extends CustomPainter {
  const _MiniWheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 74, size.height / 74);
    const c = Offset(37, 37);
    const r = 33.0;
    const segColors = [
      Color(0xFFF59E0B),
      Color(0xFF38BDF8),
      Color(0xFFA855F7),
      Color(0xFF34D399),
      Color(0xFFEF4444),
      Color(0xFF38BDF8),
      Color(0xFFF59E0B),
      Color(0xFF818CF8),
    ];

    // ظل
    canvas.drawCircle(
        c.translate(0, 2.5), r, Paint()..color = Colors.black.withOpacity(0.4));

    // المقاطع
    const step = math.pi * 2 / 8;
    for (int i = 0; i < 8; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 4),
        -math.pi / 2 + i * step,
        step - 0.04,
        true,
        Paint()..color = segColors[i].withOpacity(0.92),
      );
    }
    // فواصل داكنة
    for (int i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * step;
      canvas.drawLine(
        Offset(c.dx + math.cos(a) * (r - 4), c.dy + math.sin(a) * (r - 4)),
        c,
        Paint()
          ..color = const Color(0xFF0A0F24)
          ..strokeWidth = 1.4,
      );
    }

    // الإطار الذهبي
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = const SweepGradient(colors: [
          Color(0xFFFFE082),
          Color(0xFFFFD54F),
          Color(0xFF8B5E00),
          Color(0xFFFFD54F),
          Color(0xFFFFE082),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // مصابيح الإطار
    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * (r - 2), c.dy + math.sin(a) * (r - 2)),
        1.6,
        Paint()..color = const Color(0xFFFFF8DC),
      );
    }

    // المحور
    canvas.drawCircle(c, 7, Paint()..color = const Color(0xFF0A0F24));
    canvas.drawCircle(c, 5.5, Paint()..color = const Color(0xFFFFD54F));

    // المؤشر الذهبي العلوي
    final p = Path()
      ..moveTo(c.dx, 1.5)
      ..lineTo(c.dx - 5, 12)
      ..lineTo(c.dx + 5, 12)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0xFF3E2C00));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════════════════════════════════
// حوار عجلة الحظ — دوران متحرك يهبط على المقطع الفائز
// ══════════════════════════════════════════════════════════════
class DailyWheelDialog extends StatefulWidget {
  const DailyWheelDialog({super.key});

  @override
  State<DailyWheelDialog> createState() => _DailyWheelDialogState();
}

class _DailyWheelDialogState extends State<DailyWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _angle;
  Map<String, dynamic>? _result;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 5200));
    _angle = const AlwaysStoppedAnimation(0);
    _spin();
  }

  Future<void> _spin() async {
    final res = await AuthService().spinDailyWheel();
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _error = res['message'] as String);
      return;
    }
    final seg = res['segmentIndex'] as int;
    // المؤشر أعلى العجلة — نوجّه مركز المقطع الفائز إليه + 6 دورات + اهتزازة
    final step = math.pi * 2 / RewardsService.wheel.length;
    final jitter = (math.Random().nextDouble() - 0.5) * step * 0.55;
    final target = math.pi * 2 * 6 - (seg + 0.5) * step + jitter;
    _angle = Tween(begin: 0.0, end: target)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutQuart));
    setState(() => _result = res);
    _c.forward().whenComplete(() {
      if (mounted) {
        AppHaptics.heavy();
        setState(() => _done = true);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF16204A).withOpacity(0.92),
                    const Color(0xFF0A0F24).withOpacity(0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: DailyRewardsPanel._gold.withOpacity(0.5),
                    width: 1.3),
                boxShadow: [
                  BoxShadow(
                      color: DailyRewardsPanel._gold.withOpacity(0.15),
                      blurRadius: 30),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🎡 عجلة الحظ اليومية'.tr,
                    style: TextStyle(
                      color: DailyRewardsPanel._textWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الأموال الأكثر حظاً 🪙 — جواهر قليلة 💎 — سكن نادر 🎨'.tr,
                    style: TextStyle(
                        color: DailyRewardsPanel._textDim, fontSize: 10.5),
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Color(0xFFFCA5A5), fontSize: 13),
                      ),
                    )
                  else
                    SizedBox(
                      width: 264,
                      height: 264,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // أشعة النصر الذهبية تدور خلف العجلة عند الفوز
                          AnimatedOpacity(
                            opacity: _done ? 1 : 0,
                            duration: const Duration(milliseconds: 600),
                            child: CustomPaint(
                              size: const Size(264, 264),
                              painter: const _WinBurstPainter(),
                            ),
                          ),
                          AnimatedBuilder(
                            animation: _angle,
                            builder: (_, child) => Transform.rotate(
                              angle: _angle.value,
                              child: child,
                            ),
                            child: CustomPaint(
                              size: const Size(244, 244),
                              painter: const _WheelPainter(),
                            ),
                          ),
                          // المؤشر العلوي
                          const Positioned(
                            top: 0,
                            child: _WheelPointer(),
                          ),
                          // محور العجلة
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(colors: [
                                Color(0xFFFFF3C4),
                                DailyRewardsPanel._gold,
                                Color(0xFF8B5E00),
                              ]),
                              border: Border.all(
                                  color: const Color(0xFF3E2C00), width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 8),
                              ],
                            ),
                            child: const Center(
                              child: Text('🎡', style: TextStyle(fontSize: 17)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _done && _result != null
                        ? Container(
                            key: const ValueKey('win'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFFF3C4),
                                DailyRewardsPanel._gold,
                              ]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: DailyRewardsPanel._gold
                                        .withOpacity(0.5),
                                    blurRadius: 16),
                              ],
                            ),
                            child: Text(
                              _result!['message'] as String,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Color(0xFF1B0B30),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13),
                            ),
                          )
                        : Text(
                            _error != null ? '' : 'العجلة تدور...'.tr,
                            key: const ValueKey('spin'),
                            style: const TextStyle(
                                color: DailyRewardsPanel._textDim,
                                fontSize: 12),
                          ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_done || _error != null)
                          ? () => Navigator.of(context).pop()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DailyRewardsPanel._gold,
                        disabledBackgroundColor: Colors.white.withOpacity(0.08),
                        foregroundColor: const Color(0xFF1B0B30),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('إغلاق'.tr,
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// المؤشر الذهبي أعلى العجلة
class _WheelPointer extends StatelessWidget {
  const _WheelPointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(26, 18),
      painter: _PointerPainter(),
    );
  }
}

/// أشعة نصر ذهبية خلف العجلة عند الفوز
class _WinBurstPainter extends CustomPainter {
  const _WinBurstPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFD54F).withOpacity(0.35),
        const Color(0xFFFFD54F).withOpacity(0.10),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: c, radius: r));
    // أشعة مثلثة رفيعة متباعدة
    for (int i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p = Path()
        ..moveTo(c.dx + math.cos(a - 0.045) * r * 0.44,
            c.dy + math.sin(a - 0.045) * r * 0.44)
        ..lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r)
        ..lineTo(c.dx + math.cos(a + 0.045) * r * 0.44,
            c.dy + math.sin(a + 0.045) * r * 0.44)
        ..close();
      canvas.drawPath(p, paint);
    }
    canvas.drawCircle(c, r * 0.42, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE082), DailyRewardsPanel._gold],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF3E2C00),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// رسم مقاطع العجلة الثمانية بألوانها ونصوصها
class _WheelPainter extends CustomPainter {
  const _WheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final segs = RewardsService.wheel;
    final step = math.pi * 2 / segs.length;

    // ظل خارجي
    canvas.drawCircle(
      c.translate(0, 3),
      r,
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    // المقاطع
    for (int i = 0; i < segs.length; i++) {
      final seg = segs[i];
      final start = -math.pi / 2 + i * step;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Color(seg.color).withOpacity(0.95),
            Color(seg.color).withOpacity(0.55),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawArc(Rect.fromCircle(center: c, radius: r - 6), start,
          step - 0.02, true, paint);

      // فاصل بين المقاطع
      canvas.drawLine(
        Offset(
            c.dx + math.cos(start) * (r - 6), c.dy + math.sin(start) * (r - 6)),
        c,
        Paint()
          ..color = const Color(0xFF0A0F24)
          ..strokeWidth = 2,
      );

      // النص + الإيموجي عند منتصف المقطع
      final mid = start + step / 2;
      final tx = c.dx + math.cos(mid) * (r - 6) * 0.68;
      final ty = c.dy + math.sin(mid) * (r - 6) * 0.68;

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(mid + math.pi / 2);
      final tp = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
                text: '${seg.emoji}\n', style: const TextStyle(fontSize: 13)),
            TextSpan(
              text: seg.label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)]),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // إطار ذهبي خارجي
    canvas.drawCircle(
      c,
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = const SweepGradient(colors: [
          Color(0xFFFFE082),
          DailyRewardsPanel._gold,
          Color(0xFF8B5E00),
          DailyRewardsPanel._gold,
          Color(0xFFFFE082),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // نقاط مضيئة على الإطار
    for (int i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * (r - 3), c.dy + math.sin(a) * (r - 3)),
        2.2,
        Paint()..color = const Color(0xFFFFF8DC),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ══════════════════════════════════════════════════════════════
// حوار صندوق الغنائم — الصندوق يهتز ثم ينفتح ويكشف الجائزة
// ══════════════════════════════════════════════════════════════
class LootBoxDialog extends StatefulWidget {
  const LootBoxDialog({super.key});

  @override
  State<LootBoxDialog> createState() => _LootBoxDialogState();
}

class _LootBoxDialogState extends State<LootBoxDialog>
    with TickerProviderStateMixin {
  late final AnimationController _c;
  // متحكم ثانٍ لدوران الغطاء وتصاعد الضوء عند الفتح
  late final AnimationController _lidC;
  Map<String, dynamic>? _result;
  String? _error;
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _lidC = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _claim();
  }

  Future<void> _claim() async {
    // اهتزاز الصندوق أولاً
    _c.forward();
    final res = await AuthService().claimLootBox();
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _error = res['message'] as String);
      return;
    }
    // انتظر انتهاء الاهتزاز ثم اكشف الجائزة
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    AppHaptics.heavy();
    setState(() {
      _result = res;
      _opened = true;
    });
    _lidC.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _lidC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFC084FC);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF2A1650).withOpacity(0.94),
                    const Color(0xFF0E0820).withOpacity(0.97),
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: purple.withOpacity(0.55), width: 1.4),
                boxShadow: [
                  BoxShadow(color: purple.withOpacity(0.2), blurRadius: 32),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📦 صندوق الغنائم'.tr,
                      style: TextStyle(
                          color: Color(0xFFF1F5FF),
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  // الصندوق المرسوم — يهتز ثم ينفتح غطاؤه بشعاع ضوء
                  AnimatedBuilder(
                    animation: Listenable.merge([_c, _lidC]),
                    builder: (_, __) {
                      final t = _c.value;
                      final shake = _opened
                          ? 0.0
                          : math.sin(t * math.pi * 14) * (1 - t) * 0.16;
                      final scale =
                          _opened ? 1.18 : 1.0 + math.sin(t * math.pi) * 0.12;
                      return Transform.rotate(
                        angle: shake,
                        child: Transform.scale(
                          scale: scale,
                          child: SizedBox(
                            width: 150,
                            height: 132,
                            child: CustomPaint(
                              painter:
                                  _ChestPainter(glow: true, openT: _lidC.value),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _error != null
                        ? Text(_error!,
                            key: const ValueKey('err'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFFCA5A5), fontSize: 13))
                        : _opened && _result != null
                            ? Container(
                                key: const ValueKey('win'),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFFE9D5FF),
                                    purple,
                                  ]),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                        color: purple.withOpacity(0.5),
                                        blurRadius: 18),
                                  ],
                                ),
                                child: Text(
                                  _result!['rewardLabel'] as String? ??
                                      _result!['message'] as String,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Color(0xFF2E1065),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14),
                                ),
                              )
                            : Text('الصندوق يُفتح...'.tr,
                                key: ValueKey('wait'),
                                style: TextStyle(
                                    color: Color(0xFF8EA3C8), fontSize: 12)),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_opened || _error != null)
                          ? () => Navigator.of(context).pop()
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        disabledBackgroundColor: Colors.white.withOpacity(0.08),
                        foregroundColor: const Color(0xFF2E1065),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('إغلاق'.tr,
                          style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
