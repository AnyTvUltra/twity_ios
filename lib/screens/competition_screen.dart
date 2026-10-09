import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/competition_service.dart';
import '../services/okey_room_service.dart';
import '../services/rewards_service.dart';
import '../services/voice_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/user_avatar.dart';
import '../games/okey/okey_rules.dart';
import 'okey_game_screen.dart';
import '../l10n/app_lang.dart';

/// شاشة التنافس — المتصدرون + البطولات الأسبوعية + الموسم المصنّف.
/// تبويب سفلي خامس في الشاشة الرئيسية.
class CompetitionScreen extends StatefulWidget {
  const CompetitionScreen({super.key});

  @override
  State<CompetitionScreen> createState() => _CompetitionScreenState();
}

class _CompetitionScreenState extends State<CompetitionScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // لوحة الألوان الموحدة مع اللوبي
  static const _bgTop = Color(0xFF0A0F24);
  static const _bgBot = Color(0xFF04060F);
  static const _gold = Color(0xFFFFD54F);
  static const _cyan = Color(0xFF38BDF8);
  static const _green = Color(0xFF4ADE80);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  /// مقطع المتصدرين: أسبوعي / كل الوقت / الموسم
  int _boardSegment = 0;
  String? _seasonId;
  String? _seasonName;
  DateTime? _seasonEnds;
  StreamSubscription? _seasonSub;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _seasonSub = CompetitionService().seasonConfig().listen((cfg) {
      if (!mounted) return;
      setState(() {
        _seasonId = cfg?['id']?.toString();
        _seasonName = cfg?['name']?.toString();
        final e = cfg?['endsAt'];
        _seasonEnds = e is DateTime ? e : (e?.toDate() as DateTime?);
      });
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _seasonSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBot],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildLeaderboardTab(),
                    _buildTournamentsTab(),
                    _buildSeasonTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Text(
            'التنافسية'.tr,
            style: const TextStyle(
                color: _textWhite, fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          // رتبتي — ميدالية رتبي الحالية من نظام Ranks
          AnimatedBuilder(
            animation: AuthService(),
            builder: (_, __) {
              final rank = Ranks.of(AuthService().currentUser?.rating ?? 1200);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x2E16204A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withOpacity(0.4)),
                ),
                child: Text('${rank.emoji} ${rank.name}',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x2E101838),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: _gold.withOpacity(0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _gold.withOpacity(0.5)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: _gold,
        unselectedLabelColor: _textDim,
        labelStyle:
            const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'المتصدرون'.tr),
          Tab(text: 'البطولات'.tr),
          Tab(text: 'الموسم'.tr),
        ],
      ),
    );
  }

  // ═══════════════════ المتصدرون ═══════════════════

  Widget _buildLeaderboardTab() {
    return Column(
      children: [
        const SizedBox(height: 4),
        // مقطع: أسبوعي / كل الوقت
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _segButton(0, 'هذا الأسبوع'.tr, '🔥'),
              const SizedBox(width: 8),
              _segButton(1, 'كل الوقت'.tr, '👑'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _boardSegment == 0
              ? _leaderList(CompetitionService().leaderboardWeekly(), 'wins')
              : _leaderList(
                  CompetitionService().leaderboardAllTime(), 'rating'),
        ),
      ],
    );
  }

  Widget _segButton(int i, String label, String emoji) {
    final sel = _boardSegment == i;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() => _boardSegment = i);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? _cyan.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
                color: sel ? _cyan.withOpacity(0.55) : const Color(0x1EFFFFFF)),
          ),
          child: Text(
            '$emoji $label',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: sel ? _cyan : _textDim,
                fontSize: 12,
                fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Widget _leaderList(Stream<List<LeaderRow>> stream, String metric) {
    final myUid = CompetitionService().myUid;
    return StreamBuilder<List<LeaderRow>>(
      stream: stream,
      builder: (_, snap) {
        final rows = snap.data ?? const <LeaderRow>[];
        if (snap.connectionState == ConnectionState.waiting && rows.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: _gold, strokeWidth: 2));
        }
        if (rows.isEmpty) {
          return Center(
            child: Text('لا نتائج بعد — كن أول المتصدرين! 🎯'.tr,
                style: const TextStyle(color: _textDim, fontSize: 13)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          physics: const BouncingScrollPhysics(),
          itemCount: rows.length,
          itemBuilder: (_, i) =>
              _leaderRow(rows[i], i + 1, metric, rows[i].uid == myUid),
        );
      },
    );
  }

  Widget _leaderRow(LeaderRow r, int rank, String metric, bool isMe) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank';
    final playerRank = Ranks.of(r.rating);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? _gold.withOpacity(0.13) : const Color(0x22101838),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isMe
                ? _gold.withOpacity(0.6)
                : rank <= 3
                    ? _gold.withOpacity(0.3)
                    : const Color(0x18FFFFFF),
            width: isMe ? 1.4 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              medal,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: rank <= 3 ? null : _textDim,
                  fontSize: rank <= 3 ? 20 : 13,
                  fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 6),
          UserAvatar(
              photoUrl: r.photoUrl,
              name: r.name,
              size: 36,
              showEquippedFrame: r.uid == myUid),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isMe ? _gold : _textWhite,
                            fontSize: 13,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (r.isVip) ...[
                      const SizedBox(width: 4),
                      const Text('👑', style: TextStyle(fontSize: 10)),
                    ],
                  ],
                ),
                if (r.title.isNotEmpty)
                  Text(r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFFFE9A8),
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                Text(
                  '${playerRank.emoji} ${playerRank.name} • ${r.wins} ${'فوز'.tr}',
                  style: const TextStyle(color: _textDim, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                metric == 'wins'
                    ? '${r.weeklyWins}'
                    : metric == 'season'
                        ? '${r.seasonRating}'
                        : '${r.rating}',
                style: TextStyle(
                    color: metric == 'wins'
                        ? _green
                        : metric == 'season'
                            ? const Color(0xFFC084FC)
                            : _cyan,
                    fontSize: 16,
                    fontWeight: FontWeight.w900),
              ),
              Text(
                  metric == 'wins'
                      ? 'انتصار'.tr
                      : metric == 'season'
                          ? 'تقييم موسمي'.tr
                          : 'تقييم'.tr,
                  style: const TextStyle(color: _textDim, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  String? get myUid => AuthService().currentUser?.uid;

  // ═══════════════════ البطولات ═══════════════════

  Widget _buildTournamentsTab() {
    return StreamBuilder<List<Tournament>>(
      stream: CompetitionService().tournaments(),
      builder: (_, snap) {
        final ts = snap.data ?? const <Tournament>[];
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _gold, strokeWidth: 2));
        }
        if (ts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 46)),
                const SizedBox(height: 10),
                Text('لا بطولات فعّالة الآن'.tr,
                    style: const TextStyle(
                        color: _textWhite,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('البطولات الأسبوعية تُعلن من الإدارة — تابع الإعلانات'.tr,
                    style: const TextStyle(color: _textDim, fontSize: 11.5)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          physics: const BouncingScrollPhysics(),
          itemCount: ts.length,
          itemBuilder: (_, i) => _tournamentCard(ts[i]),
        );
      },
    );
  }

  String _timeLeftText(Duration d) {
    if (d.inDays > 0) return 'متبقٍ {} يوم'.trp([d.inDays]);
    if (d.inHours > 0) return 'متبقٍ {} ساعة'.trp([d.inHours]);
    return 'متبقٍ {} دقيقة'.trp([d.inMinutes.clamp(0, 999)]);
  }

  Widget _tournamentCard(Tournament t) {
    final uid = myUid;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: t.isLive
                      ? _gold.withOpacity(0.5)
                      : const Color(0x22FFFFFF),
                  width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              style: const TextStyle(
                                  color: _textWhite,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(
                            t.isLive
                                ? '${_timeLeftText(t.timeLeft)} • دخول {} 🪙'
                                    .trp([t.entryFee])
                                : 'انتهت البطولة'.tr,
                            style: const TextStyle(
                                color: _textDim, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    // الجوائز
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < t.prizes.length && i < 3; i++)
                          Text(
                            '${['🥇', '🥈', '🥉'][i]} ${t.prizes[i]}',
                            style: const TextStyle(
                                color: _gold,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ترتيبي + زر اللعب
                if (uid != null)
                  StreamBuilder<StandingRow?>(
                    stream: CompetitionService().myStanding(t.id, uid),
                    builder: (_, s) {
                      final st = s.data;
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              st == null
                                  ? 'لم تلعب بعد — النقاط: فوز=3'.tr
                                  : 'نقاطك: {} • مباريات: {}'
                                      .trp([st.points, st.matches]),
                              style: const TextStyle(
                                  color: _cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (t.isLive)
                            GestureDetector(
                              onTap: () => _joinTournament(t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFF22C55E),
                                    Color(0xFF15803D)
                                  ]),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                        color: _green.withOpacity(0.3),
                                        blurRadius: 10)
                                  ],
                                ),
                                child: Text('العب الآن'.tr,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900)),
                              ),
                            )
                          else
                            _claimPrizeButton(t, uid),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// زر استلام الجائزة — يظهر للفائزين بعد انتهاء البطولة
  Widget _claimPrizeButton(Tournament t, String uid) {
    return StreamBuilder<List<StandingRow>>(
      stream: CompetitionService().standings(t.id, limit: 3),
      builder: (_, s) {
        final rows = s.data ?? const <StandingRow>[];
        final rank = rows.indexWhere((r) => r.uid == uid) + 1;
        if (rank < 1 || rank > 3) return const SizedBox.shrink();
        return StreamBuilder<bool>(
          stream: CompetitionService().prizeClaimed(t.id, uid),
          builder: (_, c) {
            final claimed = c.data ?? false;
            return GestureDetector(
              onTap: claimed
                  ? null
                  : () async {
                      final res = await CompetitionService()
                          .claimTournamentPrize(t, rank);
                      if (!mounted) return;
                      TopNotification.show(
                          context,
                          res.ok
                              ? 'مبروك! استلمت {} عملة 🏆'.trp([res.prize])
                              : 'تعذر الاستلام'.tr,
                          icon: Icons.emoji_events_rounded);
                    },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: claimed
                      ? const Color(0x22FFFFFF)
                      : _gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: claimed
                          ? const Color(0x22FFFFFF)
                          : _gold.withOpacity(0.6)),
                ),
                child: Text(
                  claimed
                      ? 'تم الاستلام ✓'.tr
                      : '${'استلم جائزتك'.tr} ${t.prizes[rank - 1]} 🪙',
                  style: TextStyle(
                      color: claimed ? _textDim : _gold,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// انضمام لمباراة بطولة — غرفة موسومة بالبطولة ثم دخول مباشر
  Future<void> _joinTournament(Tournament t) async {
    final user = AuthService().currentUser;
    if (user == null) return;
    if (user.chips < t.entryFee) {
      TopNotification.show(
          context, 'رصيدك غير كافٍ لدخول البطولة ({} 🪙)'.trp([t.entryFee]),
          icon: Icons.warning_rounded);
      return;
    }
    AppHaptics.medium();
    final room = await CompetitionService().joinTournamentMatch(t, user);
    if (!mounted) return;
    if (room == null) {
      TopNotification.show(context, 'تعذر الانضمام للبطولة'.tr,
          icon: Icons.error_outline_rounded);
      return;
    }
    // نفس مسار الغرفة العادية: استمع للغرفة وانتقل عند البدء
    VoiceService().joinRoomVoice(room.id);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _TournamentWaiting(room: room),
    ));
  }

  // ═══════════════════ الموسم ═══════════════════

  Widget _buildSeasonTab() {
    if (_seasonId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗓️', style: TextStyle(fontSize: 46)),
            const SizedBox(height: 10),
            Text('لا موسم نشطاً حالياً'.tr,
                style: const TextStyle(
                    color: _textWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('المواسم المصنّفة تبدأ بإعلان من الإدارة'.tr,
                style: const TextStyle(color: _textDim, fontSize: 11.5)),
          ],
        ),
      );
    }
    return Column(
      children: [
        // بطاقة الموسم: الاسم + ينتهي خلال + تقييمي
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0x334C1D95), Color(0x2A1E1040)]),
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: const Color(0xFFC084FC).withOpacity(0.45)),
          ),
          child: Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_seasonName ?? 'الموسم الحالي'.tr,
                        style: const TextStyle(
                            color: _textWhite,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      _seasonEnds == null
                          ? 'موسم جارٍ'.tr
                          : _timeLeftText(
                              _seasonEnds!.difference(DateTime.now())),
                      style: const TextStyle(color: _textDim, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${AuthService().currentUser?.seasonRating ?? 1200}',
                    style: const TextStyle(
                        color: Color(0xFFC084FC),
                        fontSize: 17,
                        fontWeight: FontWeight.w900),
                  ),
                  Text('تقييمك الموسمي'.tr,
                      style: const TextStyle(color: _textDim, fontSize: 9)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _leaderList(
              CompetitionService().leaderboardSeason(_seasonId!), 'season'),
        ),
      ],
    );
  }
}

