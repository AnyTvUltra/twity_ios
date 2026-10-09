import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../games/okey/okey_rules.dart';
import '../services/auth_service.dart';
import '../services/okey_room_service.dart';
import '../services/social_service.dart';
import '../services/voice_service.dart';
import '../utils/format.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/gem_icon.dart';
import '../widgets/radio_player_widget.dart';
import 'okey_game_screen.dart';
import 'store_screen.dart';
import '../l10n/app_lang.dart';

class OkeyLobbyScreen extends StatefulWidget {
  final OkeyRules rules;
  OkeyLobbyScreen({super.key, OkeyRules? rules})
      : rules = rules ?? OkeyRules.turkish;

  @override
  State<OkeyLobbyScreen> createState() => _OkeyLobbyScreenState();
}

class _OkeyLobbyScreenState extends State<OkeyLobbyScreen>
    with SingleTickerProviderStateMixin {
  int _selectedStakes = 50;
  bool _isSearching = false;

  /// زوجي: اللاعب المقابل شريك (فوزه فوزك)
  bool _teamMode = false;
  bool _ctaPressed = false;
  OkeyRoom? _currentRoom;
  StreamSubscription<OkeyRoom>? _roomSub;
  late final AnimationController _ctaGlow;

  /// غرفة جارية أنا عضو فيها — لافتة «عودة للجولة» بعد انقطاع
  OkeyRoom? _activeRoom;

  // ═══ لوحة الألوان: Deep Navy + Electric Blue + Gold ═══
  static const _bgTop = Color(0xFF0A0F24);
  static const _bgMid = Color(0xFF070B18);
  static const _bgBot = Color(0xFF04060F);
  static const _neonBlue = Color(0xFF3B82F6);
  static const _cyan = Color(0xFF38BDF8);
  static const _gold = Color(0xFFFFD54F);
  static const _goldDeep = Color(0xFFB8860B);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  final List<Map<String, dynamic>> _stakeTiers = [
    {
      'stakes': 50,
      'pot': 200,
      'title': 'طاولة المبتدئين'.tr,
      'medal': '🥉',
      'color': const Color(0xFFCD8B5A),
      'glow': const Color(0xFF10B981),
    },
    {
      'stakes': 200,
      'pot': 800,
      'title': 'طاولة المحترفين'.tr,
      'medal': '🥈',
      'color': const Color(0xFF9FB8D8),
      'glow': const Color(0xFF3B82F6),
    },
    {
      'stakes': 1000,
      'pot': 4000,
      'title': 'طاولة كبار الشخصيات VIP'.tr,
      'medal': '👑',
      'color': const Color(0xFFFFD54F),
      'glow': const Color(0xFFFFB300),
    },
  ];

  @override
  void initState() {
    super.initState();
    _ctaGlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.6,
      upperBound: 1.0,
    )..repeat(reverse: true);
    _checkActiveRoom();
  }

  /// هل أنا عضو في غرفة جارية؟ — بعد انقطاع/إعادة فتح يظهر
  /// زر العودة فينقلني مباشرة إلى مقعدي
  Future<void> _checkActiveRoom() async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    final room = await OkeyRoomService().findMyActiveRoom(uid);
    if (mounted && room != null && _currentRoom == null) {
      setState(() => _activeRoom = room);
    }
  }

  /// العودة إلى جولتي الجارية بعد انقطاع
  void _rejoinActiveRoom() {
    final room = _activeRoom;
    if (room == null) return;
    AppHaptics.medium();
    VoiceService().joinRoomVoice(room.id);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => OkeyGameScreen(
        rules: OkeyRules.fromId(room.variant),
        teamMode: _teamMode,
        roomId: room.id,
      ),
    ));
  }

  Future<void> _handleQuickMatch() async {
    final user = AuthService().currentUser;
    if (user == null) {
      TopNotification.show(context, 'يرجى تسجيل الدخول أولاً!'.tr,
          icon: Icons.lock_rounded);
      return;
    }

    if (user.chips < _selectedStakes) {
      TopNotification.show(
          context,
          'رصيدك غير كافٍ لدخول هذه الطاولة! تحتاج {} عملة'
              .trp([_selectedStakes]),
          icon: Icons.warning_rounded);
      return;
    }

    AppHaptics.medium();
    setState(() => _isSearching = true);

    final room = await OkeyRoomService().quickMatch(
        stakes: _selectedStakes, user: user, variant: widget.rules.id);
    setState(() => _isSearching = false);

    if (room != null) {
      setState(() => _currentRoom = room);
      _listenToRoom(room.id);
    } else {
      if (mounted) {
        TopNotification.show(context, 'تعذر الدخول للطاولة، حاول مرة أخرى'.tr,
            icon: Icons.error_outline_rounded);
      }
    }
  }

  void _listenToRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = OkeyRoomService().getRoomStream(roomId).listen((room) {
      setState(() => _currentRoom = room);

      if (room.status == 'playing' && mounted) {
        // Start voice chat room connection
        VoiceService().joinRoomVoice(room.id);

        _roomSub?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => OkeyGameScreen(
                  rules: OkeyRules.fromId(_currentRoom?.variant),
                  teamMode: _teamMode,
                  roomId: room.id)),
        );
      }
    },
        // تدفق الغرفة بلا معالج خطأ — رفض القواعد أو انقطاع
        // الشبكة كان يقتل التطبيق؛ الآن يُسجَّل ويبقى اللوبي حياً
        onError: (Object e) =>
            debugPrint('roomStream error (permissions?): $e'));
  }

  Future<void> _startWithBotsNow() async {
    if (_currentRoom == null) return;
    AppHaptics.medium();
    await OkeyRoomService()
        .fillWithBotsAndStart(_currentRoom!.id, _currentRoom!.stakes);
  }

  /// نافذة ملء مقعد فارغ: إضافة روبوت أو دعوة صديق
  void _showSeatInviteSheet(OkeyRoom room) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SeatInviteSheet(room: room),
    );
  }

  @override
  void dispose() {
    _ctaGlow.dispose();
    _roomSub?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  البناء الرئيسي
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBot,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LobbyBackdrop(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _currentRoom == null
                      ? _buildTableSelection()
                      : _buildWaitingRoom(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══ الهيدر الزجاجي ═══
  Widget _buildHeader() {
    final user = AuthService().currentUser;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      child: Row(
        children: [
          _glassIcon(Icons.arrow_back_ios_new_rounded, _textDim,
              () => Navigator.of(context).pop()),
          const SizedBox(width: 8),
          // رصيد اللاعب: عملات + جواهر داخل كبسولة زجاجية واحدة
          _glassCapsule(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  formatBalance(user?.chips ?? 0),
                  style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5),
                ),
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  color: const Color(0x33FFFFFF),
                ),
                const GemIcon(size: 13),
                const SizedBox(width: 4),
                Text(
                  formatBalance(user?.gems ?? 0),
                  style: const TextStyle(
                      color: _cyan,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _glassIcon(Icons.storefront_rounded, _neonBlue, () {
            AppHaptics.selection();
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const StoreScreen()));
          }),
          const SizedBox(width: 6),
          _glassIcon(
              Icons.radio_rounded, _gold, () => RadioPlayerSheet.show(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'صالات تركيش أوكي أونلاين 🀄'.tr,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                  color: _textWhite,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCapsule({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x3A16204A),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0x33FFFFFF), width: 1),
            boxShadow: [
              BoxShadow(
                  color: _neonBlue.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x26FFFFFF), width: 1),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
  }

  // ═══ محتوى اختيار الطاولة ═══
  Widget _buildTableSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // لافتة العودة: لديّ جولة جارية بعد انقطاع — زر مباشر لمقعدي
          if (_activeRoom != null) ...[
            _buildReturnBanner(),
            const SizedBox(height: 14),
          ],
          _buildTournamentBanner(),
          const SizedBox(height: 20),

          // عنوان اختيار الطاولة مع خطّي Glow جانبيين
          Row(
            children: [
              Expanded(child: _sideGlowLine(reverse: true)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'اختر الطاولة:'.tr,
                  style: TextStyle(
                      color: _textWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .4),
                ),
              ),
              Expanded(child: _sideGlowLine()),
            ],
          ),
          const SizedBox(height: 14),

          ..._stakeTiers.map(_buildTierCard),

          const SizedBox(height: 16),
          _buildModeSelector(),
          const SizedBox(height: 16),
          _buildJoinButton(),
          const SizedBox(height: 14),
          // الغرف الخاصة: أنشئ بكود أو انضم بكود صديقك
          Row(
            children: [
              Expanded(child: _buildPrivateCreateCard()),
              const SizedBox(width: 10),
              Expanded(child: _buildJoinByCodeCard()),
            ],
          ),
          const SizedBox(height: 14),
          _buildTrainingCard(),
        ],
      ),
    );
  }

  /// بطاقة حجرة التدريب — جولة تعليمية ضد بوتات سهلة بتلميحات حية،
  /// بلا رهان ولا نقاط: للمبتدئين ومن يريد الإحماء قبل اللعب الحقيقي
  Widget _buildTrainingCard() {
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OkeyGameScreen(
              rules: widget.rules,
              teamMode: false,
              trainingMode: true,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x331E5B8C), Color(0x2A142A4E)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF38BDF8).withOpacity(0.5), width: 1.1),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.14),
                    blurRadius: 16,
                    spreadRadius: -4),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                        colors: [Color(0x4038BDF8), Colors.transparent]),
                    border: Border.all(
                        color: const Color(0xFF38BDF8).withOpacity(0.4)),
                  ),
                  child: const Center(
                      child: Text('🎓', style: TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حجرة التدريب'.tr,
                          style: TextStyle(
                              color: _textWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        'تعلّم اللعب ببوتات سهلة وتلميحات حية — بلا رهان'.tr,
                        style: const TextStyle(color: _textDim, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF38BDF8), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// لافتة «عودة للجولة» — أنا عضو في غرفة جارية (عدت من انقطاع)
  Widget _buildReturnBanner() {
    final room = _activeRoom!;
    return GestureDetector(
      onTap: _rejoinActiveRoom,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0x402E7D32), Color(0x2A0F3D1B)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: const Color(0xFF4ADE80).withOpacity(0.55), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF4ADE80).withOpacity(0.16),
                    blurRadius: 18,
                    spreadRadius: -4),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                        colors: [Color(0x404ADE80), Colors.transparent]),
                    border: Border.all(
                        color: const Color(0xFF4ADE80).withOpacity(0.4)),
                  ),
                  child: const Center(
                      child: Text('🔄', style: TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('لديك جولة جارية!'.tr,
                          style: TextStyle(
                              color: _textWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        'الرهان {} 🪙 — اضغط للعودة إلى مقعدك'
                            .trp([room.stakes]),
                        style: const TextStyle(color: _textDim, fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill_rounded,
                    color: Color(0xFF4ADE80), size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بطاقة «غرفة خاصة» — أنشئ غرفة بكود تشاركه مع أصدقائك
  Widget _buildPrivateCreateCard() {
    return _lobbyMiniCard(
      icon: '🔑',
      title: 'غرفة خاصة'.tr,
      subtitle: 'كود لأصدقائك'.tr,
      accent: const Color(0xFFFBBF24),
      onTap: _createPrivateRoom,
    );
  }

  /// بطاقة «انضم بكود» — أدخل كود غرفة صديقك
  Widget _buildJoinByCodeCard() {
    return _lobbyMiniCard(
      icon: '🎟️',
      title: 'انضم بكود'.tr,
      subtitle: 'أدخل كود الغرفة'.tr,
      accent: const Color(0xFF38BDF8),
      onTap: _showJoinByCodeDialog,
    );
  }

  Widget _lobbyMiniCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withOpacity(0.45), width: 1.1),
              boxShadow: [
                BoxShadow(
                    color: accent.withOpacity(0.12),
                    blurRadius: 16,
                    spreadRadius: -4),
              ],
            ),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: _textWhite,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style:
                              const TextStyle(color: _textDim, fontSize: 9.5)),
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

  /// إنشاء غرفة خاصة بالرهان المحدد — ثم تظهر شاشة الانتظار
  /// بكودها الكبير القابل للنسخ ليشاركه المضيف مع أصدقائه
  Future<void> _createPrivateRoom() async {
    final user = AuthService().currentUser;
    if (user == null) {
      TopNotification.show(context, 'يرجى تسجيل الدخول أولاً!'.tr,
          icon: Icons.lock_rounded);
      return;
    }
    if (user.chips < _selectedStakes) {
      TopNotification.show(context,
          'رصيدك غير كافٍ لهذه الطاولة! تحتاج {} عملة'.trp([_selectedStakes]),
          icon: Icons.warning_rounded);
      return;
    }
    AppHaptics.medium();
    setState(() => _isSearching = true);
    final room = await OkeyRoomService().createPrivateRoom(
        stakes: _selectedStakes, user: user, variant: widget.rules.id);
    setState(() => _isSearching = false);
    if (room != null) {
      setState(() => _currentRoom = room);
      _listenToRoom(room.id);
    } else if (mounted) {
      TopNotification.show(context, 'تعذر إنشاء الغرفة — حاول مجدداً'.tr,
          icon: Icons.error_outline_rounded);
    }
  }

  /// نافذة إدخال كود الغرفة — 6 خانات كبيرة، تنضم فور التحقق
  void _showJoinByCodeDialog() {
    AppHaptics.selection();
    final ctrl = TextEditingController();
    var busy = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF141B33),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0x40FFD54F))),
          title: Text('انضم بكود الغرفة'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('أدخل الكود الذي شاركه صديقك (6 خانات)'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF8EA3C8), fontSize: 11.5)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                textAlign: TextAlign.center,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: const TextStyle(
                      color: Color(0x40FFD54F), letterSpacing: 8),
                  filled: true,
                  fillColor: const Color(0x40000000),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('إلغاء'.tr,
                  style: const TextStyle(color: Color(0xFF8EA3C8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: busy
                  ? null
                  : () async {
                      final code = ctrl.text.trim().toUpperCase();
                      if (code.length != 6) return;
                      setDlg(() => busy = true);
                      final user = AuthService().currentUser;
                      if (user == null) {
                        Navigator.of(ctx).pop();
                        return;
                      }
                      final res =
                          await OkeyRoomService().joinRoomByCode(code, user);
                      setDlg(() => busy = false);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (res.room != null) {
                        setState(() => _currentRoom = res.room);
                        _listenToRoom(res.room!.id);
                      } else {
                        TopNotification.show(context, res.error,
                            icon: Icons.error_outline_rounded);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('انضم'.tr,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  /// نوع اللعبة: فردي (كل لاعب لنفسه) أو زوجي (اللاعب المقابل شريكك)
  Widget _buildModeSelector() {
    Widget option(bool team, String icon, String title, String sub) {
      final selected = _teamMode == team;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            AppHaptics.selection();
            setState(() => _teamMode = team);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: selected
                  ? _neonBlue.withOpacity(0.16)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? _neonBlue.withOpacity(0.8)
                    : Colors.white.withOpacity(0.12),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(title,
                    style: TextStyle(
                        color: selected ? _textWhite : _textDim,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _textDim, fontSize: 10)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(false, '👤', 'فردي'.tr, 'كل لاعب لنفسه'.tr),
        const SizedBox(width: 10),
        option(true, '🤝', 'زوجي'.tr, 'اللاعب المقابل شريكك'.tr),
      ],
    );
  }

  Widget _sideGlowLine({bool reverse = false}) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
          end: reverse ? Alignment.centerLeft : Alignment.centerRight,
          colors: [Colors.transparent, _neonBlue.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(color: _neonBlue.withOpacity(0.5), blurRadius: 8),
        ],
      ),
    );
  }

  // ═══ بطاقة البطولة ═══
  Widget _buildTournamentBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0x401B2A5E),
                const Color(0x2A101838),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x40FFD54F), width: 1.1),
            boxShadow: [
              BoxShadow(
                  color: _gold.withOpacity(0.12),
                  blurRadius: 24,
                  spreadRadius: -4),
              BoxShadow(
                  color: _neonBlue.withOpacity(0.14),
                  blurRadius: 30,
                  spreadRadius: -6,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0x40FFD54F), Colors.transparent],
                  ),
                  boxShadow: [
                    BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 22),
                  ],
                ),
                child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 38))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تنافس حقيقي مع 4 لاعبين'.tr,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                          color: _textWhite,
                          fontSize: 15,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'اختر قيمة الرهان، وانضم لطاولة نشطة مع دردشة صوتية وراديو مباشر!'
                          .tr,
                      textAlign: TextAlign.start,
                      style:
                          TextStyle(color: _textDim, fontSize: 11, height: 1.4),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _cyan.withOpacity(0.4), width: 0.9),
                      ),
                      child: Text(
                        '{} {} — افتتاح {}'.trp([
                          widget.rules.icon,
                          widget.rules.name,
                          widget.rules.openingPoints
                        ]),
                        style: const TextStyle(
                            color: _cyan,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══ بطاقة طاولة ═══
  Widget _buildTierCard(Map<String, dynamic> tier) {
    final stakes = tier['stakes'] as int;
    final pot = tier['pot'] as int;
    final isVip = stakes == 1000;
    final isSelected = _selectedStakes == stakes;
    final accent = isVip ? _gold : _neonBlue;
    final medalColor = tier['color'] as Color;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        setState(() => _selectedStakes = stakes);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [
                          accent.withOpacity(0.55),
                          const Color(0xFF14286B).withOpacity(0.85),
                        ]
                      : [
                          const Color(0x2E141C3C),
                          const Color(0x1E0C1230),
                        ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isSelected ? accent : const Color(0x2EFFFFFF),
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                        color: accent.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: -2),
                  if (isVip && !isSelected)
                    BoxShadow(
                        color: _gold.withOpacity(0.10),
                        blurRadius: 18,
                        spreadRadius: -4),
                ],
              ),
              child: Row(
                children: [
                  // دائرة سعر الدخول المضيئة — يمين البطاقة (أول عنصر RTL)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withOpacity(isSelected ? 0.6 : 0.32),
                          const Color(0xFF0A1230),
                        ],
                        center: const Alignment(0, -0.35),
                        radius: 1.1,
                      ),
                      border: Border.all(
                        color: accent.withOpacity(isSelected ? 1.0 : 0.6),
                        width: 1.7,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withOpacity(isSelected ? 0.55 : 0.3),
                            blurRadius: isSelected ? 20 : 12),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$stakes',
                        style: TextStyle(
                          color: isVip
                              ? _gold
                              : (isSelected ? Colors.white : medalColor),
                          fontWeight: FontWeight.w900,
                          fontSize: stakes >= 1000 ? 13 : 16.5,
                          shadows: [
                            Shadow(
                                color: accent.withOpacity(0.9), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // الاسم + الميدالية + الجائزة — في المنتصف
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tier['medal'],
                                style: const TextStyle(fontSize: 17)),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                tier['title'],
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? _textWhite
                                      : const Color(0xFFDDE6F8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'الجائزة الإجمالية للفائز: {} عملة ذهبية'
                                    .trp([formatBalance(pot)]),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // دائرة الاختيار — يسار البطاقة (آخر عنصر RTL)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? accent : const Color(0x55FFFFFF),
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: accent.withOpacity(0.6),
                                  blurRadius: 10)
                            ]
                          : null,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? accent : Colors.transparent,
                        ),
                      ),
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

  // ═══ زر الدخول الذهبي ═══
  Widget _buildJoinButton() {
    return AnimatedBuilder(
      animation: _ctaGlow,
      builder: (context, child) {
        final glow = _ctaGlow.value;
        return GestureDetector(
          onTapDown: (_) => setState(() => _ctaPressed = true),
          onTapCancel: () => setState(() => _ctaPressed = false),
          onTapUp: (_) => setState(() => _ctaPressed = false),
          onTap: _isSearching ? null : _handleQuickMatch,
          child: AnimatedScale(
            scale: _ctaPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFE082),
                        _gold,
                        Color(0xFFE8A820),
                        _goldDeep,
                      ],
                      stops: [0.0, 0.35, 0.75, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: const Color(0xFFFFE9A8), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                          color: _gold.withOpacity(0.45 * glow),
                          blurRadius: 26 * glow,
                          spreadRadius: -2),
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // انعكاس زجاجي علوي
                      Positioned(
                        top: 0,
                        left: 24,
                        right: 24,
                        height: 14,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.55),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      _isSearching
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Color(0xFF1B0B30))),
                                SizedBox(width: 10),
                                Text('جاري البحث عن طاولة...'.tr,
                                    style: TextStyle(
                                        color: Color(0xFF1B0B30),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('🀄', style: TextStyle(fontSize: 20)),
                                SizedBox(width: 10),
                                Text(
                                  'دخول الطاولة وبدء التحدي'.tr,
                                  style: TextStyle(
                                      color: Color(0xFF1B0B30),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16.5,
                                      letterSpacing: .2),
                                ),
                                SizedBox(width: 10),
                                Icon(Icons.play_arrow_rounded,
                                    color: Color(0xFF1B0B30), size: 24),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══ غرفة الانتظار ═══
  Widget _buildWaitingRoom() {
    final room = _currentRoom!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x2E16204A),
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: const Color(0x40FFD54F), width: 1.1),
                  boxShadow: [
                    BoxShadow(
                        color: _gold.withOpacity(0.1),
                        blurRadius: 18,
                        spreadRadius: -4),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                        room.isPrivate
                            ? 'غرفة خاصة 🔑'.tr
                            : 'غرفة الانتظار 🪑'.tr,
                        style: TextStyle(
                            color: _textWhite,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                        'قيمة الرهان: {} 🪙 • الجائزة: {} 💰'
                            .trp([room.stakes, room.stakes * 4]),
                        style: const TextStyle(color: _gold, fontSize: 13)),
                    // كود الغرفة الخاصة — كبير وقابل للنسخ لمشاركته
                    if (room.isPrivate && room.code.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          AppHaptics.selection();
                          Clipboard.setData(ClipboardData(text: room.code));
                          TopNotification.show(
                              context, 'نُسخ الكود — شاركه مع أصدقائك'.tr,
                              icon: Icons.copy_rounded);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0x40000000),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _gold.withOpacity(0.5), width: 1.1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                room.code,
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 6),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.copy_rounded,
                                  color: _gold, size: 17),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('اضغط الكود لنسخه — أصدقاؤك ينضمّون به'.tr,
                          style:
                              const TextStyle(color: _textDim, fontSize: 9.5)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4 مقاعد
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                final player =
                    index < room.players.length ? room.players[index] : null;

                final seat = ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: player != null
                            ? const Color(0x2E1B2A5E)
                            : const Color(0x180E1430),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: player != null
                              ? _neonBlue.withOpacity(0.7)
                              : const Color(0x1EFFFFFF),
                          width: player != null ? 1.4 : 1,
                        ),
                        boxShadow: player != null
                            ? [
                                BoxShadow(
                                    color: _neonBlue.withOpacity(0.15),
                                    blurRadius: 14,
                                    spreadRadius: -4),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: player != null
                                  ? const Color(0x331B2A5E)
                                  : const Color(0x14000000),
                              border: Border.all(
                                color: player != null
                                    ? _neonBlue.withOpacity(0.5)
                                    : const Color(0x1EFFFFFF),
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                player != null
                                    ? Icons.person
                                    : Icons.chair_rounded,
                                color: player != null
                                    ? _cyan
                                    : _textDim.withOpacity(0.5),
                                size: 26,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            player != null ? player.name : 'مقعد فارغ'.tr,
                            style: TextStyle(
                              color: player != null
                                  ? _textWhite
                                  : _textDim.withOpacity(0.6),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (player != null)
                            Text(
                              player.isBot
                                  ? 'روبوت ذكي 🤖'.tr
                                  : 'لاعب حقيقي 🟢'.tr,
                              style: TextStyle(
                                  color: player.isBot
                                      ? _textDim
                                      : const Color(0xFF4ADE80),
                                  fontSize: 10),
                            ),
                          // زر + صغير على المقعد الفارغ
                          if (player == null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF34D399).withOpacity(0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: const Color(0xFF34D399)
                                        .withOpacity(0.55)),
                              ),
                              child: Text('+ دعوة / روبوت'.tr,
                                  style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );

                if (player != null) return seat;
                return GestureDetector(
                  onTap: () => _showSeatInviteSheet(room),
                  child: seat,
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // زر البدء الفوري مع الروبوتات — للمضيف فقط (قواعد
          // Firestore تمنع غيره من تغيير status على أي حال)
          if (room.hostUid == AuthService().currentUser?.uid)
            GestureDetector(
              onTap: _startWithBotsNow,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF34D399), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFF6EE7B7), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: -4),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'بدء اللعبة فوراً (ملء المقاعد بروبوتات)'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              height: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // ضيف ينتظر بدء المضيف — القواعد تمنعه من تغيير status
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.white.withOpacity(0.14), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF34D399))),
                  const SizedBox(width: 10),
                  Text('بانتظار المضيف لبدء اللعبة…'.tr,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// خلفية اللوبي: Deep Navy + توهجات + زخارف هندسية شفافة
class _LobbyBackdrop extends StatelessWidget {
  const _LobbyBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _OkeyLobbyScreenState._bgTop,
            _OkeyLobbyScreenState._bgMid,
            _OkeyLobbyScreenState._bgBot,
          ],
        ),
      ),
      child: CustomPaint(painter: _LobbyDecorPainter()),
    );
  }
}

