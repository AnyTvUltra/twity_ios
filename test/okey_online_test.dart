import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/okey/okey_engine.dart';
import 'package:game_hub/games/okey/okey_models.dart';
import 'package:game_hub/games/okey/okey_rules.dart';

/// اختبارات اللعب الأونلاين: تسلسل الحالة، دوران المقاعد على المرآة،
/// تطبيق حركات اللاعبين البعيدين على محرك المضيف، ولمحة التدريب
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('تسلسل الحالة الأونلاين', () {
    test('serializeGame → loadGameState رحلة ذهاب وعودة بالمقعد نفسه', () {
      final host = OkeyEngine(rules: OkeyRules.turkish);
      final snap = host.serializeGame();

      final guest = OkeyEngine.mirror(rules: OkeyRules.turkish);
      guest.loadGameState(
        Map<String, dynamic>.from(snap),
        seatOffset: 0,
        myHand: [for (final t in host.players[0].activeTiles) t],
      );

      expect(guest.currentTurnIndex, host.currentTurnIndex);
      expect(guest.turnPhase, host.turnPhase);
      expect(guest.drawDeck.length, host.drawDeck.length);
      expect(guest.indicatorTile.value, host.indicatorTile.value);
      expect(guest.indicatorTile.color, host.indicatorTile.color);
      expect(guest.realOkeySample.value, host.realOkeySample.value);
      // يدي دُمجت كاملة
      expect(guest.players[0].activeTiles.length,
          host.players[0].activeTiles.length);
      // خصومي placeholders بعددهم الصحيح
      for (var i = 1; i < 4; i++) {
        expect(guest.players[i].activeTiles.length,
            host.players[i].activeTiles.length);
      }
      host.dispose();
      guest.dispose();
    });

    test('المقاعد تُدار بمقعد الضيف — لاعبي دائماً محلياً 0', () {
      final host = OkeyEngine(rules: OkeyRules.turkish);
      // مقعد الوثيقة 2 (ضيف) يلعب — نرسم الوضع يدوياً
      host.currentTurnIndex = 2;
      final snap = host.serializeGame();

      final guest = OkeyEngine.mirror(rules: OkeyRules.turkish);
      // يد مقعد 2 الحقيقية تُحمَّل محلياً كيد لاعبنا
      guest.loadGameState(
        Map<String, dynamic>.from(snap),
        seatOffset: 2,
        myHand: host.players[2].activeTiles.toList(),
      );

      // دور مقعد الوثيقة 2 = المقعد المحلي 0 للضيف صاحب المقعد 2
      expect(guest.currentTurnIndex, 0);
      expect(guest.gameState, OkeyGameState.yourTurn);
      expect(guest.players[0].activeTiles.length,
          host.players[2].activeTiles.length);
      // مقعد الوثيقة 3 = اليمين محلياً (1)
      expect(guest.players[1].activeTiles.length,
          host.players[3].activeTiles.length);
      // كومة مقعد الوثيقة 1 (السابق في الدور) = كومة اليسار محلياً (3)
      host.dispose();
      guest.dispose();
    });

    test('اللقطة العامة لا تكشف محتوى الأيدي ولا الرزمة', () {
      final host = OkeyEngine(rules: OkeyRules.turkish);
      final snap = host.serializeGame();
      final pl = snap['pl'] as List;
      // عدد الأحجار فقط — لا معرّفات ولا ألوان
      for (final p in pl) {
        final m = Map<String, dynamic>.from(p as Map);
        expect(m.containsKey('n'), isTrue);
        expect(m.containsKey('tiles'), isFalse);
        expect(m.containsKey('t'), isFalse);
      }
      // الرزمة عدد فقط
      expect(snap['deck'] is int, isTrue);
      host.dispose();
    });
  });

  group('تطبيق حركات اللاعبين البعيدين (محرك المضيف)', () {
    test('سحب من الرزمة ثم رمي بمعرّف الحجر', () {
      final host = OkeyEngine(rules: OkeyRules.turkish);
      host.remoteHumanSeats.add(1);
      // نجعل الدور للمقعد 1 وفي طور السحب
      host.currentTurnIndex = 1;
      host.turnPhase = OkeyTurnPhase.awaitingDraw;
      final before = host.players[1].activeTiles.length;
      final deckBefore = host.drawDeck.length;

      expect(host.applyRemoteAction(1, {'t': 'draw'}), isTrue,
          reason: 'سحب مشروع في دوره');
      expect(host.players[1].activeTiles.length, before + 1);
      expect(host.drawDeck.length, deckBefore - 1);
      expect(host.turnPhase, OkeyTurnPhase.awaitingDiscard);

      final tile = host.players[1].activeTiles.first;
      expect(host.applyRemoteAction(1, {'t': 'disc', 'id': tile.id}), isTrue);
      expect(host.players[1].activeTiles.length, before);
      expect(host.currentTurnIndex, 2);
      expect(host.discardPiles[1].last.id, tile.id);
      host.dispose();
    });

    test('الحركات خارج الدور أو بمعرّفات غير موجودة تُرفض', () {
      final host = OkeyEngine(rules: OkeyRules.turkish);
      host.remoteHumanSeats.add(2);
      host.currentTurnIndex = 0;
      host.turnPhase = OkeyTurnPhase.awaitingDraw;
      // ليس دور المقعد 2
      expect(host.applyRemoteAction(2, {'t': 'draw'}), isFalse);
      host.currentTurnIndex = 2;
      // معرّف غير موجود
      host.turnPhase = OkeyTurnPhase.awaitingDiscard;
      expect(host.applyRemoteAction(2, {'t': 'disc', 'id': 'nope'}), isFalse);
      // مقعد 0 (المضيف نفسه) لا تُطبَّق عليه الحركات البعيدة
      expect(host.applyRemoteAction(0, {'t': 'draw'}), isFalse);
      // حركة غير معروفة
      expect(host.applyRemoteAction(2, {'t': 'hack'}), isFalse);
      host.dispose();
    });

    test('نزول بير بمعرّفات الأحجار مع إعادة التحقق على المضيف', () {
      final host = OkeyEngine(rules: OkeyRules.turkish);
      host.remoteHumanSeats.add(1);
      host.currentTurnIndex = 1;
      host.turnPhase = OkeyTurnPhase.awaitingDiscard;
      final rack = host.players[1].rackTiles;
      // نزرع سلسلة صحيحة في يد المقعد 1
      final run = [
        OkeyTile(id: 'r5', color: OkeyTileColor.red, value: 5),
        OkeyTile(id: 'r6', color: OkeyTileColor.red, value: 6),
        OkeyTile(id: 'r7', color: OkeyTileColor.red, value: 7),
      ];
      rack[0] = run[0];
      rack[1] = run[1];
      rack[2] = run[2];

      // مجموعة غير صحيحة تُرفض
      expect(
          host.applyRemoteAction(1, {
            't': 'meld',
            'ids': ['r5', 'r7', 'ghost']
          }),
          isFalse);
      // الصحيحة تنزل
      expect(
          host.applyRemoteAction(1, {
            't': 'meld',
            'ids': ['r5', 'r6', 'r7']
          }),
          isTrue);
      expect(host.tableMelds.length, 1);
      expect(host.tableMelds.first.ownerIndex, 1);
      expect(host.tableMelds.first.isRun, isTrue);
      expect(host.tableMelds.first.pending, isTrue); // دون 101 معلّق
      host.dispose();
    });

    test('أخذ حجر اليسار يتتبّع قاعدة الإعادة لكل مقعد', () {
      final host = OkeyEngine(rules: OkeyRules.turkish);
      host.remoteHumanSeats.add(1);
      // المقعد 0 يرمي حجراً في كومته (كومة اليسار بالنسبة للمقعد 1)
      host.currentTurnIndex = 0;
      host.turnPhase = OkeyTurnPhase.awaitingDiscard;
      final myTile = host.players[0].activeTiles.first;
      host.discardTileForSeat(0, myTile.id);
      // الآن دور المقعد 1 — يأخذ حجر اليسار
      expect(host.currentTurnIndex, 1);
      expect(host.applyRemoteAction(1, {'t': 'take'}), isTrue);
      expect(host.players[1].activeTiles.contains(myTile), isTrue);
      // رمى حجراً عادياً دون فتح اللعب → الحجر المأخوذ يعود لكومة اليسار
      final other =
          host.players[1].activeTiles.firstWhere((x) => x.id != myTile.id);
      host.applyRemoteAction(1, {'t': 'disc', 'id': other.id});
      expect(host.discardPiles[0].contains(myTile), isTrue);
      host.dispose();
    });
  });

  group('وضع التدريب', () {
    test('اقتراح الرمي يختار حجراً معزولاً لا ضمن مجموعة ولا أوكي', () {
      final e = OkeyEngine(rules: OkeyRules.turkish);
      final hint = e.trainingDiscardHint;
      if (hint != null) {
        final t = e.players[0].rackTiles[hint]!;
        expect(t.isRealOkey, isFalse);
        expect(e.getHighlightedSlotIndices().contains(hint), isFalse);
      }
      e.dispose();
    });

    test('المحرك يقبل صعوبة البوتات السهلة للتدريب', () {
      final e = OkeyEngine(rules: OkeyRules.turkish);
      for (var i = 1; i < 4; i++) {
        e.players[i].botDifficulty = BotDifficulty.easy;
      }
      expect(
          e.players
              .sublist(1)
              .every((p) => p.botDifficulty == BotDifficulty.easy),
          isTrue);
      e.dispose();
    });
  });
}