/// شاشة انتظار غرفة البطولة — نفس منطق اللوبي: انتقل للعب عند playing
class _TournamentWaiting extends StatelessWidget {
  final OkeyRoom room;
  const _TournamentWaiting({required this.room});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OkeyRoom>(
      stream: OkeyRoomService().getRoomStream(room.id),
      builder: (ctx, snap) {
        final r = snap.data ?? room;
        if (r.status == 'playing') {
          // الانتقال بعد البناء — ندخل شاشة اللعب مباشرة
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!ctx.mounted) return;
            Navigator.of(ctx).pushReplacement(MaterialPageRoute(
              builder: (_) => OkeyGameScreen(
                  rules: OkeyRules.fromId(r.variant), roomId: r.id),
            ));
          });
        }
        return Scaffold(
          backgroundColor: const Color(0xFF0A0F24),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                    color: Color(0xFFFFD54F), strokeWidth: 2.5),
                const SizedBox(height: 16),
                Text(
                  r.status == 'waiting'
                      ? 'بانتظار اللاعبين… ({}/4)'.trp([r.players.length])
                      : 'تبدأ الجولة…'.tr,
                  style: const TextStyle(
                      color: Color(0xFFF1F5FF),
                      fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('غرفة بطولة — الرهان {} 🪙'.trp([r.stakes]),
                    style: const TextStyle(
                        color: Color(0xFF8EA3C8), fontSize: 11.5)),
                const SizedBox(height: 20),
                // بدء ببوتات إن كان المضيف — نفس قاعدة اللوبي
                if (r.hostUid == AuthService().currentUser?.uid &&
                    r.status == 'waiting')
                  TextButton(
                    onPressed: () =>
                        OkeyRoomService().fillWithBotsAndStart(r.id, r.stakes),
                    child: Text('ابدأ فوراً بروبوتات'.tr,
                        style: const TextStyle(
                            color: Color(0xFF4ADE80),
                            fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