class _LobbyDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // توهج أزرق علوي يسار
    _glow(canvas, Offset(size.width * 0.15, size.height * 0.08),
        size.width * 0.55, const Color(0xFF2540A0), 0.30);
    // توهج نيلي يمين وسط
    _glow(canvas, Offset(size.width * 0.9, size.height * 0.35),
        size.width * 0.5, const Color(0xFF1E3A8A), 0.22);
    // توهج ذهبي خافت أسفل
    _glow(canvas, Offset(size.width * 0.3, size.height * 0.98),
        size.width * 0.6, const Color(0xFF8A6400), 0.14);

    // زخارف: أقواس هندسية شفافة أسفل الشاشة (مثل المرجع)
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      arcPaint.color = const Color(0xFFFFD54F).withOpacity(0.05 + i * 0.015);
      final rect = Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 1.12),
        width: size.width * (0.9 + i * 0.35),
        height: size.height * (0.35 + i * 0.14),
      );
      canvas.drawArc(rect, 3.6, 5.0, false, arcPaint);
    }

    // خطوط نيلية شفافة أعلى يمين
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF3B82F6).withOpacity(0.08);
    for (int i = 0; i < 3; i++) {
      final p = Path()
        ..moveTo(size.width * (0.55 + i * 0.15), 0)
        ..quadraticBezierTo(size.width * (0.7 + i * 0.12), size.height * 0.08,
            size.width * (0.95 + i * 0.1), size.height * 0.02);
      canvas.drawPath(p, linePaint);
    }
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color,
      double opacity) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withOpacity(opacity), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_LobbyDecorPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════
