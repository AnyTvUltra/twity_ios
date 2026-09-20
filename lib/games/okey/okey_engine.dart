import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'okey_models.dart';
import 'utils/okey_audio.dart';
import '../../services/firebase_service.dart';

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

  int currentTurnIndex = 0; // 0: Bottom (Human), 1: Right, 2: Top, 3: Left
  OkeyTurnPhase turnPhase = OkeyTurnPhase.awaitingDiscard; // Start player has 15 tiles
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

  OkeyEngine() {
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

    // Real Okey is (indicator value + 1) in the same color (13 wraps to 1)
    final okeyValue = indicatorTile.value == 13 ? 1 : indicatorTile.value + 1;
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

    // Discard piles
    discardPiles = List.generate(4, (_) => <OkeyTile>[]);

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
    _loadFirebaseProfile();
    notifyListeners();
  }

  void _loadFirebaseProfile() async {
    final profile = await FirebaseService().getOrCreatePlayerProfile(
      playerId: 'p_0',
      defaultName: players[0].name,
      defaultChips: players[0].chips,
      defaultRating: players[0].rating,
      defaultLevel: players[0].level,
    );
    if (!isDisposed) {
      players[0].chips = (profile['chips'] as num?)?.toInt() ?? players[0].chips;
      players[0].rating = (profile['rating'] as num?)?.toInt() ?? players[0].rating;
      notifyListeners();
    }
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
      swapTiles(selectedTileIndex!, slotIndex);
      selectedTileIndex = null;
    } else {
      selectedTileIndex = slotIndex;
      OkeyAudio.playTilePickup();
    }
    notifyListeners();
  }

  void moveTile(int fromSlot, int toSlot) {
    if (fromSlot == toSlot) return;
    final tile = players[0].rackTiles[fromSlot];
    players[0].rackTiles[fromSlot] = null;
    players[0].rackTiles[toSlot] = tile;
    selectedTileIndex = null;
    OkeyAudio.playTilePickup();
    notifyListeners();
  }

  void swapTiles(int slotA, int slotB) {
    final temp = players[0].rackTiles[slotA];
    players[0].rackTiles[slotA] = players[0].rackTiles[slotB];
    players[0].rackTiles[slotB] = temp;
    OkeyAudio.playTilePickup();
    notifyListeners();
  }

  /// Draw from center stock
  bool drawFromDeck() {
    if (currentTurnIndex != 0 || turnPhase != OkeyTurnPhase.awaitingDraw) return false;
    if (drawDeck.isEmpty) return false;

    final emptySlot = players[0].rackTiles.indexOf(null);
    if (emptySlot == -1) return false;

    final tile = drawDeck.removeAt(0);
    players[0].rackTiles[emptySlot] = tile;
    selectedTileIndex = emptySlot;
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    gameState = OkeyGameState.discardPhase;
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  /// Take the latest discarded tile from previous player (Left Bot, index 3)
  bool drawFromDiscard() {
    if (currentTurnIndex != 0 || turnPhase != OkeyTurnPhase.awaitingDraw) return false;
    final leftPlayerDiscards = discardPiles[3];
    if (leftPlayerDiscards.isEmpty) return false;

    final emptySlot = players[0].rackTiles.indexOf(null);
    if (emptySlot == -1) return false;

    final tile = leftPlayerDiscards.removeLast();
    players[0].rackTiles[emptySlot] = tile;
    selectedTileIndex = emptySlot;
    turnPhase = OkeyTurnPhase.awaitingDiscard;
    gameState = OkeyGameState.discardPhase;
    OkeyAudio.playTilePickup();
    notifyListeners();
    return true;
  }

  /// Discard selected tile
  bool discardSelectedTile() {
    if (selectedTileIndex == null) return false;
    return discardSlot(selectedTileIndex!);
  }

  /// Discard specific slot
  bool discardSlot(int slotIndex) {
    if (currentTurnIndex != 0 || turnPhase != OkeyTurnPhase.awaitingDiscard) return false;
    final tile = players[0].rackTiles[slotIndex];
    if (tile == null) return false;

    players[0].rackTiles[slotIndex] = null;
    discardPiles[0].add(tile);
    selectedTileIndex = null;
    OkeyAudio.playTileDiscard();

    // Check if human won by discarding!
    if (isWinningHand(players[0].activeTiles)) {
      _declareWinner(players[0], tile.isRealOkey ? WinType.discardOkey : WinType.normal);
      return true;
    }

    _advanceTurn();
    return true;
  }

  void discardSelectedOrLastTile() {
    if (selectedTileIndex != null && players[0].rackTiles[selectedTileIndex!] != null) {
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
    gameState = (currentTurnIndex == 0) ? OkeyGameState.yourTurn : OkeyGameState.opponentTurn;
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
      p.chips += 140;
      p.rating += 25;
      OkeyAudio.playWin();
    } else {
      players[0].chips = math.max(0, players[0].chips - 35);
      players[0].rating = math.max(1000, players[0].rating - 15);
    }

    // مزامنة رصيد اللاعب وتقييمه سحابياً في قاعدة بيانات Firebase
    FirebaseService().updatePlayerScore(
      playerId: players[0].id,
      chips: players[0].chips,
      rating: players[0].rating,
      isWin: p.isHuman,
    );
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

      if (prevDiscards.isNotEmpty && bot.botDifficulty != BotDifficulty.easy) {
        final candidate = prevDiscards.last;
        final currentHand = bot.activeTiles;
        // Test if adding candidate improves hand runs/sets
        if (_tileUsefulForHand(currentHand, candidate)) {
          takeDiscard = true;
        }
      }

      if (takeDiscard && prevDiscards.isNotEmpty) {
        drawnTile = prevDiscards.removeLast();
      } else if (drawDeck.isNotEmpty) {
        drawnTile = drawDeck.removeAt(0);
      } else {
        // Deck empty -> Draw round end
        gameState = OkeyGameState.roundEnd;
        turnPhase = OkeyTurnPhase.gameOver;
        notifyListeners();
        return;
      }

      // Place tile in bot rack
      final emptyIdx = bot.rackTiles.indexOf(null);
      if (emptyIdx != -1) {
        bot.rackTiles[emptyIdx] = drawnTile;
      } else {
        bot.rackTiles[bot.rackTiles.length - 1] = drawnTile;
      }
      notifyListeners();

      // Check if bot has winning 15 tiles (discard one to win)
      Timer(const Duration(milliseconds: 900), () {
        if (isDisposed || currentTurnIndex == 0) return;

        final active = bot.activeTiles;
        // Check winning hand
        for (int i = 0; i < active.length; i++) {
          final candidateDiscard = active[i];
          final remaining14 = List<OkeyTile>.from(active)..removeAt(i);
          if (isWinningHand(remaining14)) {
            final slot = bot.rackTiles.indexOf(candidateDiscard);
            if (slot != -1) bot.rackTiles[slot] = null;
            discardPiles[currentTurnIndex].add(candidateDiscard);
            _declareWinner(bot, candidateDiscard.isRealOkey ? WinType.discardOkey : WinType.normal);
            return;
          }
        }

        // Strategic discard
        final discardTile = _chooseBotDiscard(active);
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
      if (t.color == candidate.color && (t.value == candidate.value - 1 || t.value == candidate.value + 1)) {
        sameColorAdjacent++;
      }
      if (t.value == candidate.value && t.color != candidate.color) {
        sameNumberDiffColor++;
      }
    }
    return sameColorAdjacent >= 1 || sameNumberDiffColor >= 1;
  }

  OkeyTile _chooseBotDiscard(List<OkeyTile> tiles) {
    // Never discard real Okey if possible
    final nonOkeys = tiles.where((t) => !t.isRealOkey).toList();
    if (nonOkeys.isEmpty) return tiles.last;

    // Find the most isolated tile (no adjacent colors, no matching numbers)
    OkeyTile bestDiscard = nonOkeys.first;
    int minConnections = 999;

    for (final t in nonOkeys) {
      int conn = 0;
      for (final other in nonOkeys) {
        if (other == t) continue;
        if (other.color == t.color && (other.value == t.value - 1 || other.value == t.value + 1)) {
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

    // 1. Check Seven Pairs (Çift)
    if (_checkSevenPairs(tiles)) return true;

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

  List<List<OkeyTile>> _findMeldsContaining(List<OkeyTile> pool, OkeyTile target) {
    final results = <List<OkeyTile>>[];
    final okeys = pool.where((t) => t.isRealOkey).toList();

    // 1. Check Sets of size 3 and 4 (same number, different colors)
    final sameNumber = pool.where((t) => !t.isRealOkey && t.value == target.value).toList();
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
      results.add([uniqueColorTiles[0], uniqueColorTiles[1], uniqueColorTiles[2], okeys[0]]);
    }

    // 2. Check Runs of size 3, 4, 5 (same color, consecutive values)
    // Runs for normal values 1..13 plus 12-13-1
    final sameColor = pool.where((t) => !t.isRealOkey && t.color == target.color).toList();

    for (int len = 3; len <= 5; len++) {
      for (int start = 1; start <= 13 - len + 1; start++) {
        final needed = List.generate(len, (i) => start + i);
        if (needed.contains(target.value)) {
          _tryBuildRun(needed, sameColor, okeys, results);
        }
      }
      // Check 12-13-1 special run
      if (len == 3 && (target.value == 12 || target.value == 13 || target.value == 1)) {
        _tryBuildRun([12, 13, 1], sameColor, okeys, results);
      }
      if (len == 4 && (target.value == 11 || target.value == 12 || target.value == 13 || target.value == 1)) {
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
      final match = colorPool.where((t) => t.value == v && !meld.contains(t)).toList();
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
  bool get canDeclareOkeyOut {
    final active = players[0].activeTiles;
    if (active.length >= 14) {
      return isWinningHand(active.sublist(0, 14));
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
        if (next.value != current.value + 1 && !(current.value == 13 && next.value == 1)) {
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

