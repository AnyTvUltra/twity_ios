import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'okey_models.dart';
import 'okey_rules.dart';
import 'utils/okey_audio.dart';
import '../../services/firebase_service.dart';
import '../../l10n/app_lang.dart';

enum OkeyTurnPhase {
  awaitingDraw,
  awaitingDiscard,
  gameOver,
}

class OkeyEngine extends ChangeNotifier {
  final math.Random _random = math.Random();

  late List<OkeyPlayer> players;
  late List<OkeyTile> drawDeck;
  late OkeyTile indicatorTile;
  late OkeyTile realOkeySample;
  late OkeyTile fakeJokerAssigned;

  // Discard piles for each player (0: Human, 1: Right, 2: Top, 3: Left)
  late List<List<OkeyTile>> discardPiles;
  late List<OkeyGroup> tableMelds;

  int currentTurnIndex = 0; // 0: Bottom (Human), 1: Right, 2: Top, 3: Left
  OkeyTurnPhase turnPhase =
      OkeyTurnPhase.awaitingDiscard; // Start player has 15 tiles
  OkeyGameState gameState = OkeyGameState.yourTurn;
  int? selectedTileIndex; // Index in human rack (0-27)

  // Turn Timer
  int turnTimeRemaining = 72; // 01:12
  static const int defaultTurnDuration = 72;

  /// مهلة الدور الفعلية (ثواني) — تُضبط من إعدادات السيرفر عبر الشاشة
  /// مدة الدور بالثواني — قابلة للتحديث على محرك المرآة لتطابق
  /// إعداد المضيف (القيمة تُحمَّل مع كل لقطة في loadGameState)
  int turnDuration;
  Timer? _turnCountdownTimer;
  Timer? _botTimer;
  bool isDisposed = false;

  // Winner data
  OkeyPlayer? winner;
  WinType? winType;

  /// قناة إشعارات للواجهة (نزول لاعب، فتح اللعب، إعادة أحجار...)
  void Function(String message)? onNotice;

  /// قانون الكونكان المختار (سليمانية / أربيل / تركي)
  final OkeyRules rules;

  OkeyEngine({OkeyRules? rules, this.turnDuration = defaultTurnDuration})
      : rules = rules ?? OkeyRules.turkish {
    initGame();
  }

  /// محرك مرآة لجهاز الضيف في اللعب الأونلاين: هياكل فارغة فقط —
  /// بلا توزيع ولا مؤقتات ولا بوتات، والحالة تُحمَّل كاملة من
  /// loadGameState بعد كل تحديث للوثيقة. حركات اللاعب تُرسل
  /// للمضيف كـpendingMoves بدل تنفيذها محلياً
  OkeyEngine.mirror({OkeyRules? rules, this.turnDuration = defaultTurnDuration})
      : rules = rules ?? OkeyRules.turkish {
    isOnlineMirror = true;
    indicatorTile =
        OkeyTile(id: '_pending', color: OkeyTileColor.black, value: 1);
    realOkeySample = indicatorTile;
    fakeJokerAssigned = indicatorTile;
    drawDeck = <OkeyTile>[];
    discardPiles = List.generate(4, (_) => <OkeyTile>[]);
    tableMelds = <OkeyGroup>[];
    players = [
      for (var i = 0; i < 4; i++)
        OkeyPlayer(
          id: 'p_$i',
          name: '…',
          avatarUrl: 'assets/images/player_left.png',
          level: 1,
          rating: 0,
          chips: 0,
          isHuman: i == 0,
        )
    ];
    turnPhase = OkeyTurnPhase.awaitingDraw;
    gameState = OkeyGameState.lobby;
  }

  void initGame() {
    _botTimer?.cancel();
    _turnCountdownTimer?.cancel();
    winner = null;
    winType = null;

    // 1. Generate standard 106 Okey tiles
    final allTiles = <OkeyTile>[];
    int tileIdCounter = 0;

    for (int copy = 1; copy <= 2; copy++) {
      for (final color in OkeyTileColor.values) {
        for (int v = 1; v <= 13; v++) {
          allTiles.add(OkeyTile(
            id: 'tile_${tileIdCounter++}',
            color: color,
            value: v,
          ));
        }
      }
    }

    // Shuffle once to pick random indicator
    allTiles.shuffle(_random);

    // 2. Pick Indicator tile (Gösterge) - must be a regular numbered tile
    final indicatorIndex = allTiles.indexWhere((t) => !t.isFalseJoker);
    indicatorTile = allTiles.removeAt(indicatorIndex);

    if (rules.isRummy) {
      // رامي: لا أوكي بالأرقام ولا مؤشر وظيفي — ورقتا الجوكر بريّتان
      // (isRealOkey=true تجعلهما يمثلان أي ورقة في كل عمليات التحقق)
      realOkeySample = OkeyTile(
        id: 'sample_joker',
        color: indicatorTile.color,
        value: 0,
        isFalseJoker: true,
        isRealOkey: true,
      );
      fakeJokerAssigned = realOkeySample;
      allTiles.add(OkeyTile(
        id: 'fake_1',
        color: indicatorTile.color,
        value: 0,
        isFalseJoker: true,
        isRealOkey: true,
      ));
      allTiles.add(OkeyTile(
        id: 'fake_2',
        color: indicatorTile.color,
        value: 0,
        isFalseJoker: true,
        isRealOkey: true,
      ));
    } else {
      // الأوكي الحقيقي بنفس لون المؤشر: التالي له (13←1) في التركي/أربيل،
      // والسابق له (1←13) في قانون سليمانية
      final okeyValue = rules.jokerBelowIndicator
          ? (indicatorTile.value == 1 ? 13 : indicatorTile.value - 1)
          : (indicatorTile.value == 13 ? 1 : indicatorTile.value + 1);
      realOkeySample = OkeyTile(
        id: 'sample_okey',
        color: indicatorTile.color,
        value: okeyValue,
        isRealOkey: true,
      );

      // 2 False Jokers (Sahte Okey) take the exact identity of the real Okey
      fakeJokerAssigned = OkeyTile(
        id: 'fake_1',
        color: indicatorTile.color,
        value: okeyValue,
        isFalseJoker: true,
      );
      allTiles.add(OkeyTile(
        id: 'fake_1',
        color: indicatorTile.color,
        value: okeyValue,
        isFalseJoker: true,
      ));
      allTiles.add(OkeyTile(
        id: 'fake_2',
        color: indicatorTile.color,
        value: okeyValue,
        isFalseJoker: true,
      ));

      // Mark the real Okey tiles in the deck
      for (int i = 0; i < allTiles.length; i++) {
        if (!allTiles[i].isFalseJoker &&
            allTiles[i].color == indicatorTile.color &&
            allTiles[i].value == okeyValue) {
          allTiles[i].isRealOkey = true;
        }
      }
    }

    // Thorough shuffle
    allTiles.shuffle(_random);

    // 3. Create 4 Players
    players = [
      OkeyPlayer(
        id: 'p_0',
        name: 'Alex K.',
        avatarUrl: 'assets/images/user_avatar.png',
        level: 28,
        rating: 1358,
        chips: 1250,
        isHuman: true,
      ),
      OkeyPlayer(
        id: 'p_1',
        name: 'Player',
        avatarUrl: 'assets/images/player_right.png',
        level: 24,
        rating: 1280,
        chips: 70,
        isHuman: false,
        botDifficulty: BotDifficulty.medium,
      ),
      OkeyPlayer(
        id: 'p_2',
        name: 'User',
        avatarUrl: 'assets/images/player_top.png',
        level: 24,
        rating: 1420,
        chips: 70,
        isHuman: false,
        botDifficulty: BotDifficulty.hard,
      ),
      OkeyPlayer(
        id: 'p_3',
        name: 'Player',
        avatarUrl: 'assets/images/player_left.png',
        level: 24,
        rating: 1190,
        chips: 70,
        isHuman: false,
        botDifficulty: BotDifficulty.medium,
      ),
    ];

    for (final p in players) {
      p.hasOpened = false;
      p.openedPoints = 0;
    }

    // Discard piles
    discardPiles = List.generate(4, (_) => <OkeyTile>[]);
    tableMelds = <OkeyGroup>[];
    if (rules.isRummy) {
      // رامي: الورقة المكشوفة الأولى (الـ Upcard) في كومة رمي اليسار —
      // يستطيع البشري أخذها في دوره الأول بدل السحب من الرزمة
      discardPiles[3].add(indicatorTile);
    }

    // 4. Deal: Okey starter gets 15, others 14 — Rummy deals 14 to everyone
    for (int i = 0; i < 4; i++) {
      final count = rules.isRummy ? 14 : ((i == 0) ? 15 : 14);
      final dealt = allTiles.sublist(0, count);
      allTiles.removeRange(0, count);

      for (int slot = 0; slot < dealt.length; slot++) {
        players[i].rackTiles[slot] = dealt[slot];
      }
    }

    drawDeck = allTiles;
    currentTurnIndex = 0; // Human starts
    // رامي: يد متساوية (14) فيبدأ الدور بالسحب — أوكي: البادئ بـ15 فيرمي أولاً
    turnPhase = rules.isRummy
        ? OkeyTurnPhase.awaitingDraw
        : OkeyTurnPhase.awaitingDiscard;
    gameState = OkeyGameState.yourTurn;
    selectedTileIndex = null;
    _takenLeftTile = null;
    lastDiscardTile = null;
    lastDiscardPlayer = -1;

    // Auto sort human hand initially for a clean presentation
    sortHumanTiles();
    _startTurnTimer();
    notifyListeners();
  }

  // ── TURN TIMER ──

