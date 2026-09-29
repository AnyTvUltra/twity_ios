import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../games/backgammon/backgammon_engine.dart';
import '../games/backgammon/bg_audio.dart';
import '../games/backgammon/bg_themes.dart';
import '../games/backgammon/widgets/bg_chat.dart';
import '../games/backgammon/widgets/bg_geometry.dart';
import '../games/backgammon/widgets/bg_painters.dart';
import '../games/backgammon/widgets/bg_result_overlay.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../utils/format.dart';
import '../widgets/user_avatar.dart';
import '../l10n/app_lang.dart';

/// حجر في حالة طيران (حركة/ضرب/إخراج/عودة بعد إفلات خاطئ)
class _Flight {
  final int side;
  final Offset from, to;
  final AnimationController ctrl;
  final double arc;
  final bool toSlab;
  final double slabWidth;
  final bool victim;

  _Flight(this.side, this.from, this.to, this.ctrl,
      {this.arc = 1,
      this.toSlab = false,
      this.slabWidth = 0,
      this.victim = false});
}

class _Burst {
  final Offset pos;
  final AnimationController ctrl;
  final bool small;
  _Burst(this.pos, this.ctrl, {this.small = false});
}

/// حجر في أنيميشن الافتتاح (يتطاير من خارج اللوح إلى مكانه)
class _IntroPiece {
  final int side;
  final Offset start, target;
  final double delay;
  final int seed;
  bool landed = false;
  _IntroPiece(this.side, this.start, this.target, this.delay, this.seed);
}

class _RectClipper extends CustomClipper<Rect> {
  final Rect rect;
  _RectClipper(this.rect);
  @override
  Rect getClip(Size size) => rect;
  @override
  bool shouldReclip(_RectClipper old) => old.rect != rect;
}

class BackgammonGameScreen extends StatefulWidget {
  /// true = ضد الذكاء الاصطناعي، false = لاعبان على نفس الجهاز
  final bool vsAI;
  final int bet;

  const BackgammonGameScreen({super.key, this.vsAI = true, this.bet = 0});

  @override
  State<BackgammonGameScreen> createState() => _BackgammonGameScreenState();
}