// نافذة ملء مقعد فارغ: إضافة روبوت أو دعوة صديق
// ══════════════════════════════════════════════════════════
class _SeatInviteSheet extends StatelessWidget {
  final OkeyRoom room;
  const _SeatInviteSheet({required this.room});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141B36), Color(0xFF0A0F24)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            Text('املأ هذا المقعد'.tr,
                style: const TextStyle(
                    color: Color(0xFFF1F5FF),
                    fontSize: 17,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),

            // إضافة روبوت
            _inviteOption(
              icon: Icons.smart_toy_rounded,
              color: const Color(0xFF8B5CF6),
              title: 'إضافة روبوت ذكي'.tr,
              subtitle: 'ينضم للمقعد فوراً'.tr,
              onTap: () async {
                Navigator.pop(context);
                await OkeyRoomService().addBot(room.id);
              },
            ),
            const SizedBox(height: 10),

            // دعوة صديق — قائمة أصدقاء حية
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF38BDF8).withOpacity(0.25)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(children: [
                    const Icon(Icons.group_add_rounded,
                        color: Color(0xFF38BDF8), size: 20),
                    const SizedBox(width: 8),
                    Text('أرسل دعوة لصديق'.tr,
                        style: const TextStyle(
                            color: Color(0xFFF1F5FF),
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: user == null
                        ? Center(
                            child: Text('سجّل الدخول أولاً'.tr,
                                style:
                                    const TextStyle(color: Color(0xFF8EA3C8))))
                        : StreamBuilder<List<Map<String, dynamic>>>(
                            stream: SocialService().getFriendsStream(user.uid),
                            builder: (context, snap) {
                              final friends = snap.data ?? [];
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2));
                              }
                              if (friends.isEmpty) {
                                return Center(
                                  child: Text(
                                      'لا أصدقاء بعد — أضفهم من الملف الشخصي'
                                          .tr,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Color(0xFF8EA3C8),
                                          fontSize: 12)),
                                );
                              }
                              return ListView.separated(
                                itemCount: friends.length,
                                separatorBuilder: (_, __) => Divider(
                                    color: Colors.white.withOpacity(0.08),
                                    height: 8),
                                itemBuilder: (context, i) {
                                  final f = friends[i];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: const Color(0xFF2A3554),
                                      backgroundImage:
                                          (f['photoUrl'] ?? '').isNotEmpty
                                              ? NetworkImage(f['photoUrl'])
                                              : null,
                                      child: (f['photoUrl'] ?? '').isEmpty
                                          ? const Icon(Icons.person,
                                              size: 16,
                                              color: Color(0xFF8EA3C8))
                                          : null,
                                    ),
                                    title: Text(
                                        f['displayName'] ?? f['username'] ?? '',
                                        style: const TextStyle(
                                            color: Color(0xFFF1F5FF),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text('@${f['username'] ?? ''}',
                                        style: const TextStyle(
                                            color: Color(0xFF8EA3C8),
                                            fontSize: 11)),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF38BDF8)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('دعوة'.tr,
                                          style: const TextStyle(
                                              color: Color(0xFF38BDF8),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800)),
                                    ),
                                    onTap: () => _inviteFriend(context, f),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _inviteFriend(
      BuildContext context, Map<String, dynamic> f) async {
    final me = AuthService().currentUser;
    if (me == null) return;
    Navigator.pop(context);
    await SocialService().sendMessage(
      senderUid: me.uid,
      senderName: me.displayName,
      senderUsername: me.username,
      senderPhoto: me.photoUrl,
      receiverUid: f['uid'] ?? '',
      receiverName: f['displayName'] ?? '',
      receiverUsername: f['username'] ?? '',
      receiverPhoto: f['photoUrl'] ?? '',
      text:
          '🀄 ${'دعوة للعب كونكان! انضم لغرفتي — الرهان'.tr} ${room.stakes} 🪙',
    );
    if (context.mounted) {
      TopNotification.show(
          context,
          'أُرسلت الدعوة إلى {} ✉️'
              .trp([f['displayName'] ?? f['username'] ?? '']),
          icon: Icons.send_rounded);
    }
  }

  Widget _inviteOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFFF1F5FF),
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Color(0xFF8EA3C8), fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.6), size: 14),
          ],
        ),
      ),
    );
  }
}
