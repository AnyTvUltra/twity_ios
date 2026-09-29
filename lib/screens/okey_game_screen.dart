import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../games/okey/okey_engine.dart';
import '../games/okey/okey_models.dart';
import '../games/okey/okey_rules.dart';
import '../games/okey/widgets/okey_table_painter.dart';
import '../games/okey/widgets/okey_istaka_widget.dart';
import '../games/okey/widgets/okey_opponent_istaka.dart';
import '../games/okey/widgets/okey_player_badge.dart';
import '../games/okey/widgets/okey_tile_widget.dart';
import '../games/okey/widgets/okey_chat_dialog.dart';
import '../games/okey/widgets/okey_settings_dialog.dart';
import '../games/okey/widgets/okey_win_dialog.dart';
import '../games/okey/widgets/okey_win_overlay.dart';
import '../games/okey/utils/okey_audio.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/game_settings_service.dart';
import '../services/store_service.dart';
import '../services/voice_service.dart';
import '../widgets/radio_player_widget.dart';
import '../widgets/animated_skin_effect.dart';
import '../widgets/skin_image.dart';
import '../games/okey/widgets/game_notice.dart';
import 'package:game_hub/utils/haptics.dart';
import '../l10n/app_lang.dart';

/// شاشة لعبة الأوكي التركية – تصميم بورتريت واقعي بدون تدوير
class OkeyGameScreen extends StatefulWidget {
  final OkeyRules rules;

  /// زوجي: اللاعب المقابل (الأمامي) شريكك — فوزه فوزك
  final bool teamMode;
  OkeyGameScreen(
      {super.key, OkeyRules? rules, this.teamMode = false})
      : rules = rules ?? OkeyRules.turkish;

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

  // دورة تأثير سكن الطاولة المتحرك (لافا/سديم/أورورا...)
  late AnimationController _tableFxController;

  // دعم النقر المزدوج
  int? _lastTappedSlot;
  DateTime? _lastTapTime;
  bool _roundSettled = false;
  bool _winDialogShown = false;
  bool _showWinCelebration = false;
  bool _isLeaving = false;

  // تكبير المشهد (الطاولة والأخشاب والأحجار)

  // مفاتيح مواقع لأنيميشن الحجر الطائر من اليد
  final GlobalKey _sceneKey = GlobalKey();
  final GlobalKey _discardKey = GlobalKey();
  final GlobalKey _deckKey = GlobalKey();

  // إشعار داخل المشهد المدوَّر (يظهر أفقيًا باتجاه اللعبة لا الجهاز)
  String? _sceneNotice;
  IconData? _sceneNoticeIcon;
  Timer? _noticeTimer;
  final GlobalKey _leftDiscardKey = GlobalKey();
  Offset _discardFrom = const Offset(422, 330);
  Offset _discardTo = const Offset(422, 175);
  Offset _drawFrom = const Offset(380, 175);
  Offset _drawTo = const Offset(422, 330);

  /// هل مشهد اللعبة مُدار 90° (شاشة عمودية)؟ — لتدوير الحجر المسحوب مثله
  bool _sceneRotated = false;

  static const int _winChips = 200;
  static const int _lossChips = 50;
  static const int _exitChips = 35;

  @override
  void initState() {
    super.initState();
    _engine = OkeyEngine(rules: widget.rules, turnDuration: GameSettingsService().defaultTurnTimer);
    _syncHumanProfile();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
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

    _tableFxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // تسخين خامة الخشب الافتراضية (طاولة + استكانات) قبل أول رسم
    StoreService().ensureWoodBase().then((_) {
      if (mounted) setState(() {});
    });

    _engine.addListener(_onEngineUpdate);
    _engine.onNotice = (msg) {
      if (mounted) _showGameNotice(msg);
    };
    GameNotice.handler = _showGameNotice;
  }

  void _syncHumanProfile() {
    final user = AuthService().currentUser;
    if (user == null) return;
    _engine.players[0].chips = user.chips;
    _engine.players[0].rating = user.rating;
  }

