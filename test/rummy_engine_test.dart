import 'package:flutter_test/flutter_test.dart';

import 'package:game_hub/games/okey/okey_engine.dart';
import 'package:game_hub/games/okey/okey_models.dart';
import 'package:game_hub/games/okey/okey_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OkeyEngine rummy() => OkeyEngine(rules: OkeyRules.rummy);

  group('Rummy mode', () {
    test('rules: رامي بلا نقاط فتح وبلا تحويل أسلوب', () {
      final r = OkeyRules.rummy;
      expect(r.isRummy, isTrue);
      expect(r.variant, OkeyRulesVariant.rummy);
      expect(r.openingPoints, 0);
    });

    test('التوزيع: 14 ورقة لكل لاعب مع ورقة مكشوفة واحدة', () {
      final e = rummy();
      for (var i = 0; i < 4; i++) {
        expect(e.players[i].rackTiles.where((t) => t != null).length, 14);
      }
      // ورقة مكشوفة واحدة في كومة رمي اليسار
      expect(e.discardPiles[3].length, 1);
      for (var i = 0; i < 3; i++) {
        expect(e.discardPiles[i], isEmpty);
      }
      e.dispose();
    });

    test('الرزمة: ورقتا جوكر بريّتان فقط (isRealOkey + isFalseJoker)', () {
      final e = rummy();
      final all = <OkeyTile>[
        ...e.drawDeck,
        ...e.discardPiles.expand((p) => p),
        for (final p in e.players) ...p.rackTiles.whereType<OkeyTile>(),
      ];
      final wilds = all.where((t) => t.isFalseJoker && t.isRealOkey).toList();
      expect(wilds.length, 2);
      // لا أوكي مرقّم في رامي — كل الأوراق الأخرى عادية
      expect(all.where((t) => t.isRealOkey && !t.isFalseJoker), isEmpty);
      // الإجمالي: رزمتان 52 + جوكران = 106
      expect(all.length, 106);
      e.dispose();
    });

    test('بلا شرط نقاط فتح — remainingOpeningPoints دائماً صفر', () {
      final e = rummy();
      expect(e.players[0].hasOpened, isFalse);
      expect(e.remainingOpeningPoints, 0);
      e.dispose();
    });

    test('الدور يبدأ بالسحب — يد متساوية بلا رمي أول', () {
      final e = rummy();
      expect(e.turnPhase, OkeyTurnPhase.awaitingDraw);
      final before = e.drawDeck.length;
      expect(e.drawFromDeck(), isTrue);
      expect(e.drawDeck.length, before - 1);
      // بعد السحب يجب الرمي
      expect(e.turnPhase, OkeyTurnPhase.awaitingDiscard);
      final slot = e.players[0].rackTiles.lastIndexWhere((t) => t != null);
      expect(slot, greaterThanOrEqualTo(0));
      expect(e.discardSlot(slot), isTrue);
      e.dispose();
    });

    test('أخذ الورقة المكشوفة يعمل في الدور الأول', () {
      final e = rummy();
      expect(e.drawFromDiscard(), isTrue);
      expect(e.discardPiles[3], isEmpty);
      e.dispose();
    });

    test('الجوكر البري يكمل بيراً وينزل على الطاولة', () {
      final e = rummy();
      // رتّب يد البشري: ثلاث سبعات بألوان مختلفة + جوكر بري في خانات متتالية
      final rack = e.players[0].rackTiles;
      for (var i = 0; i < 28; i++) {
        rack[i] = null;
      }
      rack[0] = OkeyTile(id: 'a', color: OkeyTileColor.red, value: 7);
      rack[1] = OkeyTile(id: 'b', color: OkeyTileColor.blue, value: 7);
      rack[2] = OkeyTile(id: 'c', color: OkeyTileColor.yellow, value: 7);
      rack[3] = OkeyTile(
        id: 'j',
        color: OkeyTileColor.red,
        value: 0,
        isFalseJoker: true,
        isRealOkey: true,
      );
      rack[5] = OkeyTile(id: 'x', color: OkeyTileColor.black, value: 3);

      expect(e.layMeldContainingSlot(3), isTrue);
      expect(e.tableMelds.length, 1);
      expect(e.tableMelds.first.tiles.length, 4);
      // نزول حر — بلا شرط نقاط: يفتح فوراً
      expect(e.players[0].hasOpened, isTrue);
      expect(e.tableMelds.first.pending, isFalse);
      e.dispose();
    });

    test('لا يوجد إعلان أسلوب في رامي', () {
      final e = rummy();
      expect(e.canDeclarePlayStyle, isFalse);
      expect(e.declarePlayStyle(OkeyPlayStyle.konkan), isFalse);
      e.dispose();
    });
  });
}
