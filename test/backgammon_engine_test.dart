import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/backgammon/backgammon_engine.dart';

BgState empty() => BgState(List<int>.filled(24, 0), [0, 0], [0, 0]);

int total(BgState s, int side) {
  int t = s.bar[side] + s.off[side];
  for (int i = 0; i < 24; i++) {
    t += s.countAt(i, side);
  }
  return t;
}

void main() {
  test('الوضع الابتدائي: 15 حجراً لكل لاعب و167 نقطة', () {
    final s = BgState.initial();
    expect(total(s, 0), 15);
    expect(total(s, 1), 15);
    expect(s.pip(0), 167);
    expect(s.pip(1), 167);
  });

  test('الضرب يرسل الحجر المكشوف إلى البار', () {
    final s = empty()
      ..pts[10] = 1
      ..pts[7] = -1;
    final n = BackgammonEngine.applyTo(s, 0, const BgMove(10, 7, 3));
    expect(n.pts[7], 1);
    expect(n.bar[1], 1);
  });

  test('لا يمكن الهبوط على خانة فيها حجران للخصم', () {
    final s = empty()
      ..pts[10] = 1
      ..pts[7] = -2
      ..pts[0] = -13;
    final legal = BackgammonEngine.legalFor(s, 0, [3, 3, 3, 3]);
    expect(legal.any((m) => m.to == 7), isFalse);
  });

  test('حجر على البار يجب إدخاله أولاً', () {
    final s = empty()
      ..pts[5] = 14
      ..bar[0] = 1
      ..pts[0] = -15;
    final legal = BackgammonEngine.legalFor(s, 0, [2, 4]);
    expect(legal, isNotEmpty);
    expect(legal.every((m) => m.from == BgMove.bar), isTrue);
    expect(legal.map((m) => m.to).toSet(), {22, 20});
  });

  test('الإخراج مسموح فقط عندما تكون كل الأحجار في البيت', () {
    final s = empty()
      ..pts[3] = 14
      ..pts[8] = 1
      ..pts[23] = -15;
    var legal = BackgammonEngine.legalFor(s, 0, [4, 6]);
    expect(legal.any((m) => m.to == BgMove.off), isFalse);

    s.pts[8] = 0;
    s.pts[2] = 1;
    legal = BackgammonEngine.legalFor(s, 0, [4, 6]);
    expect(legal.any((m) => m.from == 3 && m.to == BgMove.off), isTrue);
  });

  test('نرد أكبر من المسافة يُخرج فقط الحجر الأبعد', () {
    final s = empty()
      ..pts[1] = 1
      ..pts[3] = 1
      ..pts[23] = -15;
    s.off[0] = 13;
    final legal = BackgammonEngine.legalFor(s, 0, [6, 6, 6, 6]);
    final offs = legal.where((m) => m.to == BgMove.off).map((m) => m.from);
    expect(offs.toSet(), {3});
  });

  test('إن أمكن لعب نرد واحد فقط فالأكبر إلزامي', () {
    // حجر وحيد: 6 متاح و2 متاح لكن لا يمكن لعب الاثنين معاً
    final s = empty()
      ..pts[10] = 1
      ..pts[2] = -2 // يسد 10-6-2
      ..pts[6] = -2 // يسد 10-2-6
      ..pts[23] = -11;
    s.off[0] = 14;
    final legal = BackgammonEngine.legalFor(s, 0, [6, 2]);
    expect(legal.length, 1);
    expect(legal.first.die, 6);
  });

  test('الفوز ومضاعف المارس', () {
    final e = BackgammonEngine(rng: math.Random(1));
    e.state = empty()
      ..pts[0] = 1
      ..pts[20] = -15;
    e.state.off[0] = 14;
    e.turn = 0;
    e.setDice(1, 2);
    final m = e.legalMoves().firstWhere((m) => m.to == BgMove.off);
    e.applyMove(m);
    expect(e.winner, 0);
    expect(e.winMultiplier, 2);
  });

  test('التراجع يعيد الحالة والنرد', () {
    final e = BackgammonEngine(rng: math.Random(2));
    e.setDice(3, 1);
    final before = e.state.key;
    e.applyMove(e.legalMoves().first);
    expect(e.state.key, isNot(before));
    e.undo();
    expect(e.state.key, before);
    expect(e.dice.length, 2);
  });

  test('البوت يلعب مباريات كاملة بقوانين صحيحة', () {
    for (int g = 0; g < 6; g++) {
      final e = BackgammonEngine(rng: math.Random(g));
      e.rollOpening();
      int guard = 0;
      while (e.winner == null && guard++ < 2000) {
        final seq = e.bestSequence(level: BgBotLevel.hard);
        for (final m in seq) {
          expect(e.legalMoves().contains(m), isTrue);
          e.applyMove(m);
          if (e.winner != null) break;
        }
        if (e.winner == null) {
          expect(e.legalMoves(), isEmpty);
          e.endTurn();
          e.roll();
        }
        expect(total(e.state, 0), 15);
        expect(total(e.state, 1), 15);
      }
      expect(e.winner, isNotNull);
    }
  });

  test('المسارات المركبة بنفس الحجر', () {
    final e = BackgammonEngine(rng: math.Random(3));
    e.state = empty()
      ..pts[20] = 1
      ..pts[0] = -15;
    e.state.off[0] = 14;
    e.turn = 0;
    e.setDice(3, 2);
    final paths = e.pathsFrom(20);
    expect(paths.keys.toSet(), containsAll([17, 18, 15]));
    expect(paths[15]!.length, 2);
  });
}
