import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_lang.dart';
import '../../services/auth_service.dart';
import '../../utils/haptics.dart';
import '../../utils/top_notification.dart';
import 'domino_audio.dart';
import 'domino_engine.dart';

/// شاشة الدومينو — طاولة لباد داكنة، سلسلة متعرجة، يد تفاعلية،
/// سحب من البونيارد، جولات ونقاط حتى 50
class DominoGameScreen extends StatefulWidget {
  final bool vsAI;
  final int bet;

  const DominoGameScreen({super.key, this.vsAI = true, this.bet = 0});

  @override
  State<DominoGameScreen> createState() => _DominoGameScreenState();
}

class _DominoGameScreenState extends State<DominoGameScreen> {
  late final DominoEngine _engine;

  bool _showResult = false;
  bool _confirmExit = false;
  int _resultChips = 0;
  bool _overHandled = false;

  /// حجر محدد في اليد ينتظر اختيار الطرف
  int? _selectedIdx;

  /// درع "مرّر الجهاز" في وضع الصديق — رقم اللاعب المنتظر أو null
  int? _shieldFor;

  // خلفية بهوية التطبيق: كحلي عميق → أسود نيلي
  static const _bgTop = Color(0xFF14204A);
  static const _bgMid = Color(0xFF0B1330);
  static const _bgBot = Color(0xFF060A1C);
  static const _gold = Color(0xFFFFD54F);
  static const _teal = Color(0xFF2DD4BF);
  static const _feltA = Color(0xFF175239);
  static const _feltB = Color(0xFF0D2F20);

  /// عدد خلايا النصف-حجر في عرض الطاولة (كل حجر = خليتان)
  static const _chainCellsWide = 14;

  @override
  void initState() {
    super.initState();
    _engine = DominoEngine(vsAI: widget.vsAI);
    final user = AuthService().currentUser;
    _engine.names[0] = (user != null && user.displayName.isNotEmpty)
        ? user.displayName
        : 'أنت';
    _engine.names[1] = widget.vsAI ? 'روبوت 🤖' : 'اللاعب 2';
    _engine.onNotice = (msg) {
      if (mounted) TopNotification.show(context, msg);
    };
    _engine.addListener(_onEngine);
    // وضع صديق: درع البداية على من يبدأ
    if (!widget.vsAI && _engine.currentPlayer == 1) {
      _shieldFor = 1;
    }
  }

  int _lastSeenPlayer = 0;

  void _onEngine() {
    if (!mounted) return;
    // درع تمرير الجهاز عند تبدل الدور في وضع صديق
    if (!widget.vsAI &&
        _engine.currentPlayer != _lastSeenPlayer &&
        _engine.matchWinner == null &&
        !_engine.betweenRounds) {
      _shieldFor = _engine.currentPlayer;
    }
    _lastSeenPlayer = _engine.currentPlayer;

    if (_engine.matchWinner != null && !_overHandled) {
      _overHandled = true;
      _onGameOver();
    }
    setState(() {});
  }

