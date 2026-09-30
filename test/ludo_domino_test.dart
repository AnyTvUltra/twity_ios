import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/ludo/ludo_engine.dart';
import 'package:game_hub/games/ludo/ludo_audio.dart';
import 'package:game_hub/games/domino/domino_engine.dart';
import 'package:game_hub/games/domino/domino_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // بلا إضافات صوتية في بيئة الاختبار
  LudoAudio.soundEnabled = false;
  DominoAudio.soundEnabled = false;

  group('LudoEngine —', () {
    test('البداية: كل الأحجار في القاعدة والخروج يتطلب 6', () {
      final e = LudoEngine(vsAI: false);
      e.dice = 3;
      expect(e.legalTokens(0), isEmpty);
      e.dice = 6;
      expect(e.legalTokens(0).length, 4);
      e.dispose();
    });

    test('globalOf يلف المسار ويحسب الانطلاق صحيحاً', () {
      // الأزرق (لاعب 0) ينطلق من الخانة العالمية 39
      expect(LudoEngine.globalOf(0, 0), 39);
      expect(LudoEngine.globalOf(0, 13), 0); // يلف 52
      // الأخضر (لاعب 1) ينطلق من 13
      expect(LudoEngine.globalOf(1, 0), 13);
    });

    test('الأحجار الناهية والمتجاوزة ليست قانونية', () {
      final e = LudoEngine(vsAI: false);
      e.tokens[0][0] = 57; // وصل
      e.tokens[0][1] = 54; // قرب النهاية
      e.dice = 6;
      // حجر 0 انتهى؛ حجر 1 يتجاوز 57 بستة → غير قانوني
      final legal = e.legalTokens(0);
      expect(legal.contains(0), isFalse);
      expect(legal.contains(1), isFalse);
      e.dice = 2;
      expect(e.legalTokens(0).contains(1), isTrue);
      e.dispose();
    });
  });

  group('DominoEngine —', () {
    test('التوزيع: 7+7 أحجار و14 في البونيارد وسلسلة فارغة', () {
      final e = DominoEngine(vsAI: false);
      expect(e.hands[0].length, 7);
      expect(e.hands[1].length, 7);
      expect(e.boneyard.length, 14);
      expect(e.chain, isEmpty);
      expect(e.hands[0].toSet().intersection(e.hands[1].toSet()), isEmpty);
      e.dispose();
    });

    test('السلسلة الفارغة: كل حجر يلعب على أي طرف', () async {
      final e = DominoEngine(vsAI: false);
      final t = e.hands[0].first;
      expect(e.legalSides(t).length, 2);
      e.dispose();
    });

    test('legalSides يطابق طرفي السلسلة فقط', () async {
      final e = DominoEngine(vsAI: false);
      // نفرض سلسلة بطرفين 3 و5
      e.chain.add(const PlacedDomino(DominoTile(3, 5), 3, 5));
      e.leftEnd = 3;
      e.rightEnd = 5;
      expect(e.legalSides(const DominoTile(3, 1)), [0]);
      expect(e.legalSides(const DominoTile(5, 2)), [1]);
      expect(e.legalSides(const DominoTile(3, 5)).length, 2);
      expect(e.legalSides(const DominoTile(0, 4)), isEmpty);
      e.dispose();
    });

    test('نهاية الجولة بالبلوك: الأقل نقاطاً يكسب الفرق', () async {
      final e = DominoEngine(vsAI: false);
      e.hands[0] = [const DominoTile(1, 0)]; // نقطة واحدة
      e.hands[1] = [const DominoTile(6, 6)]; // 12 نقطة
      e.chain.add(const PlacedDomino(DominoTile(4, 4), 4, 4));
      e.leftEnd = 4;
      e.rightEnd = 4;
      e.boneyard.clear();
      e.currentPlayer = 0;
      e.pass(0); // لا حركة → تمرير
      expect(e.currentPlayer, 1);
      e.pass(1); // بلوك
      expect(e.betweenRounds, isTrue);
      expect(e.roundWinner, 0); // الأقل نقاطاً
      expect(e.scores[0], 11); // فرق النقاط
      e.dispose();
    });
  });
}