  /// إشعار داخل المشهد نفسه — يظهر أفقيًا باتجاه اللعبة المدوّرة
  void _showGameNotice(String message, {IconData? icon}) {
    AppHaptics.light();
    _noticeTimer?.cancel();
    setState(() {
      _sceneNotice = message;
      _sceneNoticeIcon = icon;
    });
    _noticeTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _sceneNotice = null);
    });
  }

  Widget _buildSceneNotice() {
    final msg = _sceneNotice;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.6),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: msg == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(msg),
              constraints: const BoxConstraints(maxWidth: 380),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B1E6D), Color(0xFF1E0E35)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD54F).withOpacity(0.6),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withOpacity(0.18),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_sceneNoticeIcon ?? Icons.notifications_active_rounded,
                      color: const Color(0xFFFFD54F), size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _onEngineUpdate() {
    if (_engine.gameState == OkeyGameState.win &&
        _engine.winner != null &&
        mounted &&
        !_winDialogShown) {
      _winDialogShown = true;
      // أنيميشن الاحتفال أولاً — يظهر للجميع — ثم نافذة النتيجة
      setState(() => _showWinCelebration = true);
      Timer(const Duration(milliseconds: 2700), () {
        if (!mounted) return;
        setState(() => _showWinCelebration = false);
        _handleGameEnd();
      });
    }
  }

  Future<void> _handleGameEnd() async {
    final winner = _engine.winner!;
    // في الزوجي: فوز الشريك المقابل = فوز فريقك
    final isHumanWinner = winner.isHuman ||
        (widget.teamMode && identical(winner, _engine.players[2]));
    await _settleRound(
      chipChange: isHumanWinner ? _winChips : -_lossChips,
      ratingChange: isHumanWinner ? 25 : -15,
      isWin: isHumanWinner,
    );
    if (!mounted) return;
    OkeyAudio.playWin();
    OkeyWinDialog.show(
      context,
      winner: winner,
      winType: _engine.winType ?? WinType.normal,
      onPlayAgain: () {
        setState(() {
          _roundSettled = false;
          _winDialogShown = false;
          _isLeaving = false;
          _engine.initGame();
          _syncHumanProfile();
        });
      },
      onExit: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  Future<bool> _settleRound({
    required int chipChange,
    required int ratingChange,
    required bool isWin,
  }) async {
    if (_roundSettled) return true;
    _roundSettled = true;
    final success = await AuthService().updateMatchResult(
      chipChange: chipChange,
      ratingChange: ratingChange,
      isWin: isWin,
    );
    if (!success) {
      _roundSettled = false;
      return false;
    }
    _syncHumanProfile();
    if (mounted) setState(() {});
    return true;
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineUpdate);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _noticeTimer?.cancel();
    GameNotice.handler = null;
    _discardAnimController.dispose();
    _drawAnimController.dispose();
    _tableFxController.dispose();

    _engine.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  قوائم ونوافذ
  // ─────────────────────────────────────────────

  void _showMoreMenu() {
    AppHaptics.light();
    OkeyAudio.playButtonClick();
    showOkeyLandscapeDialog(
      context,
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
                  Row(
                    children: [
                      Icon(Icons.more_horiz_rounded,
                          color: Color(0xFFFFD54F), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'قائمة الخيارات'.tr,
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
                title: Text('قواعد اللعبة'.tr,
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('تشكيل المجموعات وحجر الأوكي'.tr,
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
                  OkeyAudio.soundEnabled ? 'كتم الصوت'.tr : 'تشغيل الصوت'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  OkeyAudio.soundEnabled
                      ? 'المؤثرات الصوتية مفعلة'.tr
                      : 'المؤثرات الصوتية معطلة'.tr,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: () {
                  setState(
                      () => OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled);
                  Navigator.of(ctx).pop();
                  _showGameNotice(OkeyAudio.soundEnabled
                        ? 'تم تشغيل الصوت 🔊'.tr
                        : 'تم كتم الصوت 🔇'.tr,
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
                label: Text('انسحاب من الجولة (خسارة)'.tr,
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
    showOkeyLandscapeDialog(
      context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E112E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text(
              'تأكيد الانسحاب'.tr,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ تحذير: إذا قمت بالانسحاب الآن ستفقد رسوم الجولة (35 عملة ذهبية) وتُسجل لك خسارة رسمية في تقييمك السحابي!'.tr,
              style: TextStyle(
                  color: Color(0xFFFCA5A5), fontSize: 13, height: 1.5),
            ),
            SizedBox(height: 12),
            Text(
              'هل أنت متأكد من رغبتك في الاستسلام ومغادرة الطاولة؟'.tr,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('متابعة اللعب'.tr,
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
            child: Text('نعم، تأكيد الانسحاب'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSurrender() async {
    if (_isLeaving) return;
    _isLeaving = true;
    AppHaptics.heavy();
    final success = await _settleRound(
      chipChange: -_exitChips,
      ratingChange: -20,
      isWin: false,
    );
    if (!mounted) return;
    if (!success) {
      _isLeaving = false;
      _showGameNotice('تعذر تحديث الرصيد، حاول مرة أخرى'.tr);
      return;
    }
    FirebaseService().logGameResult(
      winnerName: 'الانسحاب (Surrender)'.tr,
      winType: 'surrender',
      roundDurationSeconds:
          _engine.turnDuration - _engine.turnTimeRemaining,
    );
    Navigator.of(context).pop();
  }

  void _requestExit() {
    if (_roundSettled) {
      Navigator.of(context).pop();
      return;
    }
    _confirmSurrender();
  }

  void _showRulesDialog() {
    showOkeyLandscapeDialog(
      context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E112E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFFFFD54F), size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text('قواعد لعبة الأوكي (Okey)'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• الهدف: تكوين مجموعات صالحة من 14 حجراً (متتالية من نفس اللون أو متماثلة بألوان مختلفة).'.tr,
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 6),
              Text(
                '• حجر الأوكي الحقيقي (Joker): يعوض عن أي حجر ناقص.'.tr,
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 6),
              Text(
                '• الرمي: ارمِ الحجر الزائد في مربع الرمي الأحمر بالمنتصف.'.tr,
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('حسناً فهمت'.tr,
                style: TextStyle(color: Color(0xFFFFD54F))),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  منطق اللعبة
  // ─────────────────────────────────────────────

  /// مركز عنصر في المشهد بإحداثيات المشهد المنطقية (844×390)
  Offset _keyCenter(GlobalKey key) {
    final ctx = key.currentContext;
    final sceneCtx = _sceneKey.currentContext;
    if (ctx == null || sceneCtx == null) return const Offset(422, 190);
    final box = ctx.findRenderObject() as RenderBox;
    final scene = sceneCtx.findRenderObject() as RenderBox;
    return scene.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  /// موقع خانة الرف التقريبي داخل المشهد
  Offset _rackSlotCenter(int slot) {
    const slotW = 40.0;
    const tileH = 52.0;
    const rackTop = 390.0 - 12.0 - 141.0; // ارتفاع الاستكانة + الحافة السفلية
    const startX = 162.0 + slotW / 2; // مركز أول خانة
    final x = startX + slotW * (slot % 14);
    final y = slot < 14 ? rackTop + 24 + tileH / 2 : rackTop + 29 + tileH * 1.5;
    return Offset(x, y);
  }

  void _executeDiscard(int slotIndex, {Offset? dropGlobal}) {
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDiscard) {
      _showGameNotice('يجب سحب حجر أولاً قبل الرمي!'.tr);
      return;
    }
    final tile = _engine.players[0].rackTiles[slotIndex];
    if (tile == null) return;

    OkeyAudio.playTileDiscard();

    // الحجر يطير من نقطة إفلات الإصبع (اليد) وليس من الخشبة
    Offset from;
    if (dropGlobal != null && _sceneKey.currentContext != null) {
      final scene = _sceneKey.currentContext!.findRenderObject() as RenderBox;
      from = scene.globalToLocal(dropGlobal);
    } else {
      from = _rackSlotCenter(slotIndex);
    }

    setState(() {
      _animatingDiscardTile = tile;
      _discardFrom = from;
      _discardTo = _keyCenter(_discardKey);
    });

    _discardAnimController.forward(from: 0).then((_) {
      _engine.discardSlot(slotIndex);
      setState(() => _animatingDiscardTile = null);
      _discardAnimController.reset();
    });
  }

  void _executeDraw() {
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDraw) {
      _showGameNotice('لقد سحبت بالفعل! ارمِ حجراً لإنهاء دورك'.tr);
      return;
    }
    if (_engine.drawDeck.isNotEmpty) {
      OkeyAudio.playTileDraw();
      final tile = _engine.drawDeck.first;
      final emptySlot = _engine.players[0].rackTiles.indexOf(null);
      setState(() {
        _animatingDrawTile = tile;
        _drawFrom = _keyCenter(_deckKey);
        _drawTo =
            emptySlot != -1 ? _rackSlotCenter(emptySlot) : _rackSlotCenter(0);
      });

      _drawAnimController.forward(from: 0).then((_) {
        _engine.drawFromDeck();
        setState(() => _animatingDrawTile = null);
        _drawAnimController.reset();
      });
    }
  }

  /// سحب بالإفلات: من الرزمة أو كومة اليسار مباشرة إلى خانة في الرف
  void _drawToSlot(int source, int toSlot) {
    if (_engine.currentTurnIndex != 0) {
      _showGameNotice('ليس دورك الآن!'.tr);
      return;
    }
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDraw) {
      _showGameNotice('لقد سحبت بالفعل! ارمِ حجراً لإنهاء دورك'.tr);
      return;
    }
    if (source == OkeyDrag.leftPile &&
        _engine.players[3].playStyle == OkeyPlayStyle.full) {
      _showGameNotice('اللاعب الأيسر يلعب فول — لا يمكن أخذ أحجاره'.tr);
      return;
    }
    final ok = source == OkeyDrag.deck
        ? _engine.drawFromDeck(toSlot: toSlot)
        : _engine.drawFromDiscard(toSlot: toSlot);
    if (ok) {
      OkeyAudio.playTileDraw();
      AppHaptics.light();
    }
  }

  /// سحب آخر حجر رماه اللاعب الأيسر
  void _executeDrawFromLeft() {
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDraw) {
      _showGameNotice('لقد سحبت بالفعل! ارمِ حجراً لإنهاء دورك'.tr);
      return;
    }
    final pile = _engine.discardPiles[3];
    if (pile.isEmpty) {
      _showGameNotice('اللاعب الأيسر لم يرمِ أي حجر بعد'.tr);
      return;
    }
    if (_engine.players[3].playStyle == OkeyPlayStyle.full) {
      _showGameNotice('اللاعب الأيسر يلعب فول — لا يمكن أخذ أحجاره'.tr);
      return;
    }

    OkeyAudio.playTileDraw();
    final tile = pile.last;
    final emptySlot = _engine.players[0].rackTiles.indexOf(null);
    setState(() {
      _animatingDrawTile = tile;
      _drawFrom = _keyCenter(_leftDiscardKey);
      _drawTo =
          emptySlot != -1 ? _rackSlotCenter(emptySlot) : _rackSlotCenter(0);
    });

    _drawAnimController.forward(from: 0).then((_) {
      _engine.drawFromDiscard();
      setState(() => _animatingDrawTile = null);
      _drawAnimController.reset();
    });
  }

  void _handleTileTap(int slotIndex) {
    final now = DateTime.now();
    if (_lastTappedSlot == slotIndex &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 350)) {
      if (_engine.getHighlightedSlotIndices().contains(slotIndex) &&
          _engine.layMeldContainingSlot(slotIndex)) {
        AppHaptics.medium();
        _showGameNotice('تم إنزال الـ Per على الطاولة'.tr);
        _lastTappedSlot = null;
        _lastTapTime = null;
        return;
      }
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
    final media = MediaQuery.of(context);
    final rotateToLandscape = media.orientation == Orientation.portrait;
    final landscapeMedia = rotateToLandscape
        ? media.copyWith(
            size: Size(media.size.height, media.size.width),
            padding: EdgeInsets.symmetric(
              horizontal:
                  media.padding.top > media.padding.bottom ? media.padding.top : media.padding.bottom,
              vertical:
                  media.padding.left > media.padding.right ? media.padding.left : media.padding.right,
            ),
          )
        : media;
    _sceneRotated = rotateToLandscape;
    final game = MediaQuery(
      data: landscapeMedia,
      child: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_engine, StoreService()]),
          builder: (context, _) => _buildLandscapeLayout(context),
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _requestExit();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF070B13),
          body: rotateToLandscape
              ? RotatedBox(quarterTurns: 1, child: game)
              : game,
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    const sw = 844.0;
    const sh = 390.0;
    final isHumanTurn = _engine.currentTurnIndex == 0;
    final minutes =
        (_engine.turnTimeRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_engine.turnTimeRemaining % 60).toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        // معامل تكبير FittedBox + تكبير المستخدم لمطابقة حجم الحجر المسحوب
        final scaleX = constraints.maxWidth / sw;
        final scaleY = constraints.maxHeight / sh;
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              key: _sceneKey,
              width: sw,
              height: sh,
              child: _buildScene(context, isHumanTurn, minutes, seconds,
                  scaleX, scaleY),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScene(BuildContext context, bool isHumanTurn, String minutes,
      String seconds, double scaleX, double scaleY) {
    const sw = 844.0;
    const sh = 390.0;
    return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              // ═══ منطقة اللعب القابلة للتكبير (الطاولة والأحجار والاستكانات) ═══
              Positioned.fill(
                child: ClipRect(
                  child: SizedBox(
                      width: sw,
                      height: sh,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
              Builder(builder: (context) {
                final bgItem = StoreService()
                    .equippedFor(StoreCategory.background);
                if (bgItem != null) {
                  return SkinTransformImage.fromItem(bgItem);
                }
                return Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.1),
                      radius: 1.05,
                      colors: [
                        Color(0xFF17171B),
                        Color(0xFF090C12),
                        Color(0xFF030509)
                      ],
                      stops: [0, 0.6, 1],
                    ),
                  ),
                );
              }),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.08),
                          Colors.black.withOpacity(0.52)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 148,
                right: 148,
                top: 66,
                bottom: 128,
                child: Builder(builder: (context) {
                  final tblSkin = StoreService()
                      .equippedFor(StoreCategory.table);
                  final tblFx = skinEffectOf(tblSkin);
                  if (tblFx == SkinEffect.none) {
                    return CustomPaint(
                      painter: OkeyTablePainter(
                        isHumanTurn: isHumanTurn,
                        surfaceItem: tblSkin,
                      ),
                    );
                  }
                  return AnimatedBuilder(
                    animation: _tableFxController,
                    builder: (context, _) => CustomPaint(
                      painter: OkeyTablePainter(
                        isHumanTurn: isHumanTurn,
                        surfaceItem: tblSkin,
                        surfaceEffect: tblFx,
                        animT: _tableFxController.value,
                      ),
                    ),
                  );
                }),
              ),
              // منطقة رمي تغطي المشهد كله: إسقاط الحجر في أي مكان خارج
              // الاستكانة وأماكن البير = رمي (الأهداف الأدق فوقها لها الأولوية)
              Positioned.fill(
                child: DragTarget<int>(
                  onWillAcceptWithDetails: (details) => true,
                  onAcceptWithDetails: (details) =>
                      _dropOnTable(details.data, details.offset),
                  builder: (context, candidateData, rejectedData) {
                    final hovering =
                        candidateData.isNotEmpty && isHumanTurn;
                    return Stack(children: [
                      Positioned(
                        left: 148,
                        right: 148,
                        top: 62,
                        bottom: 128,
                        child: IgnorePointer(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: hovering
                                  ? const Color(0xFFEF4444).withOpacity(0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: hovering
                                  ? Border.all(
                                      color: const Color(0x55EF4444),
                                      width: 1.2)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
              Positioned(
                top: 26,
                left: 0,
                right: 0,
                child: Center(
                  child: OkeyOpponentIstaka(
                    position: OpponentPosition.top,
                    tileCount: _engine.players[2].tileCount,
                    isTurn: _engine.currentTurnIndex == 2,
                    rackItem:
                        StoreService().equippedFor(StoreCategory.rack),
                  ),
                ),
              ),
              Positioned(
                left: 96,
                top: 66,
                child: OkeyOpponentIstaka(
                  position: OpponentPosition.left,
                  tileCount: _engine.players[3].tileCount,
                  isTurn: _engine.currentTurnIndex == 3,
                  rackItem:
                      StoreService().equippedFor(StoreCategory.rack),
                ),
              ),
              Positioned(
                right: 96,
                top: 66,
                child: OkeyOpponentIstaka(
                  position: OpponentPosition.right,
                  tileCount: _engine.players[1].tileCount,
                  isTurn: _engine.currentTurnIndex == 1,
                  rackItem:
                      StoreService().equippedFor(StoreCategory.rack),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: OkeyIstakaWidget(
                  rackTiles: _engine.players[0].rackTiles,
                  selectedIndex: _engine.selectedTileIndex,
                  isTurn: isHumanTurn,
                  highlightedIndices: _engine.getHighlightedSlotIndices(),
                  dragScaleX: scaleX,
                  dragScaleY: scaleY,
                  feedbackQuarterTurns: _sceneRotated ? 1 : 0,
                  rackItem: StoreService()
                      .equippedFor(StoreCategory.rack),
                  onTileTap: _handleTileTap,
                  onTileMove: (fromSlot, toSlot) =>
                      _engine.moveTile(fromSlot, toSlot),
                  onDropAboveRack: _dropOnTable,
                  onDrawToSlot: _drawToSlot,
                  onGroupMove: (slot, to) => _engine.moveGroup(slot, to),
                ),
              ),
              if (_engine.canDeclareOkeyOut)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 132,
                  child: Center(child: _buildOkeyOutButton()),
                ),
              Positioned(
                left: 326,
                right: 244,
                top: 98,
                child: Center(child: _buildTableCenter(isHumanTurn)),
              ),
              // أماكن البير على الطاولة — لكل لاعب جهته، ظاهرة للجميع
              ..._buildTableMelds(),
              // ═══════ أنيميشن الحجر الطائر: الرمي من يد اللاعب ═══════
              if (_animatingDiscardTile != null)
                AnimatedBuilder(
                  animation: _discardCurve,
                  builder: (context, _) {
                    final t = _discardCurve.value;
                    final x = _discardFrom.dx +
                        (_discardTo.dx - _discardFrom.dx) * t;
                    final arcLift = math.sin(t * math.pi) * 46;
                    final y = _discardFrom.dy +
                        (_discardTo.dy - _discardFrom.dy) * t -
                        arcLift;
                    return Positioned(
                      left: x - 14,
                      top: y - 19,
                      child: IgnorePointer(
                        child: Transform.rotate(
                          angle: 0.18 * math.sin(t * math.pi),
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

              // ═══════ أنيميشن الحجر الطائر: السحب إلى الرف ═══════
              if (_animatingDrawTile != null)
                AnimatedBuilder(
                  animation: _drawCurve,
                  builder: (context, _) {
                    final t = _drawCurve.value;
                    final x =
                        _drawFrom.dx + (_drawTo.dx - _drawFrom.dx) * t;
                    final arcLift = math.sin(t * math.pi) * 34;
                    final y = _drawFrom.dy +
                        (_drawTo.dy - _drawFrom.dy) * t -
                        arcLift;
                    return Positioned(
                      left: x - 14,
                      top: y - 19,
                      child: IgnorePointer(
                        child: Transform.scale(
                          scale: 1.0 + 0.18 * math.sin(t * math.pi),
                          child: Material(
                            color: Colors.transparent,
                            elevation: 8,
                            child: OkeyTileWidget(
                              tile: _animatingDrawTile,
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
                        ],
                      ),
                    ),
                  ),
              ),
              // ═══ عناصر الواجهة الثابتة ═══
              // إشعار داخل المشهد — أفقي باتجاه اللعبة المدوّرة
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(child: _buildSceneNotice()),
                ),
              ),
              Positioned(
                top: 6,
                left: 14,
                child: _landscapeCircleButton(
                  icon: Icons.logout_rounded,
                  color: const Color(0xFFFCA5A5),
                  onTap: _requestExit,
                ),
              ),
              Positioned(
                top: 10,
                left: 60,
                child: _buildStyleButtons(),
              ),
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _withStyleChip(
                        OkeyPlayerBadge(
                          player: _engine.players[2],
                          isTurn: _engine.currentTurnIndex == 2,
                          type: PlayerBadgeType.top,
                        ),
                        _engine.players[2],
                      ),
                      const SizedBox(width: 6),
                      _roleChip(widget.teamMode),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 7,
                right: 14,
                child: _landscapeCircleButton(
                  icon: OkeyAudio.soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: OkeyAudio.soundEnabled
                      ? const Color(0xFF73E6A2)
                      : Colors.white54,
                  onTap: () => setState(() =>
                      OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled),
                ),
              ),

              Positioned(
                left: 10,
                top: 138,
                child: _withStyleChip(
                  OkeyPlayerBadge(
                    player: _engine.players[3],
                    isTurn: _engine.currentTurnIndex == 3,
                    type: PlayerBadgeType.left,
                  ),
                  _engine.players[3],
                ),
              ),
              Positioned(
                right: 10,
                top: 138,
                child: _withStyleChip(
                  OkeyPlayerBadge(
                    player: _engine.players[1],
                    isTurn: _engine.currentTurnIndex == 1,
                    type: PlayerBadgeType.right,
                  ),
                  _engine.players[1],
                ),
              ),
              Positioned(
                left: 12,
                top: 70,
                child: _buildRoundStats(),
              ),
              // بطاقة اللاعب والأزرار — أعمدة جانبية رفيعة على الحافتين
              // حتى لا تغطي طرفي الاستكانة أبداً
              Positioned(
                left: 8,
                bottom: 8,
                child: _buildSidePlayerBadge('$minutes:$seconds', isHumanTurn),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: _buildLandscapeDock(),
              ),
              // ═══ طبقة احتفال الفوز — تظهر للجميع فوق الطاولة ═══
              if (_showWinCelebration && _engine.winner != null)
                Positioned.fill(
                  child: OkeyWinOverlay(
                    winner: _engine.winner!,
                    winType: _engine.winType ?? WinType.normal,
                    lastTile: () {
                      final wi = _engine.players.indexOf(_engine.winner!);
                      final pile = _engine.discardPiles[wi];
                      return pile.isNotEmpty ? pile.last : null;
                    }(),
                  ),
                ),
            ],
    );
  }

  static const _konkanColor = Color(0xFFF59E0B);
  static const _fullColor = Color(0xFFC084FC);

  Color _styleColor(OkeyPlayStyle s) =>
      s == OkeyPlayStyle.full ? _fullColor : _konkanColor;

  /// شارة صغيرة فوق بطاقة اللاعب تبيّن أنه بدأ كونكان أو فول — يراها الجميع
  Widget _withStyleChip(Widget badge, OkeyPlayer p) {
    if (p.playStyle == OkeyPlayStyle.normal) return badge;
    final c = _styleColor(p.playStyle);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        Positioned(
          top: -9,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(color: c.withOpacity(0.55), blurRadius: 8),
              ],
            ),
            child: Text(
              p.playStyle.label,
              style: const TextStyle(
                  color: Color(0xFF1B0B30),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  /// زرّا كونكان / فول — يختار اللاعب أسلوبه قبل أي نزول، ثم يُقفل
  Widget _buildStyleButtons() {
    final me = _engine.players[0];
    Widget btn(OkeyPlayStyle style) {
      final c = _styleColor(style);
      final chosen = me.playStyle == style;
      final enabled = _engine.canDeclarePlayStyle;
      if (!chosen && !enabled) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () async {
          if (!enabled) return;
          AppHaptics.medium();
          final ok = await showOkeyLandscapeDialog<bool>(
            context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF141C34),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: c.withOpacity(0.6))),
              title: Text('اللعب {}؟'.trp([style.label]),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
              content: Text(
                style == OkeyPlayStyle.full
                    ? 'تفوز بجمع لون واحد كامل: 1 2 3 … 13 1.\nأحجارك المرمية تظهر مقلوبة للجميع ولا يستطيع أحد أخذها، وأنت تستطيع أخذ أحجار غيرك.\nلن تستطيع النزول على الطاولة.'.tr
                    : 'تفوز بـ 10 أحجار متسلسلة بلون واحد + بير عادي (3 أحجار فأكثر).\nلن تستطيع النزول على الطاولة.'.tr,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    color: Color(0xFFB8C4DC), fontSize: 12.5, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('إلغاء'.tr,
                      style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: c,
                      foregroundColor: const Color(0xFF1B0B30)),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('ابدأ {}'.trp([style.label]),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          );
          if (ok == true) _engine.declarePlayStyle(style);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: chosen ? c : c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(chosen ? 1 : 0.6)),
            boxShadow: chosen
                ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 10)]
                : null,
          ),
          child: Text(
            chosen ? '✓ ${style.label}' : style.label,
            style: TextStyle(
                color: chosen ? const Color(0xFF1B0B30) : c,
                fontSize: 11,
                fontWeight: FontWeight.w900),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [btn(OkeyPlayStyle.konkan), btn(OkeyPlayStyle.full)],
    );
  }

  /// شارة دور اللاعب المقابل: شريك (زوجي) أو خصم (فردي)
  Widget _roleChip(bool partner) {
    final c = partner ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Text(partner ? '🤝 شريك'.tr : '⚔️ خصم'.tr,
          style: TextStyle(
              color: c, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }

  Widget _buildOkeyOutButton() {
    return GestureDetector(
      onTap: () {
        AppHaptics.heavy();
        OkeyAudio.playWin();
        _engine.declareHumanWin();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withOpacity(0.8),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆', style: TextStyle(fontSize: 15)),
            SizedBox(width: 7),
            Text(
              'إعلان الفوز بالأوكي (Okey Out!)'.tr,
              style: TextStyle(
                color: Color(0xFF1B0B30),
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundStats() {
    Widget stat(String value, String label, Color color) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700)),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC241107),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x665F3A24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.45),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          stat('${_engine.livePoints}', 'نقاطي'.tr,
              const Color(0xFFFFD46B)),
          const SizedBox(width: 10),
          stat('${_engine.liveGroupCount}', 'Per',
              const Color(0xFF86EFAC)),
          const SizedBox(width: 10),
          stat(
              _engine.players[0].hasOpened
                  ? 'مفتوح ✓'.tr
                  : '${_engine.remainingOpeningPoints}',
              'المطلوب'.tr,
              _engine.players[0].hasOpened
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFCA5A5)),
        ],
      ),
    );
  }

  /// إفلات حجر على الطاولة (أي مكان خارج الاستكانة وأماكن البير) = رمي
  void _dropOnTable(int slot, Offset dropGlobal) {
    if (OkeyDrag.isGroup(slot)) {
      // كتلة مرفوعة أُفلتت على الطاولة: إن كانت Per صحيحاً تنزل، ولا تُرمى أبداً
      final s = slot - OkeyDrag.groupBase;
      if (_engine.getHighlightedSlotIndices().contains(s) &&
          _engine.layMeldContainingSlot(s)) {
        AppHaptics.medium();
      } else {
        _showGameNotice('لا يمكن رمي مجموعة — ارمِ حجراً واحداً'.tr);
      }
      return;
    }
    if (!OkeyDrag.isRackTile(slot)) return;
    if (_engine.currentTurnIndex != 0) {
      _showGameNotice('ليس دورك الآن!'.tr);
      return;
    }
    if (_engine.turnPhase == OkeyTurnPhase.awaitingDiscard) {
      _executeDiscard(slot, dropGlobal: dropGlobal);
    } else {
      _showGameNotice('يجب سحب حجر أولاً قبل الرمي!'.tr);
    }
  }

  // ══════════════════════════════════════════════════════
  // البير على الطاولة — كل لاعب له جهة (أنت أسفل، الخصوم أعلى/يمين/يسار)
  // الأحجار مرسومة ممدّدة على السطح بمنظور ثلاثي الأبعاد وظل
  // ══════════════════════════════════════════════════════

  /// منطقة كل لاعب على سطح الطاولة (بإحداثيات المشهد 844×390)
  static const _meldZones = <int, Rect>{
    0: Rect.fromLTWH(196, 196, 452, 38), // أنت — طرف الطاولة القريب
    2: Rect.fromLTWH(250, 68, 344, 30), // الخصم المقابل
    3: Rect.fromLTWH(156, 104, 166, 90), // الخصم الأيسر
    1: Rect.fromLTWH(604, 104, 90, 90), // الخصم الأيمن (بعد كومة الرمي)
  };

  List<Widget> _buildTableMelds() {
    final out = <Widget>[];
    for (final entry in _meldZones.entries) {
      final owner = entry.key;
      final zone = entry.value;
      final melds = <MapEntry<int, OkeyGroup>>[
        for (var i = 0; i < _engine.tableMelds.length; i++)
          if (_engine.tableMelds[i].ownerIndex == owner)
            MapEntry(i, _engine.tableMelds[i]),
      ];
      final content = melds.isEmpty
          ? (owner == 0 ? _myMeldHint() : const SizedBox.shrink())
          : _meldsOnTable(melds, zone);
      out.add(Positioned.fromRect(
        rect: zone,
        child: owner == 0 ? _myMeldDropZone(content) : content,
      ));
    }
    return out;
  }

  /// خانة الرف من قيمة السحب (حجر مفرد أو كتلة)، أو -1
  int _rackSlotOf(int data) => OkeyDrag.isRackTile(data)
      ? data
      : (OkeyDrag.isGroup(data) ? data - OkeyDrag.groupBase : -1);

  /// منطقتك: إسقاط Per مميّز هنا = نزول على الطاولة
  Widget _myMeldDropZone(Widget child) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => _engine
          .getHighlightedSlotIndices()
          .contains(_rackSlotOf(details.data)),
      onAcceptWithDetails: (details) {
        if (!_engine.humanCanLayMelds) {
          _showGameNotice(
              'أنت تلعب {} — لا نزول على الطاولة'.trp([_engine.players[0].playStyle.label]));
          return;
        }
        if (_engine.layMeldContainingSlot(_rackSlotOf(details.data))) {
          AppHaptics.medium();
        } else {
          _showGameNotice('هذه الأحجار لا تكوّن Per صحيحاً'.tr);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: hovering ? const Color(0x3334D399) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hovering
                  ? const Color(0xFF6EE7B7)
                  : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _myMeldHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Text(
            _engine.humanCanLayMelds
                ? 'اسحب الـ Per هنا لتنزله على الطاولة'.tr
                : 'تلعب {} — أكمل يدك وأعلن الفوز'.trp([_engine.players[0].playStyle.label]),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 8.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// مجموعة بيرات لاعب واحد ممدّدة على السطح بمنظور ثري دي
  Widget _meldsOnTable(List<MapEntry<int, OkeyGroup>> melds, Rect zone) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: zone.width * 1.25,
        child: Transform(
          alignment: Alignment.center,
          // ميلان للخلف: الأحجار تبدو مستلقية على الطاولة
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0018)
            ..rotateX(0.62),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 5,
            children: [for (final m in melds) _meld3D(m.key, m.value)],
          ),
        ),
      ),
    );
  }

  /// بير واحد: أحجار متلاصقة بسماكة وظل، وتقبل صرف حجر عليها
  Widget _meld3D(int meldIndex, OkeyGroup meld) {
    final isMine = meld.ownerIndex == 0;
    final ownerColor =
        isMine ? const Color(0xFF4ADE80) : const Color(0xFF38BDF8);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        if (!_engine.players[0].hasOpened) return false;
        if (!OkeyDrag.isRackTile(details.data)) return false;
        final tile = _engine.players[0].rackTiles[details.data];
        return tile != null && _engine.canLayOffTile(tile, meld);
      },
      onAcceptWithDetails: (details) {
        if (_engine.layTileOnMeld(details.data, meldIndex)) {
          AppHaptics.light();
        } else {
          _showGameNotice('هذا الحجر لا يصرف على هذا البير'.tr);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final glow = hovering
            ? const Color(0xFF6EE7B7)
            : meld.pending
                ? const Color(0xFFFBBF24)
                : ownerColor;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(hovering ? 0.10 : 0.22),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: glow.withOpacity(hovering || meld.pending ? 0.9 : 0.35),
                width: hovering ? 1.4 : 0.8),
            boxShadow: [
              // ظل الأحجار على سطح الطاولة
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 6,
                offset: const Offset(0, 4),
              ),
              if (hovering || meld.pending)
                BoxShadow(color: glow.withOpacity(0.35), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tile in meld.tiles)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  // سماكة الحجر: حافة سفلية داكنة تحت الوجه
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xFF8C7A55),
                          offset: Offset(0, 2.2),
                          blurRadius: 0),
                      BoxShadow(
                          color: Color(0x88000000),
                          offset: Offset(0, 3),
                          blurRadius: 2),
                    ],
                  ),
                  child: OkeyTileWidget(tile: tile, width: 22, height: 30),
                ),
            ],
          ),
        );
      },
    );
  }

  /// عمود أزرار جانبي رفيع (يمين أسفل) — لا يلامس الاستكانة
  Widget _buildLandscapeDock() {
    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xEE151922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDockButton(
              icon: Icons.swap_horiz_rounded,
              label: 'Sırala',
              onTap: _engine.sortHumanTiles),
          _buildDockDivider(vertical: true),
          _buildDockButton(
              icon: Icons.auto_awesome_rounded,
              label: 'Otomatik',
              onTap: _engine.sortHumanTilesBySets),
          _buildDockDivider(vertical: true),
          _buildDockButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat',
              onTap: () => OkeyChatDialog.show(context)),
          _buildDockDivider(vertical: true),
          _buildDockButton(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () => OkeySettingsDialog.show(context,
                  onStateChanged: () => setState(() {}))),
        ],
      ),
    );
  }

  /// بطاقة لاعب جانبية عمودية رفيعة (يسار أسفل) — أفاتار + اسم + مؤقت
  Widget _buildSidePlayerBadge(String timerString, bool isTurn) {
    final player = _engine.players[0];
    return Container(
      width: 88,
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xEB1A1E29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTurn ? const Color(0xFF4ADE80) : const Color(0x334B5563),
          width: isTurn ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isTurn)
            BoxShadow(
              color: const Color(0xFF4ADE80).withOpacity(0.35),
              blurRadius: 12,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isTurn ? const Color(0xFF4ADE80) : const Color(0xFF6B7280),
                width: isTurn ? 2.0 : 1.2,
              ),
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF2E384D),
                child: const Icon(Icons.person, color: Colors.white, size: 16),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                height: 1.1),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${player.rating}',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 8,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80), shape: BoxShape.circle),
              ),
              const SizedBox(width: 3),
              Text(
                timerString,
                style: TextStyle(
                    color: isTurn
                        ? (_engine.turnTimeRemaining <= 10
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF4ADE80))
                        : const Color(0xFFD1D5DB),
                    fontSize: 8.5,
                    fontWeight: isTurn ? FontWeight.w800 : FontWeight.w600),
              ),
            ],
          ),
          if (isTurn) ...[
            const SizedBox(height: 3),
            SizedBox(
              width: 64,
              height: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (_engine.turnTimeRemaining /
                          _engine.turnDuration)
                      .clamp(0.0, 1.0),
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
    );
  }

  Widget _landscapeCircleButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: const Color(0xDD151922),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 6)
            ]),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget buildPortraitLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    final isHumanTurn = _engine.currentTurnIndex == 0;
    final minutes =
        (_engine.turnTimeRemaining ~/ 60).toString().padLeft(2, '0');
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xEB1A1E29),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0x50FFD54F), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_rounded,
                          color: Color(0xFFFFD54F), size: 15),
                      SizedBox(width: 5),
                      Text('المزيد'.tr,
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
                        border: Border.all(
                            color: const Color(0x40FFD54F), width: 1),
                      ),
                      child: const Icon(Icons.radio_rounded,
                          color: Color(0xFFFFD54F), size: 16),
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
                          if (!context.mounted) return;
                          _showGameNotice(on
                                ? 'تم تشغيل المايك 🎙️ تحدث الآن'.tr
                                : 'تم كتم المايك 🔇'.tr,
                            icon: on ? Icons.mic : Icons.mic_off,
                          );
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: voice.isMicOn
                                ? const Color(0xFF10B981)
                                : const Color(0xEB1A1E29),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: voice.isSpeaking
                                  ? Colors.white
                                  : const Color(0x334B5563),
                              width: voice.isSpeaking ? 2 : 1,
                            ),
                            boxShadow: voice.isSpeaking
                                ? [
                                    BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withOpacity(0.8),
                                        blurRadius: 8,
                                        spreadRadius: 1)
                                  ]
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
                      setState(() =>
                          OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled);
                      _showGameNotice(OkeyAudio.soundEnabled
                            ? 'تم تشغيل الصوت 🔊'.tr
                            : 'تم كتم الصوت 🔇'.tr,
                        icon: OkeyAudio.soundEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xEB1A1E29),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0x334B5563), width: 1),
                      ),
                      child: Icon(
                        OkeyAudio.soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: OkeyAudio.soundEnabled
                            ? const Color(0xFF4ADE80)
                            : Colors.white60,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'إعلان الفوز بالأوكي (Okey Out!) 🎯'.tr,
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
            rackItem: StoreService().equippedFor(StoreCategory.rack),
            onTileTap: _handleTileTap,
            onTileMove: (fromSlot, toSlot) =>
                _engine.moveTile(fromSlot, toSlot),
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xEB1A1E29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x334B5563), width: 1),
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
                        _showGameNotice('تم ترتيب المجموعات المتتالية! ✨'.tr);
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
                        _showGameNotice('تم ترتيب المجموعات المتشابهة! 🎯'.tr);
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
                      label: 'إعدادات'.tr,
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

  // ─────────────────────────────────────────────
  //  مركز الطاولة: المؤشر + رزمة السحب الطولية + شريط الرمي (للجميع)
  // ─────────────────────────────────────────────

  /// مقاس حجر الـ feedback عند السحب من الرزمة — يطابق حجر الاستكانة
  static const double _rackTileW = 38;
  static const double _rackTileH = 38 * 1.36;

  Widget _buildTableCenter(bool isHumanTurn) {
    final canDraw =
        isHumanTurn && _engine.turnPhase == OkeyTurnPhase.awaitingDraw;
    final canDiscard =
        isHumanTurn && _engine.turnPhase == OkeyTurnPhase.awaitingDiscard;
    final leftPile = _engine.discardPiles[3];
    bool hidden(int i) =>
        i != 0 && _engine.players[i].playStyle == OkeyPlayStyle.full;
    final canTakeLeft = canDraw && leftPile.isNotEmpty && !hidden(3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIndicator(),
        const SizedBox(width: 8),
        _buildDrawTower(canDraw),
        const SizedBox(width: 10),
        // كومة رمي موحّدة مبعثرة لكل اللاعبين — مثل طاولة حقيقية
        _buildScatterPile(canDraw: canDraw, canDiscard: canDiscard,
            canTakeLeft: canTakeLeft),
      ],
    );
  }

  /// كومة أحجار مرمية مشتركة ومبعثرة: أحجار الجميع في مكان واحد
  /// بزوايا وإزاحات عشوائية ثابتة. حجر اليسار الأخير وحده قابل للأخذ
  /// (توهّج أخضر + لمس أو سحب)، وأحجار الفول تبقى مقلوبة بيضاء.
  Widget _buildScatterPile({
    required bool canDraw,
    required bool canDiscard,
    required bool canTakeLeft,
  }) {
    // اجمع مرميات اللاعبين الأربعة بالترتيب (صاحب اللاعب الأخير يظهر فوقاً)
    final entries = <MapEntry<int, OkeyTile>>[];
    for (var p = 0; p < 4; p++) {
      for (final t in _engine.discardPiles[p]) {
        entries.add(MapEntry(p, t));
      }
    }
    final total = entries.length;
    // نعرض آخر 22 حجراً كحد أقصى حتى لا تتكاثر الكومة بلا حدود
    const maxShown = 22;
    final shown = entries.length > maxShown
        ? entries.sublist(entries.length - maxShown)
        : entries;
    // الحجر الوحيد القابل للأخذ = آخر رمية للاعب اليسار
    final leftTopTile =
        _engine.discardPiles[3].isNotEmpty ? _engine.discardPiles[3].last : null;

    const w = 118.0, h = 78.0;
    const tw = 20.0, th = 28.0;
    return GestureDetector(
      onTap: () {
        if (canDiscard) {
          final sel = _engine.selectedTileIndex;
          if (sel != null) {
            _executeDiscard(sel);
          } else {
            _showGameNotice('اختر حجراً أو اسحبه إلى الطاولة لرميه'.tr,
                icon: Icons.pan_tool_alt_rounded);
          }
        }
      },
      child: Container(
        key: _discardKey,
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0x8C142040),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canDiscard
                ? const Color(0xFFEF4444).withOpacity(0.7)
                : Colors.white.withOpacity(0.10),
            width: canDiscard ? 1.4 : 0.8,
          ),
        ),
        child: total == 0
            ? Center(
                child: Icon(Icons.layers_clear_rounded,
                    color: Colors.white.withOpacity(0.18), size: 22))
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  // عداد الأحجار المرمية
                  Positioned(
                    left: 4,
                    bottom: 2,
                    child: Text('$total',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 8,
                            fontWeight: FontWeight.w900)),
                  ),
                  for (var i = 0; i < shown.length; i++)
                    _scatteredTile(
                      entries: shown,
                      i: i,
                      w: w, h: h, tw: tw, th: th,
                      isTakeable: canTakeLeft &&
                          identical(shown[i].value, leftTopTile) &&
                          shown[i].key == 3,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _scatteredTile({
    required List<MapEntry<int, OkeyTile>> entries,
    required int i,
    required double w,
    required double h,
    required double tw,
    required double th,
    required bool isTakeable,
  }) {
    // بذرة ثابتة لكل حجر حتى لا "يقفز" عند كل إعادة بناء
    final seed = (entries[i].value.hashCode ^
            (entries[i].key * 7919) ^
            (i * 104729)) &
        0x7fffffff;
    final r = math.Random(seed);
    final dx = 8 + r.nextDouble() * (w - tw - 16);
    final dy = 4 + r.nextDouble() * (h - th - 8);
    final angle = (r.nextDouble() - 0.5) * 0.9; // ±25°
    final faceDown =
        entries[i].key != 0 && _engine.players[entries[i].key].playStyle == OkeyPlayStyle.full;

    Widget tile = Transform.rotate(
      angle: angle,
      child: faceDown
          ? _tileBack(tw, th)
          : OkeyTileWidget(tile: entries[i].value, width: tw, height: th),
    );
    if (isTakeable) {
      tile = Draggable<int>(
        key: _leftDiscardKey,
        data: OkeyDrag.leftPile,
        maxSimultaneousDrags: 1,
        onDragStarted: () => AppHaptics.selection(),
        dragAnchorStrategy: (d, c, p) => const Offset(
            _rackTileW / 2, _rackTileH / 2 + _rackTileH * 0.28),
        feedback: Material(
          color: Colors.transparent,
          elevation: 10,
          child: OkeyTileWidget(
              tile: entries[i].value,
              isDragging: true,
              width: _rackTileW,
              height: _rackTileH),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: tile),
        child: GestureDetector(
          onTap: _executeDrawFromLeft,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF4ADE80).withOpacity(0.75),
                    blurRadius: 9,
                    spreadRadius: 1.5),
              ],
            ),
            child: tile,
          ),
        ),
      );
    }
    return Positioned(left: dx, top: dy, child: tile);
  }

  Widget _buildIndicator() {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        final indColor = _engine.indicatorTile.color.displayName;
        final okeyColor = _engine.realOkeySample.color.displayName;
        _showGameNotice(
          'المؤشر: {} {} | الأوكي: {} {}'.trp([indColor, _engine.indicatorTile.value, okeyColor, _engine.realOkeySample.value]),
          icon: Icons.star_rounded,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1),
              ],
            ),
            child: OkeyTileWidget(
                tile: _engine.indicatorTile, width: 24, height: 33),
          ),
          const SizedBox(height: 3),
          Text('مؤشر'.tr,
              style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// ظهر الحجر (مقلوب) — للرزمة وللحجر المسحوب منها
  Widget _tileBack(double w, double h, {bool glow = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFDF5), Color(0xFFEDE0C4), Color(0xFFD6C29E)],
        ),
        borderRadius: BorderRadius.circular(w * 0.12),
        border: Border.all(color: const Color(0xFFC4B28F), width: 0.7),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 3,
              offset: const Offset(0, 2)),
          if (glow)
            BoxShadow(
                color: const Color(0xFF4ADE80).withOpacity(0.55),
                blurRadius: 10),
        ],
      ),
      child: Center(
        child: Container(
          width: w * 0.42,
          height: w * 0.42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFB89A62).withOpacity(0.7), width: 1),
          ),
        ),
      ),
    );
  }

  /// رزمة السحب: برج طولي من الأحجار المتراصة — المس للسحب أو اسحب إلى رفّك
  Widget _buildDrawTower(bool canDraw) {
    final remaining = _engine.drawDeck.length;
    final layers = (remaining / 6).ceil().clamp(1, 8);
    const w = 24.0, h = 33.0, step = 3.2;
    final tower = SizedBox(
      width: w + 2,
      height: h + step * (layers - 1),
      child: Stack(
        children: [
          for (var i = 0; i < layers; i++)
            Positioned(
              left: 1,
              top: step * i,
              child: _tileBack(w, h, glow: canDraw && i == layers - 1),
            ),
        ],
      ),
    );
    return GestureDetector(
      onTap: _executeDraw,
      child: Draggable<int>(
        key: _deckKey,
        data: OkeyDrag.deck,
        maxSimultaneousDrags: canDraw && remaining > 0 ? 1 : 0,
        onDragStarted: () => AppHaptics.selection(),
        dragAnchorStrategy: (d, c, p) => const Offset(
            _rackTileW / 2, _rackTileH / 2 + _rackTileH * 0.28),
        feedback: Material(
          color: Colors.transparent,
          elevation: 10,
          child: _tileBack(_rackTileW, _rackTileH),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tower,
            const SizedBox(height: 3),
            Text('$remaining',
                style: TextStyle(
                    color: canDraw ? const Color(0xFF86EFAC) : Colors.white60,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }


  Widget _buildBottomPlayerBadge(String timerString, bool isTurn) {
    final player = _engine.players[0];
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xEB1A1E29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? const Color(0xFF4ADE80) : const Color(0x334B5563),
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
                color:
                    isTurn ? const Color(0xFF4ADE80) : const Color(0xFF6B7280),
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
                child: const Icon(Icons.person, color: Colors.white, size: 18),
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
                        color: Color(0xFF4ADE80), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    timerString,
                    style: TextStyle(
                        color: isTurn
                            ? (_engine.turnTimeRemaining <= 10
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF4ADE80))
                            : const Color(0xFFD1D5DB),
                        fontSize: 9,
                        fontWeight: isTurn ? FontWeight.w800 : FontWeight.w600),
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
                      value: (_engine.turnTimeRemaining /
                              _engine.turnDuration)
                          .clamp(0.0, 1.0),
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

  Widget _buildDockDivider({bool vertical = false}) => Container(
        width: vertical ? 40 : 1,
        height: vertical ? 1 : 18,
        color: const Color(0x22FFFFFF),
        margin: EdgeInsets.symmetric(
            horizontal: vertical ? 0 : 2, vertical: vertical ? 1 : 0),
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