  void _startTurnTimer() {
    _turnCountdownTimer?.cancel();
    turnTimeRemaining = turnDuration;

    _turnCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isDisposed) {
        timer.cancel();
        return;
      }
      if (turnTimeRemaining > 0) {
        turnTimeRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        _handleTurnTimeout();
      }
    });
  }

  void _handleTurnTimeout() {
    if (currentTurnIndex != 0) {
      // أونلاين على جهاز المضيف: لاعب بعيد تجاوز مهلة الدور — يلعب
      // المضيف عنه آلياً (سحب + رمي) فلا تتجمّد الغرفة على غائب
      if (remoteHumanSeats.contains(currentTurnIndex)) {
        autoPlaySeat(currentTurnIndex);
        onRemoteSeatAutoPlayed?.call(currentTurnIndex);
      }
      return; // bot timeouts handled by bot AI
    }

    if (turnPhase == OkeyTurnPhase.awaitingDraw) {
      drawFromDeck();
      // then immediately discard least useful
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!isDisposed) discardSelectedOrLastTile();
      });
    } else if (turnPhase == OkeyTurnPhase.awaitingDiscard) {
      discardSelectedOrLastTile();
    }
  }

  // ── HUMAN ACTIONS ──

  void selectTile(int slotIndex) {
    if (players[0].rackTiles[slotIndex] == null) {
      if (selectedTileIndex != null) {
        moveTile(selectedTileIndex!, slotIndex);
      }
      return;
    }

    if (selectedTileIndex == slotIndex) {
      selectedTileIndex = null;
    } else if (selectedTileIndex != null) {
      insertTile(selectedTileIndex!, slotIndex);
      return;
    } else {
      selectedTileIndex = slotIndex;
      OkeyAudio.playTilePickup();
    }
    notifyListeners();
  }

  void moveTile(int fromSlot, int toSlot) {
    insertTile(fromSlot, toSlot);
  }

  /// إدراج/وضع حر: خانة فارغة تستقبل الحجر في مكانها (الفجوات مسموحة)،
  /// وخانة مشغولة تُزيح الأحجار نحو الفراغ بدون دفعها بعيداً
  void insertTile(int fromSlot, int toSlot) {
    if (fromSlot == toSlot ||
        fromSlot < 0 ||
        fromSlot >= 28 ||
        toSlot < 0 ||
        toSlot >= 28) return;
    final rack = players[0].rackTiles;
    final tile = rack[fromSlot];
    if (tile == null) return;

    final fromRow = fromSlot ~/ 14;
    final toRow = toSlot ~/ 14;

    if (rack[toSlot] == null) {
      // خانة فارغة: ضع الحجر فيها مباشرة وتبقى الخانة المصدر فارغة
      rack[fromSlot] = null;
      rack[toSlot] = tile;
    } else if (fromRow == toRow) {
      // نفس الصف: أزح الأحجار نحو الفراغ الذي تركه الحجر المسحوب
      rack[fromSlot] = null;
      if (fromSlot < toSlot) {
        for (int i = fromSlot; i < toSlot - 1; i++) {
          rack[i] = rack[i + 1];
        }
        rack[toSlot - 1] = tile;
      } else {
        for (int i = fromSlot; i > toSlot; i--) {
          rack[i] = rack[i - 1];
        }
        rack[toSlot] = tile;
      }
    } else {
      // صف مختلف: أزح داخل صف الهدف نحو أقرب خانة فارغة
      rack[fromSlot] = null;
      final rs = toRow * 14;
      int? rightEmpty;
      for (int i = toSlot + 1; i < rs + 14; i++) {
        if (rack[i] == null) {
          rightEmpty = i;
          break;
        }
      }
      int? leftEmpty;
      for (int i = toSlot - 1; i >= rs; i--) {
        if (rack[i] == null) {
          leftEmpty = i;
          break;
        }
      }
      if (rightEmpty != null) {
        for (int i = rightEmpty; i > toSlot; i--) {
          rack[i] = rack[i - 1];
        }
        rack[toSlot] = tile;
      } else if (leftEmpty != null) {
        for (int i = leftEmpty; i < toSlot - 1; i++) {
          rack[i] = rack[i + 1];
        }
        rack[toSlot - 1] = tile;
      } else {
        // الصف الهدف ممتلئ: بدّل مع الهدف وأعد حجره إلى صف المصدر
        final displaced = rack[toSlot]!;
        rack[toSlot] = tile;
        final srs = fromRow * 14;
        int target = srs;
        while (target < srs + 14 && rack[target] != null) {
          target++;
        }
        rack[target < srs + 14 ? target : fromSlot] = displaced;
      }
    }

    selectedTileIndex = null;
    OkeyAudio.playTilePickup();
    notifyListeners();
  }

  /// الكتلة المتجاورة (أحجار بلا فراغ بينها) التي تحتوي الخانة
  List<int> groupSlotsAt(int slot) {
    final rack = players[0].rackTiles;
    if (slot < 0 || slot >= 28 || rack[slot] == null) return const [];
    final rs = slot < 14 ? 0 : 14;
    var a = slot, b = slot;
    while (a > rs && rack[a - 1] != null) {
      a--;
    }
    while (b < rs + 13 && rack[b + 1] != null) {
      b++;
    }
    return [for (var i = a; i <= b; i++) i];
  }

  /// نقل كتلة كاملة (Per) إلى مكان جديد في الرف — تبقى متلاصقة بترتيبها.
  /// toSlot = الخانة المطلوبة لأول حجر؛ إن لم تتسع يُختار أقرب مكان فارغ كافٍ.
  bool moveGroup(int anySlot, int toSlot) {
    final slots = groupSlotsAt(anySlot);
    if (slots.isEmpty || toSlot < 0 || toSlot >= 28) return false;
    final rack = players[0].rackTiles;
    final tiles = [for (final s in slots) rack[s]!];
    final n = tiles.length;
    for (final s in slots) {
      rack[s] = null;
    }

    bool fits(int start) {
      final rs = start < 14 ? 0 : 14;
      if (start < rs || start + n - 1 > rs + 13) return false;
      for (var i = start; i < start + n; i++) {
        if (rack[i] != null) return false;
      }
      return true;
    }

    final row = toSlot ~/ 14;
    final rs = row * 14;
    final desired = toSlot.clamp(rs, rs + 14 - n);
    int? best;
    for (var d = 0; d < 14 && best == null; d++) {
      for (final c in [desired - d, desired + d]) {
        if (c >= rs && c + n - 1 <= rs + 13 && fits(c)) {
          best = c;
          break;
        }
      }
    }
    if (best == null) {
      // لا مكان يتسع لها — تعود لمكانها
      for (var i = 0; i < n; i++) {
        rack[slots[i]] = tiles[i];
      }
      notifyListeners();
      return false;
    }
    for (var i = 0; i < n; i++) {
      rack[best + i] = tiles[i];
    }
    selectedTileIndex = null;
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  /// يضع الحجر المسحوب الجديد في الخانة التي أفلته عليها اللاعب
  void _placeDrawnAt(int placedSlot, int? toSlot) {
    if (toSlot == null || toSlot == placedSlot || toSlot < 0 || toSlot >= 28) {
      return;
    }
    insertTile(placedSlot, toSlot);
    // لا تحديد تلقائي بعد إعادة ترتيب الحجر المسحوب — التحديد ضغطة
    // صريحة فقط حتى لا يُنقل أو يُرمى لاحقاً عن غير قصد
    selectedTileIndex = null;
  }

  /// الحجر المأخوذ من مرميات اليسار هذا الدور — يُتتبَّع لقاعدة الإعادة:
  /// من أخذه ولم يفتح اللعب ولم ينزل يُعاده للكومة ويسحب بديلاً من الرزمة
  OkeyTile? _takenLeftTile;

  /// آخر حجر رُمي على الطاولة من أي لاعب ولاعبه — تُظهره الواجهة وحيداً
  /// فوق كومة المرميات الثابتة. يُصفَّر إذا أُخذ من الكومة أو أُعيد خلط
  /// المرميات في الرزمة، ويُحدَّث مع كل رمية جديدة.
  OkeyTile? lastDiscardTile;
  int lastDiscardPlayer = -1;

  /// حدث لحظي: بوت أخذ آخر حجر مرمي من كومة اللاعب السابق — تشغّله
  /// الواجهة لتحريك الحجر نحو حامل الآخذ بدل أن يبدو وكأنه اختفى
  void Function(int takerIndex, OkeyTile tile)? onDiscardTaken;

  /// مقاعد اللاعبين البشريين البعيدين في وضع الأونلاين (على جهاز
  /// المضيف فقط): الـAI لا يشغّلهم — حركاتهم تصل عبر
  /// applyRemoteAction، وتجاوز المهلة يشغّلهم آلياً
  final Set<int> remoteHumanSeats = {};

  /// يُستدعى عندما يلعب المضيف عن مقعد بعيد متجمد — الشاشة تعلّم
  /// المقعد «منقطعاً» على وثيقة الغرفة فيظهر للجميع
  void Function(int seat)? onRemoteSeatAutoPlayed;

  /// أحجار اليسار المأخوذة لكل مقعد بعيد — المقعد 0 يبقى عبر
  /// _takenLeftTile (قاعدة: من أخذه دون فتح يُعاده للكومة ويسحب بديلاً)
  final Map<int, OkeyTile> _takenLeftBySeat = {};

  /// صحيح في محرك المرآة على جهاز الضيف — لا توزيع ولا مؤقتات
  bool isOnlineMirror = false;

  void swapTiles(int slotA, int slotB) {
    final temp = players[0].rackTiles[slotA];
    players[0].rackTiles[slotA] = players[0].rackTiles[slotB];
    players[0].rackTiles[slotB] = temp;
    OkeyAudio.playTilePickup();
    notifyListeners();
  }

  /// عند نفاد رزمة السحب: تُنقل كل الأحجار المرمية وتُخلط من جديد
  void _refillDeckFromDiscards() {
    final recycled = <OkeyTile>[];
    for (final pile in discardPiles) {
      recycled.addAll(pile);
      pile.clear();
    }
    lastDiscardTile = null;
    lastDiscardPlayer = -1;
    if (recycled.isEmpty) return;
    recycled.shuffle(_random);
    drawDeck.addAll(recycled);
    onNotice?.call('🔄 نفدت رزمة السحب — أُعيد خلط {} حجراً مرموياً'
        .trp([recycled.length]));
  }

  /// يضمن وجود أحجار قابلة للسحب: إن نفدت الرزمة تُعاد خلط المرميات
  /// (يُستخدم من الواجهة قبل عرض أنيميشن السحب). يُرجع false فقط
  /// إن لم يتبقَّ أي حجر نهائياً (الرزمة والمرميات فارغة معاً).
  bool ensureDrawableDeck() {
    if (drawDeck.isEmpty) _refillDeckFromDiscards();
    return drawDeck.isNotEmpty;
  }

  /// هل يمكن إعادة ملء الرزمة من المرميات الآن؟
  bool get canRefillDeck =>
      drawDeck.isEmpty && discardPiles.any((p) => p.isNotEmpty);

  /// Draw from center stock
  bool drawFromDeck({int? toSlot}) {
    if (currentTurnIndex != 0 || turnPhase != OkeyTurnPhase.awaitingDraw) {
      return false;
    }
    if (drawDeck.isEmpty) _refillDeckFromDiscards();
    if (drawDeck.isEmpty) return false;

    final emptySlot = players[0].rackTiles.indexOf(null);
    if (emptySlot == -1) return false;

    final tile = drawDeck.removeAt(0);
    players[0].rackTiles[emptySlot] = tile;
    // لا تحديد تلقائي للحجر المسحوب — التحديد يتم بضغطة صريحة فقط،
    // حتى لا تبدّل ضغطةٌ لاحقة مكانه أو ترميه عن غير قصد
    selectedTileIndex = null;
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    gameState = OkeyGameState.discardPhase;
    _placeDrawnAt(emptySlot, toSlot);
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  /// Take the latest discarded tile from previous player (Left Bot, index 3)
  bool drawFromDiscard({int? toSlot}) {
    if (currentTurnIndex != 0 || turnPhase != OkeyTurnPhase.awaitingDraw) {
      return false;
    }
    final leftPlayerDiscards = discardPiles[3];
    if (leftPlayerDiscards.isEmpty) return false;
    // مرميات لاعب الفول مخفية ولا يجوز أخذها
    if (players[3].playStyle == OkeyPlayStyle.full) return false;

    final emptySlot = players[0].rackTiles.indexOf(null);
    if (emptySlot == -1) return false;

    final tile = leftPlayerDiscards.removeLast();
    if (identical(tile, lastDiscardTile)) {
      lastDiscardTile = null;
      lastDiscardPlayer = -1;
    }
    players[0].rackTiles[emptySlot] = tile;
    // لا تحديد تلقائي للحجر المسحوب — التحديد يتم بضغطة صريحة فقط
    selectedTileIndex = null;
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    gameState = OkeyGameState.discardPhase;
    _takenLeftTile = tile;
    _placeDrawnAt(emptySlot, toSlot);
    // أخذ حجر غيره لا يحوّل اللاعب كونكان — الأسلوب يُختار يدوياً فقط.
    // وإن لم يكمل نقاط الافتتاح ولم ينزل يُعاد الحجر عند الرمي.
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  // ══════════════════════════════════════════════════════
  // أسلوب اللعب: عادي / كونكان / فول
  // ══════════════════════════════════════════════════════

  /// هل يستطيع اللاعب البشري إعلان أسلوب (قبل أي نزول على الطاولة)؟
  bool get canDeclarePlayStyle =>
      !rules.isRummy &&
      players[0].playStyle == OkeyPlayStyle.normal &&
      !players[0].hasOpened &&
      !tableMelds.any((m) => m.ownerIndex == 0);

  /// اللاعب البشري يعلن كونكان أو فول
  bool declarePlayStyle(OkeyPlayStyle style) {
    if (style == OkeyPlayStyle.normal || !canDeclarePlayStyle) return false;
    players[0].playStyle = style;
    onNotice?.call(style == OkeyPlayStyle.full
        ? '🃏 بدأت اللعب فول — لون واحد من 1 إلى 13 ثم 1'.tr
        : '🀄 بدأت اللعب كونكان — 10 متسلسلة بلون واحد + بير'.tr);
    notifyListeners();
    return true;
  }

  /// النزول على الطاولة مسموح للأسلوب العادي فقط
  bool get humanCanLayMelds => players[0].playStyle == OkeyPlayStyle.normal;

  /// فوز اليد (بعد الرمي) حسب أسلوب اللاعب
  bool _styleWins(OkeyPlayer p, List<OkeyTile> tiles) {
    switch (p.playStyle) {
      case OkeyPlayStyle.konkan:
        return isKonkanHand(tiles);
      case OkeyPlayStyle.full:
        return isFullHand(tiles);
      case OkeyPlayStyle.normal:
        return p.hasOpened
            ? _remainingAllMeldable(tiles)
            : isWinningHand(tiles);
    }
  }

  /// فول: 14 حجراً بلون واحد = 1..13 + 1 إضافي (الأوكي يعوّض أي ناقص)
  bool isFullHand(List<OkeyTile> tiles) {
    if (tiles.length != 14) return false;
    final okeys = tiles.where((t) => t.isRealOkey).length;
    final regular = tiles.where((t) => !t.isRealOkey).toList();
    if (regular.isEmpty) return true;
    final color = regular.first.color;
    if (regular.any((t) => t.color != color)) return false;
    final need = <int, int>{for (var v = 1; v <= 13; v++) v: 1};
    need[1] = 2;
    for (final t in regular) {
      final left = need[t.value] ?? 0;
      if (left <= 0) return false; // رقم زائد عن التسلسل
      need[t.value] = left - 1;
    }
    final missing = need.values.fold(0, (a, b) => a + b);
    return missing <= okeys;
  }

  /// كونكان: تسلسل واحد بلون واحد من 10 أحجار فأكثر + بقية الأحجار بيرات صحيحة
  bool isKonkanHand(List<OkeyTile> tiles) {
    if (tiles.length < 13) return false;
    final okeys = tiles.where((t) => t.isRealOkey).toList();
    for (final color in OkeyTileColor.values) {
      final colorTiles =
          tiles.where((t) => !t.isRealOkey && t.color == color).toList();
      for (var len = 10; len <= tiles.length - 3; len++) {
        // تسلسل عادي start..start+len-1، أو ينتهي بـ 13→1
        for (var start = 1; start <= 14 - len + 1; start++) {
          final seq = [
            for (var i = 0; i < len; i++) ((start + i - 1) % 13) + 1
          ];
          if (start + len - 1 > 14) continue;
          final used = <OkeyTile>[];
          var jokersUsed = 0;
          var ok = true;
          for (final v in seq) {
            final m = colorTiles
                .where((t) => t.value == v && !used.contains(t))
                .toList();
            if (m.isNotEmpty) {
              used.add(m.first);
            } else if (jokersUsed < okeys.length) {
              used.add(okeys[jokersUsed++]);
            } else {
              ok = false;
              break;
            }
          }
          if (!ok) continue;
          final rest = List<OkeyTile>.from(tiles);
          for (final u in used) {
            rest.remove(u);
          }
          if (rest.length >= 3 && _canPartitionIntoValidMelds(rest)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Discard selected tile
  bool discardSelectedTile() {
    if (selectedTileIndex == null) return false;
    return discardSlot(selectedTileIndex!);
  }

  /// Discard specific slot
  bool discardSlot(int slotIndex) {
    if (currentTurnIndex != 0 || turnPhase != OkeyTurnPhase.awaitingDiscard) {
      return false;
    }
    var tile = players[0].rackTiles[slotIndex];
    if (tile == null) return false;

    // إذا أنزل أحجاراً ولم تكتمل نقاط الافتتاح (101) تُعاد إلى الرف
    if (!players[0].hasOpened) {
      _retractPendingMelds(0);
    }

    // من أخذ حجر مرميات اليسار ولم يفتح اللعب (لم يكمل النقاط ولم ينزل)
    // يُعاد الحجر إلى كومته ويسحب بديلاً من الرزمة. الفاتح والكونكان
    // والفول ورامي يحتفظون بحجرهم — لا نقاط افتتاح مطلوبة منهم
    final taken = _takenLeftTile;
    _takenLeftTile = null;
    if (taken != null &&
        !rules.isRummy &&
        players[0].playStyle == OkeyPlayStyle.normal &&
        !players[0].hasOpened) {
      _returnTakenLeftTile(taken);
      if (identical(tile, taken)) {
        // كان يحاول رمي الحجر المأخوذ نفسه — عاد للكومة وسُحب بديله؛
        // يختار الآن حجراً آخر للرمي
        notifyListeners();
        return true;
      }
      // قد تكون الخانة المختارة أُعيد ملؤها بالسحب — أعد القراءة
      tile = players[0].rackTiles[slotIndex];
      if (tile == null) return false;
    }

    players[0].rackTiles[slotIndex] = null;
    // لا نضغط الصف — الفجوات تحافظ على تجميعات اللاعب منفصلة
    discardPiles[0].add(tile);
    lastDiscardTile = tile;
    lastDiscardPlayer = 0;
    selectedTileIndex = null;
    OkeyAudio.playTileDiscard();

    // Check if human won by discarding!
    final remaining = players[0].activeTiles;
    final won = _styleWins(players[0], remaining);
    if (won) {
      _declareWinner(
          players[0], tile.isRealOkey ? WinType.discardOkey : WinType.normal);
      return true;
    }

    _advanceTurn();
    return true;
  }

  void discardSelectedOrLastTile() {
    if (selectedTileIndex != null &&
        players[0].rackTiles[selectedTileIndex!] != null) {
      discardSlot(selectedTileIndex!);
      return;
    }
    // Discard the first non-Okey tile
    for (int i = 27; i >= 0; i--) {
      final t = players[0].rackTiles[i];
      if (t != null && !t.isRealOkey) {
        discardSlot(i);
        return;
      }
    }
    // Fallback
    for (int i = 27; i >= 0; i--) {
      if (players[0].rackTiles[i] != null) {
        discardSlot(i);
        return;
      }
    }
  }

  void _advanceTurn() {
    currentTurnIndex = (currentTurnIndex + 1) % 4;
    turnPhase = OkeyTurnPhase.awaitingDraw;
    gameState = (currentTurnIndex == 0)
        ? OkeyGameState.yourTurn
        : OkeyGameState.opponentTurn;
    _startTurnTimer();

    if (currentTurnIndex == 0) {
      OkeyAudio.playTurnNotification();
    }

    notifyListeners();

    // مقاعد اللاعبين البعيدين لا يشغّلها الـAI — تنتظر حركاتهم
    if (currentTurnIndex != 0 && !remoteHumanSeats.contains(currentTurnIndex)) {
      _runBotTurn();
    }
  }

  void _declareWinner(OkeyPlayer p, WinType type) {
    winner = p;
    winType = type;
    turnPhase = OkeyTurnPhase.gameOver;
    gameState = OkeyGameState.win;
    _turnCountdownTimer?.cancel();
    _botTimer?.cancel();

    if (p.isHuman) {
      OkeyAudio.playWin();
    }

    FirebaseService().logGameResult(
      winnerName: p.name,
      winType: type.name,
      roundDurationSeconds: turnDuration - turnTimeRemaining,
    );

    notifyListeners();
  }

  // ── BOT AI ENGINE ──

  void _runBotTurn() {
    _botTimer?.cancel();
    if (isDisposed) return;

    final bot = players[currentTurnIndex];
    final thinkDelay = Duration(milliseconds: 1400 + _random.nextInt(800));

    _botTimer = Timer(thinkDelay, () {
      if (isDisposed ||
          currentTurnIndex == 0 ||
          remoteHumanSeats.contains(currentTurnIndex)) return;

      final prevIndex = (currentTurnIndex + 3) % 4;
      final prevDiscards = discardPiles[prevIndex];

      // 1. Draw Phase: Check if previous player discard helps
      OkeyTile drawnTile;
      bool takeDiscard = false;

      if (prevDiscards.isNotEmpty &&
          players[prevIndex].playStyle != OkeyPlayStyle.full &&
          bot.botDifficulty != BotDifficulty.easy) {
        final candidate = prevDiscards.last;
        final currentHand = bot.activeTiles;
        // البوت قد لا يلاحظ حجراً مفيداً أحياناً (واقعية — لا لعب مثالي)
        if (_tileUsefulForHand(currentHand, candidate) &&
            _random.nextDouble() >= _mistakeChance(bot.botDifficulty)) {
          takeDiscard = true;
        }
      }

      if (takeDiscard && prevDiscards.isNotEmpty) {
        drawnTile = prevDiscards.removeLast();
        if (identical(drawnTile, lastDiscardTile)) {
          lastDiscardTile = null;
          lastDiscardPlayer = -1;
        }
        // أُشعر الواجهة لتحريك الحجر إلى حامل الآخذ — بلا هذه الحركة
        // يبدو الحجر وكأنه اختفى فجأة من الطاولة
        onDiscardTaken?.call(currentTurnIndex, drawnTile);
      } else {
        // رزمة فارغة؟ أعد خلط المرميات أولاً
        if (drawDeck.isEmpty) _refillDeckFromDiscards();
        if (drawDeck.isNotEmpty) {
          drawnTile = drawDeck.removeAt(0);
        } else {
          // Deck empty -> Draw round end
          gameState = OkeyGameState.roundEnd;
          turnPhase = OkeyTurnPhase.gameOver;
          notifyListeners();
          return;
        }
      }

      // Place tile in bot rack
      final emptyIdx = bot.rackTiles.indexOf(null);
      if (emptyIdx != -1) {
        bot.rackTiles[emptyIdx] = drawnTile;
      } else {
        bot.rackTiles[bot.rackTiles.length - 1] = drawnTile;
      }
      notifyListeners();

      // البوت يحاول النزول بمجموعة إن أمكن (يحترم شرط الافتتاح 101)
      _botTryLayMeld(bot, currentTurnIndex);

      // Check if bot has winning 15 tiles (discard one to win)
      Timer(const Duration(milliseconds: 900), () {
        if (isDisposed || currentTurnIndex == 0 || winner != null) return;

        final active = bot.activeTiles;
        // Check winning hand
        for (int i = 0; i < active.length; i++) {
          final candidateDiscard = active[i];
          final remaining14 = List<OkeyTile>.from(active)..removeAt(i);
          final botWon = _styleWins(bot, remaining14);
          if (botWon) {
            final slot = bot.rackTiles.indexOf(candidateDiscard);
            if (slot != -1) bot.rackTiles[slot] = null;
            discardPiles[currentTurnIndex].add(candidateDiscard);
            lastDiscardTile = candidateDiscard;
            lastDiscardPlayer = currentTurnIndex;
            _declareWinner(
                bot,
                candidateDiscard.isRealOkey
                    ? WinType.discardOkey
                    : WinType.normal);
            return;
          }
        }

        // Strategic discard
        final discardTile = _chooseBotDiscard(active, bot.botDifficulty);
        final slot = bot.rackTiles.indexOf(discardTile);
        if (slot != -1) {
          bot.rackTiles[slot] = null;
        }
        discardPiles[currentTurnIndex].add(discardTile);
        lastDiscardTile = discardTile;
        lastDiscardPlayer = currentTurnIndex;
        OkeyAudio.playTileDiscard();

        _advanceTurn();
      });
    });
  }

  bool _tileUsefulForHand(List<OkeyTile> hand, OkeyTile candidate) {
    if (candidate.isRealOkey) return true;
    int sameColorAdjacent = 0;
    int sameNumberDiffColor = 0;

    for (final t in hand) {
      if (t.color == candidate.color &&
          (t.value == candidate.value - 1 || t.value == candidate.value + 1)) {
        sameColorAdjacent++;
      }
      if (t.value == candidate.value && t.color != candidate.color) {
        sameNumberDiffColor++;
      }
    }
    return sameColorAdjacent >= 1 || sameNumberDiffColor >= 1;
  }

  /// احتمال خطأ البوت حسب الصعوبة — حتى لا يلعب دائماً بشكل مثالي
  double _mistakeChance(BotDifficulty d) {
    switch (d) {
      case BotDifficulty.easy:
        return 0.45;
      case BotDifficulty.medium:
        return 0.25;
      case BotDifficulty.hard:
        return 0.10;
    }
  }

  OkeyTile _chooseBotDiscard(List<OkeyTile> tiles, BotDifficulty difficulty) {
    // Never discard real Okey if possible
    final nonOkeys = tiles.where((t) => !t.isRealOkey).toList();
    if (nonOkeys.isEmpty) return tiles.last;

    // أحياناً يرمي حجراً عشوائياً بدل الأمثل — لعب واقعي منصف
    if (_random.nextDouble() < _mistakeChance(difficulty) &&
        nonOkeys.length > 1) {
      return nonOkeys[_random.nextInt(nonOkeys.length)];
    }

    // Find the most isolated tile (no adjacent colors, no matching numbers)
    OkeyTile bestDiscard = nonOkeys.first;
    int minConnections = 999;

    for (final t in nonOkeys) {
      int conn = 0;
      for (final other in nonOkeys) {
        if (other == t) continue;
        if (other.color == t.color &&
            (other.value == t.value - 1 || other.value == t.value + 1)) {
          conn += 2;
        }
        if (other.value == t.value && other.color != t.color) {
          conn += 2;
        }
      }
      if (conn < minConnections) {
        minConnections = conn;
        bestDiscard = t;
      }
    }
    return bestDiscard;
  }

  // ── WIN VALIDATION ENGINE ──

  /// Checks if 14 tiles form a winning hand:
  /// - 7 identical pairs (Çift), OR
  /// - Complete partition into valid runs (3+) and sets (3 or 4) with Okey wildcards
  bool isWinningHand(List<OkeyTile> tiles) {
    if (tiles.length != 14) return false;

    // 1. Check Seven Pairs (Çift) — قانون أربيل لا يسمح بها
    if (rules.allowSevenPairs && _checkSevenPairs(tiles)) return true;

    // 2. Check Runs and Sets partition via recursive backtracking
    return _canPartitionIntoValidMelds(tiles);
  }

  bool _checkSevenPairs(List<OkeyTile> tiles) {
    final regular = tiles.where((t) => !t.isRealOkey).toList();
    int okeyCount = tiles.length - regular.length;

    final counts = <String, int>{};
    for (final t in regular) {
      final key = '${t.color.name}_${t.value}';
      counts[key] = (counts[key] ?? 0) + 1;
    }

    int completePairs = 0;
    int singletons = 0;

    for (final count in counts.values) {
      completePairs += count ~/ 2;
      singletons += count % 2;
    }

    // Singletons can be paired with Okeys
    if (singletons <= okeyCount) {
      completePairs += singletons;
      okeyCount -= singletons;
      completePairs += okeyCount ~/ 2;
    }

    return completePairs >= 7;
  }

  bool _canPartitionIntoValidMelds(List<OkeyTile> tiles) {
    return _searchMelds(List<OkeyTile>.from(tiles));
  }

  bool _searchMelds(List<OkeyTile> remaining) {
    if (remaining.isEmpty) return true;

    // Pick first non-okey tile, or first tile
    final first = remaining.first;

    // Find all possible valid runs or sets of length 3, 4, 5 that include 'first'
    final candidateMelds = _findMeldsContaining(remaining, first);

    for (final meld in candidateMelds) {
      final nextRemaining = List<OkeyTile>.from(remaining);
      for (final m in meld) {
        nextRemaining.remove(m);
      }
      if (_searchMelds(nextRemaining)) {
        return true;
      }
    }

    return false;
  }

  List<List<OkeyTile>> _findMeldsContaining(
      List<OkeyTile> pool, OkeyTile target) {
    final results = <List<OkeyTile>>[];
    final okeys = pool.where((t) => t.isRealOkey).toList();

    // 1. Check Sets of size 3 and 4 (same number, different colors)
    final sameNumber =
        pool.where((t) => !t.isRealOkey && t.value == target.value).toList();
    // Unique colors
    final byColor = <OkeyTileColor, OkeyTile>{};
    for (final t in sameNumber) {
      byColor[t.color] = t;
    }
    final uniqueColorTiles = byColor.values.toList();

    // Try set of 3
    if (uniqueColorTiles.length >= 3) {
      results.add(uniqueColorTiles.sublist(0, 3));
    }
    if (uniqueColorTiles.length >= 2 && okeys.isNotEmpty) {
      results.add([uniqueColorTiles[0], uniqueColorTiles[1], okeys[0]]);
    }
    // Try set of 4
    if (uniqueColorTiles.length >= 4) {
      results.add(uniqueColorTiles.sublist(0, 4));
    }
    if (uniqueColorTiles.length == 3 && okeys.isNotEmpty) {
      results.add([
        uniqueColorTiles[0],
        uniqueColorTiles[1],
        uniqueColorTiles[2],
        okeys[0]
      ]);
    }

    // 2. Check Runs of size 3, 4, 5 (same color, consecutive values)
    // Runs for normal values 1..13 plus 12-13-1
    final sameColor =
        pool.where((t) => !t.isRealOkey && t.color == target.color).toList();

    for (int len = 3; len <= 5; len++) {
      for (int start = 1; start <= 13 - len + 1; start++) {
        final needed = List.generate(len, (i) => start + i);
        if (needed.contains(target.value)) {
          _tryBuildRun(needed, sameColor, okeys, results);
        }
      }
      // Check 12-13-1 special run
      if (len == 3 &&
          (target.value == 12 || target.value == 13 || target.value == 1)) {
        _tryBuildRun([12, 13, 1], sameColor, okeys, results);
      }
      if (len == 4 &&
          (target.value == 11 ||
              target.value == 12 ||
              target.value == 13 ||
              target.value == 1)) {
        _tryBuildRun([11, 12, 13, 1], sameColor, okeys, results);
      }
    }

    return results;
  }

  void _tryBuildRun(
    List<int> sequence,
    List<OkeyTile> colorPool,
    List<OkeyTile> okeys,
    List<List<OkeyTile>> results,
  ) {
    final meld = <OkeyTile>[];
    final usedOkeys = <OkeyTile>[];

    for (final v in sequence) {
      final match =
          colorPool.where((t) => t.value == v && !meld.contains(t)).toList();
      if (match.isNotEmpty) {
        meld.add(match.first);
      } else if (usedOkeys.length < okeys.length) {
        final ok = okeys[usedOkeys.length];
        usedOkeys.add(ok);
        meld.add(ok);
      } else {
        return; // sequence cannot be fulfilled
      }
    }

    if (meld.length == sequence.length) {
      results.add(meld);
    }
  }

  /// الفوز بعد فتح اللعب: كل أحجار الرف المتبقية يجب أن تتقسم
  /// بالكامل إلى مجموعات صحيحة (أو لا يبقى شيء بعد الرمي)
  bool _remainingAllMeldable(List<OkeyTile> tiles) {
    if (tiles.isEmpty) return true;
    if (tiles.length < 3) return false;
    return _canPartitionIntoValidMelds(tiles);
  }

  /// هل يمكن إفراغ كل الأحجار المتبقية على الطاولة؟ كل حجر إما يُصرف
  /// على بير موجود (يمدّ سلسلة أو يكمل مجموعة) أو يدخل في بير جديد
  /// صحيح يُنزل من الأحجار نفسها — وهذا شرط إعلان الفوز للفاتح
  bool _remainingAllPlaceableOnTable(List<OkeyTile> tiles) {
    if (tiles.isEmpty) return true;
    final sim = tableMelds.map(_MeldBound.of).toList();
    return _searchPlaceAll(List<OkeyTile>.from(tiles), sim);
  }

  bool _searchPlaceAll(List<OkeyTile> rem, List<_MeldBound> sim) {
    if (rem.isEmpty) return true;
    final first = rem.first;
    final rest = rem.sublist(1);

    // ١) صرفه على بير موجود على الطاولة (الأوكي يمدّ أي طرف متاح)
    for (final m in sim) {
      final snap = m.snapshot();
      if (m.fits(first)) {
        m.apply(first);
        if (_searchPlaceAll(rest, sim)) return true;
        m.restore(snap);
      }
    }

    // ٢) يدخل في بير جديد يُنزل من الأحجار المتبقية نفسها
    for (final meld in _findMeldsContaining(rem, first)) {
      final next = List<OkeyTile>.from(rem);
      for (final t in meld) {
        next.remove(t);
      }
      if (_searchPlaceAll(next, sim)) return true;
    }
    return false;
  }

  /// المجموعات الجاهزة على رف اللاعب البشري (كتل متجاورة صحيحة)
  /// — لعرض النقاط/البيرات لحظياً قبل النزول
  List<List<OkeyTile>> get rackReadyGroups {
    final groups = <List<OkeyTile>>[];
    final rack = players[0].rackTiles;
    for (final rowStart in [0, 14]) {
      int i = rowStart;
      while (i < rowStart + 14) {
        if (rack[i] == null) {
          i++;
          continue;
        }
        int j = i;
        while (j < rowStart + 14 && rack[j] != null) {
          j++;
        }
        final block = rack.sublist(i, j).whereType<OkeyTile>().toList();
        if (block.length >= 3 && (_isValidRun(block) || _isValidSet(block))) {
          groups.add(block);
        }
        i = j;
      }
    }
    return groups;
  }

  /// نقاط المجموعات الجاهزة على الرف + المنزولة على الطاولة
  int get livePoints =>
      meldPointsFor(0) +
      rackReadyGroups.fold(
          0, (sum, g) => sum + okeyMeldPoints(g, _isValidRun(g)));

  /// عدد البيرات: المنزولة + الجاهزة على الرف
  int get liveGroupCount =>
      tableMelds.where((m) => m.ownerIndex == 0).length +
      rackReadyGroups.length;

  /// أزواج متطابقة على الرف (لقانون الأزواج السبعة)
  int get rackPairCount {
    final counts = <String, int>{};
    for (final t in players[0].activeTiles) {
      if (t.isRealOkey) continue;
      final k = '${t.color.name}_${t.value}';
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts.values.fold(0, (sum, c) => sum + c ~/ 2);
  }

  int get tableMeldPoints => tableMelds.fold(
        0,
        (sum, meld) =>
            sum + meld.tiles.fold(0, (tileSum, tile) => tileSum + tile.value),
      );

  /// نقاط البيرات التي أنزلها لاعب معين على الطاولة
  int meldPointsFor(int playerIndex) => tableMelds
      .where((m) => m.ownerIndex == playerIndex)
      .fold(0, (sum, m) => sum + m.points);

  /// النقاط المعلّقة للاعب البشري (لم تُحتسب بعد لعدم اكتمال الافتتاح)
  int get pendingOpenPoints => tableMelds
      .where((m) => m.ownerIndex == 0 && m.pending)
      .fold(0, (sum, m) => sum + m.points);

  bool get hasPendingMelds =>
      tableMelds.any((m) => m.ownerIndex == 0 && m.pending);

  // ── الصرف على بيرات الطاولة (Layoff) ──

  /// هل يمكن إضافة الحجر إلى بير نازل على الطاولة؟
  /// يعمل على بيرات أي لاعب — لكن يشترط أن يكون اللاعب فاتحاً اللعب
  bool canLayOffTile(OkeyTile tile, OkeyGroup meld) {
    if (tile.isRealOkey) return true; // الأوكي يمثّل أي حجر

    if (meld.isRun) {
      // سلسلة: نفس اللون ويمدّ الطرف الأدنى أو الأعلى — الحدود الفعلية
      // تُحسب بمواضع الأوكي داخلها (5-6-أوكي تنتهي عند 7 لا 6)
      final nonOkey = meld.tiles.where((t) => !t.isRealOkey).toList();
      if (nonOkey.isEmpty) return true;
      if (tile.color != nonOkey.first.color) return false;
      return _runLayoffSide(meld.tiles, tile.value) != 0;
    }

    // مجموعة (Set): نفس القيمة، لون غير مكرر، وبحد أقصى 4 أحجار
    if (meld.tiles.length >= 4) return false;
    final nonOkey = meld.tiles.where((t) => !t.isRealOkey).toList();
    if (nonOkey.isNotEmpty && tile.value != nonOkey.first.value) return false;
    return !nonOkey.any((t) => t.color == tile.color);
  }

  /// في أي طرف يُصرف الرقم على السلسلة: -1 = قبل البداية، 1 = بعد
  /// النهاية، 0 = لا يصرف. الحدود محسوبة بمواضع الأوكي الفعلية
  int _runLayoffSide(List<OkeyTile> tiles, int value) {
    final start = okeyRunStart(tiles);
    if (start == null) return 0;
    final end = start + tiles.length - 1;
    if (start > 1 && value == start - 1) return -1;
    if (end < 13 && value == end + 1) return 1;
    if (end == 13 && value == 1) return 1; // التفاف 12-13-1
    return 0;
  }

  /// إدراج حجر مصروف في موضعه الصحيح داخل البير — السلاسل تبقى
  /// مرتبة (الطرف الأدنى أولاً) فلا يظهر حجر 4 بعد 8 كما كان عند البوت
  void _insertIntoMeld(OkeyGroup meld, OkeyTile tile) {
    if (!meld.isRun) {
      meld.tiles.add(tile);
      return;
    }
    if (tile.isRealOkey) {
      // الأوكي يمدّ النهاية إن أمكن وإلا البداية
      final start = okeyRunStart(meld.tiles) ?? 1;
      final end = start + meld.tiles.length - 1;
      if (end < 14) {
        meld.tiles.add(tile);
      } else {
        meld.tiles.insert(0, tile);
      }
      return;
    }
    if (_runLayoffSide(meld.tiles, tile.value) == -1) {
      meld.tiles.insert(0, tile);
    } else {
      meld.tiles.add(tile);
    }
  }

  /// موضع الأوكي في البير الذي يمثّله هذا الحجر بالضبط، أو -1.
  /// سلسلة: الأوكي في موضع قيمته = رقم الحجر وبنفس اللون.
  /// مجموعة: الحجر بقيمة المجموعة ولون غير موجود فيها.
  int jokerSlotFor(OkeyGroup meld, OkeyTile tile) {
    if (tile.isRealOkey) return -1;
    if (!meld.tiles.any((t) => t.isRealOkey)) return -1;
    if (meld.isRun) {
      final start = okeyRunStart(meld.tiles);
      if (start == null) return -1;
      final color =
          meld.tiles.firstWhere((t) => !t.isRealOkey, orElse: () => tile).color;
      if (tile.color != color) return -1;
      for (var k = 0; k < meld.tiles.length; k++) {
        if (!meld.tiles[k].isRealOkey) continue;
        final v = start + k;
        if ((v == 14 ? 1 : v) == tile.value) return k;
      }
      return -1;
    }
    final value = okeySetValue(meld.tiles);
    if (value != 0 && tile.value != value) return -1;
    if (meld.tiles.any((t) => !t.isRealOkey && t.color == tile.color)) {
      return -1;
    }
    return meld.tiles.indexWhere((t) => t.isRealOkey);
  }

  /// أخذ الجوكر من بير على الطاولة: تضع الحجر الحقيقي الذي يمثّله الأوكي
  /// مكانه وتأخذ الأوكي إلى رفّك. يشترط دورك وأن تكون فاتحاً (أو البير
  /// بيرك المعلّق) — مثل الصرف تماماً
  bool swapJokerFromMeld(int slotIndex, int meldIndex) {
    final human = players[0];
    if (currentTurnIndex != 0 || !humanCanLayMelds) return false;
    if (slotIndex < 0 ||
        slotIndex >= 28 ||
        meldIndex < 0 ||
        meldIndex >= tableMelds.length) return false;
    final tile = human.rackTiles[slotIndex];
    if (tile == null) return false;
    final meld = tableMelds[meldIndex];
    final myPending = meld.ownerIndex == 0 && meld.pending;
    if (!human.hasOpened && !myPending) return false;
    final k = jokerSlotFor(meld, tile);
    if (k == -1) return false;

    final joker = meld.tiles[k];
    meld.tiles[k] = tile;
    human.rackTiles[slotIndex] = joker;
    selectedTileIndex = slotIndex;
    OkeyAudio.playTilePickup();
    onNotice?.call('🃏 أخذت الجوكر ووضعت حجرك مكانه'.tr);
    notifyListeners();
    return true;
  }

  /// صرف حجر من رف اللاعب البشري على بير نازل على الطاولة
  /// - بيراتك المعلّقة (لم تكتمل نقاط الافتتاح بعد) تُمدّ دائماً في دورك
  /// - بيراتك الثابتة وبيرات الخصوم تشترط أن تكون قد فتحت اللعب
  /// - في الكونكان والفول لا يوجد نزول على الطاولة أصلاً
  bool layTileOnMeld(int slotIndex, int meldIndex) {
    final human = players[0];
    if (currentTurnIndex != 0) return false;
    if (!humanCanLayMelds) return false;
    if (slotIndex < 0 ||
        slotIndex >= 28 ||
        meldIndex < 0 ||
        meldIndex >= tableMelds.length) return false;
    final tile = human.rackTiles[slotIndex];
    if (tile == null) return false;
    final meld = tableMelds[meldIndex];
    final myPending = meld.ownerIndex == 0 && meld.pending;
    if (!human.hasOpened && !myPending) return false;
    if (!canLayOffTile(tile, meld)) return false;

    human.rackTiles[slotIndex] = null;
    _insertIntoMeld(meld, tile);

    selectedTileIndex = null;
    OkeyAudio.playTileDiscard();

    // إن كان البير معلّقاً فالصرف يزيد نقاط الافتتاح — وقد يكمل الفتح
    if (meld.pending && !human.hasOpened) {
      final total = meldPointsFor(0);
      if (total >= rules.openingPoints) {
        human.hasOpened = true;
        human.openedPoints = total;
        for (final m in tableMelds.where((m) => m.ownerIndex == 0)) {
          m.pending = false;
        }
        onNotice?.call(rules.isRummy
            ? '✨ أنزلت بيراتك على الطاولة!'.tr
            : '🎉 فتحت اللعب بـ {} نقطة!'.trp([total]));
      }
    }

    // الحجر المصروف أفرغ الرف كاملاً على الطاولة = فوز فوري به —
    // الفوز يتم بآخر حجر يُصرف على بير، لا برمي حجر أخير
    if (human.activeTiles.isEmpty) {
      _checkEmptyRackWin(0);
      return true;
    }

    final ownerName = meld.ownerIndex == 0
        ? 'بيرك'.tr
        : 'بير {}'.trp([players[meld.ownerIndex].name]);
    onNotice
        ?.call('✨ صرفت حجراً على {} (+{} نقطة)'.trp([ownerName, tile.value]));
    notifyListeners();
    return true;
  }

  int get remainingOpeningPoints => players[0].hasOpened
      ? 0
      : math.max(0, rules.openingPoints - meldPointsFor(0));

  /// إذا أفرغ اللاعب رفّه كاملاً على الطاولة فهو فائز — الحجر الأخير
  /// الذي نزل (مصروفاً على بير أو ضمن بير جديد) هو حجر الفوز، ولا
  /// حاجة لرمي حجر إضافي. البيرات المعلّقة دون نقاط الافتتاح تُعاد
  /// إلى الرف بدل إعلان الفوز
  void _checkEmptyRackWin(int playerIndex) {
    final p = players[playerIndex];
    if (p.activeTiles.isNotEmpty || winner != null) return;
    if (!p.hasOpened) {
      final total = meldPointsFor(playerIndex);
      if (total >= rules.openingPoints) {
        p.hasOpened = true;
        p.openedPoints = total;
        for (final m in tableMelds.where((m) => m.ownerIndex == playerIndex)) {
          m.pending = false;
        }
      } else {
        _retractPendingMelds(playerIndex);
        notifyListeners();
        return;
      }
    }
    _declareWinner(p, WinType.normal);
  }

  /// إعادة الأحجار المعلّقة إلى رف اللاعب عند عدم اكتمال الافتتاح
  void _retractPendingMelds(int playerIndex) {
    final pending =
        tableMelds.where((m) => m.ownerIndex == playerIndex && m.pending);
    if (pending.isEmpty) return;

    final rack = players[playerIndex].rackTiles;
    int returned = 0;
    for (final meld in pending.toList()) {
      for (final tile in meld.tiles) {
        final emptySlot = rack.indexOf(null);
        if (emptySlot != -1) {
          rack[emptySlot] = tile;
          returned++;
        }
      }
      tableMelds.remove(meld);
    }
    if (returned > 0) {
      onNotice?.call('لم تكتمل نقاط الافتتاح ({}) — أُعيدت الأحجار إلى رفّك'
          .trp([rules.openingPoints]));
    }
  }

  /// من أخذ حجر مرميات اليسار ولم يكمل نقاط الافتتاح ولم ينزل:
  /// يُعاد الحجر إلى كومة صاحبه ويسحب اللاعب بديلاً من الرزمة
  /// في الخانة نفسها — فيكمل دوره ويرمي بشكل طبيعي
  void _returnTakenLeftTile(OkeyTile taken) {
    final rack = players[0].rackTiles;
    final slot = rack.indexWhere((t) => identical(t, taken));
    if (slot != -1) {
      rack[slot] = null;
      discardPiles[3].add(taken);
      // الحجر العائد لقمة الكومة — يُظهر مكشوفاً فوقها من جديد
      lastDiscardTile = taken;
      lastDiscardPlayer = 3;
    }
    if (drawDeck.isEmpty) _refillDeckFromDiscards();
    if (drawDeck.isNotEmpty) {
      final empty = rack.indexOf(null);
      if (empty != -1) {
        final drawn = drawDeck.removeAt(0);
        rack[empty] = drawn;
        selectedTileIndex = null;
      }
    }
    onNotice?.call(
        'لم تكتمل نقاط الافتتاح — عاد الحجر لكومة اليسار وسحبت من الرزمة'.tr);
    OkeyAudio.playTileDraw();
  }

  /// يبحث في أحجار البوت الفعلية عن كل المجموعات الصالحة غير
  /// المتداخلة — سلاسل ومجموعات قيمة — ويستعين بالأوكي الحقيقي
  /// لإكمال زوجٍ إلى ثلاثية
  List<_BotMeld> _findBotMelds(OkeyPlayer bot) {
    final tiles = bot.activeTiles;
    final jokers = tiles.where((t) => t.isRealOkey).toList();
    final normal = tiles.where((t) => !t.isRealOkey).toList();
    final used = <OkeyTile>{};
    final melds = <_BotMeld>[];
    var jokersUsed = 0;

    // مجموعات القيمة: نفس الرقم بألوان مختلفة (3 أو 4)
    final byValue = <int, Map<OkeyTileColor, OkeyTile>>{};
    for (final t in normal) {
      byValue.putIfAbsent(t.value, () => {}).putIfAbsent(t.color, () => t);
    }
    for (final entry in byValue.entries) {
      final distinct = entry.value.values.toList();
      if (distinct.length >= 3) {
        final g = distinct.take(4).toList();
        melds.add(_BotMeld(List.of(g), false));
        used.addAll(g);
      }
    }

    // سلاسل اللون: نفس اللون بقيم متتالية (3+)
    final byColor = <OkeyTileColor, Map<int, OkeyTile>>{};
    for (final t in normal) {
      if (used.contains(t)) continue;
      byColor.putIfAbsent(t.color, () => {})[t.value] = t;
    }
    for (final entry in byColor.entries) {
      final vals = entry.value.keys.toList()..sort();
      var i = 0;
      while (i < vals.length) {
        var j = i;
        while (j + 1 < vals.length && vals[j + 1] == vals[j] + 1) j++;
        final len = j - i + 1;
        if (len >= 3) {
          final g = [for (var k = i; k <= j; k++) entry.value[vals[k]]!];
          melds.add(_BotMeld(g, true));
          used.addAll(g);
        } else if (len == 2 && jokersUsed < jokers.length) {
          // زوج متتالي + أوكي = سلسلة ثلاثية
          final g = [entry.value[vals[i]]!, entry.value[vals[j]]!];
          melds.add(_BotMeld(g, true, jokers: 1));
          used.addAll(g);
          jokersUsed++;
        }
        i = j + 1;
      }
    }

    // زوج قيمة + أوكي = مجموعة ثلاثية
    for (final entry in byValue.entries) {
      if (jokersUsed >= jokers.length) break;
      final free = entry.value.values.where((t) => !used.contains(t));
      if (free.length == 2) {
        final g = free.toList();
        melds.add(_BotMeld(g, false, jokers: 1));
        used.addAll(g);
        jokersUsed++;
      }
    }
    // حارس أخير: لا ينزل البوت إلا بيراً صحيحاً بنفس قواعد اللاعب
    return melds.where((m) {
      final test = [
        ...m.tiles,
        for (var j = 0; j < m.jokers; j++) realOkeySample,
      ];
      return m.isRun ? _isValidRun(test) : _isValidSet(test);
    }).toList();
  }

  /// نقاط مجموعة بوت للافتتاح (الأوكي المستخدم يُحتسب 10)
  int _botMeldPoints(_BotMeld m) => okeyMeldPoints([
        ...m.tiles,
        for (var j = 0; j < m.jokers; j++) realOkeySample,
      ], m.isRun);

  /// إنزال مجموعة بوت واحدة على الطاولة (يُرفق أوكي حقيقي إن استُخدم)
  void _layBotMeld(int playerIndex, _BotMeld meld) {
    final bot = players[playerIndex];
    final tiles = List<OkeyTile>.of(meld.tiles);
    for (var j = 0; j < meld.jokers; j++) {
      final joker = bot.activeTiles
          .where((t) => t.isRealOkey && !tiles.contains(t))
          .firstOrNull;
      if (joker != null) tiles.add(joker);
    }
    for (final t in tiles) {
      final slot = bot.rackTiles.indexOf(t);
      if (slot != -1) bot.rackTiles[slot] = null;
    }
    tableMelds.add(OkeyGroup(
      tiles: tiles,
      isRun: meld.isRun,
      ownerIndex: playerIndex,
    ));
  }

  /// محاولة البوت إنزال مجموعات على الطاولة
  /// - قبل الفتح: يجب أن يملك مجموعات مجموعها ≥ نقاط الافتتاح فينزلها
  ///   دفعة واحدة (قاعدة الـ101) — إصلاح: كان يبحث عن مجموعة واحدة
  ///   مستحيلة النقاط فلم يفتح أي بوت قط
  /// - بعد الفتح: ينزل مجموعة كل دور + يصرف أحجاراً مفردة على
  ///   بيرات الطاولة (إشليمة) كاللاعب الحقيقي
  void _botTryLayMeld(OkeyPlayer bot, int playerIndex) {
    if (bot.playStyle != OkeyPlayStyle.normal) return;
    // البوت قد يتأخر في ملاحظة مجموعة جاهزة (واقعية اللعب)
    if (_random.nextDouble() < _mistakeChance(bot.botDifficulty) * 0.5) {
      return;
    }

    final melds = _findBotMelds(bot);

    if (!bot.hasOpened) {
      if (melds.length < 2) return; // الافتتاح يحتاج أكثر من مجموعة عادة
      final total = melds.fold(0, (s, m) => s + _botMeldPoints(m));
      if (total < rules.openingPoints) return;
      for (final m in melds) {
        _layBotMeld(playerIndex, m);
      }
      bot.hasOpened = true;
      bot.openedPoints = total;
      onNotice?.call('🎉 {} فتح اللعب بـ {} نقطة!'.trp([bot.name, total]));
      _checkEmptyRackWin(playerIndex); // أنزل يده كاملة = فاز بالحجر الأخير
      notifyListeners();
      return;
    }

    // فاتح: أنزل أطول مجموعة جاهزة إن وُجدت
    var laid = false;
    if (melds.isNotEmpty) {
      melds.sort((a, b) => b.tiles.length.compareTo(a.tiles.length));
      _layBotMeld(playerIndex, melds.first);
      onNotice?.call('🀄 {} أنزل مجموعة على الطاولة'.trp([bot.name]));
      laid = true;
    }
    // ثم يصرف حجراً مفرداً على بير موجود (بحد أقصى حجرين بالدور)
    var laidOff = 0;
    for (var s = 0; s < bot.rackTiles.length && laidOff < 2; s++) {
      final tile = bot.rackTiles[s];
      if (tile == null || tile.isRealOkey) continue;
      for (final meld in tableMelds) {
        if (canLayOffTile(tile, meld)) {
          bot.rackTiles[s] = null;
          _insertIntoMeld(meld, tile);
          laidOff++;
          laid = true;
          break;
        }
      }
    }
    _checkEmptyRackWin(playerIndex); // صرف آخر حجر على بير = فوز فوري
    if (laid) notifyListeners();
  }

  /// أفضل كتلة بير صحيحة تضم الخانة المعطاة على رف مقعد معيّن —
  /// قراءة فقط بلا أي تعديل للحالة. تخدم إنزال البير المحلي ومعاينة
  /// المجموعة على جهاز الضيف قبل إرسال حركة «نزول» للمضيف
  (List<int> slots, bool isRun)? _meldGroupAt(int seat, int slotIndex) {
    if (slotIndex < 0 || slotIndex >= 28) return null;
    final rack = players[seat].rackTiles;
    if (rack[slotIndex] == null) return null;
    final rowStart = slotIndex < 14 ? 0 : 14;
    final rowEnd = rowStart + 14;
    List<int>? bestSlots;
    bool bestIsRun = false;

    for (int start = rowStart; start <= slotIndex; start++) {
      if (rack[start] == null) continue;
      for (int end = slotIndex + 1; end <= rowEnd; end++) {
        final slots = List.generate(end - start, (i) => start + i);
        if (slots.length < 3 || slots.any((i) => rack[i] == null)) continue;
        final tiles = slots.map((i) => rack[i]!).toList();
        final isRun = _isValidRun(tiles);
        final isSet = _isValidSet(tiles);
        if ((isRun || isSet) &&
            (bestSlots == null || slots.length > bestSlots.length)) {
          bestSlots = slots;
          bestIsRun = isRun;
        }
      }
    }
    return bestSlots == null ? null : (bestSlots, bestIsRun);
  }

  /// إنزال مجموعة مؤكدة على الطاولة لأي مقعد — الأحجار تُزال من
  /// الرف بالمعرّف فيعمل مع مقاعد اللاعبين البعيدين (خاناتهم على
  /// أجهزتهم لا تطابق ترتيب المضيف)
  bool _commitMeldForSeat(int seat, List<OkeyTile> tiles, bool isRun) {
    final p = players[seat];
    // النزول معلّق حتى تكتمل نقاط الافتتاح (101) في نفس الدور
    final group = OkeyGroup(
      tiles: tiles,
      isRun: isRun,
      ownerIndex: seat,
      pending: !p.hasOpened,
    );
    tableMelds.add(group);
    for (final t in tiles) {
      final i = p.rackTiles.indexWhere((x) => x?.id == t.id);
      if (i != -1) p.rackTiles[i] = null;
    }
    if (seat == 0) selectedTileIndex = null;
    OkeyAudio.playTileDiscard();

    if (!p.hasOpened) {
      final total = meldPointsFor(seat);
      if (total >= rules.openingPoints) {
        p.hasOpened = true;
        p.openedPoints = total;
        for (final m in tableMelds.where((m) => m.ownerIndex == seat)) {
          m.pending = false;
        }
        onNotice?.call(seat == 0
            ? (rules.isRummy
                ? '✨ أنزلت بيراتك على الطاولة!'.tr
                : '🎉 فتحت اللعب بـ {} نقطة!'.trp([total]))
            : '🎉 {} فتح اللعب بـ {} نقطة!'.trp([p.name, total]));
      } else if (seat == 0) {
        onNotice?.call(
            'مجموعتك {} نقطة — المجموع {}/{}. أنزل المزيد قبل الرمي وإلا ستُعاد الأحجار'
                .trp([group.points, total, rules.openingPoints]));
      }
    }

    // نزل آخر أحجار يده كاملة على الطاولة = فوز بالحجر الأخير
    if (p.activeTiles.isEmpty) {
      _checkEmptyRackWin(seat);
      return true;
    }

    notifyListeners();
    return true;
  }

  bool layMeldContainingSlot(int slotIndex) {
    if (!humanCanLayMelds) return false;
    final found = _meldGroupAt(0, slotIndex);
    if (found == null) return false;
    final rack = players[0].rackTiles;
    final tiles = found.$1.map((i) => rack[i]!).toList();
    return _commitMeldForSeat(0, tiles, found.$2);
  }

  // ── SORTING ALGORITHMS ──

  /// Sort by Color & Runs (ترتيب المجموعات المتتالية)
  void sortHumanTiles() {
    final tiles = players[0].activeTiles;
    if (tiles.isEmpty) return;

    players[0].rackTiles = List.filled(28, null);

    final byColor = <OkeyTileColor, List<OkeyTile>>{};
    final jokers = <OkeyTile>[];

    for (final t in tiles) {
      if (t.isRealOkey) {
        jokers.add(t);
      } else {
        byColor.putIfAbsent(t.color, () => []).add(t);
      }
    }

    for (final list in byColor.values) {
      list.sort((a, b) => a.value.compareTo(b.value));
    }

    // Place into slots with small gaps between distinct groups as in reference image!
    int currentSlot = 0;
    for (final color in OkeyTileColor.values) {
      if (byColor.containsKey(color)) {
        final list = byColor[color]!;
        for (final t in list) {
          if (currentSlot < 28) {
            players[0].rackTiles[currentSlot++] = t;
          }
        }
        // Leave 1 gap between colors if on top row (0..13) and space permits
        if (currentSlot < 13 && list.length >= 3) {
          currentSlot++;
        }
      }
    }

    for (final j in jokers) {
      if (currentSlot < 28) {
        players[0].rackTiles[currentSlot++] = j;
      }
    }

    selectedTileIndex = null;
    OkeyAudio.playButtonClick();
    notifyListeners();
  }

  /// Sort by Sets (ترتيب المجموعات المتشابهة في الأرقام)
  void sortHumanTilesBySets() {
    final tiles = players[0].activeTiles;
    if (tiles.isEmpty) return;

    players[0].rackTiles = List.filled(28, null);

    final byValue = <int, List<OkeyTile>>{};
    final jokers = <OkeyTile>[];

    for (final t in tiles) {
      if (t.isRealOkey) {
        jokers.add(t);
      } else {
        byValue.putIfAbsent(t.value, () => []).add(t);
      }
    }

    int currentSlot = 0;
    // Put values with multiple colors first
    final sortedKeys = byValue.keys.toList()
      ..sort((a, b) {
        final lenCmp = byValue[b]!.length.compareTo(byValue[a]!.length);
        return lenCmp != 0 ? lenCmp : a.compareTo(b);
      });

    for (final v in sortedKeys) {
      final list = byValue[v]!;
      for (final t in list) {
        if (currentSlot < 28) {
          players[0].rackTiles[currentSlot++] = t;
        }
      }
      if (currentSlot < 13 && list.length >= 2) {
        currentSlot++;
      }
    }

    for (final j in jokers) {
      if (currentSlot < 28) {
        players[0].rackTiles[currentSlot++] = j;
      }
    }

    selectedTileIndex = null;
    OkeyAudio.playButtonClick();
    notifyListeners();
  }

  /// هل يستطيع اللاعب البشري إعلان الفوز بالأوكي الآن؟
  /// يفحص كل الأحجار كمرشحات للرمي — لا يفترض أن أول 14 خانة هي اليد
  bool get canDeclareOkeyOut {
    final player = players[0];
    final active = player.activeTiles;

    // كونكان/فول: الفوز إذا اكتمل النمط بعد رمي أي حجر
    if (player.playStyle != OkeyPlayStyle.normal) {
      for (int i = 0; i < active.length; i++) {
        final rest = List<OkeyTile>.from(active)..removeAt(i);
        if (_styleWins(player, rest)) return true;
      }
      return false;
    }

    // بعد فتح اللعب: الفوز يُعلن فقط إذا أمكن إفراغ الرف كاملاً على
    // الطاولة — كل حجر يُصرف على بير موجود أو يدخل في بير جديد صحيح.
    // حجر واحد لا يصرف على شيء = لا فوز بعد، ولا يظهر الزر قبل أوانه
    if (player.hasOpened) {
      return _remainingAllPlaceableOnTable(active);
    }

    if (active.length == 14) return isWinningHand(active);
    if (active.length == 15) {
      for (int i = 0; i < active.length; i++) {
        final rest = List<OkeyTile>.from(active)..removeAt(i);
        if (isWinningHand(rest)) return true;
      }
    }
    return false;
  }

  /// إعلان فوز اللاعب البشري فوراً
  void declareHumanWin() {
    _declareWinner(players[0], WinType.normal);
  }

  /// إرجاع مؤشرات الخانات التي تشكل مجموعات صحيحة لتمييزها بظلال ملونة
  Set<int> getHighlightedSlotIndices() {
    final highlighted = <int>{};
    final rack = players[0].rackTiles;

    // فحص الصف العلوي (0..13) والصف السفلي (14..27)
    for (final rowStart in [0, 14]) {
      int i = rowStart;
      while (i < rowStart + 14) {
        if (rack[i] == null) {
          i++;
          continue;
        }

        // إيجاد الكتلة المتتالية من الأحجار دون فواصل
        int j = i;
        while (j < rowStart + 14 && rack[j] != null) {
          j++;
        }

        final length = j - i;
        if (length >= 3) {
          // فحص هل تشكل متسلسلة (Run) أو مجموعة أرقام متطابقة (Set)
          final subTiles = rack.sublist(i, j).whereType<OkeyTile>().toList();
          if (_isValidRun(subTiles) || _isValidSet(subTiles)) {
            for (int k = i; k < j; k++) {
              highlighted.add(k);
            }
          }
        }
        i = j;
      }
    }

    return highlighted;
  }

  /// سلسلة صحيحة: نفس اللون وكل حجر في موضعه الصحيح بالضبط — الأوكي
  /// يملأ فجوة واحدة بموضعه فقط (كانت 5-أوكي-9 تُقبل خطأً لأن الفحص
  /// كان بين الجيران غير الأوكي فقط)
  bool _isValidRun(List<OkeyTile> tiles) => okeyRunStart(tiles) != null;

  bool _isValidSet(List<OkeyTile> tiles) {
    if (tiles.length < 3 || tiles.length > 4) return false;
    final nonJokers = tiles.where((t) => !t.isRealOkey).toList();
    if (nonJokers.isEmpty) return true;

    final value = nonJokers.first.value;
    final colors = <OkeyTileColor>{};
    for (final t in nonJokers) {
      if (t.value != value) return false;
      if (colors.contains(t.color)) return false;
      colors.add(t.color);
    }
    return true;
  }

  // ══════════════════════════════════════════════════════
  //  اللعب الأونلاين — تسلسل الحالة + عمليات مقعدية عامة
  // ══════════════════════════════════════════════════════
  //
  // المعمارية: المضيف (المقعد 0 في الوثيقة) يملك المحرك الحقيقي —
  // يوزّع ويشغّل البوتات ويطبّق حركات اللاعبين البعيدين الواردة من
  // rooms/{id}/moves ثم يكتب لقطة عامة في حقل game على الوثيقة.
  // أيدي اللاعبين الخاصة تُكتب في rooms/{id}/hands/{uid} يقرأها
  // صاحبها فقط. الضيف يشغّل OkeyEngine.mirror ويحمّل اللقطة عبر
  // loadGameState مع seatOffset = مقعده فيُصبح محلياً المقعد 0 —
  // كل ميكانيكيات الواجهة (الرف، النزول، التمييز) تعمل بلا تعديل.

  /// دور اللاعب وطوره صحيحان لهذه العملية؟ (على محرك المضيف فقط)
  bool _seatTurnOk(int seat, OkeyTurnPhase need) =>
      !isOnlineMirror &&
      winner == null &&
      currentTurnIndex == seat &&
      turnPhase == need;

  /// سحب من الرزمة لأي مقعد (المقعد 0 يمرّر للمسار المحلي الأصلي)
  bool drawFromDeckForSeat(int seat) {
    if (seat == 0) return drawFromDeck();
    if (!_seatTurnOk(seat, OkeyTurnPhase.awaitingDraw)) return false;
    if (drawDeck.isEmpty) _refillDeckFromDiscards();
    if (drawDeck.isEmpty) return false;
    final rack = players[seat].rackTiles;
    final emptySlot = rack.indexOf(null);
    if (emptySlot == -1) return false;
    rack[emptySlot] = drawDeck.removeAt(0);
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  /// أخذ آخر حجر مرمي من لاعب اليسار لأي مقعد
  bool drawFromDiscardForSeat(int seat) {
    if (seat == 0) return drawFromDiscard();
    if (!_seatTurnOk(seat, OkeyTurnPhase.awaitingDraw)) return false;
    final left = (seat + 3) % 4;
    final pile = discardPiles[left];
    if (pile.isEmpty) return false;
    // مرميات لاعب الفول مخفية ولا تُؤخذ
    if (players[left].playStyle == OkeyPlayStyle.full) return false;
    final rack = players[seat].rackTiles;
    final emptySlot = rack.indexOf(null);
    if (emptySlot == -1) return false;
    final tile = pile.removeLast();
    if (identical(tile, lastDiscardTile)) {
      lastDiscardTile = null;
      lastDiscardPlayer = -1;
    }
    rack[emptySlot] = tile;
    _takenLeftBySeat[seat] = tile;
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    // يُشعر الواجهة لتحريك الحجر نحو حامل الآخذ
    onDiscardTaken?.call(seat, tile);
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  /// إعادة حجر اليسار المأخوذ لكومته + سحب بديل — نسخة مقعدية عامة
  /// من _returnTakenLeftTile (التي تخدم المقعد 0 فقط)
  void _returnTakenTileForSeat(int seat, OkeyTile taken) {
    if (seat == 0) {
      _returnTakenLeftTile(taken);
      return;
    }
    final rack = players[seat].rackTiles;
    final slot = rack.indexWhere((t) => identical(t, taken));
    if (slot != -1) {
      rack[slot] = null;
      final left = (seat + 3) % 4;
      discardPiles[left].add(taken);
      lastDiscardTile = taken;
      lastDiscardPlayer = left;
    }
    if (drawDeck.isEmpty) _refillDeckFromDiscards();
    if (drawDeck.isNotEmpty) {
      final empty = rack.indexOf(null);
      if (empty != -1) rack[empty] = drawDeck.removeAt(0);
    }
  }

  /// رمي حجر من أي مقعد — يُعنون بمعرّف الحجر لا بخانته (ترتيب
  /// الضيف على جهازه خاص ولا يعرفه المضيف)
  bool discardTileForSeat(int seat, String tileId) {
    if (seat == 0) {
      final i = players[0].rackTiles.indexWhere((t) => t?.id == tileId);
      return i != -1 && discardSlot(i);
    }
    if (!_seatTurnOk(seat, OkeyTurnPhase.awaitingDiscard)) return false;
    final rack = players[seat].rackTiles;
    var slot = rack.indexWhere((t) => t?.id == tileId);
    if (slot == -1) return false;
    var tile = rack[slot]!;

    // نزول معلّق دون نقاط الافتتاح يُعاد للرف قبل الرمي
    if (!players[seat].hasOpened) _retractPendingMelds(seat);

    // من أخذ حجر اليسار ولم يفتح: يُعاد لكومته ويسحب بديلاً
    final taken = _takenLeftBySeat.remove(seat);
    if (taken != null &&
        !rules.isRummy &&
        players[seat].playStyle == OkeyPlayStyle.normal &&
        !players[seat].hasOpened) {
      _returnTakenTileForSeat(seat, taken);
      if (identical(tile, taken)) {
        // حاول رمي الحجر المأخوذ نفسه — عاد وسُحب بديله؛ اختر غيره
        notifyListeners();
        return true;
      }
      slot = rack.indexWhere((t) => t?.id == tileId);
      if (slot == -1) {
        notifyListeners();
        return true;
      }
      tile = rack[slot]!;
    }

    rack[slot] = null;
    discardPiles[seat].add(tile);
    lastDiscardTile = tile;
    lastDiscardPlayer = seat;
    OkeyAudio.playTileDiscard();

    final remaining = players[seat].activeTiles;
    if (_styleWins(players[seat], remaining)) {
      _declareWinner(players[seat],
          tile.isRealOkey ? WinType.discardOkey : WinType.normal);
      return true;
    }
    _advanceTurn();
    return true;
  }

  /// إنزال بير بمعرّفات أحجاره (الضيف يرسل القائمة والمضيف يعيد
  /// التحقق من صحتها — لا ثقة بأي تجميع يصل من الشبكة)
  bool layMeldByIdsForSeat(int seat, List<String> ids) {
    if (seat == 0) return false;
    if (!_seatTurnOk(seat, OkeyTurnPhase.awaitingDiscard)) return false;
    final p = players[seat];
    if (p.playStyle != OkeyPlayStyle.normal) return false;
    final rack = p.rackTiles;
    final tiles = <OkeyTile>[];
    for (final id in ids) {
      final i = rack.indexWhere((t) => t?.id == id);
      if (i == -1 || tiles.any((t) => t.id == id)) return false;
      tiles.add(rack[i]!);
    }
    if (tiles.length < 3) return false;
    final isRun = _isValidRun(tiles);
    if (!isRun && !_isValidSet(tiles)) return false;
    return _commitMeldForSeat(seat, tiles, isRun);
  }

  /// صرف حجر على بير نازل — نسخة مقعدية عامة من layTileOnMeld
  bool layTileOnMeldForSeat(int seat, String tileId, int meldIndex) {
    if (seat == 0) {
      final i = players[0].rackTiles.indexWhere((t) => t?.id == tileId);
      return i != -1 && layTileOnMeld(i, meldIndex);
    }
    if (!_seatTurnOk(seat, OkeyTurnPhase.awaitingDiscard)) return false;
    final p = players[seat];
    if (p.playStyle != OkeyPlayStyle.normal) return false;
    if (meldIndex < 0 || meldIndex >= tableMelds.length) return false;
    final rack = p.rackTiles;
    final slot = rack.indexWhere((t) => t?.id == tileId);
    if (slot == -1) return false;
    final tile = rack[slot]!;
    final meld = tableMelds[meldIndex];
    final myPending = meld.ownerIndex == seat && meld.pending;
    if (!p.hasOpened && !myPending) return false;
    if (!canLayOffTile(tile, meld)) return false;

    rack[slot] = null;
    _insertIntoMeld(meld, tile);
    OkeyAudio.playTileDiscard();

    // صرف على بير معلّق قد يُكمل نقاط الافتتاح
    if (meld.pending && !p.hasOpened) {
      final total = meldPointsFor(seat);
      if (total >= rules.openingPoints) {
        p.hasOpened = true;
        p.openedPoints = total;
        for (final m in tableMelds.where((m) => m.ownerIndex == seat)) {
          m.pending = false;
        }
      }
    }
    if (p.activeTiles.isEmpty) {
      _checkEmptyRackWin(seat);
      return true;
    }
    notifyListeners();
    return true;
  }

  /// أخذ الجوكر من بير مقابل إبداله بالحجر الحقيقي — نسخة مقعدية
  bool swapJokerFromMeldForSeat(int seat, String tileId, int meldIndex) {
    if (seat == 0) {
      final i = players[0].rackTiles.indexWhere((t) => t?.id == tileId);
      return i != -1 && swapJokerFromMeld(i, meldIndex);
    }
    if (!_seatTurnOk(seat, OkeyTurnPhase.awaitingDiscard)) return false;
    final p = players[seat];
    if (p.playStyle != OkeyPlayStyle.normal) return false;
    if (meldIndex < 0 || meldIndex >= tableMelds.length) return false;
    final rack = p.rackTiles;
    final slot = rack.indexWhere((t) => t?.id == tileId);
    if (slot == -1) return false;
    final tile = rack[slot]!;
    final meld = tableMelds[meldIndex];
    final myPending = meld.ownerIndex == seat && meld.pending;
    if (!p.hasOpened && !myPending) return false;
    final k = jokerSlotFor(meld, tile);
    if (k == -1) return false;
    final joker = meld.tiles[k];
    meld.tiles[k] = tile;
    rack[slot] = joker;
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  /// إعلان كونكان/فول لأي مقعد — نفس شروط اللاعب المحلي
  bool declarePlayStyleForSeat(int seat, OkeyPlayStyle style) {
    if (seat == 0) return declarePlayStyle(style);
    if (style == OkeyPlayStyle.normal || rules.isRummy) return false;
    final p = players[seat];
    if (p.playStyle != OkeyPlayStyle.normal || p.hasOpened) return false;
    if (tableMelds.any((m) => m.ownerIndex == seat)) return false;
    p.playStyle = style;
    onNotice?.call('🀄 {} بدأ اللعب {}'.trp([p.name, style.label]));
    notifyListeners();
    return true;
  }

  /// إعلان فوز لأي مقعد — نفس تحقق canDeclareOkeyOut لكن للمقعد s
  bool declareWinForSeat(int seat) {
    if (seat == 0) {
      if (!canDeclareOkeyOut) return false;
      _declareWinner(players[0], WinType.normal);
      return true;
    }
    if (currentTurnIndex != seat || winner != null) return false;
    final p = players[seat];
    final active = p.activeTiles;
    bool ok;
    if (p.playStyle != OkeyPlayStyle.normal) {
      ok = false;
      for (var i = 0; i < active.length; i++) {
        final rest = List<OkeyTile>.from(active)..removeAt(i);
        if (_styleWins(p, rest)) {
          ok = true;
          break;
        }
      }
    } else if (p.hasOpened) {
      ok = _remainingAllPlaceableOnTable(active);
    } else if (active.length == 14) {
      ok = isWinningHand(active);
    } else if (active.length == 15) {
      ok = false;
      for (var i = 0; i < active.length; i++) {
        final rest = List<OkeyTile>.from(active)..removeAt(i);
        if (isWinningHand(rest)) {
          ok = true;
          break;
        }
      }
    } else {
      ok = false;
    }
    if (!ok) return false;
    _declareWinner(p, WinType.normal);
    return true;
  }

  /// لعب آلي لمقعد بعيد تجاوز مهلته: سحب من الرزمة ثم رمي أرخص
  /// حجر غير أوكي — يُبقي الغرفة حية إذا انقطع اتصال لاعب
  void autoPlaySeat(int seat) {
    if (isOnlineMirror || currentTurnIndex != seat || winner != null) return;
    if (turnPhase == OkeyTurnPhase.awaitingDraw) {
      drawFromDeckForSeat(seat);
    }
    if (turnPhase != OkeyTurnPhase.awaitingDiscard) return;
    final rack = players[seat].rackTiles;
    for (var i = rack.length - 1; i >= 0; i--) {
      final t = rack[i];
      if (t != null && !t.isRealOkey && !t.isFalseJoker) {
        discardTileForSeat(seat, t.id);
        return;
      }
    }
    for (var i = rack.length - 1; i >= 0; i--) {
      final t = rack[i];
      if (t != null) {
        discardTileForSeat(seat, t.id);
        return;
      }
    }
  }

  /// معاينة أحجار البير الذي يضم الخانة (قراءة فقط) — الضيف
  /// الأونلاين يستخدمها لإرسال معرّفات الأحجار ضمن حركة «نزول»
  /// بدل تنفيذ النزول على المرآة
  List<OkeyTile> previewMeldTiles(int slotIndex) {
    final found = _meldGroupAt(0, slotIndex);
    if (found == null) return const [];
    return [for (final i in found.$1) players[0].rackTiles[i]!];
  }

  /// المضيف يطبّق حركة واردة من لاعب بعيد — إعادة false تعني
  /// حركة غير صالحة (خارج الدور أو مخالفة للقواعد) فتُحذف وتُتجاهل
  bool applyRemoteAction(int seat, Map<String, dynamic> m) {
    if (isOnlineMirror || seat <= 0 || seat > 3) return false;
    switch (m['t']) {
      case 'draw':
        return drawFromDeckForSeat(seat);
      case 'take':
        return drawFromDiscardForSeat(seat);
      case 'disc':
        return discardTileForSeat(seat, '${m['id']}');
      case 'meld':
        final raw = m['ids'];
        return layMeldByIdsForSeat(
            seat, [for (final e in (raw is List ? raw : const [])) '$e']);
      case 'layoff':
        return layTileOnMeldForSeat(
            seat, '${m['id']}', (m['m'] as num?)?.toInt() ?? -1);
      case 'joker':
        return swapJokerFromMeldForSeat(
            seat, '${m['id']}', (m['m'] as num?)?.toInt() ?? -1);
      case 'style':
        final s = OkeyPlayStyle.values.firstWhere((e) => e.name == m['s'],
            orElse: () => OkeyPlayStyle.normal);
        return declarePlayStyleForSeat(seat, s);
      case 'win':
        return declareWinForSeat(seat);
    }
    return false;
  }

  // ─── التسلسل ───

  Map<String, dynamic> _meldToMap(OkeyGroup m) => {
        'o': m.ownerIndex,
        'r': m.isRun,
        'p': m.pending,
        't': [for (final t in m.tiles) t.toMap()],
      };

  /// لقطة الحالة العامة: كل ما يظهر للجميع على الطاولة — بلا
  /// محتوى الرزمة ولا أيدي اللاعبين (اليد الخاصة تُرسل عبر
  /// handForSeat إلى وثيقة hands/{uid} المحمية بالقواعد)
  Map<String, dynamic> serializeGame() {
    return {
      'v': 1,
      'turn': currentTurnIndex,
      'phase': turnPhase.name,
      'gs': gameState.name,
      'turnDur': turnDuration,
      'deck': drawDeck.length,
      'ind': indicatorTile.toMap(),
      'okey': realOkeySample.toMap(),
      'ldTile': lastDiscardTile?.toMap(),
      'ldSeat': lastDiscardPlayer,
      'melds': [for (final m in tableMelds) _meldToMap(m)],
      'piles': [
        for (final p in discardPiles)
          {'n': p.length, 'top': p.isEmpty ? null : p.last.toMap()}
      ],
      'pl': [
        for (var i = 0; i < 4; i++)
          {
            'n': players[i].activeTiles.length,
            'open': players[i].hasOpened,
            'pts': players[i].openedPoints,
            'st': players[i].playStyle.name,
          }
      ],
      'win': winner == null ? -1 : players.indexOf(winner!),
      'wt': winType?.name,
    };
  }

  /// اليد الخاصة لمقعد — تُكتب في rooms/{id}/hands/{uid} يقرأها
  /// صاحبها فقط (المضيف لا يحتاج وثيقة ليده — محركه يملكها أصلاً)
  Map<String, dynamic> handForSeat(int seat) => {
        'tiles': [for (final t in players[seat].activeTiles) t.toMap()]
      };

  // ═══ حالة المضيف الكاملة — نجاة المضيف من إعادة فتح التطبيق ═══
  // تُكتب في rooms/{id}/host_state/state (المضيف وحده يقرؤها
  // ويكتبها بحسب القواعد): الرزمة الحقيقية + كل الأيدي + تتبّع
  // الحجر المأخوذ — أي كل ما تخفيه اللقطة العامة عن الضيوف.

  Map<String, dynamic> serializeHostState() {
    final pub = serializeGame();
    return {
      ...pub,
      'deckTiles': [for (final t in drawDeck) t.toMap()],
      'racks': [
        for (var i = 0; i < 4; i++)
          [for (final t in players[i].rackTiles) t?.toMap()]
      ],
      'pilesFull': [
        for (final p in discardPiles) [for (final t in p) t.toMap()]
      ],
      'taken': {
        for (final e in _takenLeftBySeat.entries) '${e.key}': e.value.toMap()
      },
      'remote': remoteHumanSeats.toList(),
      'botDiffs': [for (final p in players) p.botDifficulty.name],
      'conn': [for (final p in players) p.connected],
    };
  }

  /// يعيد بناء المحرك المرجعي كاملاً من وثيقة host_state — يُستدعى
  /// على محرك جديد (أعاد المضيف فتح التطبيق وسط جولة) فيستعيد
  /// الرزمة والأيدي والدور كما كانت لحظة آخر نشر
  void loadHostState(Map<String, dynamic> s) {
    loadGameState(s, seatOffset: 0); // الحقول العامة أولاً

    final dt = s['deckTiles'] as List? ?? const [];
    if (dt.isNotEmpty) {
      drawDeck = [
        for (final m in dt)
          OkeyTile.fromMap(Map<String, dynamic>.from(m as Map))
      ];
    }

    final racks = s['racks'] as List? ?? const [];
    for (var i = 0; i < 4 && i < racks.length; i++) {
      final r = racks[i] as List? ?? const [];
      for (var k = 0; k < 28; k++) {
        final v = k < r.length ? r[k] : null;
        players[i].rackTiles[k] =
            v is Map ? OkeyTile.fromMap(Map<String, dynamic>.from(v)) : null;
      }
    }

    final pf = s['pilesFull'] as List? ?? const [];
    for (var i = 0; i < 4 && i < pf.length; i++) {
      discardPiles[i] = [
        for (final m in (pf[i] as List? ?? const []))
          OkeyTile.fromMap(Map<String, dynamic>.from(m as Map))
      ];
    }

    _takenLeftBySeat.clear();
    final tk = s['taken'];
    if (tk is Map) {
      tk.forEach((k, v) {
        final seat = int.tryParse('$k');
        if (seat != null && v is Map) {
          _takenLeftBySeat[seat] =
              OkeyTile.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    final rem = s['remote'] as List? ?? const [];
    remoteHumanSeats
      ..clear()
      ..addAll(rem.map((e) => (e as num).toInt()));

    final bd = s['botDiffs'] as List? ?? const [];
    for (var i = 0; i < 4 && i < bd.length; i++) {
      players[i].botDifficulty = BotDifficulty.values.firstWhere(
          (e) => e.name == bd[i],
          orElse: () => BotDifficulty.medium);
    }

    // علم الاتصال — المقاعد المنقطعة تستمر مؤتمتة بعد استعادة المضيف
    final conn = s['conn'] as List? ?? const [];
    for (var i = 0; i < 4 && i < conn.length; i++) {
      players[i].connected = conn[i] == true;
    }

    notifyListeners();
  }

  /// أحجار رفّي بعد دمج اليد الواردة — للاختبار وفحص الأخطاء
  List<OkeyTile> get mirrorMyTiles => players[0].activeTiles;

  /// تحميل لقطة عامة على محرك المرآة. [seatOffset] مقعدي في الوثيقة
  /// فتُدار الإحالات بحيث يصبح لاعبي المقعد المحلي 0 وتعمل كل
  /// ميكانيكيات الواجهة بلا تعديل. [myHand] آخر يد وصلت من وثيقة
  /// hands/{uid}. [handDropSlot] خانة مفضّلة للحجر الجديد (سحب
  /// بالإفلات على خانة معيّنة)
  void loadGameState(
    Map<String, dynamic> g, {
    required int seatOffset,
    List<OkeyTile>? myHand,
    int? handDropSlot,
  }) {
    int loc(int docSeat) => (docSeat - seatOffset + 4) % 4;

    final td = (g['turnDur'] as num?)?.toInt();
    if (td != null && td > 0) turnDuration = td;
    currentTurnIndex = loc((g['turn'] as num?)?.toInt() ?? 0);
    turnPhase = OkeyTurnPhase.values
        .firstWhere((e) => e.name == g['phase'], orElse: () => turnPhase);
    final gs = OkeyGameState.values
        .firstWhere((e) => e.name == g['gs'], orElse: () => gameState);
    // حالات الدور في اللقطة من منظور المضيف — تُعاد ترجمتها محلياً
    gameState = (gs == OkeyGameState.win ||
            gs == OkeyGameState.roundEnd ||
            gs == OkeyGameState.lobby)
        ? gs
        : (currentTurnIndex == 0
            ? OkeyGameState.yourTurn
            : OkeyGameState.opponentTurn);

    final deckCount = (g['deck'] as num?)?.toInt() ?? 0;
    if (drawDeck.length != deckCount) {
      drawDeck = List.generate(
          deckCount,
          (i) =>
              OkeyTile(id: '_deck_$i', color: OkeyTileColor.black, value: 1));
    }

    if (g['ind'] is Map) {
      indicatorTile =
          OkeyTile.fromMap(Map<String, dynamic>.from(g['ind'] as Map));
    }
    if (g['okey'] is Map) {
      realOkeySample =
          OkeyTile.fromMap(Map<String, dynamic>.from(g['okey'] as Map));
      fakeJokerAssigned = realOkeySample;
    }

    final ld = g['ldTile'];
    lastDiscardTile =
        ld is Map ? OkeyTile.fromMap(Map<String, dynamic>.from(ld)) : null;
    final ldSeat = (g['ldSeat'] as num?)?.toInt() ?? -1;
    lastDiscardPlayer = ldSeat < 0 ? -1 : loc(ldSeat);

    tableMelds = [
      for (final raw in (g['melds'] as List? ?? const []))
        if (raw is Map)
          OkeyGroup(
            tiles: [
              for (final tm in (raw['t'] as List? ?? const []))
                OkeyTile.fromMap(Map<String, dynamic>.from(tm as Map))
            ],
            isRun: raw['r'] == true,
            ownerIndex: loc((raw['o'] as num?)?.toInt() ?? 0),
            pending: raw['p'] == true,
          )
    ];

    // كومات الرمي: القمة الحقيقية فقط تكفي العرض (الأخذ يتحقق
    // منها المضيف)، والعدد الفعلي يُحفظ في mirrorPileCounts
    final piles = g['piles'] as List? ?? const [];
    for (var ds = 0; ds < 4; ds++) {
      final li = loc(ds);
      final pd = ds < piles.length ? piles[ds] : null;
      final top = pd is Map ? pd['top'] : null;
      mirrorPileCounts[li] = pd is Map ? (pd['n'] as num?)?.toInt() ?? 0 : 0;
      discardPiles[li] = [
        if (top is Map) OkeyTile.fromMap(Map<String, dynamic>.from(top)),
      ];
    }

    final pl = g['pl'] as List? ?? const [];
    for (var ds = 0; ds < 4; ds++) {
      final li = loc(ds);
      final pd = ds < pl.length && pl[ds] is Map ? pl[ds] as Map : null;
      if (pd == null) continue;
      final p = players[li];
      p.hasOpened = pd['open'] == true;
      p.openedPoints = (pd['pts'] as num?)?.toInt() ?? 0;
      p.playStyle = OkeyPlayStyle.values.firstWhere((e) => e.name == pd['st'],
          orElse: () => OkeyPlayStyle.normal);
      final n = (pd['n'] as num?)?.toInt() ?? 0;
      if (li == 0 && myHand != null) {
        _mergeMyRack(myHand, preferredSlot: handDropSlot);
      } else {
        _resizePlaceholderRack(p, n);
      }
    }

    final winSeat = (g['win'] as num?)?.toInt() ?? -1;
    if (winSeat >= 0) {
      winner = players[loc(winSeat)];
      winType = WinType.values
          .firstWhere((e) => e.name == g['wt'], orElse: () => WinType.normal);
      gameState = OkeyGameState.win;
      turnPhase = OkeyTurnPhase.gameOver;
    }

    selectedTileIndex = null;
    notifyListeners();
  }

  /// عدد أحجار كل كومة رمي كما في الوثيقة (على المرآة تحمل الكومة
  /// قمتها الحقيقية فقط — هذا العداد للعرض إن احتاجته الواجهة)
  final List<int> mirrorPileCounts = [0, 0, 0, 0];

  /// دمج يدي الواردة من وثيقة اليد الخاصة مع ترتيبي المحلي الحالي:
  /// الأحجار المعروفة تبقى في خاناتها فيحافظ اللاعب على ترتيبه،
  /// والجديدة تُوضع في خانة الإفلات المفضّلة ثم أول خانة فارغة
  void _mergeMyRack(List<OkeyTile> fresh, {int? preferredSlot}) {
    final rack = players[0].rackTiles;
    final byId = <String, OkeyTile>{for (final t in fresh) t.id: t};
    final placed = <String>{};
    for (var i = 0; i < rack.length; i++) {
      final t = rack[i];
      if (t == null) continue;
      final f = byId[t.id];
      if (f != null && placed.add(t.id)) {
        rack[i] = f; // نسخة اللقطة — تحمل رايات الأوكي المحدّثة
      } else {
        rack[i] = null; // حجر غادر اليد (رُمي أو نزل على الطاولة)
      }
    }
    for (final t in fresh) {
      if (placed.contains(t.id)) continue;
      var slot = -1;
      if (preferredSlot != null &&
          preferredSlot >= 0 &&
          preferredSlot < 28 &&
          rack[preferredSlot] == null) {
        slot = preferredSlot;
        preferredSlot = null;
      } else {
        slot = rack.indexOf(null);
      }
      if (slot == -1) break;
      rack[slot] = t;
      placed.add(t.id);
    }
  }

  /// رفّ placeholders لأحجار خصم مخفية — العدد وحده ما يظهر على
  /// حامله، ولا تُرسل هوية الأحجار للمرآة أصلاً (معلومة مخفية)
  void _resizePlaceholderRack(OkeyPlayer p, int n) {
    p.rackTiles = List.filled(28, null);
    for (var i = 0; i < n && i < 28; i++) {
      p.rackTiles[i] =
          OkeyTile(id: '_h_${p.id}_$i', color: OkeyTileColor.black, value: 1);
    }
  }

  /// ضبط الفائز على المرآة من بيانات وثيقة الغرفة — احتياط لحالة
  /// وصول winner/status=finished قبل آخر لقطة محمّلة بعلم الفوز
  void markWinnerBySeat(int localSeat, WinType type) {
    if (winner != null) return;
    winner = players[localSeat];
    winType = type;
    gameState = OkeyGameState.win;
    turnPhase = OkeyTurnPhase.gameOver;
    notifyListeners();
  }

  // ─── وضع التدريب ───

  /// خانة الحجر المقترح رميه في وضع التدريب: أقل حجر عزلة — ليس
  /// جزءاً من مجموعة مميّزة، ليس أوكي، وأقل قيمة وأبعد عن تشكيل
  /// سلاسل/أزواج مع بقية اليد. null إن لم يوجد مرشّح
  int? get trainingDiscardHint {
    final hl = getHighlightedSlotIndices();
    final rack = players[0].rackTiles;
    int? best;
    var bestScore = 1 << 30;
    for (var i = 0; i < 28; i++) {
      final t = rack[i];
      if (t == null || hl.contains(i) || t.isRealOkey || t.isFalseJoker) {
        continue;
      }
      var score = t.value;
      for (final o in rack) {
        if (o == null || identical(o, t)) continue;
        if (!o.isRealOkey &&
            o.color == t.color &&
            (o.value - t.value).abs() <= 2) {
          score += 20; // جار لوني قريب = احتمال سلسلة
        }
        if (!o.isRealOkey && o.value == t.value && o.color != t.color) {
          score += 15; // نفس الرقم بلون آخر = زوج محتمل
        }
      }
      if (score < bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  @override
  void dispose() {
    isDisposed = true;
    _turnCountdownTimer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }
}

/// مجموعة بوت مُكتشفة قبل إنزالها — أحجار + هل هي سلسلة + عدد الأوكي المُكمل
class _BotMeld {
  final List<OkeyTile> tiles;
  final bool isRun;
  final int jokers;
  _BotMeld(this.tiles, this.isRun, {this.jokers = 0});
}

/// لقطة حدود بير نازل على الطاولة لمحاكاة الصرف — بلا لمس الكائن الأصلي
class _MeldBound {
  final bool isRun;
  OkeyTileColor? color; // لون السلسلة (من أول حجر غير أوكي)
  int lo = 14; // أدنى قيمة في السلسلة
  int hi = 0; // أعلى قيمة في السلسلة
  bool hasOne = false; // هل تضم الواحد (لالتفاف 12-13-1)
  int value = 0; // قيمة المجموعة (Set)
  int count; // عدد الأحجار — للمجموعات لا تتجاوز 4
  final Set<OkeyTileColor> colors = {}; // ألوان المجموعة المستخدمة

  _MeldBound._({required this.isRun, this.count = 0});

  factory _MeldBound.of(OkeyGroup g) {
    final b = _MeldBound._(isRun: g.isRun, count: g.tiles.length);
    if (g.isRun) {
      // الحدود الفعلية بمواضع الأوكي — hi=14 تعني انتهت بالتفاف 13-1
      final start = okeyRunStart(g.tiles) ?? 1;
      b.lo = start;
      b.hi = start + g.tiles.length - 1;
      b.hasOne = b.hi == 14;
      for (final t in g.tiles) {
        if (!t.isRealOkey) {
          b.color = t.color;
          break;
        }
      }
      return b;
    }
    for (final t in g.tiles) {
      if (t.isRealOkey) continue;
      b.value = t.value;
      b.colors.add(t.color);
    }
    return b;
  }

  /// هل يصرف الحجر على هذا البير — مرآة canLayOffTile (فحص فقط بلا تعديل)
  bool fits(OkeyTile t) {
    if (isRun) {
      if (t.isRealOkey) return lo > 1 || hi < 14;
      if (color != null && t.color != color) return false;
      if (lo > 1 && t.value == lo - 1) return true;
      if (hi < 13 && t.value == hi + 1) return true;
      if (hi == 13 && t.value == 1) return true;
      return false;
    }
    if (count >= 4) return false;
    if (t.isRealOkey) return true;
    if (value != 0 && t.value != value) return false;
    return !colors.contains(t.color);
  }

  (int, int, bool, int, int, OkeyTileColor?, Set<OkeyTileColor>) snapshot() =>
      (lo, hi, hasOne, value, count, color, Set.of(colors));

  void apply(OkeyTile t) {
    if (isRun) {
      if (t.isRealOkey) {
        if (hi < 14) {
          hi++;
        } else {
          lo--;
        }
      } else {
        color ??= t.color;
        if (lo > 1 && t.value == lo - 1) {
          lo--;
        } else {
          hi++; // يمدّ النهاية (بما فيها 13→1 فتصبح 14)
        }
      }
      hasOne = hi == 14;
      count++;
      return;
    }
    if (t.isRealOkey) {
      count++;
      return;
    }
    {
      if (value == 0) value = t.value;
      colors.add(t.color);
    }
    count++;
  }

  void restore(
      (int, int, bool, int, int, OkeyTileColor?, Set<OkeyTileColor>) s) {
    lo = s.$1;
    hi = s.$2;
    hasOne = s.$3;
    value = s.$4;
    count = s.$5;
    color = s.$6;
    colors
      ..clear()
      ..addAll(s.$7);
  }
}
