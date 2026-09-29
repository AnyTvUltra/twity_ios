import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../utils/format.dart';
import '../services/auth_service.dart';
import '../widgets/daily_rewards_panel.dart';
import '../l10n/app_lang.dart';

import '../theme_mode.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final List<bool> _claimedMissions = [false, true, false, false];

  static final _bgTop = L(0xFF0A0F24);
  static final _bgMid = L(0xFF080C1C);
  static final _bgBot = L(0xFF04060F);
  static final _neonBlue = L(0xFF3B82F6);
  static final _cyan = L(0xFF38BDF8);
  static final _gold = L(0xFFFFD54F);
  static final _emerald = L(0xFF34D399);
  static final _textWhite = L(0xFFF1F5FF);
  static final _textDim = L(0xFF8EA3C8);

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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgMid, _bgBot],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
              child: CustomPaint(painter: _AchievementsDecorPainter())),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══ الهيدر ═══
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                Shadow(color: L(0x33FFFFFF), blurRadius: 10),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              decoration: BoxDecoration(
                                color: L(0x3A16204A),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: _gold.withOpacity(0.5), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                      color: _gold.withOpacity(0.18),
                                      blurRadius: 10),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.emoji_events_rounded,
                                      color: _gold, size: 15),
                                  SizedBox(width: 5),
                                  Text(
                                    '18 / 40',
                                    style: TextStyle(
                                        color: _textWhite,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 8),

                  DailyRewardsPanel(),

                  SizedBox(height: 22),

                  // ═══ المهام اليومية ═══
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
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
                        SizedBox(width: 8),
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
                        SizedBox(width: 8),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: L(0x2E141C3C),
                            borderRadius: BorderRadius.circular(9),
                            border:
                                Border.all(color: L(0x26FFFFFF), width: 0.9),
                          ),
                          child: Row(
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

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
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
                          title: 'حقق الفوز في مباراة لودو'.tr,
                          progress: '1 / 1',
                          progressRatio: 1.0,
                          reward: 500,
                          icon: Icons.casino_rounded,
                          color: AppColors.ludoGlow,
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

                  SizedBox(height: 22),

                  // ═══ كؤوس التميز ═══
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
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
                        SizedBox(width: 8),
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
                  SizedBox(height: 12),

                  SizedBox(
                    height: 132,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildTrophyBadge('تاج اللودو الذهبي'.tr,
                            'فز بـ 50 مباراة لودو'.tr, '🏆', _gold),
                        _buildTrophyBadge('فارس الشطرنج'.tr,
                            'اهزم 20 منافساً'.tr, '♟️', L(0xFF94A3B8)),
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
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: L(0x2E141C3C),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDone && !isClaimed ? _gold : L(0x26FFFFFF),
              width: isDone && !isClaimed ? 1.5 : 1,
            ),
            boxShadow: isDone && !isClaimed
                ? [
                    BoxShadow(color: _gold.withOpacity(0.22), blurRadius: 14),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // أيقونة اللعبة في مربع متوهج
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: color.withOpacity(0.45), width: 1),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.2), blurRadius: 10),
                  ],
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _textWhite,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressRatio,
                              backgroundColor: L(0x2EFFFFFF),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDone ? _emerald : color,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          progress,
                          style: TextStyle(
                            color: isDone ? _emerald : _textDim,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // زر المكافأة
              GestureDetector(
                onTap: () {
                  if (isDone) {
                    _claimMission(index, title, reward);
                  } else {
                    AppHaptics.light();
                  }
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: isDone && !isClaimed
                        ? LinearGradient(colors: [
                            L(0xFFFFE082),
                            _gold,
                            L(0xFFE8A820),
                          ])
                        : null,
                    color: isClaimed
                        ? _emerald.withOpacity(0.15)
                        : (isDone ? null : L(0x2EFFFFFF)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDone && !isClaimed
                          ? L(0xFFFFE9A8)
                          : (isClaimed
                              ? _emerald.withOpacity(0.6)
                              : Colors.transparent),
                      width: 1,
                    ),
                    boxShadow: isDone && !isClaimed
                        ? [
                            BoxShadow(
                                color: _gold.withOpacity(0.4), blurRadius: 10),
                          ]
                        : null,
                  ),
                  child: isClaimed
                      ? Text(
                          'تم الاستلام ✔'.tr,
                          style: TextStyle(
                              color: _emerald,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        )
                      : (isDone
                          ? Text(
                              'استلام 💰'.tr,
                              style: TextStyle(
                                  color: L(0xFF1B0B30),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900),
                            )
                          : Text(
                              '+${formatBalance(reward)} 💰',
                              style: TextStyle(
                                  color: _gold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800),
                            )),
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
          margin: EdgeInsets.only(left: 10),
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                L(0xFF1B2A5E).withOpacity(0.45),
                L(0xFF101838).withOpacity(0.35),
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    glowColor.withOpacity(0.3),
                    L(0xFF0A1230),
                  ]),
                  border:
                      Border.all(color: glowColor.withOpacity(0.6), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: glowColor.withOpacity(0.3), blurRadius: 12),
                  ],
                ),
                child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 21))),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
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
                style: TextStyle(color: _textDim, fontSize: 9),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
        L(0xFF2540A0), 0.28);
    glow(Offset(size.width * 0.9, size.height * 0.45), size.width * 0.45,
        L(0xFF7C5CFF), 0.13);
    glow(Offset(size.width * 0.5, size.height * 1.05), size.width * 0.65,
        L(0xFF8A6400), 0.15);

    // أقواس هندسية ذهبية شفافة في الأسفل
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      arcPaint.color = L(0xFFFFD54F).withOpacity(0.04 + i * 0.013);
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