  Future<void> _onGameOver() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final win = _engine.matchWinner == 0;
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
      _selectedIdx = null;
      _shieldFor = (!widget.vsAI && _engine.currentPlayer == 1) ? 1 : null;
    });
    _engine.reset();
  }

  void _requestExit() {
    if (_engine.matchWinner != null || widget.bet == 0) {
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
    _engine.dispose();
    super.dispose();
  }

  /// اليد الظاهرة أسفل — وضع الذكاء: يدي دائماً؛ وضع صديق: يد صاحب الدور
  int get _visibleHandPlayer => widget.vsAI ? 0 : _engine.currentPlayer;

  bool get _myTurn =>
      _engine.humanTurn &&
      _engine.matchWinner == null &&
      !_engine.betweenRounds &&
      _shieldFor == null;

  void _onHandTileTap(int handIndex) {
    if (!_myTurn) return;
    final hand = _engine.hands[_visibleHandPlayer];
    if (handIndex >= hand.length) return;
    final tile = hand[handIndex];
    final sides = _engine.legalSides(tile);
    if (sides.isEmpty) {
      TopNotification.show(context, 'هذا الحجر لا يلائم أي طرف 🚫'.tr);
      AppHaptics.light();
      return;
    }
    AppHaptics.selection();
    if (_engine.chain.isEmpty || sides.length == 1) {
      _engine.playTile(_visibleHandPlayer, handIndex,
          _engine.chain.isEmpty ? 0 : sides.first);
      _selectedIdx = null;
    } else {
      setState(() => _selectedIdx = handIndex);
    }
  }

  void _onEndTap(int side) {
    if (!_myTurn || _selectedIdx == null) return;
    final idx = _selectedIdx!;
    setState(() => _selectedIdx = null);
    _engine.playTile(_visibleHandPlayer, idx, side);
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
                          center: const Alignment(0, -0.15),
                          radius: 0.95,
                          colors: [
                            _teal.withOpacity(0.10),
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
                    _buildScoreBar(),
                    const SizedBox(height: 4),
                    _buildOpponentHand(),
                    Expanded(child: _buildTable()),
                    _buildActionArea(),
                    _buildMyHand(),
                    const SizedBox(height: 10),
                  ],
                ),
                if (_engine.betweenRounds) _buildRoundBanner(),
                if (_confirmExit) _buildExitDialog(),
                if (_showResult) _buildResultOverlay(),
                if (_shieldFor != null) _buildTurnShield(),
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
              'دومينو'.tr,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900),
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
            DominoAudio.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            () => setState(
                () => DominoAudio.soundEnabled = !DominoAudio.soundEnabled),
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
  //  شريط النقاط والجولة
  // ─────────────────────────────────────────────
  Widget _buildScoreBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          _scoreChip(0),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              'جولة {}'.trp([_engine.round]),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          _scoreChip(1),
          const SizedBox(width: 8),
          Text(
            'الهدف {}'.trp([_engine.target]),
            style: const TextStyle(
                color: Color(0xFF8A9AB0),
                fontSize: 10,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(int p) {
    final isTurn = _engine.currentPlayer == p && _engine.matchWinner == null;
    final c = p == 0 ? _teal : const Color(0xFFF87171);
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isTurn ? c.withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
              color: isTurn ? c : Colors.white.withOpacity(0.10),
              width: isTurn ? 1.4 : 0.9),
          boxShadow: isTurn
              ? [BoxShadow(color: c.withOpacity(0.3), blurRadius: 10)]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _engine.names[p],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_engine.scores[p]}',
              style: TextStyle(
                  color: c, fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  يد الخصم (أحجار مقلوبة)
  // ─────────────────────────────────────────────
  Widget _buildOpponentHand() {
    final opp = widget.vsAI ? 1 : 1 - _engine.currentPlayer;
    final count = _engine.hands[opp].length;
    return SizedBox(
      height: 46,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: math.min(count, 12) * 14.0 + 18,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(
                math.min(count, 12),
                (i) => Transform.translate(
                  offset: Offset((i - math.min(count, 12) / 2 + 0.5) * 14, 0),
                  child: Transform.rotate(
                    angle: (i - math.min(count, 12) / 2 + 0.5) * 0.04,
                    child: _tileBack(16, 30),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '×$count',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  الطاولة: السلسلة + البونيارد + مؤشرات الطرفين
  // ─────────────────────────────────────────────
  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final u = w / _chainCellsWide;
          final rects = _layoutChain(_engine.chain.length);

          // إطار خشب جوز متدرّج بتطعيم ذهبي يحيط بلبّاد أخضر عميق
          return Container(
            width: w,
            height: h,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7A4A26),
                  Color(0xFF3F220F),
                  Color(0xFF6B3E1F)
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.15,
                  colors: [_feltA, _feltB],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFD4A64A).withOpacity(0.75),
                    width: 1.4),
                boxShadow: const [
                  // ظل داخلي على حافة اللبّاد
                  BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 10,
                      spreadRadius: -2),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  children: [
                    // نص توجيهي عند البداية الفارغة
                    if (_engine.chain.isEmpty)
                      Center(
                        child: Text(
                          _myTurn
                              ? 'العب أول حجر ⚫'.tr
                              : 'في انتظار {}…'
                                  .trp([_engine.names[_engine.currentPlayer]]),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.35),
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    // السلسلة
                    for (var i = 0; i < _engine.chain.length; i++)
                      _placedTile(i, rects[i], u),
                    // مؤشرات الطرفين عند اختيار حجر بوجهين
                    if (_selectedIdx != null && _engine.chain.isNotEmpty) ...[
                      _endMarker(rects.first, u, side: 0),
                      _endMarker(rects.last, u, side: 1),
                    ],
                    // البونيارد
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: _buildBoneyard(u),
                    ),
                    // حجر يطير للطاولة
                    if (_engine.flyingTile != null) _flyingTile(w, h),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// تخطيط متعرج: كل حجر خليتان أفقيتان، الصفوف بالتناوب يمين/يسار
  List<Rect> _layoutChain(int n) {
    const w = _chainCellsWide;
    final rects = <Rect>[];
    var x = 0, y = 0, dir = 1;
    for (var i = 0; i < n; i++) {
      rects.add(Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 1));
      if (dir == 1) {
        x += 2;
        if (x + 2 > w) {
          dir = -1;
          x = w - 2;
          y++;
        }
      } else {
        x -= 2;
        if (x < 0) {
          dir = 1;
          x = 0;
          y++;
        }
      }
    }
    return rects;
  }

  Widget _placedTile(int i, Rect cellRect, double u) {
    final p = _engine.chain[i];
    final isDouble = p.tile.isDouble;
    final left = cellRect.left * u + 1.5;
    final top = cellRect.top * u + 16;

    Widget tile = DominoTileWidget(
      left: p.left,
      right: p.right,
      width: u * 2 - 3,
      height: u - 3,
      horizontal: true,
    );
    if (isDouble) {
      // الدبل يوضع عمودياً في منتصف خانته
      tile = SizedBox(
        width: u - 3,
        height: u * 2 - 3,
        child: OverflowBox(
          maxHeight: u * 2,
          maxWidth: u * 2,
          child: Center(
            child: DominoTileWidget(
              left: p.left,
              right: p.right,
              width: u * 0.9,
              height: u * 1.8,
              horizontal: false,
            ),
          ),
        ),
      );
    }

    return Positioned(
      left: isDouble ? left + u * 0.5 : left,
      top: top,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.7, end: 1.0),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        builder: (_, s, __) => Transform.scale(scale: s, child: tile),
      ),
    );
  }

  /// مؤشر طرف مفتوح متوهج — لمسه يختار هذا الجانب
  Widget _endMarker(Rect cellRect, double u, {required int side}) {
    final endValue = side == 0 ? _engine.leftEnd : _engine.rightEnd;
    final cx = (side == 0 ? cellRect.left + 0.5 : cellRect.right - 0.5) * u;
    final cy = cellRect.top * u + 16 + (u - 3) / 2;
    return Positioned(
      left: cx - u * 0.55,
      top: cy - u * 0.55,
      child: GestureDetector(
        onTap: () => _onEndTap(side),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.12),
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeInOut,
          builder: (_, s, __) => Transform.scale(
            scale: s,
            child: Container(
              width: u * 1.1,
              height: u * 1.1,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _gold.withOpacity(0.22),
                border: Border.all(color: _gold, width: 2),
                boxShadow: [
                  BoxShadow(color: _gold.withOpacity(0.5), blurRadius: 12),
                ],
              ),
              child: Center(
                child: Text(
                  '$endValue',
                  style: const TextStyle(
                      color: _gold, fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBoneyard(double u) {
    final canDraw = _myTurn && _engine.mustDraw;
    return GestureDetector(
      onTap: canDraw
          ? () {
              AppHaptics.selection();
              _engine.drawTile(_visibleHandPlayer);
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              children: [
                for (var i = 0; i < math.min(_engine.boneyard.length, 3); i++)
                  Positioned(
                    left: i * 3.0,
                    top: (2 - i) * 2.0,
                    child: _tileBack(30, 34),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: canDraw
                  ? _gold.withOpacity(0.2)
                  : Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(9),
              border: canDraw ? Border.all(color: _gold, width: 1) : null,
            ),
            child: Text(
              'سحب ×{}'.trp([_engine.boneyard.length]),
              style: TextStyle(
                  color: canDraw ? _gold : Colors.white54,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// حجر يطير من اليد نحو الطاولة
  Widget _flyingTile(double w, double h) {
    final t = _engine.flyingTile!;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOut,
      builder: (_, v, __) {
        final from = Offset(w / 2, h + 30);
        final to = Offset(w / 2, h * 0.28);
        final lin = Offset.lerp(from, to, v)!;
        final arc = Offset(0, -math.sin(v * math.pi) * 60);
        return Positioned(
          left: lin.dx + arc.dx - 21,
          top: lin.dy + arc.dy - 13,
          child: Transform.rotate(
            angle: (1 - v) * 1.2,
            child: DominoTileWidget(
              left: t.a,
              right: t.b,
              width: 42,
              height: 26,
              horizontal: true,
            ),
          ),
        );
      },
    );
  }

  Widget _tileBack(double w, double h) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25365E), Color(0xFF131F3A)],
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: const Color(0xFF4A5F8F), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: Container(
          width: w * 0.42,
          height: w * 0.42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF6C80B5).withOpacity(0.6), width: 1),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  منطقة الأفعال: تمرير / تلميح
  // ─────────────────────────────────────────────
  Widget _buildActionArea() {
    final pass = _myTurn && _engine.mustPass;
    final draw = _myTurn && _engine.mustDraw;
    String hint;
    if (_engine.matchWinner != null) {
      hint = '';
    } else if (_engine.betweenRounds) {
      hint = '';
    } else if (pass) {
      hint = 'لا حركة والبونيارد فارغ — مرّر'.tr;
    } else if (draw) {
      hint = 'لا حركة — اسحب من البونيارد ⬇'.tr;
    } else if (_selectedIdx != null) {
      hint = 'اختر الطرف: يسار أو يمين ◂▸'.tr;
    } else if (_myTurn) {
      hint = 'دورك — العب حجراً ⚫'.tr;
    } else {
      hint = 'دور {}…'.trp([_engine.names[_engine.currentPlayer]]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFA8B4C8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700),
            ),
          ),
          if (pass)
            GestureDetector(
              onTap: () {
                AppHaptics.medium();
                _engine.pass(_visibleHandPlayer);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE082), _gold, Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: _gold.withOpacity(0.4), blurRadius: 12),
                  ],
                ),
                child: Text(
                  'تمرير ⏭'.tr,
                  style: const TextStyle(
                      color: Color(0xFF1B0B30),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  يدي (أو يد صاحب الدور في وضع صديق)
  // ─────────────────────────────────────────────
  Widget _buildMyHand() {
    final hand = _engine.hands[_visibleHandPlayer];
    const tw = 30.0, th = 54.0;
    return SizedBox(
      height: th + 14,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(hand.length, (i) {
              final t = hand[i];
              final playable = _myTurn && _engine.legalSides(t).isNotEmpty;
              final selected = _selectedIdx == i;
              return GestureDetector(
                onTap: () => _onHandTileTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  transform: Matrix4.translationValues(0, selected ? -9 : 0, 0),
                  child: Opacity(
                    opacity: playable || !_myTurn ? 1.0 : 0.55,
                    child: Container(
                      decoration: selected || playable
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: [
                                BoxShadow(
                                  color: (selected ? _gold : _teal)
                                      .withOpacity(selected ? 0.55 : 0.30),
                                  blurRadius: selected ? 14 : 8,
                                  spreadRadius: selected ? 1 : 0,
                                ),
                              ],
                            )
                          : null,
                      child: DominoTileWidget(
                        left: t.a,
                        right: t.b,
                        width: tw,
                        height: th,
                        horizontal: false,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  لافتة نهاية الجولة
  // ─────────────────────────────────────────────
  Widget _buildRoundBanner() {
    final w = _engine.roundWinner;
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (_, s, __) => Transform.scale(
              scale: s,
              child: Container(
                margin: const EdgeInsets.all(28),
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A2A), Color(0xFF0C1F14)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border:
                      Border.all(color: _teal.withOpacity(0.55), width: 1.4),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.6), blurRadius: 26),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      w == null ? '🔒 بلوك!'.tr : '⚫ دومينو!'.tr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      w == null
                          ? 'تعادل — لا نقاط'.tr
                          : '{} يكسب +{} نقطة'
                              .trp([_engine.names[w], _engine.roundPoints]),
                      style: const TextStyle(
                          color: Color(0xFFB8D4C8), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '{} : {} — {} : {}'.trp([
                        _engine.names[0],
                        _engine.scores[0],
                        _engine.names[1],
                        _engine.scores[1],
                      ]),
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 14,
                          fontWeight: FontWeight.w900),
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

  // ─────────────────────────────────────────────
  //  درع تمرير الجهاز (وضع صديق)
  // ─────────────────────────────────────────────
  Widget _buildTurnShield() {
    final p = _shieldFor!;
    return Positioned.fill(
      child: Container(
        color: const Color(0xF20A1210),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔄', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text(
                'مرّر الجهاز إلى'.tr,
                style: const TextStyle(
                    color: Color(0xFFB8C4DC),
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _engine.names[p],
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () {
                  AppHaptics.medium();
                  setState(() => _shieldFor = null);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE082), _gold, Color(0xFFB8860B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'أنا جاهز — ابدأ دوري ⚫'.tr,
                    style: const TextStyle(
                        color: Color(0xFF1B0B30),
                        fontSize: 14,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final win = _engine.matchWinner == 0;
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
                          ? 'وصلت {} نقطة أولاً!'.trp([_engine.target])
                          : 'وصل {} إلى {} نقطة'
                              .trp([_engine.names[1], _engine.target]),
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

/// ويدجت حجر دومينو عاجي — horizontal: يمين/يسار جنباً إلى جنب
class DominoTileWidget extends StatelessWidget {
  final int left;
  final int right;
  final double width;
  final double height;
  final bool horizontal;

  const DominoTileWidget({
    super.key,
    required this.left,
    required this.right,
    required this.width,
    required this.height,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final short = math.min(width, height);
    // خط الوسط المحفور + مسمار نحاسي في منتصفه
    final divider = SizedBox(
      width: horizontal ? 2.2 : null,
      height: horizontal ? null : 2.2,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: horizontal
                ? EdgeInsets.symmetric(vertical: short * 0.12)
                : EdgeInsets.symmetric(horizontal: short * 0.12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8C7A55), Color(0xFFFFFFFF)],
              ),
            ),
          ),
          Container(
            width: short * 0.16,
            height: short * 0.16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.3),
                colors: [Color(0xFFFFE6A3), Color(0xFFB8862B)],
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFFAF5E9), Color(0xFFE9DEC6)],
        ),
        borderRadius: BorderRadius.circular(short * 0.18),
        border: Border.all(color: const Color(0xFFD2C4A3), width: 0.9),
        boxShadow: [
          // سماكة الحجر العاجية
          const BoxShadow(
              color: Color(0xFFB8A882), offset: Offset(0, 2.4), blurRadius: 0),
          // ظل أرضي ناعم
          BoxShadow(
              color: Colors.black.withOpacity(0.42),
              blurRadius: 6,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Container(
        // حافة ضوء علوية ناعمة (بيفل)
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(short * 0.18),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.9), width: 0.8),
            left: BorderSide(color: Colors.white.withOpacity(0.6), width: 0.6),
          ),
        ),
        child: horizontal
            ? Row(
                children: [
                  Expanded(child: _DominoFace(value: left)),
                  divider,
                  Expanded(child: _DominoFace(value: right)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _DominoFace(value: left)),
                  divider,
                  Expanded(child: _DominoFace(value: right)),
                ],
              ),
      ),
    );
  }
}

/// وجه نصف حجر — نقاط 0..6 بمواضع قياسية
class _DominoFace extends StatelessWidget {
  final int value;
  const _DominoFace({required this.value});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DominoFacePainter(value));
  }
}

class _DominoFacePainter extends CustomPainter {
  final int value;
  const _DominoFacePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    if (value == 0) return;
    final w = size.width, h = size.height;
    final r = math.min(w, h) * 0.115;
    // نقاط محفورة: لون مميز لكل رقم + ظل داخلي علوي وحافة ضوء سفلية
    const inks = [
      Color(0xFF1F2937),
      Color(0xFF1D4ED8), // 1
      Color(0xFF15803D), // 2
      Color(0xFFB91C1C), // 3
      Color(0xFF7E22CE), // 4
      Color(0xFFC2410C), // 5
      Color(0xFF0F172A), // 6
    ];
    final ink = inks[value.clamp(0, 6)];

    Offset at(double fx, double fy) => Offset(w * fx, h * fy);
    final spots = <Offset>[
      if (value == 1) at(0.5, 0.5),
      if (value == 2 || value == 3) ...[at(0.28, 0.28), at(0.72, 0.72)],
      if (value == 3) at(0.5, 0.5),
      if (value == 4 || value == 5 || value == 6) ...[
        at(0.28, 0.28),
        at(0.72, 0.28),
        at(0.28, 0.72),
        at(0.72, 0.72),
      ],
      if (value == 5) at(0.5, 0.5),
      if (value == 6) ...[at(0.28, 0.5), at(0.72, 0.5)],
    ];
    final rim = Paint()..color = Colors.white.withOpacity(0.85);
    for (final s in spots) {
      canvas.drawCircle(s + Offset(0, r * 0.22), r, rim);
      canvas.drawCircle(
        s,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 0.45),
            radius: 0.9,
            colors: [Color.lerp(ink, Colors.white, 0.18)!, ink],
          ).createShader(Rect.fromCircle(center: s, radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_DominoFacePainter old) => old.value != value;
}