class _BackgammonGameScreenState extends State<BackgammonGameScreen>
    with TickerProviderStateMixin {
  final BackgammonEngine _e = BackgammonEngine();
  final math.Random _rnd = math.Random();

  BgGeom? _g;
  final Map<String, int> _hidden = {};
  final List<_Flight> _flights = [];
  final List<_Burst> _bursts = [];

  bool _busy = true;
  bool _opening = true;
  bool _rolling = false;
  List<int> _faces = [1, 1];

  int? _selected;
  Map<int, List<BgMove>> _paths = {};
  int? _dragFrom;

  /// موضع الحجر المسحوب — ValueNotifier حتى لا يُعاد بناء اللوح مع كل
  /// حركة إصبع (سبب التقطيع في السحب)
  final ValueNotifier<Offset?> _dragVN = ValueNotifier<Offset?>(null);
  int? _hover;

  String? _notice;
  Timer? _noticeTimer;
  bool _showResult = false;
  int _resultChips = 0;

  // مراحل الافتتاح
  bool _lidPhase = true;
  bool _introPhase = false;
  List<_IntroPiece> _introPieces = [];

  // الدردشة
  bool _chatOpen = false;
  final Map<int, BgChatMsg> _bubbles = {};
  bool _confirmExit = false;

  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  late final AnimationController _diceCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _fx =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));
  late final AnimationController _lid = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  static const _mint = Color(0xFF3FF5A8);
  static const _gold = Color(0xFFFFD54F);
  static const _red = Color(0xFFEF4444);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  BgBoardTheme get _theme => BgThemes.boardFromItemId(
      StoreService().equippedFor(StoreCategory.bgBoard)?.id);
  BgCheckerSet get _set => BgThemes.checkersFromItemId(
      StoreService().equippedFor(StoreCategory.bgCheckers)?.id);

  BgBotLevel get _level => widget.bet >= 1000
      ? BgBotLevel.hard
      : (widget.bet >= 250 ? BgBotLevel.medium : BgBotLevel.easy);

  bool get _isHumanTurn => !widget.vsAI || _e.turn == 0;

  bool get _canAct =>
      !_busy &&
      !_opening &&
      !_rolling &&
      _e.winner == null &&
      _e.hasRolled &&
      _isHumanTurn;

  bool get _awaitingRoll =>
      !_busy &&
      !_opening &&
      !_rolling &&
      _e.winner == null &&
      !_e.hasRolled &&
      _isHumanTurn;

  @override
  void initState() {
    super.initState();
    StoreService().ensureWoodBase();
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (_theme.animated || _set.animated) _fx.repeat();
    _intro.addListener(_onIntroTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runLid());
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _noticeTimer?.cancel();
    for (final f in _flights) {
      f.ctrl.dispose();
    }
    for (final b in _bursts) {
      b.ctrl.dispose();
    }
    _pulse.dispose();
    _diceCtrl.dispose();
    _shake.dispose();
    _fx.dispose();
    _lid.dispose();
    _intro.dispose();
    _dragVN.dispose();
    _e.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════
  // الافتتاح: الغطاء ينفتح ثم الأحجار تتطاير لأماكنها
  // ══════════════════════════════════════════════════════

  Future<void> _runLid() async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    BgAudio.open();
    try {
      await _lid.forward(from: 0).orCancel;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    _shake.forward(from: 0);
    setState(() => _lidPhase = false);
    await Future.delayed(const Duration(milliseconds: 150));
    _runIntro();
  }

  Future<void> _runIntro() async {
    final g = _g;
    if (g == null || !mounted) return;
    final s = _e.state;
    final pieces = <_IntroPiece>[];
    for (int i = 0; i < 24; i++) {
      final n = s.pts[i].abs();
      for (int k = 0; k < n; k++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        final start = g.size.center(Offset.zero) +
            Offset(math.cos(a) * g.size.width * 0.75,
                math.sin(a) * g.size.height * 0.95);
        pieces.add(_IntroPiece(
            s.pts[i] > 0 ? 0 : 1, start, g.checker(i, k, n), 0, i * 5 + k));
      }
    }
    pieces.shuffle(_rnd);
    _introPieces = [
      for (int i = 0; i < pieces.length; i++)
        _IntroPiece(pieces[i].side, pieces[i].start, pieces[i].target,
            i / pieces.length * 0.58, pieces[i].seed)
    ];
    setState(() => _introPhase = true);
    try {
      await _intro.forward(from: 0).orCancel;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _introPhase = false);
    _startOpening();
  }

  int _landedCount = 0;
  void _onIntroTick() {
    for (final p in _introPieces) {
      if (!p.landed && _introLocal(p) >= 1) {
        p.landed = true;
        if (_landedCount++ % 3 == 0) BgAudio.place(volume: 0.5);
      }
    }
  }

  double _introLocal(_IntroPiece p) =>
      ((_intro.value - p.delay) / 0.42).clamp(0.0, 1.0);

  // ══════════════════════════════════════════════════════
  // تدفق اللعب
  // ══════════════════════════════════════════════════════

  void _toast(String msg, {int ms = 1600}) {
    _noticeTimer?.cancel();
    setState(() => _notice = msg);
    _noticeTimer = Timer(Duration(milliseconds: ms), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _startOpening() async {
    setState(() {
      _opening = true;
      _busy = true;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final (a, b) = _e.rollOpening();
    await _animateDice(a, b);
    if (!mounted) return;
    final who = _e.turn == 0
        ? 'أنت تبدأ! 🎲'.tr
        : (widget.vsAI ? 'الخصم يبدأ'.tr : 'اللاعب 2 يبدأ'.tr);
    _toast('{} ضد {} — {}'.trp([a, b, who]), ms: 1500);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _opening = false;
      _busy = false;
    });
    _afterRoll();
  }

  Future<void> _animateDice(int a, int b) async {
    BgAudio.dice();
    setState(() => _rolling = true);
    void tick() {
      if (!mounted) return;
      if (_diceCtrl.value < 0.78) {
        setState(() => _faces = [_rnd.nextInt(6) + 1, _rnd.nextInt(6) + 1]);
      } else if (_faces[0] != a || _faces[1] != b) {
        setState(() => _faces = [a, b]);
      }
    }

    _diceCtrl.addListener(tick);
    try {
      await _diceCtrl.forward(from: 0).orCancel;
    } catch (_) {}
    _diceCtrl.removeListener(tick);
    if (!mounted) return;
    setState(() {
      _faces = [a, b];
      _rolling = false;
    });
  }

  Future<void> _humanRoll() async {
    if (!_awaitingRoll) return;
    setState(() => _busy = true);
    final (a, b) = _e.roll();
    await _animateDice(a, b);
    if (!mounted) return;
    setState(() => _busy = false);
    _afterRoll();
  }

  Future<void> _afterRoll() async {
    if (_e.legalMoves().isEmpty) {
      _toast(_isHumanTurn ? 'لا توجد حركات متاحة 😕'.tr : 'الخصم لا يملك حركات'.tr);
      setState(() => _busy = true);
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      setState(() => _busy = false);
      _endTurn();
      return;
    }
    if (!_isHumanTurn) _botPlay();
  }

  void _endTurn() {
    if (_e.winner != null) return;
    _clearSelection();
    _e.endTurn();
    setState(() {});
    if (widget.vsAI && _e.turn == 1) _botTurn();
  }

  Future<void> _botTurn() async {
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    final (a, b) = _e.roll();
    await _animateDice(a, b);
    if (!mounted) return;
    if (a == b && _rnd.nextDouble() < 0.35) _botSay(BgChatMsg('🔥', emoji: true));
    setState(() => _busy = false);
    _afterRoll();
  }

  Future<void> _botPlay() async {
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 450));
    final seq = _e.bestSequence(level: _level);
    for (final m in seq) {
      if (!mounted) return;
      await _executePath([m]);
      if (_e.winner != null) break;
      await Future.delayed(const Duration(milliseconds: 220));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (_e.winner != null) {
      _onGameOver();
    } else {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) _endTurn();
    }
  }

  Future<void> _afterHumanMove() async {
    if (_e.winner != null) {
      _onGameOver();
      return;
    }
    if (_e.dice.isEmpty || _e.legalMoves().isEmpty) {
      setState(() => _busy = true);
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      setState(() => _busy = false);
      _endTurn();
    }
  }

  Future<void> _onGameOver() async {
    setState(() => _busy = true);
    final win = _e.winner == 0;
    final mult = _e.winMultiplier;
    if (widget.vsAI) {
      _botSay(win ? BgChatMsg('أحسنت 👏'.tr) : BgChatMsg('😎', emoji: true));
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    int chips = 0;
    if (widget.vsAI && widget.bet > 0) {
      chips = win ? widget.bet * mult : -widget.bet * mult;
      AuthService().updateMatchResult(
        chipChange: chips,
        ratingChange: win ? 12 * mult : -10 * mult,
        isWin: win,
      );
    }
    (win || !widget.vsAI) ? BgAudio.win() : BgAudio.lose();
    setState(() {
      _resultChips = chips;
      _showResult = true;
    });
  }

  void _rematch() {
    _clearSelection();
    _e.reset();
    setState(() {
      _showResult = false;
      _hidden.clear();
      _busy = true;
      _opening = true;
      _landedCount = 0;
    });
    _runIntro();
  }

  void _requestExit() {
    if (_e.winner != null || !widget.vsAI || widget.bet == 0) {
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

  // ── الدردشة ──
  void _send(BgChatMsg m) {
    BgAudio.pop();
    setState(() {
      _bubbles[0] = m;
      _chatOpen = false;
    });
    if (widget.vsAI) {
      final reply = BgChat.botReply(m, _rnd);
      if (reply != null) {
        Future.delayed(Duration(milliseconds: 1100 + _rnd.nextInt(900)), () {
          if (mounted) _botSay(reply);
        });
      }
    }
  }

  void _botSay(BgChatMsg m) {
    if (!mounted) return;
    BgAudio.pop();
    setState(() => _bubbles[1] = m);
  }

  // ══════════════════════════════════════════════════════
  // الحركة والأنيميشن
  // ══════════════════════════════════════════════════════

  String _key(int loc, int side) => loc == BgMove.bar
      ? 'bar$side'
      : (loc == BgMove.off ? 'off$side' : 'p$loc');

  Offset _topPos(int loc, int side) {
    final g = _g!, s = _e.state;
    if (loc == BgMove.bar) {
      final n = math.max(1, s.bar[side]);
      return g.barChecker(side, n - 1, n);
    }
    if (loc == BgMove.off) {
      return g.offSlab(side, math.max(0, s.off[side] - 1)).center;
    }
    final n = math.max(1, s.countAt(loc, side));
    return g.checker(loc, n - 1, n);
  }

  Future<void> _fly(int side, Offset from, Offset to, String hideKey,
      {required Duration dur,
      Duration delay = Duration.zero,
      double arc = 1,
      bool toSlab = false,
      bool victim = false}) async {
    final ctrl = AnimationController(vsync: this, duration: dur);
    final f = _Flight(side, from, to, ctrl,
        arc: arc,
        toSlab: toSlab,
        slabWidth: toSlab ? _g!.offSlab(side, 0).width : 0,
        victim: victim);
    setState(() {
      _hidden[hideKey] = (_hidden[hideKey] ?? 0) + 1;
      victim ? _flights.insert(0, f) : _flights.add(f);
    });
    if (delay > Duration.zero) await Future.delayed(delay);
    if (!mounted) return;
    try {
      await ctrl.forward().orCancel;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _hidden[hideKey] = (_hidden[hideKey] ?? 1) - 1;
      _flights.remove(f);
    });
    ctrl.dispose();
  }

  void _burst(Offset p, {bool small = false}) {
    final ctrl = AnimationController(
        vsync: this, duration: Duration(milliseconds: small ? 500 : 650));
    final b = _Burst(p, ctrl, small: small);
    setState(() => _bursts.add(b));
    ctrl.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _bursts.remove(b));
      ctrl.dispose();
    });
  }

  Future<void> _executePath(List<BgMove> path, {Offset? start}) async {
    final g = _g;
    if (g == null) return;
    final side = _e.turn;
    for (final m in path) {
      final from = start ?? _topPos(m.from, side);
      start = null;
      final victimFrom = m.hit ? g.checker(m.to, 0, 1) : null;
      _e.applyMove(m);
      final to = _topPos(m.to, side);
      final dist = (to - from).distance;
      final off = m.to == BgMove.off;
      final dur = Duration(
          milliseconds:
              (280 + dist / g.size.width * 520 + (off ? 180 : 0)).round());
      final futures = <Future>[
        _fly(side, from, to, _key(m.to, side),
            dur: dur, arc: off ? 1.4 : 1, toSlab: off),
      ];
      if (m.hit && victimFrom != null) {
        final v = 1 - side;
        futures.add(_fly(v, victimFrom, _topPos(BgMove.bar, v), 'bar$v',
            dur: const Duration(milliseconds: 620),
            delay: dur,
            arc: 1.8,
            victim: true));
        Future.delayed(dur, () {
          if (!mounted) return;
          BgAudio.hit();
          _burst(to);
          _shake.forward(from: 0);
          if (widget.vsAI && _rnd.nextDouble() < 0.45) {
            _botSay(side == 1
                ? BgChatMsg(_rnd.nextBool() ? '😎' : '😏', emoji: true)
                : (_rnd.nextBool()
                    ? BgChatMsg('ما هذا الحظ؟! 😤'.tr)
                    : BgChatMsg('😡', emoji: true)));
          }
        });
      } else {
        Future.delayed(dur, () {
          if (!mounted) return;
          if (off) {
            BgAudio.bearOff();
            _burst(to, small: true);
          } else {
            BgAudio.place();
          }
        });
      }
      await Future.wait(futures);
      if (_e.winner != null) break;
    }
  }

  void _clearSelection() {
    _selected = null;
    _paths = {};
    _hover = null;
  }

  int? _sourceAt(Offset p) {
    final hit = _g!.hitTest(p);
    if (hit == null || hit == 24) return null;
    if (hit == -1) return _e.state.bar[_e.turn] > 0 ? -1 : null;
    return _e.state.countAt(hit, _e.turn) > 0 ? hit : null;
  }

  bool _trySelect(int? src) {
    if (src == null) return false;
    if (!_e.movableSources().contains(src)) {
      BgAudio.illegal();
      if (_e.state.bar[_e.turn] > 0 && src != -1) {
        _toast('أدخل الحجر من البار أولاً ⚠️'.tr);
      }
      return false;
    }
    BgAudio.pick();
    setState(() {
      _selected = src;
      _paths = _e.pathsFrom(src);
    });
    return true;
  }

  void _onTapUp(Offset p) {
    if (_awaitingRoll) {
      _humanRoll();
      return;
    }
    if (!_canAct) return;
    final hit = _g!.hitTest(p);
    if (_selected != null && hit != null && _paths.containsKey(hit)) {
      final path = _paths[hit]!;
      setState(_clearSelection);
      _runHuman(path);
      return;
    }
    final src = _sourceAt(p);
    if (src != null && src == _selected) {
      setState(_clearSelection);
      return;
    }
    if (!_trySelect(src)) setState(_clearSelection);
  }

  Future<void> _runHuman(List<BgMove> path, {Offset? start}) async {
    setState(() => _busy = true);
    await _executePath(path, start: start);
    if (!mounted) return;
    setState(() => _busy = false);
    _afterHumanMove();
  }

  void _onPanStart(Offset p) {
    if (!_canAct) return;
    final src = _sourceAt(p);
    if (!_trySelect(src)) return;
    final key = _key(src!, _e.turn);
    setState(() {
      _dragFrom = src;
      _hidden[key] = (_hidden[key] ?? 0) + 1;
    });
    _dragVN.value = p;
  }

  void _onPanUpdate(Offset p) {
    if (_dragFrom == null) return;
    final hit = _g!.hitTest(p);
    final newHover = hit != null && _paths.containsKey(hit) ? hit : null;
    // تحريك الحجر فورياً بدون إعادة بناء اللوح — setState فقط عند
    // تغيّر خانة الهدف لتحديث توهّجها
    _dragVN.value = p;
    if (newHover != _hover) setState(() => _hover = newHover);
  }

  void _onPanEnd() {
    final src = _dragFrom;
    final pos = _dragVN.value;
    _dragVN.value = null;
    if (src == null || pos == null) return;
    final key = _key(src, _e.turn);
    final target = _hover;
    setState(() {
      _hidden[key] = (_hidden[key] ?? 1) - 1;
      _dragFrom = null;
      _hover = null;
    });
    if (target != null) {
      final path = _paths[target]!;
      setState(_clearSelection);
      _runHuman(path, start: pos);
    } else {
      _fly(_e.turn, pos, _topPos(src, _e.turn), key,
          dur: const Duration(milliseconds: 260), arc: 0.3);
    }
  }

  void _undo() {
    if (!_canAct || !_e.canUndo) return;
    _e.undo();
    BgAudio.place();
    setState(_clearSelection);
  }

  // ══════════════════════════════════════════════════════
  // الواجهة — أفقية دائماً (تُدار 90° على الشاشات الطولية)
  // ══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rotate = media.orientation == Orientation.portrait;
    final data = rotate
        ? media.copyWith(
            size: Size(media.size.height, media.size.width),
            padding: EdgeInsets.fromLTRB(media.padding.top,
                media.padding.right, media.padding.bottom, media.padding.left),
          )
        : media;
    final game = MediaQuery(data: data, child: _landscape());
    return Directionality(
      textDirection: TextDirection.ltr,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _requestExit();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF03050D),
          body: rotate ? RotatedBox(quarterTurns: 1, child: game) : game,
        ),
      ),
    );
  }

  Widget _landscape() {
    final user = AuthService().currentUser;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 1.3,
          colors: [Color(0xFF1A2752), Color(0xFF0B1226), Color(0xFF03050D)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(builder: (context, c) {
          final sideW = (c.maxWidth * 0.17).clamp(112.0, 172.0);
          return Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: sideW,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Row(
                            children: [
                              _glassBtn(Icons.arrow_back_ios_new_rounded,
                                  _requestExit),
                              const Spacer(),
                              if (widget.bet > 0) _betChip(),
                            ],
                          ),
                        ),
                        _playerCard(
                          side: 1,
                          name: widget.vsAI ? 'الخصم الذكي'.tr : 'اللاعب 2'.tr,
                          avatar: _botAvatar(),
                        ),
                        const Spacer(),
                        if (!widget.vsAI && _e.turn == 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _actionButtons(),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: _chatButton(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _boardArea()),
                  SizedBox(
                    width: sideW,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Row(
                            children: [
                              const Spacer(),
                              _glassBtn(Icons.flag_rounded, _requestExit),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (widget.vsAI || _e.turn == 0) _actionButtons(),
                        const SizedBox(height: 8),
                        _playerCard(
                          side: 0,
                          name: user?.displayName ?? 'أنت'.tr,
                          avatar: UserAvatar(
                              photoUrl: user?.photoUrl ?? '',
                              name: user?.displayName ?? '',
                              size: 42),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),

              // فقاعات الدردشة بجانب البطاقتين
              if (_bubbles[1] != null)
                Positioned(
                  left: sideW - 6,
                  top: 56,
                  child: BgChatBubble(
                    key: ValueKey(_bubbles[1]!.id),
                    msg: _bubbles[1]!,
                    pointLeft: true,
                    onDone: () => setState(() => _bubbles.remove(1)),
                  ),
                ),
              if (_bubbles[0] != null)
                Positioned(
                  right: sideW - 6,
                  bottom: 30,
                  child: BgChatBubble(
                    key: ValueKey(_bubbles[0]!.id),
                    msg: _bubbles[0]!,
                    pointLeft: false,
                    onDone: () => setState(() => _bubbles.remove(0)),
                  ),
                ),

              if (_chatOpen) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _chatOpen = false),
                    child: Container(color: Colors.black26),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 60,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: BgChatPanel(
                      onSend: _send,
                      onClose: () => setState(() => _chatOpen = false),
                    ),
                  ),
                ),
              ],

              if (_confirmExit) _exitDialog(),

              if (_showResult)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: BgResultOverlay(
                    win: _e.winner == 0,
                    multiplier: _e.winMultiplier,
                    chips: _resultChips,
                    title: widget.vsAI
                        ? (_e.winner == 0 ? 'فزت! 🎉'.tr : 'خسرت الجولة'.tr)
                        : (_e.winner == 0 ? 'فاز اللاعب 1'.tr : 'فاز اللاعب 2'.tr),
                    onRematch: _rematch,
                    onExit: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _exitDialog() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xF2141C34),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _red.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Text('🏳️', style: TextStyle(fontSize: 44)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الانسحاب؟'.tr,
                          style: TextStyle(
                              color: _textWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('ستخسر رهانك {} 🪙'.trp([widget.bet]),
                          style:
                              const TextStyle(color: _textDim, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _pill('متابعة'.tr, _mint,
                                const Color(0xFF052E1C),
                                () => setState(() => _confirmExit = false)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _pill('انسحاب'.tr, _red, Colors.white,
                                _resignConfirmed),
                          ),
                        ],
                      ),
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

  Widget _betChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x3316204A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.45)),
      ),
      child: Text('🪙 ${formatBalance(widget.bet)}',
          style: const TextStyle(
              color: _gold, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x26FFFFFF)),
            ),
            child: Icon(icon, color: _textDim, size: 17),
          ),
        ),
      ),
    );
  }

  Widget _chatButton() {
    return GestureDetector(
      onTap: () => setState(() => _chatOpen = !_chatOpen),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('😎', style: TextStyle(fontSize: 18)),
            SizedBox(width: 6),
            Text('دردشة'.tr,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _botAvatar() {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient:
            LinearGradient(colors: [Color(0xFF374151), Color(0xFF0B0C10)]),
      ),
      child: const Center(child: Text('🤖', style: TextStyle(fontSize: 21))),
    );
  }

  /// بطاقة اللاعب العمودية المدمجة (تناسب العمود الجانبي)
  Widget _playerCard({
    required int side,
    required String name,
    required Widget avatar,
  }) {
    final active = _e.turn == side && _e.winner == null && !_opening;
    final s = _e.state;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0x331A2550),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: active
                  ? _mint.withValues(alpha: 0.5 + 0.4 * _pulse.value)
                  : const Color(0x22FFFFFF),
              width: active ? 1.6 : 1),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: _mint.withValues(alpha: 0.12 + 0.12 * _pulse.value),
                      blurRadius: 18,
                      spreadRadius: -2)
                ]
              : null,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  avatar,
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _textWhite,
                                fontWeight: FontWeight.w900,
                                fontSize: 12)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CustomPaint(
                                  painter:
                                      CheckerPainter(style: _set.of(side))),
                            ),
                            const SizedBox(width: 4),
                            Text('${s.pip(side)}',
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // تقدّم الإخراج
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Container(height: 6, color: const Color(0x22FFFFFF)),
                    FractionallySizedBox(
                      widthFactor: s.off[side] / 15,
                      child: Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0xFFFFE082), _gold]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                active && !_isHumanTurn
                    ? 'يفكر…'.tr
                    : (active ? 'دورك'.tr : 'خرج {}/15'.trp([s.off[side]])),
                style: TextStyle(
                    color: active ? _mint : _textDim,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButtons() {
    final ready = _awaitingRoll;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: ready ? 1 : 0.35,
              child: GestureDetector(
                onTap: ready ? _humanRoll : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFE082), _gold, Color(0xFFE8A820)],
                    ),
                    border: Border.all(color: const Color(0xFFFFF1C4)),
                    boxShadow: ready
                        ? [
                            BoxShadow(
                                color: _gold.withValues(
                                    alpha: 0.25 + 0.35 * _pulse.value),
                                blurRadius: 18)
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: CustomPaint(painter: DicePainter(5))),
                      const SizedBox(width: 6),
                      Text('ارمِ'.tr,
                          style: TextStyle(
                              color: Color(0xFF1B0B30),
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_canAct && _e.canUndo) ...[
            const SizedBox(height: 6),
            _pill('↶ تراجع'.tr, const Color(0x22FFFFFF), _textWhite, _undo),
          ],
        ],
      ),
    );
  }

  Widget _pill(String label, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: fg, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // اللوح
  // ══════════════════════════════════════════════════════

  Widget _boardArea() {
    return LayoutBuilder(builder: (context, c) {
      const aspect = 1.45;
      final bw = math.min(c.maxWidth - 8, (c.maxHeight - 10) * aspect);
      final size = Size(bw, bw / aspect);
      if (_g == null || _g!.size != size) _g = BgGeom(size);
      return Stack(
        alignment: Alignment.center,
        children: [
          Center(
              child: SizedBox.fromSize(
                  size: size, child: _lidPhase ? _lidView() : _board())),
          IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                  child: FadeTransition(opacity: a, child: child)),
              child: _notice == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(_notice),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xE60B1226),
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: _mint.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                              color: _mint.withValues(alpha: 0.2),
                              blurRadius: 20)
                        ],
                      ),
                      child: Text(_notice!,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                              color: _textWhite,
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ),
            ),
          ),
        ],
      );
    });
  }

  Widget _boardPaint(BgGeom g) => CustomPaint(
        size: g.size,
        painter: BackgammonBoardPainter(g,
            theme: _theme, wood: StoreService().defaultWoodImage),
      );

  /// الطاولي المغلق ← النصف الأيسر ينقلب كالغطاء حول المفصل (البار)
  Widget _lidView() {
    final g = _g!;
    final cx = g.size.width / 2;
    return AnimatedBuilder(
      animation: Listenable.merge([_lid, StoreService()]),
      builder: (_, __) {
        final t = _lid.value;
        final appear = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
        final p = Curves.easeInCubic.transform(((t - 0.15) / 0.7).clamp(0.0, 1.0));
        final angle = -math.pi * (1 - p);
        final exterior = angle.abs() > math.pi / 2;
        final lidShadow = (1 - p) * 0.6;
        return Transform.scale(
          scale: 0.85 + 0.15 * appear,
          child: Opacity(
            opacity: appear.clamp(0.0, 1.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRect(
                  clipper:
                      _RectClipper(Rect.fromLTRB(cx, -20, g.size.width, g.size.height + 30)),
                  child: _boardPaint(g),
                ),
                Positioned(
                  left: cx,
                  top: 0,
                  width: cx,
                  height: g.size.height,
                  child: IgnorePointer(
                    child: Container(
                        color: Colors.black.withValues(alpha: lidShadow * 0.5)),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  width: cx,
                  height: g.size.height,
                  child: Transform(
                    alignment: Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0011)
                      ..rotateY(angle),
                    child: exterior
                        ? CustomPaint(
                            size: Size(cx, g.size.height),
                            painter: BoardLidPainter(_theme,
                                wood: StoreService().defaultWoodImage))
                        : ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              minWidth: g.size.width,
                              maxWidth: g.size.width,
                              child: _boardPaint(g),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _board() {
    final g = _g!;
    final theme = _theme;
    final set = _set;
    return AnimatedBuilder(
      animation: Listenable.merge([_e, _shake, StoreService()]),
      builder: (context, _) {
        final st = _shake.value;
        final shake = st == 0 || st == 1
            ? Offset.zero
            : Offset(math.sin(st * math.pi * 9) * (1 - st) * 5,
                math.cos(st * math.pi * 7) * (1 - st) * 2);
        return Transform.translate(
          offset: shake,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTapUp(d.localPosition),
            onPanStart: (d) => _onPanStart(d.localPosition),
            onPanUpdate: (d) => _onPanUpdate(d.localPosition),
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: _onPanEnd,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RepaintBoundary(child: _boardPaint(g)),
                if (theme.animated)
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: _fx,
                      builder: (_, __) => CustomPaint(
                          size: g.size,
                          painter: BoardEffectPainter(g, theme, _fx.value)),
                    ),
                  ),
                if (_paths.isNotEmpty)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => CustomPaint(
                      size: g.size,
                      painter: TargetsPainter(
                          g, _paths.keys.toSet(), _pulse.value,
                          hover: _hover),
                    ),
                  ),
                CustomPaint(
                  size: g.size,
                  painter: OffTrayPainter(
                      g,
                      [
                        _e.state.off[0] - (_hidden['off0'] ?? 0),
                        _e.state.off[1] - (_hidden['off1'] ?? 0),
                      ],
                      set),
                ),
                if (_introPhase)
                  ..._introCheckers(g, set)
                else if (set.animated)
                  AnimatedBuilder(
                    animation: _fx,
                    builder: (_, __) => Stack(
                        clipBehavior: Clip.none,
                        children: _checkers(g, set)),
                  )
                else
                  ..._checkers(g, set),
                ..._dice(g),
                ..._flights.map((f) => _flightWidget(g, f, set)),
                ValueListenableBuilder<Offset?>(
                  valueListenable: _dragVN,
                  builder: (_, pos, __) => pos == null
                      ? const SizedBox.shrink()
                      : _dragWidget(g, set, pos),
                ),
                ..._bursts.map((b) => _burstWidget(g, b)),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _introCheckers(BgGeom g, BgCheckerSet set) {
    return [
      AnimatedBuilder(
        animation: _intro,
        builder: (_, __) => Stack(
          clipBehavior: Clip.none,
          children: [
            for (final p in _introPieces)
              if (_introLocal(p) > 0)
                Builder(builder: (_) {
                  final lt = _introLocal(p);
                  final e = Curves.easeOutCubic.transform(lt);
                  final lift = math.sin(math.pi * lt);
                  final pos = Offset.lerp(p.start, p.target, e)! -
                      Offset(0, lift * g.size.height * 0.22);
                  final scale = 1 + 0.6 * lift;
                  return Positioned(
                    left: pos.dx - g.d / 2,
                    top: pos.dy - g.d / 2,
                    width: g.d,
                    height: g.d,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX((1 - e) * 1.1)
                        ..scaleByDouble(scale, scale, 1, 1),
                      child: CustomPaint(
                        painter: CheckerPainter(
                            style: set.of(p.side),
                            lift: lift,
                            time: _fx.value,
                            seed: p.seed),
                      ),
                    ),
                  );
                }),
          ],
        ),
      ),
    ];
  }

  List<Widget> _checkers(BgGeom g, BgCheckerSet set) {
    final out = <Widget>[];
    final s = _e.state;
    final movable = _canAct && _selected == null && _dragFrom == null
        ? _e.movableSources()
        : const <int>{};

    void place(Offset c, int side, int seed,
        {bool glow = false, bool selected = false}) {
      Widget painter(double pulse) => CustomPaint(
            painter: CheckerPainter(
              style: set.of(side),
              glow: selected ? 1 : (glow ? 0.45 + 0.55 * pulse : 0),
              glowColor: selected ? _gold : _mint,
              time: _fx.value,
              seed: seed,
            ),
          );
      out.add(Positioned(
        left: c.dx - g.d / 2,
        top: c.dy - g.d / 2,
        width: g.d,
        height: g.d,
        child: IgnorePointer(
          child: glow || selected
              ? AnimatedBuilder(
                  animation: _pulse, builder: (_, __) => painter(_pulse.value))
              : painter(0),
        ),
      ));
    }

    for (int i = 0; i < 24; i++) {
      final v = s.pts[i];
      if (v == 0) continue;
      final side = v > 0 ? 0 : 1;
      final n = v.abs();
      final visible = n - (_hidden['p$i'] ?? 0);
      for (int k = 0; k < visible; k++) {
        final top = k == visible - 1 && visible == n;
        place(g.checker(i, k, n), side, i * 5 + k,
            glow: top && side == _e.turn && movable.contains(i),
            selected: top && side == _e.turn && _selected == i);
      }
    }
    for (int side = 0; side < 2; side++) {
      final n = s.bar[side];
      final visible = n - (_hidden['bar$side'] ?? 0);
      for (int k = 0; k < visible; k++) {
        final top = k == visible - 1 && visible == n;
        place(g.barChecker(side, k, n), side, 200 + k,
            glow: top && side == _e.turn && movable.contains(-1),
            selected: top && side == _e.turn && _selected == -1);
      }
    }
    return out;
  }

  List<Widget> _dice(BgGeom g) {
    if (!_e.hasRolled && !_rolling) return const [];
    final size = g.d * 1.08;
    final t = _diceCtrl.isAnimating || _rolling ? _diceCtrl.value : 1.0;
    final out = <Widget>[];

    for (int i = 0; i < 2; i++) {
      final Offset rest;
      final Offset start;
      if (_opening) {
        final half = i == 0 ? g.rightHalf : g.leftHalf;
        rest = half.center;
        start = Offset(i == 0 ? g.rightTray.center.dx : g.leftTray.center.dx,
            g.size.height * 0.8);
      } else {
        final half = _e.turn == 0 ? g.rightHalf : g.leftHalf;
        rest = half.center + Offset((i == 0 ? -1 : 1) * size * 0.75, 0);
        final tray = _e.turn == 0 ? g.rightTray : g.leftTray;
        start =
            Offset(tray.center.dx, g.size.height * (i == 0 ? 0.75 : 0.25));
      }
      final e = Curves.easeOutCubic.transform(t);
      final bounce = (math.sin(t * math.pi * 3.2)).abs() * (1 - t) * size * 1.6;
      final pos = Offset.lerp(start, rest, e)! - Offset(0, bounce);
      final angle = math.pow(1 - t, 2) * math.pi * 5 * (i == 0 ? 1 : -1);

      bool used = false;
      if (!_rolling && !_opening && _e.rolled.length == 2) {
        final a = _e.rolled[0], b = _e.rolled[1];
        used = a == b
            ? (i == 0 ? _e.dice.length <= 2 : _e.dice.isEmpty)
            : !_e.dice.contains(_e.rolled[i]);
      }

      out.add(Positioned(
        left: pos.dx - size / 2,
        top: pos.dy - size / 2,
        width: size,
        height: size,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: angle.toDouble(),
            child: Transform.scale(
              scale: 1 + (1 - t) * 0.25,
              child: CustomPaint(
                painter: DicePainter(_faces[i],
                    used: used,
                    pip: _opening && i == 1
                        ? const Color(0xFF111827)
                        : const Color(0xFF0E7490)),
              ),
            ),
          ),
        ),
      ));
    }

    if (!_rolling &&
        !_opening &&
        _e.rolled.length == 2 &&
        _e.rolled[0] == _e.rolled[1]) {
      final half = _e.turn == 0 ? g.rightHalf : g.leftHalf;
      out.add(Positioned(
        left: half.center.dx - 26,
        top: half.center.dy + size * 0.75,
        width: 52,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xCC0B1226),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withValues(alpha: 0.6)),
            ),
            child: Text('دبل ×{}'.trp([_e.dice.length]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _gold, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ),
      ));
    }
    return out;
  }

  Widget _flightWidget(BgGeom g, _Flight f, BgCheckerSet set) {
    return AnimatedBuilder(
      animation: f.ctrl,
      builder: (_, __) {
        final raw = f.ctrl.value;
        final t = f.victim
            ? Curves.easeInOutQuad.transform(raw)
            : Curves.easeInOutCubic.transform(raw);
        final lift = math.sin(math.pi * t);
        final dist = (f.to - f.from).distance;
        final h = g.d * 0.55 * f.arc * (0.6 + dist / g.size.width * 1.6);
        final pos = Offset.lerp(f.from, f.to, t)! - Offset(0, h * lift);
        final scale = 1 + 0.28 * lift * f.arc.clamp(0.3, 1.2);

        // الإخراج: الحجر ينقلب على حافته ويتمدد ليطابق الشريحة
        Matrix4 m = Matrix4.identity()..setEntry(3, 2, 0.002);
        if (f.toSlab && t > 0.5) {
          final k = Curves.easeInOut.transform((t - 0.5) / 0.5);
          final sx = 1 + (f.slabWidth / g.d - 1) * k;
          m
            ..rotateX(k * 1.32)
            ..scaleByDouble(sx * scale, scale, 1, 1);
        } else {
          m
            ..rotateZ(f.victim ? t * math.pi * 3 : 0)
            ..scaleByDouble(scale, scale, 1, 1);
        }

        final trail = <Widget>[];
        if (f.victim && raw > 0) {
          for (int k = 1; k <= 3; k++) {
            final tk = (t - k * 0.06).clamp(0.0, 1.0);
            final pk = Offset.lerp(f.from, f.to, tk)! -
                Offset(0, h * math.sin(math.pi * tk));
            trail.add(Positioned(
              left: pk.dx - g.d / 2,
              top: pk.dy - g.d / 2,
              width: g.d,
              height: g.d,
              child: Opacity(
                opacity: 0.22 / k,
                child: CustomPaint(
                    painter: CheckerPainter(style: set.of(f.side), flash: 1)),
              ),
            ));
          }
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            ...trail,
            Positioned(
              left: pos.dx - g.d / 2,
              top: pos.dy - g.d / 2,
              width: g.d,
              height: g.d,
              child: IgnorePointer(
                child: Transform(
                  alignment: Alignment.center,
                  transform: m,
                  child: CustomPaint(
                    painter: CheckerPainter(
                      style: set.of(f.side),
                      lift: f.toSlab && t > 0.5 ? 0 : lift,
                      glow: f.toSlab ? 0.6 * lift : 0,
                      glowColor: _gold,
                      flash: f.victim ? (1 - t) * (raw > 0 ? 1 : 0) : 0,
                      time: _fx.value,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dragWidget(BgGeom g, BgCheckerSet set, Offset p) {
    final size = g.d * 1.22;
    return Positioned(
      left: p.dx - size / 2,
      top: p.dy - size / 2 - g.d * 0.35,
      width: size,
      height: size,
      child: IgnorePointer(
        child: CustomPaint(
          painter: CheckerPainter(
            style: set.of(_e.turn),
            lift: 1,
            glow: _hover != null ? 1 : 0.4,
            glowColor: _hover != null ? _mint : _gold,
            time: _fx.value,
          ),
        ),
      ),
    );
  }

  Widget _burstWidget(BgGeom g, _Burst b) {
    final r = g.d * (b.small ? 1.3 : 2.2);
    return Positioned(
      left: b.pos.dx - r,
      top: b.pos.dy - r,
      width: r * 2,
      height: r * 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: b.ctrl,
          builder: (_, __) =>
              CustomPaint(painter: _BurstPainter(b.ctrl.value, gold: b.small)),
        ),
      ),
    );
  }
}

/// شرارات وحلقة صدمة (ضرب = برتقالي، إخراج = بريق ذهبي)
class _BurstPainter extends CustomPainter {
  final double t;
  final bool gold;
  _BurstPainter(this.t, {this.gold = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final e = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
        c,
        r * 0.25 + r * 0.6 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - t) + 0.5
          ..color = const Color(0xFFFFD54F).withValues(alpha: 1 - t));
    if (!gold) {
      canvas.drawCircle(
          c,
          r * 0.35 * (1 - t),
          Paint()
            ..color = const Color(0xFFFF6B3D).withValues(alpha: 0.6 * (1 - t))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    final rnd = math.Random(9);
    final n = gold ? 10 : 14;
    for (int i = 0; i < n; i++) {
      final a = i / n * math.pi * 2 + rnd.nextDouble() * 0.4;
      final sp = 0.55 + rnd.nextDouble() * 0.45;
      final dir = Offset(math.cos(a), math.sin(a));
      if (gold) {
        // نجيمات بريق
        final p = c + dir * r * sp * e;
        final s = 3.5 * (1 - t) + 0.5;
        final star = Path()
          ..moveTo(p.dx, p.dy - s * 2)
          ..lineTo(p.dx + s * 0.5, p.dy - s * 0.5)
          ..lineTo(p.dx + s * 2, p.dy)
          ..lineTo(p.dx + s * 0.5, p.dy + s * 0.5)
          ..lineTo(p.dx, p.dy + s * 2)
          ..lineTo(p.dx - s * 0.5, p.dy + s * 0.5)
          ..lineTo(p.dx - s * 2, p.dy)
          ..lineTo(p.dx - s * 0.5, p.dy - s * 0.5)
          ..close();
        canvas.drawPath(
            star,
            Paint()
              ..color = const Color(0xFFFFF1B8).withValues(alpha: 1 - t));
        continue;
      }
      canvas.drawLine(
          c + dir * r * sp * e * 0.7,
          c + dir * r * sp * e,
          Paint()
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = (i.isEven
                    ? const Color(0xFFFFE08A)
                    : const Color(0xFFFF7A45))
                .withValues(alpha: 1 - t));
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}
