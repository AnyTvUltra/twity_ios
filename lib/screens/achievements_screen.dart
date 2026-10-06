import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../utils/format.dart';
import '../services/auth_service.dart';
import '../widgets/daily_rewards_panel.dart';
import '../l10n/app_lang.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final List<bool> _claimedMissions = [false, true, false, false];

  static const _bgTop = Color(0xFF0A0F24);
  static const _bgMid = Color(0xFF080C1C);
  static const _bgBot = Color(0xFF04060F);
  static const _neonBlue = Color(0xFF3B82F6);
  static const _cyan = Color(0xFF38BDF8);
  static const _gold = Color(0xFFFFD54F);
  static const _emerald = Color(0xFF34D399);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  Future<void> _claimMission(int index, String title, int reward) async {
    if (!_claimedMissions[index]) {
      AppHaptics.medium();
      setState(() {
        _claimedMissions[index] = true;
      });
      await AuthService().updateMatchResult(
        chipChange: reward,
        ratingChange: 5,
        isWin: false,
        recordResult: false,
      );
      if (mounted) {
        TopNotification.show(
          context,
          'تم استلام مكافأة "{}" 💰 +{} عملة ذهبية في رصيدك!'
              .trp([title, reward]),
          icon: Icons.stars_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgMid, _bgBot],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
              child: CustomPaint(painter: _AchievementsDecorPainter())),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══ الهيدر ═══
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'الإنجازات والجوائز'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textWhite,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                    color: Color(0x33FFFFFF), blurRadius: 10),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // حلقة تقدّم الإنجازات الزجاجية
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x3A16204A),
                            border: Border.all(
                                color: _gold.withOpacity(0.35), width: 1),
                            boxShadow: [
                              BoxShadow(
                                  color: _gold.withOpacity(0.18),
                                  blurRadius: 12),
                            ],
                          ),
                          child: CustomPaint(
                            painter: const _RingProgressPainter(
                                progress: 18 / 40, color: _gold),
                            child: const Center(
                              child: Text(
                                '18/40',
                                style: TextStyle(
                                    color: _textWhite,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  const DailyRewardsPanel(),

                  const SizedBox(height: 22),

                  // ═══ المهام اليومية ═══
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              _neonBlue.withOpacity(0.8),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'المهام اليومية (تتجدد كل 24 ساعة)'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textWhite,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x2E141C3C),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: const Color(0x26FFFFFF), width: 0.9),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  color: _cyan, size: 11),
                              SizedBox(width: 4),
                              Text(
                                '12:45:10',
                                style: TextStyle(
                                  color: _cyan,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // شبكة مهام 2×2 — كل مهمة بطاقة مستقلة بحلقة
                  // تقدّم وشارة مكافأة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.02,
                      children: [
                        _buildQuestCard(
                          index: 0,
                          title: 'العب 3 مباريات شطرنج اليوم'.tr,
                          progress: '2 / 3',
                          progressRatio: 2 / 3,
                          reward: 300,
                          icon: Icons.castle_rounded,
                          color: AppColors.chessGlow,
                        ),
                        _buildQuestCard(
                          index: 1,
                          title: 'حقق الفوز في مباراة دومينو'.tr,
                          progress: '1 / 1',
                          progressRatio: 1.0,
                          reward: 500,
                          icon: Icons.grid_on_rounded,
                          color: AppColors.dominoGlow,
                        ),
                        _buildQuestCard(
                          index: 2,
                          title: 'رتب أوراقك وفز في سوليتر'.tr,
                          progress: '0 / 1',
                          progressRatio: 0.0,
                          reward: 250,
                          icon: Icons.style_rounded,
                          color: AppColors.solitaireGlow,
                        ),
                        _buildQuestCard(
                          index: 3,
                          title: 'تحدى صديقاً في طاولي (Backgammon)'.tr,
                          progress: '0 / 1',
                          progressRatio: 0.0,
                          reward: 400,
                          icon: Icons.table_restaurant_rounded,
                          color: AppColors.backgammonGlow,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ═══ كؤوس التميز ═══
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              _gold.withOpacity(0.8),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'كؤوس التميز الملكية'.tr,
                          style: TextStyle(
                            color: _textWhite,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    height: 132,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildTrophyBadge('تاج الدومينو الذهبي'.tr,
                            'فز بـ 50 مباراة دومينو'.tr, '🏆', _gold),
                        _buildTrophyBadge(
                            'فارس الشطرنج'.tr,
                            'اهزم 20 منافساً'.tr,
                            '♟️',
                            const Color(0xFF94A3B8)),
                        _buildTrophyBadge('ساحر السوليتر'.tr,
                            'أنهِ اللعبة بأقل من دقيقتين'.tr, '🃏', _emerald),
                        _buildTrophyBadge('أسطورة الطاولي'.tr,
                            'ارمِ الدوشيش 10 مرات'.tr, '🎲', _cyan),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقة مهمة في الشبكة — أيقونة اللعبة + حلقة تقدّم دائرية +
  /// زر الاستلام أسفلها. المهمة المكتملة تتوهج ذهبياً
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(isDone && !isClaimed ? 0.20 : 0.10),
                const Color(0xFF101838).withOpacity(0.55),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDone && !isClaimed ? _gold : color.withOpacity(0.30),
              width: isDone && !isClaimed ? 1.5 : 1,
            ),
            boxShadow: isDone && !isClaimed
                ? [
                    BoxShadow(color: _gold.withOpacity(0.22), blurRadius: 14),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // أيقونة اللعبة في مربع متوهج
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: color.withOpacity(0.45), width: 1),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.22), blurRadius: 8),
                      ],
                    ),
                    child: Icon(icon, color: color, size: 17),
                  ),
                  const Spacer(),
                  // حلقة التقدّم
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CustomPaint(
                      painter: _RingProgressPainter(
                          progress: progressRatio,
                          color: isDone ? _emerald : color),
                      child: Center(
                        child: Text(
                          progress.replaceAll(' ', ''),
                          style: TextStyle(
                            color: isDone ? _emerald : _textWhite,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textWhite,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              // زر المكافأة بعرض البطاقة
              GestureDetector(
                onTap: () {
                  if (isDone) {
                    _claimMission(index, title, reward);
                  } else {
                    AppHaptics.light();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                  decoration: BoxDecoration(
                    gradient: isDone && !isClaimed
                        ? const LinearGradient(colors: [
                            Color(0xFFFFE082),
                            _gold,
                            Color(0xFFE8A820),
                          ])
                        : null,
                    color: isClaimed
                        ? _emerald.withOpacity(0.15)
                        : (isDone ? null : const Color(0x1FFFFFFF)),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isDone && !isClaimed
                          ? const Color(0xFFFFE9A8)
                          : (isClaimed
                              ? _emerald.withOpacity(0.6)
                              : const Color(0x1AFFFFFF)),
                      width: 1,
                    ),
                    boxShadow: isDone && !isClaimed
                        ? [
                            BoxShadow(
                                color: _gold.withOpacity(0.4), blurRadius: 10),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: isClaimed
                          ? Text(
                              'تم الاستلام ✔'.tr,
                              style: const TextStyle(
                                  color: _emerald,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800),
                            )
                          : (isDone
                              ? Text(
                                  'استلام 💰'.tr,
                                  style: const TextStyle(
                                      color: Color(0xFF1B0B30),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900),
                                )
                              : Text(
                                  '+${formatBalance(reward)} 💰',
                                  style: const TextStyle(
                                      color: _gold,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800),
                                )),
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

  Widget _buildTrophyBadge(
      String title, String desc, String emoji, Color glowColor) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(left: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1B2A5E).withOpacity(0.45),
                const Color(0xFF101838).withOpacity(0.35),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: glowColor.withOpacity(0.45), width: 1.1),
            boxShadow: [
              BoxShadow(
                  color: glowColor.withOpacity(0.15),
                  blurRadius: 14,
                  spreadRadius: -2),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ميدالية بحلقتين — دائرة خارجية متوهجة + نواة داكنة
              Container(
                width: 56,
                height: 56,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: glowColor.withOpacity(0.5), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: glowColor.withOpacity(0.25), blurRadius: 14),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      glowColor.withOpacity(0.35),
                      const Color(0xFF0A1230),
                    ]),
                    border: Border.all(
                        color: glowColor.withOpacity(0.7), width: 1.4),
                  ),
                  child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 23))),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _textWhite,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textDim, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// حلقة تقدّم دائرية رفيعة — مسار داكن + قوس ملوّن متوهج
class _RingProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x1FFFFFFF),
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1.2),
      );
    }
  }

  @override
  bool shouldRepaint(_RingProgressPainter old) =>
      old.progress != progress || old.color != color;
}

class _AchievementsDecorPainter extends CustomPainter {
  const _AchievementsDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color color, double o) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [color.withOpacity(o), Colors.transparent],
            ).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    glow(Offset(size.width * 0.15, size.height * 0.04), size.width * 0.5,
        const Color(0xFF2540A0), 0.28);
    glow(Offset(size.width * 0.9, size.height * 0.45), size.width * 0.45,
        const Color(0xFF7C5CFF), 0.13);
    glow(Offset(size.width * 0.5, size.height * 1.05), size.width * 0.65,
        const Color(0xFF8A6400), 0.15);

    // أقواس هندسية ذهبية شفافة في الأسفل
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      arcPaint.color = const Color(0xFFFFD54F).withOpacity(0.04 + i * 0.013);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 1.15),
          width: size.width * (0.9 + i * 0.35),
          height: size.height * (0.35 + i * 0.14),
        ),
        3.6,
        5.0,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_AchievementsDecorPainter oldDelegate) => false;
}
