import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/okey/okey_engine.dart';
import 'package:game_hub/games/okey/okey_models.dart';

OkeyTile t(int id, OkeyTileColor c, int v,
        {bool fake = false, bool real = false}) =>
    OkeyTile(
        id: 't$id',
        color: c,
        value: v,
        isFalseJoker: fake,
        isRealOkey: real);

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
        e.discardPiles[i]
            .add(t(100 + i, OkeyTileColor.values[i], 3 + i));
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
}
