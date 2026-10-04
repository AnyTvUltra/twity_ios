import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/okey/okey_engine.dart';
import 'package:game_hub/games/okey/okey_models.dart';
import 'package:game_hub/games/okey/okey_rules.dart';

OkeyTile t(int id, OkeyTileColor c, int v,
        {bool fake = false, bool real = false}) =>
    OkeyTile(
        id: 't$id', color: c, value: v, isFalseJoker: fake, isRealOkey: real);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OkeyEngine — فجوات الرف بعد الرمي', () {
    test('رمي حجر من الصف العلوي يترك فجوة ولا يدمج المجموعات', () {
      final e = OkeyEngine();
      e.initGame();
      final rack = e.players[0].rackTiles;

      // رتّب يدوياً: مجموعتان مفصولتان بفجوة في الصف العلوي
      final a = t(1, OkeyTileColor.red, 5);
      final b = t(2, OkeyTileColor.red, 6);
      final c = t(3, OkeyTileColor.red, 7);
      final x = t(4, OkeyTileColor.blue, 9);
      final d = t(5, OkeyTileColor.black, 2);
      final f = t(6, OkeyTileColor.black, 3);
      final g = t(7, OkeyTileColor.black, 4);
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      rack[0] = a;
      rack[1] = b;
      rack[2] = c;
      rack[3] = x; // مرشح الرمي
      // خانة 4 فارغة — فاصل المجموعات
      rack[5] = d;
      rack[6] = f;
      rack[7] = g;

      e.turnPhase = OkeyTurnPhase.awaitingDiscard;
      e.discardSlot(3);

      // الفجوة بقيت والمجموعتان لم تندمجا
      expect(rack[0], a);
      expect(rack[1], b);
      expect(rack[2], c);
      expect(rack[4], null, reason: 'الفجوة الفاصلة يجب أن تبقى');
      expect(rack[5], d);
      expect(rack[6], f);
      expect(rack[7], g);
      e.dispose();
    });
  });

  group('OkeyEngine — المجموعات الجاهزة على الرف', () {
    test('rackReadyGroups تحسب الكتل الصحيحة فقط', () {
      final e = OkeyEngine();
      e.initGame();
      final rack = e.players[0].rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      // Run صحيح أحمر 5-6-7
      rack[0] = t(1, OkeyTileColor.red, 5);
      rack[1] = t(2, OkeyTileColor.red, 6);
      rack[2] = t(3, OkeyTileColor.red, 7);
      // كتلة غير صحيحة (ألوان مختلفة قيم مختلفة)
      rack[4] = t(4, OkeyTileColor.blue, 1);
      rack[5] = t(5, OkeyTileColor.black, 9);
      rack[6] = t(6, OkeyTileColor.yellow, 4);
      // Set صحيح في الصف السفلي: ثلاث سبعات بألوان مختلفة
      rack[14] = t(7, OkeyTileColor.red, 9);
      rack[15] = t(8, OkeyTileColor.blue, 9);
      rack[16] = t(9, OkeyTileColor.black, 9);

      final groups = e.rackReadyGroups;
      expect(groups.length, 2);
      expect(e.liveGroupCount, 2);
      expect(e.livePoints, 5 + 6 + 7 + 9 + 9 + 9);
      e.dispose();
    });
  });

  group('OkeyEngine — الفوز', () {
    test('يد فائزة من 14 حجراً (أربعة Per + زوج)', () {
      final e = OkeyEngine();
      final hand = [
        t(1, OkeyTileColor.red, 5),
        t(2, OkeyTileColor.red, 6),
        t(3, OkeyTileColor.red, 7),
        t(4, OkeyTileColor.blue, 9),
        t(5, OkeyTileColor.black, 9),
        t(6, OkeyTileColor.yellow, 9),
        t(7, OkeyTileColor.red, 1),
        t(8, OkeyTileColor.blue, 1),
        t(9, OkeyTileColor.black, 1),
        t(10, OkeyTileColor.yellow, 3),
        t(11, OkeyTileColor.yellow, 4),
        t(12, OkeyTileColor.yellow, 5),
        t(13, OkeyTileColor.yellow, 6),
        t(14, OkeyTileColor.yellow, 7),
      ];
      expect(e.isWinningHand(hand), true);
      e.dispose();
    });

    test('canDeclareOkeyOut يفحص كل مرشحي الرمي لا أول 14 فقط', () {
      final e = OkeyEngine();
      e.initGame();
      final rack = e.players[0].rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      // حجر زائد في أول خانة ثم اليد الفائزة الـ14
      rack[0] = t(0, OkeyTileColor.black, 13);
      final hand = [
        t(1, OkeyTileColor.red, 5),
        t(2, OkeyTileColor.red, 6),
        t(3, OkeyTileColor.red, 7),
        t(4, OkeyTileColor.blue, 9),
        t(5, OkeyTileColor.black, 9),
        t(6, OkeyTileColor.yellow, 9),
        t(7, OkeyTileColor.red, 1),
        t(8, OkeyTileColor.blue, 1),
        t(9, OkeyTileColor.black, 1),
        t(10, OkeyTileColor.yellow, 3),
        t(11, OkeyTileColor.yellow, 4),
        t(12, OkeyTileColor.yellow, 5),
        t(13, OkeyTileColor.yellow, 6),
        t(14, OkeyTileColor.yellow, 7),
      ];
      for (int i = 0; i < hand.length; i++) {
        rack[1 + i] = hand[i];
      }
      expect(e.players[0].activeTiles.length, 15);
      expect(e.canDeclareOkeyOut, true,
          reason: 'الفوز يجب أن يُكتشف ولو كان الحجر الزائد في أول الرف');
      e.dispose();
    });

    test('اللاعب المفتوح يفوز عندما تتقسم بقايا رفّه بالكامل', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = true;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      // مجموعة واحدة متبقية (3 أحجار) + حجر للرمي = فوز
      rack[0] = t(1, OkeyTileColor.red, 5);
      rack[1] = t(2, OkeyTileColor.red, 6);
      rack[2] = t(3, OkeyTileColor.red, 7);
      rack[3] = t(4, OkeyTileColor.black, 10);

      e.turnPhase = OkeyTurnPhase.awaitingDiscard;
      e.discardSlot(3);
      expect(e.gameState, OkeyGameState.win);
      expect(e.winner, p);
      e.dispose();
    });

    test('اللاعب المفتوح لا يفوز بحجرين متبقيين غير قابلين للتقسيم', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = true;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      rack[0] = t(1, OkeyTileColor.red, 5);
      rack[1] = t(2, OkeyTileColor.red, 9);
      rack[2] = t(3, OkeyTileColor.black, 10);

      e.turnPhase = OkeyTurnPhase.awaitingDiscard;
      e.discardSlot(2);
      expect(e.gameState, isNot(OkeyGameState.win));
      e.dispose();
    });

    test('زر الفوز لا يظهر للفاتح بحجر لا يصرف على أي بير', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = true;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      // حجر وحيد لا يمدّ أي بير على الطاولة
      rack[0] = t(1, OkeyTileColor.red, 4);
      e.tableMelds.add(OkeyGroup(
        tiles: [
          t(2, OkeyTileColor.blue, 5),
          t(3, OkeyTileColor.blue, 6),
          t(4, OkeyTileColor.blue, 7),
        ],
        isRun: true,
        ownerIndex: 1,
      ));
      expect(e.canDeclareOkeyOut, false,
          reason: 'حجر لا يصرف على شيء ليس فوزاً — لا يظهر الزر');
      e.dispose();
    });

    test('زر الفوز يظهر للفاتح عندما يصرف حجره الأخير على بير', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = true;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      // حجر وحيد يمدّ سلسلة خصم 5-6-7 من الأسفل
      rack[0] = t(1, OkeyTileColor.red, 4);
      e.tableMelds.add(OkeyGroup(
        tiles: [
          t(2, OkeyTileColor.red, 5),
          t(3, OkeyTileColor.red, 6),
          t(4, OkeyTileColor.red, 7),
        ],
        isRun: true,
        ownerIndex: 1,
      ));
      expect(e.canDeclareOkeyOut, true,
          reason: 'صرف الحجر الأخير على بير = فوز كامل');
      e.dispose();
    });

    test('زر الفوز يظهر للفاتح ببير جديد + صرف على بير موجود', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = true;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      // سلسلة جديدة كاملة على الرف + حجر يُصرف على بير خصم
      rack[0] = t(1, OkeyTileColor.yellow, 1);
      rack[1] = t(2, OkeyTileColor.yellow, 2);
      rack[2] = t(3, OkeyTileColor.yellow, 3);
      rack[3] = t(4, OkeyTileColor.red, 4);
      e.tableMelds.add(OkeyGroup(
        tiles: [
          t(5, OkeyTileColor.red, 5),
          t(6, OkeyTileColor.red, 6),
          t(7, OkeyTileColor.red, 7),
        ],
        isRun: true,
        ownerIndex: 1,
      ));
      expect(e.canDeclareOkeyOut, true,
          reason: 'بير جديد + صرف الأخير = إفراغ كامل للرف');
      e.dispose();
    });
  });

  group('OkeyEngine — الصرف على بيرات الطاولة', () {
    test('لاعب فاتح يصرف حجراً يمدّ سلسلة خصم', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = true;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      rack[0] = t(1, OkeyTileColor.red, 4);

      // بير خصم: سلسلة حمراء 5-6-7
      e.tableMelds.add(OkeyGroup(
        tiles: [
          t(2, OkeyTileColor.red, 5),
          t(3, OkeyTileColor.red, 6),
          t(4, OkeyTileColor.red, 7),
        ],
        isRun: true,
        ownerIndex: 1,
      ));

      expect(e.layTileOnMeld(0, 0), true);
      expect(rack[0], null);
      expect(e.tableMelds[0].tiles.length, 4);
      expect(e.tableMelds[0].tiles.first.value, 4);
      e.dispose();
    });

    test('لاعب غير فاتح لا يستطيع الصرف', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = false;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      rack[0] = t(1, OkeyTileColor.red, 4);
      e.tableMelds.add(OkeyGroup(
        tiles: [
          t(2, OkeyTileColor.red, 5),
          t(3, OkeyTileColor.red, 6),
          t(4, OkeyTileColor.red, 7),
        ],
        isRun: true,
        ownerIndex: 1,
      ));

      expect(e.layTileOnMeld(0, 0), false);
      expect(rack[0], isNotNull);
      e.dispose();
    });

    test('صرف على مجموعة (Set) بلون غير مكرر فقط', () {
      final e = OkeyEngine();
      e.initGame();
      final p = e.players[0];
      p.hasOpened = true;
      final rack = p.rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      rack[0] = t(1, OkeyTileColor.yellow, 9);
      rack[1] = t(2, OkeyTileColor.red, 9); // لون مكرر — مرفوض
      rack[2] = t(3, OkeyTileColor.red, 5); // قيمة مختلفة — مرفوض

      e.tableMelds.add(OkeyGroup(
        tiles: [
          t(4, OkeyTileColor.red, 9),
          t(5, OkeyTileColor.blue, 9),
          t(6, OkeyTileColor.black, 9),
        ],
        isRun: false,
        ownerIndex: 0,
      ));

      expect(e.layTileOnMeld(0, 0), true); // أصفر 9 مقبول
      expect(e.layTileOnMeld(1, 0), false); // أحمر مكرر مرفوض
      expect(e.layTileOnMeld(2, 0), false); // قيمة مختلفة مرفوضة
      e.dispose();
    });
  });

  group('OkeyEngine — إعادة خلط المرميات', () {
    test('نفاد رزمة السحب يعيد المرميات مخلوطة للرزمة', () {
      final e = OkeyEngine();
      e.initGame();
      e.drawDeck.clear();

      // مرميات اللاعبين الأربعة
      for (int i = 0; i < 4; i++) {
        e.discardPiles[i].add(t(100 + i, OkeyTileColor.values[i], 3 + i));
      }

      e.currentTurnIndex = 0;
      e.turnPhase = OkeyTurnPhase.awaitingDraw;
      // اترك خانة فارغة على رف اللاعب للسحب
      e.players[0].rackTiles[0] = null;

      expect(e.drawFromDeck(), true);
      expect(e.discardPiles.every((p) => p.isEmpty), true,
          reason: 'كل المرميات يجب أن تُنقل للرزمة');
      expect(e.drawDeck.length, 3, // 4 مرميات - حجر مسحوب
          reason: 'الرزمة يجب أن تستعيد بقية المرميات');
      e.dispose();
    });
  });

  group('OkeyEngine — نقل الكتل والسحب إلى خانة', () {
    test('moveGroup ينقل الكتلة كاملة بترتيبها إلى الصف الآخر', () {
      final e = OkeyEngine();
      e.initGame();
      final rack = e.players[0].rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      final a = t(1, OkeyTileColor.red, 5);
      final b = t(2, OkeyTileColor.red, 6);
      final c = t(3, OkeyTileColor.red, 7);
      rack[2] = a;
      rack[3] = b;
      rack[4] = c;
      expect(e.moveGroup(3, 18), isTrue);
      expect(rack[2], null);
      expect(rack[3], null);
      expect(rack[4], null);
      expect([rack[18], rack[19], rack[20]], [a, b, c]);
      e.dispose();
    });

    test('moveGroup يختار أقرب مكان يتسع عند وجود أحجار في الهدف', () {
      final e = OkeyEngine();
      e.initGame();
      final rack = e.players[0].rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      final a = t(1, OkeyTileColor.blue, 1);
      final b = t(2, OkeyTileColor.blue, 2);
      final blocker = t(3, OkeyTileColor.black, 9);
      rack[0] = a;
      rack[1] = b;
      rack[16] = blocker;
      expect(e.moveGroup(0, 16), isTrue);
      expect(rack[16], blocker);
      final placed = [
        for (var i = 14; i < 28; i++)
          if (rack[i] == a) i
      ];
      expect(placed.length, 1);
      expect(rack[placed.first + 1], b);
      e.dispose();
    });

    test('drawFromDeck(toSlot) يضع الحجر المسحوب في الخانة المطلوبة', () {
      final e = OkeyEngine();
      e.initGame();
      final rack = e.players[0].rackTiles;
      // اجعلها بداية دور سحب مع خانات فارغة
      e.currentTurnIndex = 0;
      e.turnPhase = OkeyTurnPhase.awaitingDraw;
      rack[27] = null;
      rack[20] = null;
      final next = e.drawDeck.first;
      expect(e.drawFromDeck(toSlot: 20), isTrue);
      expect(rack[20], same(next));
      expect(e.turnPhase, OkeyTurnPhase.awaitingDiscard);
      e.dispose();
    });
  });

  group('OkeyEngine — قانون سليمانية وأساليب الكونكان/الفول', () {
    test('سليمانية: الجوكر أصغر من المؤشر بواحد وبنفس اللون', () {
      for (var i = 0; i < 20; i++) {
        final e = OkeyEngine(rules: OkeyRules.sulaymaniyah);
        final ind = e.indicatorTile.value;
        expect(e.realOkeySample.value, ind == 1 ? 13 : ind - 1);
        expect(e.realOkeySample.color, e.indicatorTile.color);
        e.dispose();
      }
      final tr = OkeyEngine(rules: OkeyRules.turkish);
      final ind = tr.indicatorTile.value;
      expect(tr.realOkeySample.value, ind == 13 ? 1 : ind + 1);
      tr.dispose();
    });

    test('فول: لون واحد 1..13 + 1 يفوز، ولون مختلط لا يفوز', () {
      final e = OkeyEngine();
      var id = 100;
      final full = [
        for (var v = 1; v <= 13; v++) t(id++, OkeyTileColor.red, v),
        t(id++, OkeyTileColor.red, 1),
      ];
      expect(e.isFullHand(full), isTrue);
      final mixed = List<OkeyTile>.from(full)
        ..[5] = t(id++, OkeyTileColor.blue, 6);
      expect(e.isFullHand(mixed), isFalse);
      // الأوكي يعوّض حجراً ناقصاً
      final withJoker = List<OkeyTile>.from(full)
        ..[7] = t(id++, OkeyTileColor.black, 4, real: true);
      expect(e.isFullHand(withJoker), isTrue);
      e.dispose();
    });

    test('كونكان: 10 متسلسلة بلون واحد + بير من 4 يفوز', () {
      final e = OkeyEngine();
      var id = 200;
      final hand = [
        for (var v = 1; v <= 10; v++) t(id++, OkeyTileColor.blue, v),
        t(id++, OkeyTileColor.red, 7),
        t(id++, OkeyTileColor.yellow, 7),
        t(id++, OkeyTileColor.black, 7),
        t(id++, OkeyTileColor.blue, 7),
      ];
      expect(e.isKonkanHand(hand), isTrue);
      // تسلسل 9 فقط لا يكفي
      final short = List<OkeyTile>.from(hand)
        ..[9] = t(id++, OkeyTileColor.red, 1);
      expect(e.isKonkanHand(short), isFalse);
      e.dispose();
    });

    test('أخذ حجر اليسار لا يحوّل اللاعب كونكان — الأسلوب يُختار يدوياً', () {
      final e = OkeyEngine();
      e.currentTurnIndex = 0;
      e.turnPhase = OkeyTurnPhase.awaitingDraw;
      e.players[0].rackTiles[27] = null;
      e.players[0].rackTiles[26] = null;
      e.discardPiles[3].add(t(300, OkeyTileColor.red, 3));
      e.players[3].playStyle = OkeyPlayStyle.full;
      expect(e.drawFromDiscard(), isFalse);
      e.players[3].playStyle = OkeyPlayStyle.normal;
      expect(e.drawFromDiscard(), isTrue);
      // يبقى عادياً ويستطيع النزول — لا تحويل تلقائي لكونكان
      expect(e.players[0].playStyle, OkeyPlayStyle.normal);
      expect(e.humanCanLayMelds, isTrue);
      e.dispose();
    });

    test('أخذ حجر اليسار دون فتح يعيده للكومة ويسحب بديلاً من الرزمة', () {
      final e = OkeyEngine();
      e.currentTurnIndex = 0;
      e.turnPhase = OkeyTurnPhase.awaitingDraw;
      // يد حتمية من 14 حجراً غير فائزة ولا تكوّن أي بير
      final rack = e.players[0].rackTiles;
      for (int i = 0; i < 28; i++) {
        rack[i] = null;
      }
      const vals = [1, 3, 5, 7, 9, 11, 13, 2, 4, 6, 8, 10, 12, 1];
      const cols = [
        OkeyTileColor.red,
        OkeyTileColor.blue,
        OkeyTileColor.black,
        OkeyTileColor.yellow,
        OkeyTileColor.red,
        OkeyTileColor.blue,
        OkeyTileColor.black,
        OkeyTileColor.yellow,
        OkeyTileColor.red,
        OkeyTileColor.blue,
        OkeyTileColor.black,
        OkeyTileColor.yellow,
        OkeyTileColor.red,
        OkeyTileColor.blue,
      ];
      for (int i = 0; i < 14; i++) {
        rack[i] = t(400 + i, cols[i], vals[i]);
      }
      final taken = t(300, OkeyTileColor.red, 3);
      e.discardPiles[3].add(taken);
      expect(e.players[0].activeTiles.length, 14);

      expect(e.drawFromDiscard(), isTrue);
      expect(e.players[0].activeTiles.length, 15);
      expect(e.players[0].playStyle, OkeyPlayStyle.normal);

      // رمي حجر آخر دون إكمال الافتتاح → المأخوذ يعود لكومة اليسار
      // ويُسحب بديل من الرزمة ثم يُرمى الحجر المختار
      final candidate = e.players[0].rackTiles[0]!;
      expect(identical(candidate, taken), isFalse);
      final deckBefore = e.drawDeck.length;
      e.discardSlot(0);

      expect(e.discardPiles[3].last, same(taken),
          reason: 'الحجر المأخوذ يجب أن يعود فوق كومة اليسار');
      expect(e.discardPiles[0].last, same(candidate));
      expect(e.drawDeck.length, deckBefore - 1,
          reason: 'بديل واحد يُسحب من الرزمة');
      expect(e.players[0].activeTiles.length, 14,
          reason: 'بعد الإعادة+السحب+الرمي يبقى الرف 14 حجراً');
      expect(e.currentTurnIndex, 1);
      e.dispose();
    });

    test('رمي الحجر المأخوذ نفسه يعيده ويسحب بديلاً ولا يرمي شيئاً', () {
      final e = OkeyEngine();
      e.currentTurnIndex = 0;
      e.turnPhase = OkeyTurnPhase.awaitingDraw;
      // البادئ عنده 15 حجراً — أفرغ خانة مشغولة ليصبح 14
      e.players[0].rackTiles[0] = null;
      final taken = t(300, OkeyTileColor.red, 3);
      e.discardPiles[3].add(taken);

      expect(e.drawFromDiscard(), isTrue);
      final slot =
          e.players[0].rackTiles.indexWhere((x) => identical(x, taken));
      expect(slot, isNot(-1));

      e.discardSlot(slot);
      // الحجر عاد لكومة اليسار وسُحب بديل — ولم يُرمَ أي حجر بعد
      expect(e.discardPiles[3].last, same(taken));
      expect(e.discardPiles[0], isEmpty);
      expect(e.turnPhase, OkeyTurnPhase.awaitingDiscard);
      expect(e.currentTurnIndex, 0);
      expect(e.players[0].activeTiles.length, 15);
      e.dispose();
    });

    test('الفاتح أو الكونكان يحتفظ بحجر اليسار المأخوذ', () {
      final e = OkeyEngine();
      e.currentTurnIndex = 0;
      e.turnPhase = OkeyTurnPhase.awaitingDraw;
      e.players[0].rackTiles[0] = null;
      e.players[0].hasOpened = true;
      final taken = t(300, OkeyTileColor.red, 3);
      e.discardPiles[3].add(taken);

      expect(e.drawFromDiscard(), isTrue);
      e.discardSlot(1);
      // الفاتح لا يحتاج نقاط افتتاح — يحتفظ بالحجر
      expect(e.discardPiles[3], isEmpty,
          reason: 'لا إعادة للحجر عندما يكون اللاعب فاتحاً');
      e.dispose();
    });
  });
}
