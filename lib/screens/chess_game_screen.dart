import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../games/chess/chess_audio.dart';
import '../games/chess/chess_engine.dart';
import '../games/chess/widgets/chess_board_widget.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/user_avatar.dart';

class ChessGameScreen extends StatefulWidget {
  /// true = ضد الذكاء الاصطناعي، false = لاعبان على نفس الجهاز
  final bool vsAI;
  final int bet;

  const ChessGameScreen({super.key, this.vsAI = true, this.bet = 0});

  @override
  State<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends State<ChessGameScreen> {
  final ChessEngine _engine = ChessEngine();

  /// تلوين سكن القطع من المتجر (لون متوسط صورة السكن)
  Color? _pieceTint;
  ui.Image? _pieceSkinImg;

  int? _selected;
  Set<int> _targets = {};
  Set<int> _captures = {};
  bool _gameOverShown = false;
  bool _showWinFx = false;
  int _aiToken = 0;
  int _introSeed = 0;

  // مؤقتا اللاعبين — 10 دقائق لكلٍّ منهما
  int _whiteSecs = 600;
  int _blackSecs = 600;
  Timer? _clock;
  String? _timeoutResult;

  /// نتيجة النهاية للصوت: الفائز أبيض؟ / تعادل؟
  bool? _endWinnerWhite;
  bool _endIsDraw = false;

  static const _bgTop = Color(0xFF0B1120);
  static const _bgMid = Color(0xFF070B16);
  static const _bgBot = Color(0xFF04060E);
  static const _emerald = Color(0xFF34D399);
  static const _mint = Color(0xFF3FF5A8); // Neon Mint — لون الدور والأزرار
  static const _cyan = Color(0xFF38BDF8);
  static const _gold = Color(0xFFFFD54F);
  static const _red = Color(0xFFEF4444);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  @override
  void initState() {
    super.initState();
    StoreService().initialize();
    StoreService().addListener(_updatePieceTint);
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isOver || _gameOverShown) return;
      setState(() {
        if (_engine.turn == ChessColor.white) {
          if (_whiteSecs > 0) _whiteSecs--;
          if (_whiteSecs == 0) _flagFall(ChessColor.white);
        } else {
          if (_blackSecs > 0) _blackSecs--;
          if (_blackSecs == 0) _flagFall(ChessColor.black);
        }
      });
      final secs = _engine.turn == ChessColor.white
          ? _whiteSecs
          : _blackSecs;
      if (secs > 0 && secs <= 10) ChessAudio.lowTime();
    });
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ChessAudio.gameStart());
  }

  @override
  void dispose() {
    StoreService().removeListener(_updatePieceTint);
    _clock?.cancel();
    super.dispose();
  }

  /// يستخرج اللون المتوسط من صورة سكن القطع المجهّز لتلوينها
  Future<void> _updatePieceTint() async {
    final img = StoreService().equippedUiImage('chessPieces');
    if (identical(img, _pieceSkinImg)) return;
    _pieceSkinImg = img;
    if (img == null) {
      if (mounted) setState(() => _pieceTint = null);
      return;
    }
    final data =
        await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null || !mounted) return;
    final px = data.buffer.asUint8List();
    int r = 0, g = 0, b = 0, n = 0;
    for (int i = 0; i < px.length; i += 40) {
      if (px[i + 3] < 128) continue;
      r += px[i];
      g += px[i + 1];
      b += px[i + 2];
      n++;
    }
    if (n == 0) return;
    setState(() =>
        _pieceTint = Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n));
  }

  bool get _isOver =>
      _engine.status == GameStatus.checkmate ||
      _engine.status == GameStatus.stalemate ||
      _engine.status == GameStatus.draw ||
      _timeoutResult != null;

  void _flagFall(ChessColor loser) {
    _timeoutResult =
        'انتهى الوقت! فاز ${loser == ChessColor.white ? "الأسود" : "الأبيض"} ⏱️';
    _endWinnerWhite = loser == ChessColor.black;
    _gameOverShown = true;
    _playEndFx();
    setState(() => _showWinFx = true);
    Timer(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() => _showWinFx = false);
      _showGameOverDialog();
    });
  }

  String _fmt(int secs) =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  void _onSquareTap(int sq) {
    if (_isOver) return;
    if (widget.vsAI && _engine.turn == ChessColor.black) return;

    final piece = _engine.board[sq];
    if (piece != null && piece.color == _engine.turn) {
      ChessAudio.select();
      setState(() {
        _selected = sq;
        _targets = {};
        _captures = {};
        for (final m in _engine.legalMovesFrom(sq)) {
          (_engine.board[m.to] != null || m.isEnPassant
                  ? _captures
                  : _targets)
              .add(m.to);
        }
      });
      return;
    }
    if (_selected != null &&
        (_targets.contains(sq) || _captures.contains(sq))) {
      _tryMove(_selected!, sq);
      return;
    }
    setState(() {
      _selected = null;
      _targets = {};
      _captures = {};
    });
  }

  void _onDrop(int from, int to) {
    if (_isOver) return;
    if (widget.vsAI && _engine.turn == ChessColor.black) return;
    final piece = _engine.board[from];
    if (piece == null || piece.color != _engine.turn) return;
    _tryMove(from, to);
  }

  void _tryMove(int from, int to) {
    final legal = _engine.legalMovesFrom(from);
    final candidates = legal.where((m) => m.to == to).toList();
    if (candidates.isEmpty) {
      if (_engine.board[to] == null ||
          _engine.board[to]!.color != _engine.turn) {
        ChessAudio.illegal();
      }
      setState(() {
        _selected = null;
        _targets = {};
        _captures = {};
      });
      return;
    }
    if (candidates.any((m) => m.promotion != null)) {
      _showPromotionPicker(candidates);
      return;
    }
    _executeMove(candidates.first);
  }

  void _executeMove(ChessMove m) {
    final capture =
        _engine.board[m.to] != null || m.isEnPassant;
    setState(() {
      _selected = null;
      _targets = {};
      _captures = {};
    });
    _engine.makeMove(m);
    _playMoveFx(m, capture: capture);
    _checkGameOver();
    _scheduleAI();
  }

  /// صوت الحركة المناسب + رنّة الكش إن وجدت
  void _playMoveFx(ChessMove m, {required bool capture}) {
    if (m.isCastle) {
      ChessAudio.castle();
    } else if (m.promotion != null) {
      ChessAudio.promote();
    } else if (capture) {
      ChessAudio.capture();
    } else {
      ChessAudio.move();
    }
    if (_engine.status == GameStatus.check) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (mounted && !_isOver) ChessAudio.check();
      });
    }
  }

  /// صوت نهاية المباراة حسب النتيجة
  void _playEndFx() {
    if (_endIsDraw ||
        _engine.status == GameStatus.draw ||
        _engine.status == GameStatus.stalemate) {
      ChessAudio.draw();
      return;
    }
    final winnerIsWhite =
        _endWinnerWhite ?? (_engine.turn == ChessColor.black);
    if (!widget.vsAI || winnerIsWhite) {
      ChessAudio.win();
    } else {
      ChessAudio.lose();
    }
  }

  void _scheduleAI() {
    if (!widget.vsAI ||
        _isOver ||
        _engine.turn != ChessColor.black) return;
    final token = ++_aiToken;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || token != _aiToken) return;
      final move = ChessAI.bestMove(_engine);
      if (move != null && mounted) {
        final capture =
            _engine.board[move.to] != null || move.isEnPassant;
        _engine.makeMove(move);
        _playMoveFx(move, capture: capture);
        _checkGameOver();
      }
    });
  }

  void _checkGameOver() {
    if (_isOver && !_gameOverShown && _timeoutResult == null) {
      _gameOverShown = true;
      _playEndFx();
      setState(() => _showWinFx = true);
      Timer(const Duration(milliseconds: 1700), () {
        if (!mounted) return;
        setState(() => _showWinFx = false);
        _showGameOverDialog();
      });
    }
  }

  String get _resultText {
    if (_timeoutResult != null) return _timeoutResult!;
    switch (_engine.status) {
      case GameStatus.checkmate:
        final winner =
            _engine.turn == ChessColor.white ? 'الأسود' : 'الأبيض';
        return 'كش مات! فاز $winner';
      case GameStatus.stalemate:
        return 'طريق مسدود — تعادل';
      case GameStatus.draw:
        return 'تعادل — لا مواد كافية';
      default:
        return '';
    }
  }

  // ═══ الحوارات ═══

  void _showPromotionPicker(List<ChessMove> candidates) {
    final color = _engine.turn;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _glassPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ترقية البيدق إلى:',
                  style: TextStyle(
                      color: _textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final t in [
                    PieceType.queen,
                    PieceType.rook,
                    PieceType.bishop,
                    PieceType.knight,
                  ])
                    GestureDetector(
                      onTap: () {
                        ChessAudio.select();
                        Navigator.of(ctx).pop();
                        _executeMove(candidates
                            .firstWhere((m) => m.promotion == t));
                      },
                      child: Container(
                        width: 58,
                        height: 58,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0x2E141C3C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _gold.withOpacity(0.6),
                              width: 1.3),
                          boxShadow: [
                            BoxShadow(
                                color: _gold.withOpacity(0.25),
                                blurRadius: 10),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/chess/'
                          '${color == ChessColor.white ? 'white' : 'black'}'
                          '_${t.name}.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _glassPanel(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: _gold, size: 52),
              const SizedBox(height: 10),
              Text(_resultText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _textWhite,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _goldButton('لعبة جديدة', () {
                      Navigator.of(ctx).pop();
                      _newGame();
                    }, icon: Icons.replay_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ghostButton('خروج', () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResignDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _glassPanel(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag_rounded,
                  color: _red, size: 40),
              const SizedBox(height: 10),
              const Text('الاستسلام؟',
                  style: TextStyle(
                      color: _textWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('ستخسر هذه المباراة فوراً',
                  style:
                      TextStyle(color: _textDim, fontSize: 12)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _ghostButton('إلغاء',
                        () => Navigator.of(ctx).pop()),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _goldButton('استسلام', () {
                      Navigator.of(ctx).pop();
                      _timeoutResult = widget.vsAI
                          ? 'استسلمت — فاز الذكاء الاصطناعي'
                          : 'استسلم ${_engine.turn == ChessColor.white ? "الأبيض" : "الأسود"}';
                      _endWinnerWhite =
                          _engine.turn == ChessColor.black;
                      _gameOverShown = true;
                      _playEndFx();
                      _showGameOverDialog();
                    }, icon: Icons.flag_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _offerDraw() {
    AppHaptics.medium();
    if (!widget.vsAI) {
      // وضع لاعبين — قبول فوري بالاتفاق
      _timeoutResult = 'تعادل بالاتفاق 🤝';
      _endIsDraw = true;
      _gameOverShown = true;
      _playEndFx();
      _showGameOverDialog();
      return;
    }
    // الذكاء يقبل فقط إن كان خاسراً
    final eval = ChessAI.evaluate(_engine);
    if (eval > 250) {
      _timeoutResult = 'قبل الذكاء الاصطناعي التعادل 🤝';
      _endIsDraw = true;
      _gameOverShown = true;
      _playEndFx();
      _showGameOverDialog();
    } else {
      ChessAudio.illegal();
      TopNotification.show(
        context,
        'رفض الذكاء الاصطناعي عرض التعادل',
        icon: Icons.close_rounded,
      );
    }
  }

  void _undo() {
    ChessAudio.tap();
    setState(() {
      _selected = null;
      _targets = {};
      _captures = {};
      _gameOverShown = false;
      _timeoutResult = null;
      // ضد الذكاء: نتراجع حركتين (حركتي + ردّه)
      _engine.undoMove();
      if (widget.vsAI) _engine.undoMove();
    });
    _aiToken++;
  }

  void _showSettingsSheet() {
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF2152150), Color(0xF20A0F24)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x40FFFFFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                _sheetRow(
                  icon: Icons.undo_rounded,
                  color: _cyan,
                  title: 'تراجع عن الحركة',
                  enabled: _engine.history.isNotEmpty,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _undo();
                  },
                ),
                _sheetRow(
                  icon: ChessAudio.soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: _gold,
                  title: ChessAudio.soundEnabled
                      ? 'كتم الأصوات'
                      : 'تشغيل الأصوات',
                  enabled: true,
                  onTap: () {
                    ChessAudio.soundEnabled =
                        !ChessAudio.soundEnabled;
                    if (ChessAudio.soundEnabled) {
                      ChessAudio.tap();
                    }
                    Navigator.of(ctx).pop();
                  },
                ),
                _sheetRow(
                  icon: Icons.logout_rounded,
                  color: _red,
                  title: 'الخروج من المباراة',
                  enabled: true,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetRow({
    required IconData icon,
    required Color color,
    required String title,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0x2E141C3C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0x22FFFFFF), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _textWhite,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: _textDim, size: 13),
            ],
          ),
        ),
      ),
    );
  }

  void _newGame() {
    ChessAudio.gameStart();
    _aiToken++;
    _engine.setup();
    setState(() {
      _selected = null;
      _targets = {};
      _captures = {};
      _gameOverShown = false;
      _showWinFx = false;
      _timeoutResult = null;
      _endWinnerWhite = null;
      _endIsDraw = false;
      _introSeed++;
      _whiteSecs = 600;
      _blackSecs = 600;
    });
  }

  // ═══ الواجهة ═══

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: _bgBot,
      body: Container(
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
                child: CustomPaint(painter: _ChessDecorPainter())),
            SafeArea(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_engine, StoreService()]),
                builder: (context, _) => Column(
                  children: [
                    // ═══ Top Bar ═══
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          _glassCircle(
                              Icons.arrow_back_ios_new_rounded,
                              () => Navigator.of(context).pop()),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // توهج خافت خلف الشعار
                                Container(
                                  width: 90,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        const Color(0xFF7C4DFF)
                                            .withOpacity(0.30),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                                const Column(
                                  children: [
                                    Icon(
                                        Icons
                                            .workspace_premium_rounded,
                                        color: _gold, size: 12),
                                    SizedBox(height: 1),
                                    Text('يلا ياري',
                                        style: TextStyle(
                                            color: _textWhite,
                                            fontSize: 14.5,
                                            fontWeight:
                                                FontWeight.w900)),
                                    Text('CHESS',
                                        style: TextStyle(
                                            color: _textDim,
                                            fontSize: 7.5,
                                            letterSpacing: 5.5,
                                            fontWeight:
                                                FontWeight.w800)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _glassCircle(Icons.settings_rounded,
                              _showSettingsSheet),
                        ],
                      ),
                    ),

                    // ═══ بطاقتا اللاعبين ═══
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: _playerCard(
                              name: user?.displayName ?? 'أنت',
                              subtitle:
                                  '${user?.rating ?? 1200}',
                              avatar: UserAvatar(
                                  photoUrl: user?.photoUrl ?? '',
                                  name: user?.displayName ?? '',
                                  size: 42),
                              time: _fmt(_whiteSecs),
                              isActive: _engine.turn ==
                                      ChessColor.white &&
                                  !_isOver,
                              accent: _gold,
                              flip: true,
                              badge: _engine.inCheck(
                                      ChessColor.white)
                                  ? 'كش!'
                                  : (_engine.turn ==
                                              ChessColor.white &&
                                          !_isOver
                                      ? 'دورك'
                                      : null),
                              badgeColor: _engine.inCheck(
                                      ChessColor.white)
                                  ? _red
                                  : _mint,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _playerCard(
                              name: widget.vsAI
                                  ? 'AI'
                                  : 'اللاعب الأسود',
                              subtitle: widget.vsAI
                                  ? 'Expert'
                                  : '${user?.rating ?? 1200}',
                              avatar: _aiAvatar(),
                              time: _fmt(_blackSecs),
                              isActive: _engine.turn ==
                                      ChessColor.black &&
                                  !_isOver,
                              accent: _cyan,
                              badge: _engine.inCheck(
                                      ChessColor.black)
                                  ? 'كش!'
                                  : (_engine.turn ==
                                              ChessColor.black &&
                                          !_isOver
                                      ? (widget.vsAI
                                          ? 'Thinking...'
                                          : 'دوره')
                                      : null),
                              badgeColor: _engine.inCheck(
                                      ChessColor.black)
                                  ? _red
                                  : _cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ═══ الرقعة ═══
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ChessBoardWidget(
                              engine: _engine,
                              selected: _selected,
                              legalTargets: _targets,
                              captureTargets: _captures,
                              onSquareTap: _onSquareTap,
                              onPieceDrop: _onDrop,
                              introSeed: _introSeed,
                              boardImage: StoreService()
                                  .equippedUiImage('chessBoard'),
                              pieceTint: _pieceTint,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ═══ أزرار التحكم ═══
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _controlButton(
                                'إعدادات',
                                Icons.settings_rounded,
                                _showSettingsSheet),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _controlButton(
                                'تعادل',
                                Icons.handshake_rounded,
                                _offerDraw),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: _controlButton(
                                'استسلام',
                                Icons.flag_rounded,
                                _showResignDialog),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: _primaryButton(
                              'لعبة جديدة',
                              Icons.play_arrow_rounded,
                              _newGame,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ═══ أنيميشن الفوز ═══
            if (_showWinFx)
              IgnorePointer(child: _WinOverlay(text: _resultText)),
          ],
        ),
      ),
    );
  }

  Widget _aiAvatar() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7DD3FC), Color(0xFF1D4ED8)],
        ),
        border: Border.all(
            color: _cyan.withOpacity(0.8), width: 1.6),
        boxShadow: [
          BoxShadow(color: _cyan.withOpacity(0.45), blurRadius: 12),
        ],
      ),
      child: const Icon(Icons.smart_toy_rounded,
          color: Colors.white, size: 21),
    );
  }

  Widget _playerCard({
    required String name,
    required String subtitle,
    required Widget avatar,
    required String time,
    required bool isActive,
    required Color accent,
    required String? badge,
    required Color badgeColor,
    bool flip = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0x3D1A2450)
                : const Color(0x2A10162E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? _mint.withOpacity(0.9)
                  : const Color(0x22FFFFFF),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                  color: isActive
                      ? _mint.withOpacity(0.28)
                      : Colors.black.withOpacity(0.25),
                  blurRadius: isActive ? 16 : 8),
            ],
          ),
          child: Opacity(
            opacity: isActive ? 1.0 : 0.68,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(builder: (context) {
                final avatarW = Stack(
                  children: [
                    // حلقة متوهجة حول الأفاتار
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: accent.withOpacity(0.85),
                            width: 1.8),
                        boxShadow: [
                          BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 10),
                        ],
                      ),
                      child: avatar,
                    ),
                    Positioned(
                      bottom: 0,
                      left: flip ? null : 0,
                      right: flip ? 0 : null,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? accent
                              : const Color(0xFF64748B),
                          border: Border.all(
                              color: _bgMid, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                );
                final nameCol = Expanded(
                  child: Column(
                    crossAxisAlignment: flip
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _textWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: flip
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          const Icon(Icons.military_tech_rounded,
                              color: _gold, size: 12),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(subtitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _textDim,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                return Row(
                  children: flip
                      ? [nameCol, const SizedBox(width: 8), avatarW]
                      : [avatarW, const SizedBox(width: 8), nameCol],
                );
              }),
              const SizedBox(height: 8),
              Row(
                textDirection:
                    flip ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  // شارة الحالة
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: badgeColor.withOpacity(0.7),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: badgeColor.withOpacity(0.3),
                              blurRadius: 8),
                        ],
                      ),
                      child: Text(badge,
                          style: TextStyle(
                              color: badgeColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900)),
                    )
                  else
                    const SizedBox(height: 20),
                  const Spacer(),
                  // المؤقت
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4.5),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(colors: [
                              _mint,
                              Color.lerp(_mint, Colors.black, 0.22)!,
                            ])
                          : null,
                      color: isActive
                          ? null
                          : const Color(0x1FFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? _mint
                            : const Color(0x22FFFFFF),
                        width: 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                  color: _mint.withOpacity(0.4),
                                  blurRadius: 10),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule_rounded,
                            color: isActive
                                ? const Color(0xFF0B1120)
                                : _textDim,
                            size: 11),
                        const SizedBox(width: 3),
                        Text(time,
                            style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF0B1120)
                                    : _textDim,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900)),
                      ],
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

  Widget _glassCircle(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: const Color(0x26FFFFFF), width: 1),
            ),
            child: Icon(icon, color: _textDim, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(
      String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3FF5A8), Color(0xFF0EA96A)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: const Color(0xFF8AFFD0), width: 1.3),
          boxShadow: [
            BoxShadow(
                color: _mint.withOpacity(0.42),
                blurRadius: 16,
                spreadRadius: 0.5),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(
      String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0x33141C3C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0x33FFFFFF), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _textDim, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(text,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _textDim,
                          fontWeight: FontWeight.w800,
                          fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassPanel({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF2152150), Color(0xF20A0F24)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: const Color(0x44FFFFFF), width: 1.1),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _goldButton(String text, VoidCallback onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE082),
              _gold,
              Color(0xFFE8A820),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFFE9A8), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: _gold.withOpacity(0.3), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: const Color(0xFF1B0B30), size: 16),
              const SizedBox(width: 5),
            ],
            Text(text,
                style: const TextStyle(
                    color: Color(0xFF1B0B30),
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _ghostButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x2E141C3C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0x33FFFFFF), width: 1),
            ),
            child: Center(
              child: Text(text,
                  style: const TextStyle(
                      color: _textWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }
}

/// طبقة احتفال الفوز — كونفيتي متساقط + راية متوهجة
class _WinOverlay extends StatefulWidget {
  final String text;
  const _WinOverlay({required this.text});

  @override
  State<_WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<_WinOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
                color: Colors.black.withOpacity(
                    0.25 * _ctrl.value.clamp(0.0, 1.0))),
            CustomPaint(painter: _ConfettiPainter(_ctrl.value)),
            Center(
              child: Transform.scale(
                scale: Curves.elasticOut
                    .transform(
                        _ctrl.value.clamp(0.0, 0.75) / 0.75)
                    .clamp(0.0, 1.3),
                child: Opacity(
                  opacity: (_ctrl.value * 3).clamp(0.0, 1.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Color(0xFFFFD54F), size: 72),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFFFFE082),
                            Color(0xFFFFD54F),
                            Color(0xFFE8A820),
                          ]),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFFF3C4),
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFFFD54F)
                                    .withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 2),
                          ],
                        ),
                        child: Text(
                          widget.text,
                          style: const TextStyle(
                              color: Color(0xFF1B0B30),
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const _colors = [
    Color(0xFFFFD54F),
    Color(0xFF38BDF8),
    Color(0xFF34D399),
    Color(0xFFF472B6),
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 46; i++) {
      final seed = i * 37.7;
      final x = (seed * 13.7 % 1.0) * size.width;
      final speed = 0.55 + (i % 5) * 0.12;
      final y =
          ((t * speed + (seed % 1.0)) % 1.0) * size.height;
      final wobble = math.sin(t * 12 + i) * 14;
      final fade = 1 - t;
      canvas.save();
      canvas.translate(x + wobble, y);
      canvas.rotate(seed + t * 6);
      canvas.drawRect(
        const Rect.fromLTWH(-3, -1.5, 6, 3),
        Paint()
          ..color = _colors[i % _colors.length]
              .withOpacity(fade.clamp(0, 1)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _ChessDecorPainter extends CustomPainter {
  const _ChessDecorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color color, double o) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [color.withOpacity(o), Colors.transparent],
            ).createShader(
                Rect.fromCircle(center: c, radius: r)));
    }

    glow(Offset(size.width * 0.9, size.height * 0.03),
        size.width * 0.55, const Color(0xFF2540A0), 0.28);
    glow(Offset(size.width * 0.08, size.height * 0.55),
        size.width * 0.45, const Color(0xFF7C5CFF), 0.13);
    glow(Offset(size.width * 0.5, size.height * 1.06),
        size.width * 0.65, const Color(0xFF8A6400), 0.15);

    // إضاءة جانبية خافتة إضافية لعمق المشهد
    glow(Offset(size.width * -0.05, size.height * 0.62),
        size.width * 0.4, const Color(0xFF1E2A50), 0.5);
    glow(Offset(size.width * 1.05, size.height * 0.38),
        size.width * 0.38, const Color(0xFF1A2545), 0.45);

    // ═══ زخارف زوايا رفيعة أنيقة (كالمرجع) ═══
    final ornament = Paint()
      ..color = const Color(0xFF7C4DFF).withOpacity(0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    const m = 26.0, len = 30.0;
    for (final flipX in [false, true]) {
      for (final flipY in [false, true]) {
        canvas.save();
        canvas.translate(flipX ? size.width : 0,
            flipY ? size.height : 0);
        if (flipX) canvas.scale(-1, 1);
        if (flipY) canvas.scale(1, -1);
        // زاوية L رفيعة مع خط قصير داخلي
        final p = Path()
          ..moveTo(m, m + len)
          ..quadraticBezierTo(m, m, m + len, m)
          ..moveTo(m + 5, m + len * 0.62)
          ..quadraticBezierTo(
              m + len * 0.62, m + len * 0.62, m + len * 0.62, m + 5);
        canvas.drawPath(p, ornament);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ChessDecorPainter oldDelegate) => false;
}
