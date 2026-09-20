import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/app_background.dart';

import '../services/auth_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final List<bool> _claimedMissions = [false, true, false, false];

  Future<void> _claimDailyReward() async {
    AppHaptics.medium();
    final res = await AuthService().claimDailyGift();
    if (mounted) {
      TopNotification.show(
        context,
        res['message'] as String,
        icon: res['success'] == true ? Icons.card_giftcard_rounded : Icons.lock_clock_rounded,
      );
    }
  }

  Future<void> _claimMission(int index, String title, int reward) async {
    if (!_claimedMissions[index]) {
      AppHaptics.medium();
      setState(() {
        _claimedMissions[index] = true;
      });
      await AuthService().updateMatchResult(chipChange: reward, ratingChange: 5, isWin: false);
      if (mounted) {
        TopNotification.show(
          context,
          'تم استلام مكافأة "$title" 💰 +$reward عملة ذهبية في رصيدك!',
          icon: Icons.stars_rounded,
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'الإنجازات والجوائز',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xE625143E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x40FFD54F), width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.emoji_events_rounded, color: AppColors.gold, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '18 / 40',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // Daily Login Streak (7-Day Box) with 24h timer & Firestore syncing
              AnimatedBuilder(
                animation: AuthService(),
                builder: (context, _) {
                  final user = AuthService().currentUser;
                  final lastClaim = user?.lastDailyGiftClaim;
                  final now = DateTime.now();

                  bool isClaimableNow = false;
                  int remainingHours = 0;
                  int remainingMinutes = 0;

                  if (lastClaim == null) {
                    isClaimableNow = true;
                  } else {
                    final diff = now.difference(lastClaim);
                    if (diff.inHours >= 24) {
                      isClaimableNow = true;
                    } else {
                      remainingHours = 23 - diff.inHours;
                      remainingMinutes = 59 - (diff.inMinutes % 60);
                      if (remainingHours < 0) remainingHours = 0;
                      if (remainingMinutes < 0) remainingMinutes = 0;
                    }
                  }

                  final currentStreak = user?.dailyGiftStreak ?? 0;
                  final targetIndex = isClaimableNow ? (currentStreak % 7) : ((currentStreak - 1).clamp(0, 6));

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B1E6D), Color(0xFF241242)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0x60FFD54F), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Text('🎁', style: TextStyle(fontSize: 20)),
                                  SizedBox(width: 8),
                                  Text(
                                    'مكافآت تسجيل الدخول الأسبوعي',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                isClaimableNow ? 'جاهزة للاستلام! 🎉' : 'متبقي: $remainingHours س $remainingMinutes د ⏳',
                                style: TextStyle(
                                  color: isClaimableNow ? const Color(0xFF34D399) : const Color(0xFFFFD54F),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 7 Days Grid
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (index) {
                              final isPast = !isClaimableNow ? index <= targetIndex : index < targetIndex;
                              final isCurrent = isClaimableNow && index == targetIndex;
                              final dayNum = index + 1;
                              final reward = (index + 1) * 150 + 200;

                              return GestureDetector(
                                onTap: isCurrent
                                    ? _claimDailyReward
                                    : () {
                                        if (isPast) {
                                          TopNotification.show(context, 'تم استلام هدية اليوم $dayNum بالفعل!',
                                              icon: Icons.check_circle_rounded);
                                        } else {
                                          TopNotification.show(context, 'هذه الهدية مقفلة! تفتح بعد إتمام الأيام السابقة',
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
                                            colors: [Color(0xFFFFD54F), Color(0xFFE65100)],
                                          )
                                        : null,
                                    color: isPast
                                        ? const Color(0x4034D399)
                                        : (isCurrent ? null : const Color(0x401E0E35)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCurrent
                                          ? Colors.white
                                          : (isPast ? const Color(0xFF34D399) : const Color(0x20FFFFFF)),
                                      width: isCurrent ? 1.8 : 1,
                                    ),
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF9800).withOpacity(0.6),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'يوم $dayNum',
                                        style: TextStyle(
                                          color: isCurrent ? Colors.white : AppColors.textMuted,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isPast ? '✔' : (isCurrent ? '🎁' : '🔒'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isPast ? const Color(0xFF34D399) : null,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '+$reward',
                                        style: TextStyle(
                                          color: isCurrent ? Colors.white : AppColors.gold,
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
                        ],
                      ),
                    ),
                  );
                },
              ),


              const SizedBox(height: 22),

              // Daily Quests (المهام اليومية)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'المهام اليومية (تتجدد كل 24 ساعة)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '12:45:10',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildQuestCard(
                      index: 0,
                      title: 'العب 3 مباريات شطرنج اليوم',
                      progress: '2 / 3',
                      progressRatio: 2 / 3,
                      reward: 300,
                      icon: Icons.castle_rounded,
                      color: AppColors.chessBorder,
                    ),
                    _buildQuestCard(
                      index: 1,
                      title: 'حقق الفوز في مباراة لودو',
                      progress: '1 / 1',
                      progressRatio: 1.0,
                      reward: 500,
                      icon: Icons.casino_rounded,
                      color: AppColors.ludoBorder,
                    ),
                    _buildQuestCard(
                      index: 2,
                      title: 'رتب أوراقك وفز في سوليتر',
                      progress: '0 / 1',
                      progressRatio: 0.0,
                      reward: 250,
                      icon: Icons.style_rounded,
                      color: AppColors.solitaireBorder,
                    ),
                    _buildQuestCard(
                      index: 3,
                      title: 'تحدى صديقاً في طاولي (Backgammon)',
                      progress: '0 / 1',
                      progressRatio: 0.0,
                      reward: 400,
                      icon: Icons.table_restaurant_rounded,
                      color: AppColors.backgammonBorder,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Trophies / Milestones
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'كؤوس التميز الملكية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                height: 125,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildTrophyBadge('تاج اللودو الذهبي', 'فز بـ 50 مباراة لودو', '🏆', const Color(0xFFFFD54F)),
                    _buildTrophyBadge('فارس الشطرنج', 'اهزم 20 منافساً', '♟️', const Color(0xFFC084FC)),
                    _buildTrophyBadge('ساحر السوليتر', 'أنهِ اللعبة بأقل من دقيقتين', '🃏', const Color(0xFF4ADE80)),
                    _buildTrophyBadge('أسطورة الطاولي', 'ارمِ الدوشيش 10 مرات', '🎲', const Color(0xFF38BDF8)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestCard({
    required int index,
    required String title,
    required String progress,
    required double progressRatio,
    required int reward,
    required IconData icon,
    required Color color,
  }) {
    final isDone = progressRatio >= 1.0;
    final isClaimed = _claimedMissions[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xE624143D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone && !isClaimed ? AppColors.gold : color.withOpacity(0.3),
          width: isDone && !isClaimed ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressRatio,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDone ? const Color(0xFF34D399) : color,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          progress,
                          style: TextStyle(
                            color: isDone ? const Color(0xFF34D399) : AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Action / Reward Button
          GestureDetector(
            onTap: () {
              if (isDone) {
                _claimMission(index, title, reward);
              } else {
                AppHaptics.light();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: isDone && !isClaimed
                    ? const LinearGradient(
                        colors: [Color(0xFFFFB300), Color(0xFFE65100)],
                      )
                    : null,
                color: isClaimed
                    ? const Color(0x3334D399)
                    : (isDone ? null : const Color(0x25FFFFFF)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDone && !isClaimed
                      ? const Color(0xFFFFD54F)
                      : (isClaimed ? const Color(0xFF34D399) : Colors.transparent),
                  width: 1,
                ),
              ),
              child: isClaimed
                  ? const Text(
                      'تم الاستلام ✔',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                    )
                  : (isDone
                      ? const Text(
                          'استلام 💰',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        )
                      : Text(
                          '+$reward 💰',
                          style: const TextStyle(color: AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700),
                        )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrophyBadge(String title, String desc, String emoji, Color glowColor) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(left: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE624143D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
