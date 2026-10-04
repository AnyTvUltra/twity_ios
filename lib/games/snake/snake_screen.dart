import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_lang.dart';
import '../../services/auth_service.dart';
import '../../utils/haptics.dart';
import '../../utils/top_notification.dart';
import 'snake_audio.dart';
import 'snake_board_painter.dart';
import 'snake_engine.dart';

/// شاشة لعبة الحية والدرج — لوحة 10×10 بأنيميشن كامل:
/// نرد يتدحرج، حجر يقفز خانة-خانة، انزلاق على جسم الحية، وتسلّق الدرج
class SnakeGameScreen extends StatefulWidget {
  final bool vsAI;
  final int bet;

  const SnakeGameScreen({super.key, this.vsAI = true, this.bet = 0});

  @override
  State<SnakeGameScreen> createState() => _SnakeGameScreenState();
}

class _SnakeGameScreenState extends State<SnakeGameScreen>
    with TickerProviderStateMixin {
  late final SnakeEngine _engine;
  late final AnimationController _diceCtrl;

  bool _showResult = false;
  bool _confirmExit = false;
  int _resultChips = 0;
  bool _overHandled = false;

  // خلفية فاخرة بهوية التطبيق: كحلي عميق → أسود نيلي
  static const _bgTop = Color(0xFF14204A);
  static const _bgMid = Color(0xFF0B1330);
  static const _bgBot = Color(0xFF060A1C);
  static const _gold = Color(0xFFFFD54F);
  static const _green = Color(0xFF8BC34A);
  static const _red = Color(0xFFFF5252);

  static const _playerColors = [_green, _red];

  @override
  void initState() {
    super.initState();
    _engine = SnakeEngine(vsAI: widget.vsAI);
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
    // دحرجة النرد طوال فترة rolling
    if (_engine.rolling && !_diceCtrl.isAnimating) {
      _diceCtrl.repeat();
    } else if (!_engine.rolling && _diceCtrl.isAnimating) {
      _diceCtrl.stop();
      _diceCtrl.value = 1.0;
    }
    // نهاية المباراة
    if (_engine.winner != null && !_overHandled) {
      _overHandled = true;
      _onGameOver();
    }
    setState(() {});
  }

  Future<void> _onGameOver() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
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
                // توهج مرح متعدد الألوان خلف اللوحة
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.15),
                          radius: 0.9,
                          colors: [
                            const Color(0xFFFFC46B).withOpacity(0.14),
                            const Color(0xFF3B82F6).withOpacity(0.08),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.55, 1.0],
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
          _circleBtn(
            Icons.arrow_back_ios_new_rounded,
            _requestExit,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الحية والدرج'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // رصيد الرهان
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
                  Text(
                    '${widget.bet}',
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.bet > 0) const SizedBox(width: 8),
          _circleBtn(
            SnakeAudio.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            () => setState(
                () => SnakeAudio.soundEnabled = !SnakeAudio.soundEnabled),
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
  //  شارة لاعب: أفاتار + اسم + الخانة + توهج الدور
  // ─────────────────────────────────────────────
  Widget _buildPlayerBadge(int p) {
    final isTurn = _engine.currentPlayer == p && _engine.winner == null;
    final c = _playerColors[p];
    final user = AuthService().currentUser;
    final photo = (p == 0 && user != null && user.photoUrl.isNotEmpty)
        ? user.photoUrl
        : '';
    final name = _engine.names[p];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isTurn ? c.withOpacity(0.13) : Colors.white.withOpacity(0.045),
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
          // أفاتار + مؤشر دور
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
                    colors: p == 0
                        ? const [Color(0xFF86EFAC), Color(0xFF166534)]
                        : const [Color(0xFFFCA5A5), Color(0xFF991B1B)],
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
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _engine.positions[p] == 0
                      ? 'على خط البداية'.tr
                      : 'الخانة {}'.trp([_engine.positions[p]]),
                  style: TextStyle(
                    color: c.withOpacity(0.9),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (isTurn)
            Text(
              widget.vsAI && p == 1 ? 'يلعب…'.tr : 'دورك 🎲'.tr,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
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
                  // ظل اللوحة على الأرض
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
                            color: _green.withOpacity(0.15),
                            blurRadius: 40,
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                    ),
                  ),
                  CustomPaint(
                    size: size,
                    painter: const SnakeBoardPainter(),
                  ),
                  _piece(0, size),
                  _piece(1, size),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// حجر لاعب — ينزلق على جسم الحية / يتسلق الدرج / يقفز بين الخانات
  Widget _piece(int p, Size size) {
    final e = _engine;
    final cw = SnakeBoard.gridRect(size).width / 10;
    final r = cw * 0.30;

    // انزلاق على حية: حركة على المسار المقوّس نفسه
    if (e.slidingPlayer == p) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 950),
        curve: Curves.easeInOut,
        builder: (_, t, __) {
          final pt = SnakeBoard.snakePoint(size, e.slideFrom, e.slideTo, t);
          return _pieceAt(pt, p, r, wobble: math.sin(t * math.pi * 4) * 0.25);
        },
      );
    }

    // تسلق درج: خط مستقيم + تمايل جانبي خفيف
    if (e.climbingPlayer == p) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 880),
        curve: Curves.easeInOut,
        builder: (_, t, __) {
          final a = SnakeBoard.cellCenter(size, e.climbFrom);
          final b = SnakeBoard.cellCenter(size, e.climbTo);
          final dir = b - a;
          final perp =
              Offset(-dir.dy, dir.dx) / (dir.distance == 0 ? 1 : dir.distance);
          final pt = Offset.lerp(a, b, t)! +
              perp * math.sin(t * math.pi * 3) * cw * 0.10;
          return _pieceAt(pt, p, r);
        },
      );
    }

    // عادي: انزلاق سلس بين مراكز الخانات (القفز خطوة-خطوة من المحرك)
    final pos = e.positions[p];
    final target = pos == 0
        ? SnakeBoard.homeSpot(size, p)
        : SnakeBoard.cellCenter(size, pos);
    // إزاحة جانبية بسيطة عند التقاء الحجرين على خانة واحدة
    final sameCell = e.positions[0] == e.positions[1] && e.positions[0] != 0;
    final adjusted =
        sameCell ? target + Offset(p == 0 ? -cw * 0.16 : cw * 0.16, 0) : target;

    return TweenAnimationBuilder<Offset>(
      tween: Tween(end: adjusted),
      duration: const Duration(milliseconds: 160),
      builder: (_, o, __) =>
          _pieceAt(o, p, r, pop: e.moving ? 'hop$p-${e.positions[p]}' : null),
    );
  }

  /// رسم قرص الحجر الزجاجي بموضع محدد
  Widget _pieceAt(Offset center, int p, double r,
      {double wobble = 0, String? pop}) {
    final c = _playerColors[p];
    Widget token = Container(
      width: r * 2,
      height: r * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [
            Colors.white.withOpacity(0.95),
            c,
            Color.lerp(c, Colors.black, 0.45)!,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(0.6),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          p == 0 ? '👑' : '🤖',
          style: TextStyle(fontSize: r * 0.8),
        ),
      ),
    );

    // نبضة هبوط صغيرة مع كل قفزة خانة
    if (pop != null) {
      token = TweenAnimationBuilder<double>(
        key: ValueKey(pop),
        tween: Tween(begin: 1.3, end: 1.0),
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        builder: (_, s, __) => Transform.scale(scale: s, child: token),
      );
    }

    return Positioned(
      left: center.dx - r,
      top: center.dy - r,
      child: IgnorePointer(
        child: Transform.rotate(angle: wobble, child: token),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  منطقة الدور: النرد + زر الرمي
  // ─────────────────────────────────────────────
  Widget _buildTurnArea() {
    final canRoll = !_engine.busy &&
        _engine.winner == null &&
        (!widget.vsAI || _engine.currentPlayer == 0);
    final label = _engine.busy
        ? '…'
        : (widget.vsAI && _engine.currentPlayer == 1)
            ? 'دور الروبوت 🤖'.tr
            : widget.vsAI
                ? 'ارمِ النرد 🎲'.tr
                : 'دور {} 🎲'.trp([_engine.turnName]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // النرد
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
                child: Transform.scale(
                  scale: scale,
                  child: _diceFace(face),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          // زر الرمي الذهبي
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
                            spreadRadius: -2,
                          ),
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

  /// وجه نرد عاجي بنقاط داكنة
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
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(-1, -1),
          ),
        ],
      ),
      child: CustomPaint(painter: _DicePipsPainter(value)),
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
                        () => setState(() => _confirmExit = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dialogBtn(
                        'انسحاب'.tr,
                        const Color(0xFFEF4444),
                        Colors.white,
                        _resignConfirmed,
                      ),
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
                      blurRadius: 30,
                    ),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      win
                          ? 'وصلت للخانة 100 أولاً!'.tr
                          : 'وصل {} للخانة 100 قبلك'.trp([_engine.names[1]]),
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
                              : _red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_resultChips > 0 ? '+' : ''}$_resultChips 🪙',
                          style: TextStyle(
                            color: _resultChips > 0 ? _gold : _red,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
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
                            () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _dialogBtn(
                            'إعادة 🔁'.tr,
                            _gold,
                            const Color(0xFF1B0B30),
                            _rematch,
                          ),
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
class _DicePipsPainter extends CustomPainter {
  final int value;
  const _DicePipsPainter(this.value);

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
      // لمعة صغيرة على النقطة
      canvas.drawCircle(
        s - Offset(r * 0.3, r * 0.3),
        r * 0.35,
        Paint()..color = Colors.white.withOpacity(0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_DicePipsPainter old) => old.value != value;
}
