import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_lang.dart';
import '../../services/auth_service.dart';
import '../../utils/haptics.dart';
import '../../utils/top_notification.dart';
import 'solitaire_audio.dart';
import 'solitaire_engine.dart';

/// شاشة السوليتر (كلوندايك) — طاولة لباد، بطاقات تنزلق بين الأكوام،
/// تحديد باللمس، تراجع، تلميح، إنهاء تلقائي، مؤقّت وعدّاد حركات
class SolitaireGameScreen extends StatefulWidget {
  final int bet;

  const SolitaireGameScreen({super.key, this.bet = 0});

  @override
  State<SolitaireGameScreen> createState() => _SolitaireGameScreenState();
}

class _SolitaireGameScreenState extends State<SolitaireGameScreen>
    with TickerProviderStateMixin {
  late final SolitaireEngine _engine;
  late final AnimationController _dealCtrl;
  Timer? _clock;
  int _elapsed = 0;

  bool _showResult = false;
  bool _confirmExit = false;
  int _resultChips = 0;
  bool _overHandled = false;
  bool _dealt = false;

  /// البطاقة المحددة: 'w' أو 'f0'..'f3' أو 't0'..'t6' + index
  String? _selSrc;
  int _selIdx = -1;

  /// إبراز التلميح
  String? _hintA;
  String? _hintB;
  Timer? _hintTimer;

  static const _bgTop = Color(0xFF0B1F14);
  static const _bgMid = Color(0xFF081510);
  static const _bgBot = Color(0xFF040B07);
  static const _gold = Color(0xFFFFD54F);
  static const _feltA = Color(0xFF14603E);
  static const _feltB = Color(0xFF0B3A25);
  static const _red = Color(0xFFD32F2F);
  static const _ink = Color(0xFF1A2332);

  @override
  void initState() {
    super.initState();
    _engine = SolitaireEngine();
    _engine.onNotice = (msg) {
      if (mounted) TopNotification.show(context, msg);
    };
    _engine.addListener(_onEngine);
    _dealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _dealCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _dealt = true);
      }
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_engine.won) setState(() => _elapsed++);
    });
  }

  void _onEngine() {
    if (!mounted) return;
    if (_engine.won && !_overHandled) {
      _overHandled = true;
      _onWin();
    }
    setState(() {});
  }

  Future<void> _onWin() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    var chips = 0;
    if (widget.bet > 0) {
      chips = widget.bet;
      AuthService().updateMatchResult(
        chipChange: chips,
        ratingChange: 12,
        isWin: true,
      );
    }
    setState(() {
      _resultChips = chips;
      _showResult = true;
    });
  }

  void _newGame() {
    setState(() {
      _showResult = false;
      _overHandled = false;
      _resultChips = 0;
      _elapsed = 0;
      _selSrc = null;
      _dealt = false;
    });
    _engine.reset();
    _dealCtrl.forward(from: 0);
  }

  void _requestExit() {
    if (_engine.won || widget.bet == 0) {
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
    _dealCtrl.dispose();
    _clock?.cancel();
    _hintTimer?.cancel();
    _engine.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  منطق اللمس
  // ─────────────────────────────────────────────
  void _tapCard(String src, int idx) {
    if (_engine.won || _engine.autoCompleting) return;
    AppHaptics.selection();

    // لمسة ثانية على نفس البطاقة = إلغاء التحديد
    if (_selSrc == src && _selIdx == idx) {
      setState(() => _selSrc = null);
      return;
    }

    if (_selSrc != null) {
      final moved = _tryDropOn(src);
      if (moved) {
        setState(() => _selSrc = null);
        return;
      }
    }
    // إعادة تحديد البطاقة الملموسة
    setState(() {
      _selSrc = src;
      _selIdx = idx;
    });
  }

  /// محاولة إفلات البطاقة المحددة على الهدف الملموس
  bool _tryDropOn(String dstSrc) {
    if (_selSrc == null) return false;
    if (dstSrc.startsWith('t')) {
      final col = int.parse(dstSrc[1]);
      return _engine.moveToTableau(_selSrc!, _selIdx, col);
    }
    if (dstSrc.startsWith('f')) {
      return _engine.moveToFoundation(_selSrc!, _selIdx);
    }
    return false;
  }

  /// لمس عمود/خانة فارغة
  void _tapEmpty(String dstSrc) {
    if (_selSrc == null || _engine.won || _engine.autoCompleting) return;
    if (_tryDropOn(dstSrc)) {
      setState(() => _selSrc = null);
    }
  }

  /// نقرة مزدوجة: إرسال للأساس تلقائياً
  void _dblCard(String src, int idx) {
    if (_engine.moveToFoundation(src, idx)) {
      setState(() => _selSrc = null);
      AppHaptics.medium();
    }
  }

  void _showHint() {
    final h = _engine.hint();
    if (h == null) {
      TopNotification.show(context, 'لا توجد حركة مقترحة 🤷'.tr);
      return;
    }
    setState(() {
      _hintA = h.$1;
      _hintB = h.$2;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _hintA = _hintB = null);
    });
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
                Column(
                  children: [
                    _buildHeader(),
                    _buildToolbar(),
                    const SizedBox(height: 6),
                    Expanded(child: _buildTable()),
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
  //  الهيدر + شريط الأدوات
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        children: [
          _circleBtn(Icons.arrow_back_ios_new_rounded, _requestExit),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'سوليتر'.tr,
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
            SolAudio.soundEnabled
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            () =>
                setState(() => SolAudio.soundEnabled = !SolAudio.soundEnabled),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {Color? tint}) {
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
        child: Icon(icon, color: tint ?? Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildToolbar() {
    final canAuto = _engine.canAutoComplete;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          _statChip(Icons.touch_app_rounded, '{} حركة'.trp([_engine.moves])),
          const SizedBox(width: 8),
          _statChip(Icons.timer_outlined, _fmtTime(_elapsed)),
          const Spacer(),
          _toolBtn(Icons.undo_rounded, _engine.canUndo, () {
            _engine.undo();
            setState(() => _selSrc = null);
          }),
          const SizedBox(width: 6),
          _toolBtn(Icons.lightbulb_outline_rounded, true, _showHint,
              tint: _gold),
          const SizedBox(width: 6),
          if (canAuto)
            _toolBtn(
                Icons.auto_awesome_rounded, true, () => _engine.autoComplete(),
                tint: const Color(0xFF7DD3FC)),
          if (canAuto) const SizedBox(width: 6),
          _toolBtn(Icons.refresh_rounded, true, _newGame),
        ],
      ),
    );
  }

  String _fmtTime(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _statChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, bool enabled, VoidCallback onTap,
      {Color? tint}) {
    return GestureDetector(
      onTap: enabled
          ? () {
              AppHaptics.selection();
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withOpacity(0.13)),
          ),
          child: Icon(icon, color: tint ?? Colors.white70, size: 17),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  الطاولة
  // ─────────────────────────────────────────────
  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: LayoutBuilder(
        builder: (context, box) {
          final areaW = box.maxWidth - 8;
          const gap = 6.0;
          final cw = (areaW - gap * 6 - 12) / 7;
          final ch = cw * 1.42;
          final topRowH = ch + 10;

          // إزاحات التابلو: انزلاق متوازن يلائم أطول عمود
          final availH = box.maxHeight - topRowH - 8;
          var need = 0.0;
          for (final col in _engine.tableau) {
            var n = 0.0;
            for (var i = 0; i < col.length; i++) {
              n += col[i].faceUp ? 1.0 : 0.45;
            }
            if (n > need) need = n;
          }
          final up =
              math.min(22.0, need > 1 ? (availH - ch) / (need - 1) : 22.0);
          final down = up * 0.45;

          Offset pilePos(String src) {
            if (src == 'w') return Offset(cw + gap, 0);
            if (src.startsWith('f')) {
              final i = int.parse(src[1]);
              return Offset((cw + gap) * (i + 3), 0);
            }
            return Offset.zero;
          }

          Offset tableauCardPos(int col, int idx) {
            var y = topRowH;
            final t = _engine.tableau[col];
            for (var i = 0; i < idx; i++) {
              y += t[i].faceUp ? up : down;
            }
            return Offset(col * (cw + gap) + 6, y);
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment(0, -0.25),
                radius: 1.2,
                colors: [_feltA, _feltB],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3A2512), width: 5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── المخزون: بطاقة مقلوبة أو أيقونة تدوير — المنطقة كلها قابلة للمس ──
                  Positioned(
                    left: 6,
                    top: 6,
                    child: GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        _engine.draw();
                      },
                      child: _engine.stock.isEmpty
                          ? _emptySlot(cw, ch,
                              child: Icon(Icons.autorenew_rounded,
                                  color: Colors.white.withOpacity(0.4),
                                  size: cw * 0.45))
                          : _cardWidget(null, cw, ch, faceDown: true),
                    ),
                  ),
                  // ── خانات الأساس (شبح + بطاقة) ──
                  for (var f = 0; f < 4; f++)
                    Positioned(
                      left: (cw + gap) * (f + 3) + 6,
                      top: 6,
                      child: GestureDetector(
                        onTap: () => _tapEmpty('f$f'),
                        child: _foundationGhost(f, cw, ch),
                      ),
                    ),
                  // ── أعمدة التابلو الفارغة (أهداف ملك) ──
                  for (var t = 0; t < 7; t++)
                    if (_engine.tableau[t].isEmpty)
                      Positioned(
                        left: t * (cw + gap) + 6,
                        top: topRowH,
                        child: GestureDetector(
                          onTap: () => _tapEmpty('t$t'),
                          child: _emptySlot(cw, ch),
                        ),
                      ),
                  // ── البطاقات ──
                  // مهملات: آخر 3 بإزاحة خفيفة، القمة تفاعلية
                  for (var i = math.max(0, _engine.waste.length - 3);
                      i < _engine.waste.length;
                      i++)
                    _cardAt(
                      pilePos('w') +
                          Offset(
                              6 -
                                  (math.min(2, _engine.waste.length - 1 - i) *
                                      9.0),
                              6),
                      _engine.waste[i],
                      cw,
                      ch,
                      faceDown: false,
                      src: i == _engine.waste.length - 1 ? 'w' : null,
                      idx: i,
                    ),
                  // أسس: قمة كل خانة
                  for (var f = 0; f < 4; f++)
                    if (_engine.foundations[f].isNotEmpty)
                      _cardAt(
                        pilePos('f$f') + const Offset(6, 6),
                        _engine.foundations[f].last,
                        cw,
                        ch,
                        faceDown: false,
                        src: 'f$f',
                        idx: _engine.foundations[f].length - 1,
                      ),
                  // تابلو: كل البطاقات مع إزاحات متدرجة
                  for (var t = 0; t < 7; t++)
                    for (var i = 0; i < _engine.tableau[t].length; i++)
                      _tabCard(t, i, tableauCardPos(t, i), cw, ch),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// مكان بطاقة مع أنيميشن انزلاق + تفاعل اختياري
  Widget _cardAt(
    Offset pos,
    SolCard? card,
    double w,
    double h, {
    required bool faceDown,
    String? src,
    int idx = -1,
  }) {
    final isSel = src != null && _selSrc == src && _selIdx == idx;
    final isHint = src != null && (_hintA == src || _hintB == src);
    Widget wdg = _cardWidget(card, w, h, faceDown: faceDown);

    if (isSel || isHint) {
      wdg = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color:
                  (isHint ? _gold : const Color(0xFF7DD3FC)).withOpacity(0.8),
              blurRadius: isHint ? 14 : 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: wdg,
      );
    }
    if (isSel) {
      wdg = Transform.translate(offset: const Offset(0, -7), child: wdg);
    }

    return TweenAnimationBuilder<Offset>(
      key: ValueKey('card-${card?.id ?? src}-${src ?? 'deck'}'),
      tween: Tween(end: pos),
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOut,
      builder: (_, p, __) => Positioned(
        left: p.dx,
        top: p.dy,
        child: GestureDetector(
          onTap: src != null ? () => _tapCard(src, idx) : null,
          onDoubleTap: src != null ? () => _dblCard(src, idx) : null,
          child: wdg,
        ),
      ),
    );
  }

  /// بطاقة تابلو بموضعها + أنيميشن توزيع عند البداية
  Widget _tabCard(int col, int idx, Offset pos, double w, double h) {
    final card = _engine.tableau[col][idx];
    final src = 't$col';
    final isFaceUp = card.faceUp;

    // أنيميشن التوزيع الأولي: تطير من المخزون
    if (!_dealt) {
      final delay = col * 70 + idx * 30;
      return AnimatedBuilder(
        animation: _dealCtrl,
        builder: (_, __) {
          final t = ((_dealCtrl.value * 1500 - delay) / 280).clamp(0.0, 1.0);
          if (t <= 0) return const SizedBox.shrink();
          final start = const Offset(6, 6);
          final p = Offset.lerp(start, pos, Curves.easeOut.transform(t))!;
          return Positioned(
            left: p.dx,
            top: p.dy,
            child: Opacity(
              opacity: t,
              child: _cardWidget(card, w, h, faceDown: !isFaceUp),
            ),
          );
        },
      );
    }
    return _cardAt(pos, card, w, h,
        faceDown: !isFaceUp, src: isFaceUp ? src : null, idx: idx);
  }

  Widget _foundationGhost(int f, double w, double h) {
    const suits = ['♥', '♦', '♣', '♠'];
    const colors = [_red, _red, _ink, _ink];
    if (_engine.foundations[f].isNotEmpty) return const SizedBox.shrink();
    return _emptySlot(
      w,
      h,
      child: Text(
        suits[f],
        style: TextStyle(
            color: colors[f].withOpacity(0.4),
            fontSize: w * 0.4,
            fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _emptySlot(double w, double h, {Widget? child}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1.2),
      ),
      child: child != null ? Center(child: child) : null,
    );
  }

  /// وجه/ظهر البطاقة
  Widget _cardWidget(SolCard? card, double w, double h,
      {required bool faceDown}) {
    if (faceDown || card == null) {
      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A3E6E), Color(0xFF141F3D)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF50649B), width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Center(
          child: Container(
            width: w * 0.5,
            height: w * 0.5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFF7D93C9).withOpacity(0.5), width: 1),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: w * 0.24, color: const Color(0xFF8FA5D6)),
          ),
        ),
      );
    }

    final c = card;
    final col = c.isRed ? _red : _ink;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFF8), Color(0xFFF3EDDC), Color(0xFFE2D6BB)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBCAF92), width: 0.9),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.38),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Stack(
        children: [
          // رتبة + شعار أعلى اليسار
          Positioned(
            left: w * 0.07,
            top: h * 0.05,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.rankLabel,
                  style: TextStyle(
                      color: col,
                      fontSize: w * 0.28,
                      fontWeight: FontWeight.w900,
                      height: 1.0),
                ),
                Text(c.suitChar,
                    style:
                        TextStyle(color: col, fontSize: w * 0.24, height: 1.0)),
              ],
            ),
          ),
          // شعار كبير بالمركز
          Center(
            child: Text(
              c.suitChar,
              style: TextStyle(
                  color: col.withOpacity(0.85),
                  fontSize: w * 0.5,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  حوار الخروج + نتيجة الفوز
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
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B2E08), Color(0xFF1C1403)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _gold.withOpacity(0.7), width: 1.4),
                  boxShadow: [
                    BoxShadow(color: _gold.withOpacity(0.35), blurRadius: 30),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 10),
                    Text(
                      'فزت! 🎉'.tr,
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 22,
                          fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'حللت السوليتر في {} حركة • {}'
                          .trp([_engine.moves, _fmtTime(_elapsed)]),
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
                          color: _gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$_resultChips 🪙',
                          style: const TextStyle(
                              color: _gold,
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
                              const Color(0xFF1B0B30), _newGame),
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
