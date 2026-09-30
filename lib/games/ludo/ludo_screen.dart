import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_lang.dart';
import '../../services/auth_service.dart';
import '../../utils/haptics.dart';
import '../../utils/top_notification.dart';
import 'ludo_audio.dart';
import 'ludo_board_painter.dart';
import 'ludo_engine.dart';

/// شاشة اللودو — لوحة 15×15 بأنيميشن كامل: نرد يتدحرج، أحجار تقفز،
/// أكل بقفزة قوسية للقاعدة، ونبض على الأحجار القانونية
class LudoGameScreen extends StatefulWidget {
  final bool vsAI;
  final int bet;

  const LudoGameScreen({super.key, this.vsAI = true, this.bet = 0});

  @override
  State<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends State<LudoGameScreen>
    with TickerProviderStateMixin {
  late final LudoEngine _engine;
  late final AnimationController _diceCtrl;

  bool _showResult = false;
  bool _confirmExit = false;
  int _resultChips = 0;
  bool _overHandled = false;

  static const _bgTop = Color(0xFF0D1320);
  static const _bgMid = Color(0xFF0A0F18);
  static const _bgBot = Color(0xFF05080D);
  static const _gold = Color(0xFFFFD54F);
  static const _blue = Color(0xFF3B82F6);
  static const _green = Color(0xFF22C55E);

  Color get _myColor => _blue;
  Color get _oppColor => _green;

  @override
  void initState() {
    super.initState();
    _engine = LudoEngine(vsAI: widget.vsAI);
    final user = AuthService().currentUser;
    _engine.names[0] = (user != null && user.displayName.isNotEmpty)
        ? user.displayName
        : 'أنت';
    _engine.names[1] = widget.vsAI ? 'روبوت 🤖' : 'اللاعب 2';
    _engine.onNotice = (msg) {
      if (mounted) TopNotification.show(context, msg);
    };
    _engine.addListener(_onEngine);
    _diceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  void _onEngine() {
    if (!mounted) return;
    if (_engine.rolling && !_diceCtrl.isAnimating) {
      _diceCtrl.repeat();
    } else if (!_engine.rolling && _diceCtrl.isAnimating) {
      _diceCtrl.stop();
      _diceCtrl.value = 1.0;
    }
    if (_engine.winner != null && !_overHandled) {
      _overHandled = true;
      _onGameOver();
    }
    setState(() {});
  }

  Future<void> _onGameOver() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final win = _engine.winner == 0;
    var chips = 0;
    if (widget.vsAI && widget.bet > 0) {
      chips = win ? widget.bet : -widget.bet;
      AuthService().updateMatchResult(
        chipChange: chips,
        ratingChange: win ? 12 : -10,
        isWin: win,
      );
    }
    setState(() {
      _resultChips = chips;
      _showResult = true;
    });
  }

  void _rematch() {
    setState(() {
      _showResult = false;
      _overHandled = false;
      _resultChips = 0;
    });
    _engine.reset();
  }

  void _requestExit() {
    if (_engine.winner != null || widget.bet == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _confirmExit = true);
  }

  void _resignConfirmed() {
    if (widget.bet > 0) {
      AuthService().updateMatchResult(
          chipChange: -widget.bet, ratingChange: -10, isWin: false);
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _diceCtrl.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        backgroundColor: _bgBot,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgMid, _bgBot],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.1),
                          radius: 0.95,
                          colors: [
                            _blue.withOpacity(0.09),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  children: [
                    _buildHeader(),
                    _buildPlayerBadge(1),
                    const SizedBox(height: 4),
                    Expanded(child: _buildBoard()),
                    _buildTurnArea(),
                    _buildPlayerBadge(0),
                    const SizedBox(height: 10),
                  ],
                ),
                if (_confirmExit) _buildExitDialog(),
                if (_showResult) _buildResultOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  الهيدر
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _circleBtn(Icons.arrow_back_ios_new_rounded, _requestExit),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'لودو'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (widget.bet > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x33FFD54F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _gold.withOpacity(0.55), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('${widget.bet}',
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          if (widget.bet > 0) const SizedBox(width: 8),
          _circleBtn(
            LudoAudio.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            () => setState(
                () => LudoAudio.soundEnabled = !LudoAudio.soundEnabled),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Icon(icon, color: Colors.white70, size: 18),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  شارة لاعب
  // ─────────────────────────────────────────────
  Widget _buildPlayerBadge(int p) {
    final isTurn = _engine.currentPlayer == p && _engine.winner == null;
    final c = p == 0 ? _myColor : _oppColor;
    final user = AuthService().currentUser;
    final photo = (p == 0 && user != null && user.photoUrl.isNotEmpty)
        ? user.photoUrl
        : '';
    final name = _engine.names[p];
    final home = _engine.tokens[p].where((t) => t == 57).length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isTurn ? c.withOpacity(0.12) : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? c : Colors.white.withOpacity(0.10),
          width: isTurn ? 1.5 : 0.9,
        ),
        boxShadow: isTurn
            ? [BoxShadow(color: c.withOpacity(0.35), blurRadius: 14)]
            : null,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    colors: [
                      Color.lerp(c, Colors.white, 0.4)!,
                      Color.lerp(c, Colors.black, 0.35)!,
                    ],
                  ),
                  border: Border.all(color: c, width: 1.4),
                ),
                child: ClipOval(
                  child: photo.startsWith('http')
                      ? Image.network(photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _initial(name))
                      : _initial(name),
                ),
              ),
              if (isTurn)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bgBot, width: 1.6),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
                // أحجار وصلت البيت
                Row(
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Icon(
                        i < home
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 9,
                        color: i < home ? c : Colors.white24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isTurn)
            Text(
              widget.vsAI && p == 1 ? 'يلعب…'.tr : 'دورك 🎲'.tr,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w900),
            ),
        ],
      ),
    );
  }

  Widget _initial(String name) => Center(
        child: Text(
          name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      );

  // ─────────────────────────────────────────────
  //  اللوحة + الأحجار
  // ─────────────────────────────────────────────
  Widget _buildBoard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxWidth);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                          BoxShadow(
                            color: _blue.withOpacity(0.14),
                            blurRadius: 40,
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  CustomPaint(size: size, painter: const LudoBoardPainter()),
                  // أحجار اللاعبين (الخصم أولاً ثم أحجاري فوقها)
                  for (var t = 0; t < 4; t++) _token(1, t, size),
                  for (var t = 0; t < 4; t++) _token(0, t, size),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// إزاحة تجميع عند تشارك أحجار نفس الخانة
  Offset _stackOffset(int player, int token, Size size) {
    final p = _engine.tokens[player][token];
    if (p < 0 || p > 51) return Offset.zero;
    final g = LudoEngine.globalOf(player, p);
    final mates = <int>[];
    for (var pl = 0; pl < 2; pl++) {
      for (var t = 0; t < 4; t++) {
        final tp = _engine.tokens[pl][t];
        if (tp >= 0 && tp <= 51 && LudoEngine.globalOf(pl, tp) == g) {
          mates.add(pl * 4 + t);
        }
      }
    }
    if (mates.length < 2) return Offset.zero;
    final idx = mates.indexOf(player * 4 + token);
    final cw = LudoBoard.cell(size);
    const spread = [
      (-0.22, -0.18),
      (0.22, 0.18),
      (0.22, -0.18),
      (-0.22, 0.18),
      (0.0, -0.30),
      (0.0, 0.30),
      (-0.30, 0.0),
      (0.30, 0.0),
    ];
    final o = spread[idx % spread.length];
    return Offset(o.$1 * cw, o.$2 * cw);
  }

  Widget _token(int player, int token, Size size) {
    final e = _engine;
    final cw = LudoBoard.cell(size);
    final r = cw * 0.33;

    // حجر مأكول يطير عائداً لقاعدته بقوس
    if (e.capturedPlayer == player && e.capturedToken == token) {
      final from = e.capturedFrom!;
      final a = LudoBoard.cellCenter(size, from.$1, from.$2);
      final b =
          LudoBoard.baseSpot(size, LudoBoard.playerColorIdx[player]!, token);
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeInOut,
        builder: (_, t, __) {
          final lin = Offset.lerp(a, b, t)!;
          final arc = Offset(0, -math.sin(t * math.pi) * cw * 2.2);
          return _tokenAt(lin + arc, player, r, scale: 1.0 - t * 0.15);
        },
      );
    }

    final p = e.tokens[player][token];
    final target = LudoBoard.positionOf(size, player, token, p) +
        _stackOffset(player, token, size);
    final pickable = e.awaitingHumanPick() &&
        player == e.currentPlayer &&
        e.legalTokens(player).contains(token);

    return TweenAnimationBuilder<Offset>(
      tween: Tween(end: target),
      duration: const Duration(milliseconds: 150),
      builder: (_, o, __) => _tokenAt(
        o,
        player,
        r,
        pop: e.moving ? 'hop$player$token-$p' : null,
        highlight: pickable,
        onTap: pickable
            ? () {
                AppHaptics.selection();
                e.moveToken(token);
              }
            : null,
      ),
    );
  }

  Widget _tokenAt(Offset center, int player, double r,
      {double scale = 1,
      String? pop,
      bool highlight = false,
      VoidCallback? onTap}) {
    final c = player == 0 ? _myColor : _oppColor;
    Widget disc = Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.95,
          colors: [
            Colors.white.withOpacity(0.95),
            Color.lerp(c, Colors.white, 0.15)!,
            c,
            Color.lerp(c, Colors.black, 0.5)!,
          ],
          stops: const [0.0, 0.3, 0.62, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
              color: c.withOpacity(highlight ? 0.85 : 0.5),
              blurRadius: highlight ? 14 : 8,
              spreadRadius: highlight ? 1.5 : 0),
          BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 5,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Center(
        child: Container(
          width: r * 0.72,
          height: r * 0.72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.85),
            border: Border.all(color: c.withOpacity(0.7), width: 1),
          ),
        ),
      ),
    );

    if (highlight) {
      disc = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1.10),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOut,
        builder: (_, s, __) => Transform.scale(scale: s, child: disc),
      );
    }
    if (pop != null) {
      disc = TweenAnimationBuilder<double>(
        key: ValueKey(pop),
        tween: Tween(begin: 1.28, end: 1.0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (_, s, __) => Transform.scale(scale: s, child: disc),
      );
    }

    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Transform.scale(scale: scale, child: disc),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  منطقة الدور: النرد + زر الرمي
  // ─────────────────────────────────────────────
  Widget _buildTurnArea() {
    final canRoll = !_engine.busy &&
        _engine.winner == null &&
        (!widget.vsAI || _engine.currentPlayer == 0) &&
        !_engine.awaitingHumanPick();
    final label = _engine.busy
        ? '…'
        : _engine.awaitingHumanPick()
            ? 'اختر حجراً 🎯'.tr
            : (widget.vsAI && _engine.currentPlayer == 1)
                ? 'دور الروبوت 🤖'.tr
                : widget.vsAI
                    ? 'ارمِ النرد 🎲'.tr
                    : 'دور {} 🎲'.trp([_engine.names[_engine.currentPlayer]]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _diceCtrl,
            builder: (_, __) {
              final rolling = _engine.rolling;
              final face = rolling
                  ? 1 + ((_diceCtrl.value * 13).floor() % 6)
                  : _engine.dice;
              final angle = rolling ? _diceCtrl.value * math.pi * 3 : 0.0;
              final scale = rolling
                  ? 1.0 + 0.12 * math.sin(_diceCtrl.value * math.pi * 4)
                  : 1.0;
              return Transform.rotate(
                angle: angle,
                child: Transform.scale(scale: scale, child: _diceFace(face)),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: canRoll
                  ? () {
                      AppHaptics.medium();
                      _engine.roll();
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: canRoll
                      ? const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFE082),
                            _gold,
                            Color(0xFFB8860B),
                          ],
                        )
                      : null,
                  color: canRoll ? null : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: canRoll
                        ? const Color(0xFFFFE9A8)
                        : Colors.white.withOpacity(0.14),
                    width: 1.2,
                  ),
                  boxShadow: canRoll
                      ? [
                          BoxShadow(
                              color: _gold.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: -2),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: canRoll ? const Color(0xFF1B0B30) : Colors.white38,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diceFace(int value) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF0), Color(0xFFEFE3C8), Color(0xFFD9C9A0)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFB7A276), width: 1.4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 10,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.white.withOpacity(0.5),
              blurRadius: 2,
              offset: const Offset(-1, -1)),
        ],
      ),
      child: CustomPaint(painter: LudoDicePipsPainter(value)),
    );
  }

  // ─────────────────────────────────────────────
  //  حوار الخروج + نتيجة المباراة
  // ─────────────────────────────────────────────
  Widget _buildExitDialog() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.65),
        child: Center(
          child: Container(
            width: 300,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151B2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الانسحاب من اللعبة؟'.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('ستخسر رهانك {} 🪙'.trp([widget.bet]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFB8C4DC), fontSize: 12.5)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _dialogBtn(
                          'إلغاء'.tr,
                          const Color(0x22FFFFFF),
                          Colors.white70,
                          () => setState(() => _confirmExit = false)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dialogBtn('انسحاب'.tr, const Color(0xFFEF4444),
                          Colors.white, _resignConfirmed),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogBtn(String text, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: fg, fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final win = _engine.winner == 0;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (_, s, __) => Transform.scale(
              scale: s,
              child: Container(
                width: 300,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: win
                        ? const [Color(0xFF3B2E08), Color(0xFF1C1403)]
                        : const [Color(0xFF2A1B2E), Color(0xFF140B18)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: win
                        ? _gold.withOpacity(0.7)
                        : Colors.white.withOpacity(0.2),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: (win ? _gold : Colors.black).withOpacity(0.4),
                        blurRadius: 30),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(win ? '🏆' : '😞',
                        style: const TextStyle(fontSize: 52)),
                    const SizedBox(height: 10),
                    Text(
                      win ? 'فزت! 🎉'.tr : 'خسرت'.tr,
                      style: TextStyle(
                          color: win ? _gold : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      win
                          ? 'أوصلت أحجارك الأربعة للبيت أولاً!'.tr
                          : 'أوصل {} أحجاره أولاً'.trp([_engine.names[1]]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFB8C4DC), fontSize: 12),
                    ),
                    if (_resultChips != 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: _resultChips > 0
                              ? _gold.withOpacity(0.15)
                              : const Color(0xFFF87171).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_resultChips > 0 ? '+' : ''}$_resultChips 🪙',
                          style: TextStyle(
                              color: _resultChips > 0
                                  ? _gold
                                  : const Color(0xFFF87171),
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogBtn(
                              'خروج'.tr,
                              const Color(0x22FFFFFF),
                              Colors.white70,
                              () => Navigator.of(context).pop()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dialogBtn('إعادة 🔁'.tr, _gold,
                              const Color(0xFF1B0B30), _rematch),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// رسّام نقاط وجه النرد (pip layout)
class LudoDicePipsPainter extends CustomPainter {
  final int value;
  const LudoDicePipsPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final pip = Paint()..color = const Color(0xFF2A2118);
    final r = size.width * 0.085;
    final c = size.width / 2;
    final q = size.width * 0.26;

    final spots = <Offset>[
      if ([1, 3, 5].contains(value)) Offset(c, c),
      if (value >= 2) ...[
        Offset(c - q, c - q),
        Offset(c + q, c + q),
      ],
      if (value >= 4) ...[
        Offset(c + q, c - q),
        Offset(c - q, c + q),
      ],
      if (value == 6) ...[
        Offset(c - q, c),
        Offset(c + q, c),
      ],
    ];
    for (final s in spots) {
      canvas.drawCircle(s, r, pip);
      canvas.drawCircle(
        s - Offset(r * 0.3, r * 0.3),
        r * 0.35,
        Paint()..color = Colors.white.withOpacity(0.25),
      );
    }
  }

  @override
  bool shouldRepaint(LudoDicePipsPainter old) => old.value != value;
}
