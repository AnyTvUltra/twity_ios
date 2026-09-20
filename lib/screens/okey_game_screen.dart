import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../games/okey/okey_engine.dart';
import '../games/okey/okey_models.dart';
import '../games/okey/widgets/okey_table_painter.dart';
import '../games/okey/widgets/okey_istaka_widget.dart';
import '../games/okey/widgets/okey_opponent_istaka.dart';
import '../games/okey/widgets/okey_player_badge.dart';
import '../games/okey/widgets/okey_tile_widget.dart';
import '../games/okey/widgets/okey_chat_dialog.dart';
import '../games/okey/widgets/okey_settings_dialog.dart';
import '../games/okey/widgets/okey_win_dialog.dart';
import '../games/okey/utils/okey_audio.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/voice_service.dart';
import '../widgets/radio_player_widget.dart';
import 'package:game_hub/utils/haptics.dart';
import 'package:game_hub/utils/top_notification.dart';


/// شاشة لعبة الأوكي التركية – تصميم بورتريت واقعي بدون تدوير
class OkeyGameScreen extends StatefulWidget {
  const OkeyGameScreen({super.key});

  @override
  State<OkeyGameScreen> createState() => _OkeyGameScreenState();
}

class _OkeyGameScreenState extends State<OkeyGameScreen>
    with TickerProviderStateMixin {
  late OkeyEngine _engine;

  // أنيميشن رمي الحجر بمسار قوسي
  late AnimationController _discardAnimController;
  late Animation<double> _discardCurve;
  OkeyTile? _animatingDiscardTile;

  // أنيميشن سحب حجر جديد
  late AnimationController _drawAnimController;
  late Animation<double> _drawCurve;
  OkeyTile? _animatingDrawTile;

  // دعم النقر المزدوج
  int? _lastTappedSlot;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _engine = OkeyEngine();

    // وضع بورتريت فقط
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _discardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _discardCurve = CurvedAnimation(
      parent: _discardAnimController,
      curve: Curves.easeOutCubic,
    );

    _drawAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _drawCurve = CurvedAnimation(
      parent: _drawAnimController,
      curve: Curves.easeOutCubic,
    );

    _engine.addListener(_onEngineUpdate);
  }

  void _onEngineUpdate() {
    if (_engine.gameState == OkeyGameState.win &&
        _engine.winner != null &&
        mounted) {
      final isHumanWinner = _engine.winner!.isHuman;
      if (isHumanWinner) {
        AuthService().updateMatchResult(chipChange: 200, ratingChange: 25, isWin: true);
      } else {
        AuthService().updateMatchResult(chipChange: -50, ratingChange: -15, isWin: false);
      }
      OkeyAudio.playWin();
      OkeyWinDialog.show(
        context,
        winner: _engine.winner!,
        winType: _engine.winType ?? WinType.normal,
        onPlayAgain: () {
          setState(() {
            _engine.initGame();
          });
        },
      );
    }
  }


  @override
  void dispose() {
    _engine.removeListener(_onEngineUpdate);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _discardAnimController.dispose();
    _drawAnimController.dispose();
    _engine.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  قوائم ونوافذ
  // ─────────────────────────────────────────────

  void _showMoreMenu() {
    AppHaptics.light();
    OkeyAudio.playButtonClick();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF241538), Color(0xFF160B24)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x40FFD54F), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.more_horiz_rounded,
                          color: Color(0xFFFFD54F), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'قائمة الخيارات',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFD54F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Color(0xFFFFD54F), size: 20),
                ),
                title: const Text('قواعد اللعبة',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: const Text('تشكيل المجموعات وحجر الأوكي',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showRulesDialog();
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x224ADE80),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    OkeyAudio.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: const Color(0xFF4ADE80),
                    size: 20,
                  ),
                ),
                title: Text(
                  OkeyAudio.soundEnabled ? 'كتم الصوت' : 'تشغيل الصوت',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  OkeyAudio.soundEnabled
                      ? 'المؤثرات الصوتية مفعلة'
                      : 'المؤثرات الصوتية معطلة',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: () {
                  setState(() => OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled);
                  Navigator.of(ctx).pop();
                  TopNotification.show(
                    context,
                    OkeyAudio.soundEnabled ? 'تم تشغيل الصوت 🔊' : 'تم كتم الصوت 🔇',
                    icon: OkeyAudio.soundEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                  );
                },
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('انسحاب من الجولة (خسارة)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _confirmSurrender();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSurrender() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E112E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text(
              'تأكيد الانسحاب',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ تحذير: إذا قمت بالانسحاب الآن ستفقد رسوم الجولة (35 عملة ذهبية) وتُسجل لك خسارة رسمية في تقييمك السحابي!',
              style: TextStyle(
                  color: Color(0xFFFCA5A5), fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'هل أنت متأكد من رغبتك في الاستسلام ومغادرة الطاولة؟',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('متابعة اللعب',
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeSurrender();
            },
            child: const Text('نعم، تأكيد الانسحاب'),
          ),
        ],
      ),
    );
  }

  void _executeSurrender() {
    AppHaptics.heavy();
    _engine.players[0].chips =
        math.max(0, _engine.players[0].chips - 35);
    _engine.players[0].rating =
        math.max(1000, _engine.players[0].rating - 20);
    FirebaseService().updatePlayerScore(
      playerId: _engine.players[0].id,
      chips: _engine.players[0].chips,
      rating: _engine.players[0].rating,
      isWin: false,
    );
    FirebaseService().logGameResult(
      winnerName: 'الانسحاب (Surrender)',
      winType: 'surrender',
      roundDurationSeconds: 15,
    );
    Navigator.of(context).pop();
    TopNotification.show(context, 'تم الانسحاب من المباراة وخصم 35 عملة',
        icon: Icons.flag_rounded);
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E112E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFFFFD54F), size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text('قواعد لعبة الأوكي (Okey)',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• الهدف: تكوين مجموعات صالحة من 14 حجراً (متتالية من نفس اللون أو متماثلة بألوان مختلفة).',
                style: TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 6),
              Text(
                '• حجر الأوكي الحقيقي (Joker): يعوض عن أي حجر ناقص.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 6),
              Text(
                '• الرمي: ارمِ الحجر الزائد في مربع الرمي الأحمر بالمنتصف.',
                style: TextStyle(
                    color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('حسناً فهمت',
                style: TextStyle(color: Color(0xFFFFD54F))),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  منطق اللعبة
  // ─────────────────────────────────────────────

  void _executeDiscard(int slotIndex) {
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDiscard) {
      TopNotification.show(context, 'يجب سحب حجر أولاً قبل الرمي!');
      return;
    }
    final tile = _engine.players[0].rackTiles[slotIndex];
    if (tile == null) return;

    OkeyAudio.playTileDiscard();
    setState(() => _animatingDiscardTile = tile);

    _discardAnimController.forward(from: 0).then((_) {
      _engine.discardSlot(slotIndex);
      setState(() => _animatingDiscardTile = null);
      _discardAnimController.reset();
    });
  }

  void _executeDraw() {
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDraw) {
      TopNotification.show(context, 'لقد سحبت بالفعل! ارمِ حجراً لإنهاء دورك');
      return;
    }
    if (_engine.drawDeck.isNotEmpty) {
      OkeyAudio.playTileDraw();
      final tile = _engine.drawDeck.first;
      setState(() => _animatingDrawTile = tile);

      _drawAnimController.forward(from: 0).then((_) {
        _engine.drawFromDeck();
        setState(() => _animatingDrawTile = null);
        _drawAnimController.reset();
      });
    }
  }

  void _handleTileTap(int slotIndex) {
    final now = DateTime.now();
    if (_lastTappedSlot == slotIndex &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 350)) {
      if (_engine.currentTurnIndex == 0 &&
          _engine.turnPhase == OkeyTurnPhase.awaitingDiscard) {
        _executeDiscard(slotIndex);
        _lastTappedSlot = null;
        _lastTapTime = null;
        return;
      }
    }
    _lastTappedSlot = slotIndex;
    _lastTapTime = now;
    OkeyAudio.playTilePickup();
    _engine.selectTile(slotIndex);
  }

  // ─────────────────────────────────────────────
  //  بناء الشاشة – بورتريت واقعي
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF070B13),
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _engine,
            builder: (context, _) => _buildPortraitLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;

    final isHumanTurn = _engine.currentTurnIndex == 0;
    final minutes = (_engine.turnTimeRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_engine.turnTimeRemaining % 60).toString().padLeft(2, '0');
    final timerString = '$minutes:$seconds';

    // حجم منطقة الطاولة المربعة في المنتصف
    final tableSize = sw * 0.88;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ══════════════════════════════════════════════
        // 1. خلفية الغرفة
        // ══════════════════════════════════════════════
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0),
              radius: 1.2,
              colors: [Color(0xFF111827), Color(0xFF090D17), Color(0xFF04060B)],
              stops: [0.0, 0.65, 1.0],
            ),
          ),
        ),

        // ══════════════════════════════════════════════
        // 2. شريط علوي: زر المزيد + شارة الخصم العلوي + زر الصوت
        // ══════════════════════════════════════════════
        Positioned(
          top: 6,
          left: 8,
          right: 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // زر المزيد
              GestureDetector(
                onTap: _showMoreMenu,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xEB1A1E29),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0x50FFD54F), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_rounded,
                          color: Color(0xFFFFD54F), size: 15),
                      SizedBox(width: 5),
                      Text('المزيد',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // شارة اللاعب العلوي (الخصم المواجه)
              OkeyPlayerBadge(
                player: _engine.players[2],
                isTurn: _engine.currentTurnIndex == 2,
                type: PlayerBadgeType.top,
              ),
              const Spacer(),
              // أزرار الراديو والمايك والصوت
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زر الراديو الشخصي
                  GestureDetector(
                    onTap: () => RadioPlayerSheet.show(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xEB1A1E29),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x40FFD54F), width: 1),
                      ),
                      child: const Icon(Icons.radio_rounded, color: Color(0xFFFFD54F), size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // زر المايك للتحدث مع الآخرين
                  AnimatedBuilder(
                    animation: VoiceService(),
                    builder: (context, _) {
                      final voice = VoiceService();
                      return GestureDetector(
                        onTap: () async {
                          final on = await voice.toggleMic();
                          TopNotification.show(
                            context,
                            on ? 'تم تشغيل المايك 🎙️ تحدث الآن' : 'تم كتم المايك 🔇',
                            icon: on ? Icons.mic : Icons.mic_off,
                          );
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: voice.isMicOn ? const Color(0xFF10B981) : const Color(0xEB1A1E29),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: voice.isSpeaking ? Colors.white : const Color(0x334B5563),
                              width: voice.isSpeaking ? 2 : 1,
                            ),
                            boxShadow: voice.isSpeaking
                                ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.8), blurRadius: 8, spreadRadius: 1)]
                                : null,
                          ),
                          child: Icon(
                            voice.isMicOn ? Icons.mic : Icons.mic_off,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  // زر الصوت
                  GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() => OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled);
                      TopNotification.show(
                        context,
                        OkeyAudio.soundEnabled ? 'تم تشغيل الصوت 🔊' : 'تم كتم الصوت 🔇',
                        icon: OkeyAudio.soundEnabled ? Icons.volume_up : Icons.volume_off,
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xEB1A1E29),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x334B5563), width: 1),
                      ),
                      child: Icon(
                        OkeyAudio.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        color: OkeyAudio.soundEnabled ? const Color(0xFF4ADE80) : Colors.white60,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),

            ],
          ),
        ),

        // ══════════════════════════════════════════════
        // 3. استكانة الخصم العلوي تحت الشريط العلوي
        // ══════════════════════════════════════════════
        Positioned(
          top: 54,
          left: 0,
          right: 0,
          child: Center(
            child: OkeyOpponentIstaka(
              position: OpponentPosition.top,
              tileCount: _engine.players[2].tileCount,
              isTurn: _engine.currentTurnIndex == 2,
            ),
          ),
        ),

        // ══════════════════════════════════════════════
        // 4. منطقة الطاولة الوسطى (مربعة)
        // ══════════════════════════════════════════════
        Positioned(
          top: sh * 0.17,
          left: (sw - tableSize) / 2,
          child: SizedBox(
            width: tableSize,
            height: tableSize * 0.72,
            child: Stack(
              children: [
                // سطح الطاولة الخشبية
                Positioned.fill(
                  child: CustomPaint(
                    painter: OkeyTablePainter(isHumanTurn: isHumanTurn),
                  ),
                ),

                // الخصم الأيسر داخل الطاولة
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OkeyPlayerBadge(
                          player: _engine.players[3],
                          isTurn: _engine.currentTurnIndex == 3,
                          type: PlayerBadgeType.left,
                        ),
                        const SizedBox(height: 6),
                        OkeyOpponentIstaka(
                          position: OpponentPosition.left,
                          tileCount: _engine.players[3].tileCount,
                          isTurn: _engine.currentTurnIndex == 3,
                        ),
                      ],
                    ),
                  ),
                ),

                // الخصم الأيمن داخل الطاولة
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OkeyPlayerBadge(
                          player: _engine.players[1],
                          isTurn: _engine.currentTurnIndex == 1,
                          type: PlayerBadgeType.right,
                        ),
                        const SizedBox(height: 6),
                        OkeyOpponentIstaka(
                          position: OpponentPosition.right,
                          tileCount: _engine.players[1].tileCount,
                          isTurn: _engine.currentTurnIndex == 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // مركز الطاولة: مؤشر + رمي الأحجار + سحب
                Positioned.fill(
                  child: Center(
                    child: _buildTableCenter(isHumanTurn),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ══════════════════════════════════════════════
        // 4.5. زر إعلان الفوز بالأوكي (Okey Out!) عند اكتمال 14 حجراً متناسقة
        // ══════════════════════════════════════════════
        if (_engine.canDeclareOkeyOut)
          Positioned(
            left: 0,
            right: 0,
            bottom: 128,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  AppHaptics.heavy();
                  OkeyAudio.playWin();
                  _engine.declareHumanWin();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F).withOpacity(0.85),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'إعلان الفوز بالأوكي (Okey Out!) 🎯',
                        style: TextStyle(
                          color: Color(0xFF1B0B30),
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ══════════════════════════════════════════════
        // 5. استكانة اللاعب البشري (الرف السفلي)
        // ══════════════════════════════════════════════
        Positioned(
          left: 0,
          right: 0,
          bottom: 52,
          child: OkeyIstakaWidget(
            rackTiles: _engine.players[0].rackTiles,
            selectedIndex: _engine.selectedTileIndex,
            isTurn: isHumanTurn,
            highlightedIndices: _engine.getHighlightedSlotIndices(),
            onTileTap: _handleTileTap,
            onTileMove: (fromSlot, toSlot) {
              if (_engine.players[0].rackTiles[toSlot] != null) {
                _engine.swapTiles(fromSlot, toSlot);
              } else {
                _engine.moveTile(fromSlot, toSlot);
              }
            },
          ),
        ),


        // ══════════════════════════════════════════════
        // 6. شريط الأزرار السفلي
        // ══════════════════════════════════════════════
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // بطاقة اللاعب
              _buildBottomPlayerBadge(timerString, isHumanTurn),
              const Spacer(),
              // أزرار الترتيب والدردشة
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xEB1A1E29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0x334B5563), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDockButton(
                      icon: Icons.swap_vert_rounded,
                      label: 'Sırala',
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playSort();
                        _engine.sortHumanTiles();
                        TopNotification.show(
                            context, 'تم ترتيب المجموعات المتتالية! ✨');
                      },
                    ),
                    _buildDockDivider(),
                    _buildDockButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Otomatik',
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playSort();
                        _engine.sortHumanTilesBySets();
                        TopNotification.show(
                            context, 'تم ترتيب المجموعات المتشابهة! 🎯');
                      },
                    ),
                    _buildDockDivider(),
                    _buildDockButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat',
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playButtonClick();
                        OkeyChatDialog.show(context);
                      },
                    ),
                    _buildDockDivider(),
                    _buildDockButton(
                      icon: Icons.settings_rounded,
                      label: 'إعدادات',
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playButtonClick();
                        OkeySettingsDialog.show(context,
                            onStateChanged: () => setState(() {}));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ══════════════════════════════════════════════
        // 7. أنيميشن رمي الحجر
        // ══════════════════════════════════════════════
        if (_animatingDiscardTile != null)
          AnimatedBuilder(
            animation: _discardCurve,
            builder: (context, _) {
              final t = _discardCurve.value;
              final startX = sw * 0.5;
              final startY = sh * 0.82;
              final targetX = sw * 0.5;
              final targetY = sh * 0.44;
              final currentX = startX + (targetX - startX) * t;
              final arcLift = math.sin(t * math.pi) * 50;
              final currentY = startY + (targetY - startY) * t - arcLift;
              final scale = 1.0 + 0.22 * math.sin(t * math.pi);
              final rotation = 0.18 * math.sin(t * math.pi);

              return Positioned(
                left: currentX - 14,
                top: currentY - 20,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: scale,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      child: OkeyTileWidget(
                        tile: _animatingDiscardTile,
                        isDragging: true,
                        width: 28,
                        height: 38,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // ══════════════════════════════════════════════
        // 8. أنيميشن سحب حجر جديد
        // ══════════════════════════════════════════════
        if (_animatingDrawTile != null)
          AnimatedBuilder(
            animation: _drawCurve,
            builder: (context, _) {
              final t = _drawCurve.value;
              final startX = sw * 0.5;
              final startY = sh * 0.44;
              final targetX = sw * 0.5;
              final targetY = sh * 0.82;
              final currentX = startX + (targetX - startX) * t;
              final arcLift = math.sin(t * math.pi) * 35;
              final currentY = startY + (targetY - startY) * t - arcLift;

              return Positioned(
                left: currentX - 14,
                top: currentY - 20,
                child: Transform.scale(
                  scale: 1.0 + 0.2 * math.sin(t * math.pi),
                  child: Material(
                    color: Colors.transparent,
                    child: OkeyTileWidget(
                      tile: _animatingDrawTile,
                      isDragging: true,
                      width: 28,
                      height: 38,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  مركز الطاولة: مؤشر + رمي + سحب
  // ─────────────────────────────────────────────

  Widget _buildTableCenter(bool isHumanTurn) {
    final canDiscard =
        isHumanTurn && _engine.turnPhase == OkeyTurnPhase.awaitingDiscard;
    final canDraw =
        isHumanTurn && _engine.turnPhase == OkeyTurnPhase.awaitingDraw;
    final hasSelected = _engine.selectedTileIndex != null;
    final remainingCount = _engine.drawDeck.length;
    final stackCount = (remainingCount / 10).clamp(1, 5).toInt();

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // ── رص السحب ──────────────────────────────
        GestureDetector(
          onTap: _executeDraw,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xAA1E0F07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: canDraw
                    ? const Color(0xFF4ADE80)
                    : const Color(0x33D4A373),
                width: canDraw ? 1.8 : 1.0,
              ),
              boxShadow: [
                if (canDraw)
                  BoxShadow(
                    color: const Color(0xFF4ADE80).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.layers_rounded,
                        color: Color(0xFFFFD54F), size: 11),
                    const SizedBox(width: 3),
                    Text(
                      '$remainingCount',
                      style: TextStyle(
                        color: canDraw
                            ? const Color(0xFF86EFAC)
                            : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // أحجار الرص مرتبة أفقياً
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(stackCount, (i) {
                    return Container(
                      width: 16,
                      height: 24,
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFFDF5),
                            Color(0xFFEDE0C4),
                            Color(0xFFD6C29E),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2.5),
                        border: Border.all(
                            color: const Color(0xFFC4B28F), width: 0.7),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 2,
                            offset: Offset(i % 2 == 0 ? 0.5 : -0.5, 1.5),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 3),
                Text(
                  canDraw ? 'اسحب' : 'سحب',
                  style: TextStyle(
                    color: canDraw
                        ? const Color(0xFF86EFAC)
                        : Colors.white54,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── حجر المؤشر ───────────────────────────
        GestureDetector(
          onTap: () {
            AppHaptics.selection();
            final indColor =
                _engine.indicatorTile.color.displayName;
            final okeyColor =
                _engine.realOkeySample.color.displayName;
            TopNotification.show(
              context,
              'المؤشر: $indColor ${_engine.indicatorTile.value} | الأوكي: $okeyColor ${_engine.realOkeySample.value}',
              icon: Icons.star_rounded,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color:
                        const Color(0xFFFFB300).withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1),
              ],
            ),
            child: OkeyTileWidget(
              tile: _engine.indicatorTile,
              width: 26,
              height: 36,
            ),
          ),
        ),

        const SizedBox(width: 10),

        // ── منطقة رمي الحجر ──────────────────────
        DragTarget<int>(
          onWillAcceptWithDetails: (details) => canDiscard,
          onAcceptWithDetails: (details) =>
              _executeDiscard(details.data),
          builder: (context, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            final showHighlight =
                canDiscard || hasSelected || isHovering;

            return GestureDetector(
              onTap: () {
                if (hasSelected && canDiscard) {
                  _executeDiscard(_engine.selectedTileIndex!);
                } else if (canDiscard) {
                  TopNotification.show(context,
                      'اختر حجراً من رفّك أولاً!',
                      icon: Icons.pan_tool_alt_rounded);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: showHighlight
                      ? const Color(0xFFEF4444)
                          .withOpacity(isHovering ? 0.28 : 0.12)
                      : Colors.black.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: showHighlight
                        ? const Color(0xFFEF4444)
                            .withOpacity(isHovering ? 1.0 : 0.85)
                        : const Color(0x33D4A373),
                    width: showHighlight ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    if (showHighlight)
                      BoxShadow(
                        color: const Color(0xFFEF4444)
                            .withOpacity(isHovering ? 0.5 : 0.3),
                        blurRadius: isHovering ? 18 : 10,
                        spreadRadius: isHovering ? 2 : 1,
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      color: showHighlight
                          ? const Color(0xFFFCA5A5)
                          : Colors.white60,
                      size: 14,
                    ),
                    const SizedBox(height: 4),
                    if (_engine.discardPiles[0].isNotEmpty)
                      _buildDiscardCluster()
                    else
                      Container(
                        width: 36,
                        height: 46,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white24, width: 1.2),
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.white.withOpacity(0.04),
                        ),
                        child: const Center(
                          child: Icon(Icons.arrow_downward_rounded,
                              color: Colors.white30, size: 16),
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'رمي',
                      style: TextStyle(
                        color: showHighlight
                            ? const Color(0xFFFCA5A5)
                            : Colors.white54,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDiscardCluster() {
    final discards = _engine.discardPiles[0];
    if (discards.isEmpty) return const SizedBox.shrink();

    final count = math.min(discards.length, 5);
    final recent = discards.sublist(discards.length - count);

    final offsets = [
      const Offset(-8, -3),
      const Offset(6, -5),
      const Offset(-4, 5),
      const Offset(5, 2),
      const Offset(0, 0),
    ];
    final rotations = [-0.14, 0.12, -0.07, 0.10, 0.0];

    return SizedBox(
      width: 60,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(recent.length, (i) {
          final tile = recent[i];
          final idx = (5 - recent.length + i) % 5;
          return Transform.translate(
            offset: offsets[idx],
            child: Transform.rotate(
              angle: rotations[idx],
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black
                            .withOpacity(i == recent.length - 1 ? 0.45 : 0.2),
                        blurRadius: 3,
                        offset: const Offset(0, 1)),
                  ],
                ),
                child: OkeyTileWidget(
                  tile: tile,
                  width: 22,
                  height: 30,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  بطاقة اللاعب السفلي
  // ─────────────────────────────────────────────

  Widget _buildBottomPlayerBadge(String timerString, bool isTurn) {
    final player = _engine.players[0];
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xEB1A1E29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn
              ? const Color(0xFF4ADE80)
              : const Color(0x334B5563),
          width: isTurn ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isTurn)
            BoxShadow(
              color: const Color(0xFF4ADE80).withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isTurn
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF6B7280),
                width: isTurn ? 2.2 : 1.2,
              ),
              boxShadow: [
                if (isTurn)
                  BoxShadow(
                    color: const Color(0xFF4ADE80).withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF2E384D),
                child: const Icon(Icons.person,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15),
              ),
              const SizedBox(height: 1.5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rating ${player.rating}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 9,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    timerString,
                    style: TextStyle(
                        color: isTurn
                            ? (_engine.turnTimeRemaining <= 10 ? const Color(0xFFEF4444) : const Color(0xFF4ADE80))
                            : const Color(0xFFD1D5DB),
                        fontSize: 9,
                        fontWeight: isTurn
                            ? FontWeight.w800
                            : FontWeight.w600),
                  ),
                ],
              ),
              if (isTurn) ...[
                const SizedBox(height: 3.5),
                SizedBox(
                  width: 95,
                  height: 3.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (_engine.turnTimeRemaining / OkeyEngine.defaultTurnDuration).clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _engine.turnTimeRemaining <= 10
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF4ADE80),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildDockDivider() => Container(
        width: 1,
        height: 18,
        color: const Color(0x22FFFFFF),
        margin: const EdgeInsets.symmetric(horizontal: 2),
      );

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 8,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
