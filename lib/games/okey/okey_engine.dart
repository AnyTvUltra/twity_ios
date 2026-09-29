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

  OkeyEngine({OkeyRules? rules}) : rules = rules ?? OkeyRules.turkish {
    initGame();
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

    // 4. Deal: Starter (Player 0) gets 15 tiles, others get 14 tiles
    for (int i = 0; i < 4; i++) {
      final count = (i == 0) ? 15 : 14;
      final dealt = allTiles.sublist(0, count);
      allTiles.removeRange(0, count);

      for (int slot = 0; slot < dealt.length; slot++) {
        players[i].rackTiles[slot] = dealt[slot];
      }
    }

    drawDeck = allTiles;
    currentTurnIndex = 0; // Human starts
    turnPhase = OkeyTurnPhase.awaitingDiscard; // Has 15 tiles, must discard 1
    gameState = OkeyGameState.yourTurn;
    selectedTileIndex = null;

    // Auto sort human hand initially for a clean presentation
    sortHumanTiles();
    _startTurnTimer();
    notifyListeners();
  }

  // ── TURN TIMER ──

  void _startTurnTimer() {
    _turnCountdownTimer?.cancel();
    turnTimeRemaining = defaultTurnDuration;

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
    if (currentTurnIndex != 0) return; // bot timeouts handled by bot AI

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
    final rack = players[0].rackTiles;
    // حدّد الحجر الجديد بعد النقل
    final tileIdx = rack.indexWhere((t) => identical(t, _lastDrawn));
    selectedTileIndex = tileIdx >= 0 ? tileIdx : null;
  }

  OkeyTile? _lastDrawn;

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
    if (recycled.isEmpty) return;
    recycled.shuffle(_random);
    drawDeck.addAll(recycled);
    onNotice?.call(
        '🔄 نفدت رزمة السحب — أُعيد خلط {} حجراً مرموياً'.trp([recycled.length]));
  }

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
    selectedTileIndex = emptySlot;
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    gameState = OkeyGameState.discardPhase;
    _lastDrawn = tile;
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
    players[0].rackTiles[emptySlot] = tile;
    selectedTileIndex = emptySlot;
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    gameState = OkeyGameState.discardPhase;
    _lastDrawn = tile;
    _placeDrawnAt(emptySlot, toSlot);
    // من يأخذ حجر غيره وهو عادي يتحول تلقائياً إلى كونكان
    _convertToKonkanIfNormal(0);
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  // ══════════════════════════════════════════════════════
  // أسلوب اللعب: عادي / كونكان / فول
  // ══════════════════════════════════════════════════════

  /// هل يستطيع اللاعب البشري إعلان أسلوب (قبل أي نزول على الطاولة)؟
  bool get canDeclarePlayStyle =>
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

  void _convertToKonkanIfNormal(int idx) {
    final p = players[idx];
    if (p.playStyle != OkeyPlayStyle.normal) return;
    p.playStyle = OkeyPlayStyle.konkan;
    onNotice?.call(idx == 0
        ? '🔄 أخذت حجر غيرك — تحوّلت تلقائياً إلى كونكان'.tr
        : '🔄 {} أخذ حجراً من غيره — صار يلعب كونكان'.trp([p.name]));
  }

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
    final tile = players[0].rackTiles[slotIndex];
    if (tile == null) return false;

    // إذا أنزل أحجاراً ولم تكتمل نقاط الافتتاح (101) تُعاد إلى الرف
    if (!players[0].hasOpened) {
      _retractPendingMelds(0);
    }

    players[0].rackTiles[slotIndex] = null;
    // لا نضغط الصف — الفجوات تحافظ على تجميعات اللاعب منفصلة
    discardPiles[0].add(tile);
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

    if (currentTurnIndex != 0) {
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
      roundDurationSeconds: defaultTurnDuration - turnTimeRemaining,
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
      if (isDisposed || currentTurnIndex == 0) return;

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
        _convertToKonkanIfNormal(currentTurnIndex);
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
        if (isDisposed || currentTurnIndex == 0) return;

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
        final block =
            rack.sublist(i, j).whereType<OkeyTile>().toList();
        if (block.length >= 3 &&
            (_isValidRun(block) || _isValidSet(block))) {
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
          0, (sum, g) => sum + g.fold(0, (s, t) => s + t.value));

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
      // سلسلة: نفس اللون ويمدّ الطرف الأدنى أو الأعلى
      final nonOkey = meld.tiles.where((t) => !t.isRealOkey).toList();
      if (nonOkey.isEmpty) return true;
      if (tile.color != nonOkey.first.color) return false;
      final values = nonOkey.map((t) => t.value).toList()..sort();
      final lo = values.first;
      final hi = values.last;
      if (tile.value == lo - 1) return true;
      if (tile.value == hi + 1) return true;
      // التفاف 12-13-1: الواحد يمدّ سلسلة تنتهي بـ13
      if (hi == 13 && tile.value == 1 && !values.contains(1)) return true;
      return false;
    }

    // مجموعة (Set): نفس القيمة، لون غير مكرر، وبحد أقصى 4 أحجار
    if (meld.tiles.length >= 4) return false;
    final nonOkey = meld.tiles.where((t) => !t.isRealOkey).toList();
    if (nonOkey.isNotEmpty && tile.value != nonOkey.first.value) return false;
    return !nonOkey.any((t) => t.color == tile.color);
  }

  /// صرف حجر من رف اللاعب البشري على بير نازل على الطاولة
  /// يشترط أن يكون اللاعب قد فتح اللعب (نازل ببيراته الخاصة)
  bool layTileOnMeld(int slotIndex, int meldIndex) {
    final human = players[0];
    if (!human.hasOpened) return false;
    if (slotIndex < 0 ||
        slotIndex >= 28 ||
        meldIndex < 0 ||
        meldIndex >= tableMelds.length) return false;
    final tile = human.rackTiles[slotIndex];
    if (tile == null) return false;
    final meld = tableMelds[meldIndex];
    if (!canLayOffTile(tile, meld)) return false;

    human.rackTiles[slotIndex] = null;

    // الإدراج في الموضع الصحيح للعرض المرتب
    if (meld.isRun && !tile.isRealOkey) {
      final values =
          meld.tiles.where((t) => !t.isRealOkey).map((t) => t.value).toList()
            ..sort();
      if (tile.value == 1 && values.isNotEmpty && values.last == 13) {
        meld.tiles.add(tile); // التفاف 12-13-1
      } else {
        int pos = meld.tiles.length;
        for (int i = 0; i < meld.tiles.length; i++) {
          final t2 = meld.tiles[i];
          if (!t2.isRealOkey && t2.value > tile.value) {
            pos = i;
            break;
          }
        }
        meld.tiles.insert(pos, tile);
      }
    } else {
      meld.tiles.add(tile);
    }

    selectedTileIndex = null;
    OkeyAudio.playTileDiscard();
    final ownerName =
        meld.ownerIndex == 0 ? 'بيرك'.tr : 'بير {}'.trp([players[meld.ownerIndex].name]);
    onNotice?.call('✨ صرفت حجراً على {} (+{} نقطة)'.trp([ownerName, tile.value]));
    notifyListeners();
    return true;
  }

  int get remainingOpeningPoints => players[0].hasOpened
      ? 0
      : math.max(0, rules.openingPoints - meldPointsFor(0));

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
      onNotice?.call(
          'لم تكتمل نقاط الافتتاح ({}) — أُعيدت الأحجار إلى رفّك'.trp([rules.openingPoints]));
    }
  }

  /// محاولة البوت إنزال أطول مجموعة صالحة من رفّه
  void _botTryLayMeld(OkeyPlayer bot, int playerIndex) {
    if (bot.playStyle != OkeyPlayStyle.normal) return;
    final rack = bot.rackTiles;

    // ترتيب رف البوت داخلياً حتى تظهر المجموعات الصالحة متجاورة
    final sorted = rack.whereType<OkeyTile>().toList()
      ..sort((a, b) {
        final c = a.color.index.compareTo(b.color.index);
        return c != 0 ? c : a.value.compareTo(b.value);
      });
    for (int i = 0; i < 28; i++) {
      rack[i] = i < sorted.length ? sorted[i] : null;
    }

    List<int>? bestSlots;
    bool bestIsRun = false;

    for (final rowStart in [0, 14]) {
      final rowEnd = rowStart + 14;
      for (int start = rowStart; start < rowEnd; start++) {
        if (rack[start] == null) continue;
        for (int end = start + 3; end <= rowEnd; end++) {
          final slots = List.generate(end - start, (i) => start + i);
          if (slots.any((i) => rack[i] == null)) break;
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
    }

    if (bestSlots == null) return;
    // البوت قد يتأخر في ملاحظة مجموعة جاهزة (واقعية اللعب)
    if (_random.nextDouble() < _mistakeChance(bot.botDifficulty) * 0.5) return;
    final tiles = bestSlots.map((i) => rack[i]!).toList();
    final points = tiles.fold(0, (sum, t) => sum + t.value);

    // لا يُسمح بالنزول قبل اكتمال نقاط الافتتاح المطلوبة
    if (!bot.hasOpened && points < rules.openingPoints) return;

    tableMelds.add(OkeyGroup(
      tiles: tiles,
      isRun: bestIsRun,
      ownerIndex: playerIndex,
    ));
    for (final slot in bestSlots) {
      rack[slot] = null;
    }
    if (!bot.hasOpened) {
      bot.hasOpened = true;
      bot.openedPoints = points;
    }
    onNotice?.call('🀄 {} أنزل مجموعة على الطاولة (+{} نقطة)'.trp([bot.name, points]));
    notifyListeners();
  }

  bool layMeldContainingSlot(int slotIndex) {
    if (!humanCanLayMelds) return false;
    if (slotIndex < 0 ||
        slotIndex >= 28 ||
        players[0].rackTiles[slotIndex] == null) return false;
    final rack = players[0].rackTiles;
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

    if (bestSlots == null) return false;
    final tiles = bestSlots.map((i) => rack[i]!).toList();

    final human = players[0];
    // النزول معلّق حتى تكتمل نقاط الافتتاح (101) في نفس الدور
    final group = OkeyGroup(
      tiles: tiles,
      isRun: bestIsRun,
      ownerIndex: 0,
      pending: !human.hasOpened,
    );
    tableMelds.add(group);
    for (final slot in bestSlots) {
      rack[slot] = null;
    }
    selectedTileIndex = null;
    OkeyAudio.playTileDiscard();

    if (!human.hasOpened) {
      final total = meldPointsFor(0);
      if (total >= rules.openingPoints) {
        human.hasOpened = true;
        human.openedPoints = total;
        for (final m in tableMelds.where((m) => m.ownerIndex == 0)) {
          m.pending = false;
        }
        onNotice?.call('🎉 فتحت اللعب بـ {} نقطة!'.trp([total]));
      } else {
        onNotice?.call(
            'مجموعتك {} نقطة — المجموع {}/{}. أنزل المزيد قبل الرمي وإلا ستُعاد الأحجار'.trp([group.points, total, rules.openingPoints]));
      }
    }

    notifyListeners();
    return true;
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

    // بعد فتح اللعب: الفوز إذا بقي كل شيء قابلاً للتقسيم بعد رمي حجر
    if (player.hasOpened) {
      for (int i = 0; i < active.length; i++) {
        final rest = List<OkeyTile>.from(active)..removeAt(i);
        if (_remainingAllMeldable(rest)) return true;
      }
      return false;
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

  bool _isValidRun(List<OkeyTile> tiles) {
    if (tiles.length < 3) return false;
    // التحقق أن جميع الأحجار من نفس اللون ومتتالية
    final nonJokers = tiles.where((t) => !t.isRealOkey).toList();
    if (nonJokers.isEmpty) return true;

    final color = nonJokers.first.color;
    for (final t in nonJokers) {
      if (t.color != color) return false;
    }

    for (int k = 0; k < tiles.length - 1; k++) {
      final current = tiles[k];
      final next = tiles[k + 1];
      if (!current.isRealOkey && !next.isRealOkey) {
        if (next.value != current.value + 1 &&
            !(current.value == 13 && next.value == 1)) {
          return false;
        }
      }
    }
    return true;
  }

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

  @override
  void dispose() {
    isDisposed = true;
    _turnCountdownTimer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }
}
