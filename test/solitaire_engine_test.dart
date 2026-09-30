import 'package:flutter_test/flutter_test.dart';
import 'package:game_hub/games/solitaire/solitaire_audio.dart';
import 'package:game_hub/games/solitaire/solitaire_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SolAudio.soundEnabled = false;
  });

  SolitaireEngine fresh() => SolitaireEngine();

  test('التوزيع الأولي: 7 أعمدة بأحجام 1..7، القمة مكشوفة فقط، 24 بالمخزون',
      () {
    final e = fresh();
    for (var i = 0; i < 7; i++) {
      expect(e.tableau[i].length, i + 1);
      expect(e.tableau[i].last.faceUp, isTrue);
      for (var j = 0; j < i; j++) {
        expect(e.tableau[i][j].faceUp, isFalse);
      }
    }
    expect(e.stock.length, 24);
    expect(e.waste, isEmpty);
    expect(e.foundations.every((f) => f.isEmpty), isTrue);
    // 52 بطاقة بلا تكرار
    final ids = <int>{
      ...e.stock.map((c) => c.id),
      for (final t in e.tableau) ...t.map((c) => c.id),
    };
    expect(ids.length, 52);
  });

  test('السحب: بطاقة من المخزون تكشف بالمهملات، والتدوير يعيدها مقلوبة', () {
    final e = fresh();
    final before = e.stock.last.id;
    e.draw();
    expect(e.stock.length, 23);
    expect(e.waste.length, 1);
    expect(e.waste.single.id, before);
    expect(e.waste.single.faceUp, isTrue);

    // أفرغ المخزون كله
    while (e.stock.isNotEmpty) {
      e.draw();
    }
    expect(e.waste.length, 24);
    e.draw(); // تدوير
    expect(e.stock.length, 24);
    expect(e.waste, isEmpty);
    expect(e.stock.every((c) => !c.faceUp), isTrue);
  });

  test('قواعد التابلو: تنازلي متناوب الألوان فقط، والفراغ للملوك', () {
    final e = fresh();
    // بناء سيناريو يدوي
    e.tableau[0]
      ..clear()
      ..add(SolCard(7, SolSuit.spades, faceUp: true));
    e.waste.add(SolCard(6, SolSuit.hearts, faceUp: true));
    expect(e.moveToTableau('w', 0, 0), isTrue); // 6♥ على 7♠ ✓
    expect(e.waste, isEmpty);

    e.waste.add(SolCard(5, SolSuit.clubs, faceUp: true));
    expect(e.moveToTableau('w', 0, 0), isTrue); // 5♣ على 6♥ ✓

    // لون خاطئ: 4♠ (أسود) على 5♣ (أسود) ✗
    e.waste.add(SolCard(4, SolSuit.spades, faceUp: true));
    expect(e.moveToTableau('w', 0, 0), isFalse);

    // رتبة خاطئة: 3♦ على 5♣ (لا يتبعه) ✗
    e.waste.removeLast();
    e.waste.add(SolCard(3, SolSuit.diamonds, faceUp: true));
    expect(e.moveToTableau('w', 0, 0), isFalse);

    // عمود فارغ: الملك فقط
    e.tableau[1].clear();
    e.waste.removeLast();
    e.waste.add(SolCard(9, SolSuit.diamonds, faceUp: true));
    expect(e.moveToTableau('w', 0, 1), isFalse);
    e.waste.removeLast();
    e.waste.add(SolCard(13, SolSuit.spades, faceUp: true));
    expect(e.moveToTableau('w', 0, 1), isTrue);
  });

  test('نقل تسلسل من عمود لآخر + قلب البطاقة المكشوفة', () {
    final e = fresh();
    // عمود 0: بطاقة مقلوبة + تسلسل مكشوف [8♠,7♥,6♣]
    e.tableau[0]
      ..clear()
      ..addAll([
        SolCard(10, SolSuit.diamonds), // مقلوبة
        SolCard(8, SolSuit.spades, faceUp: true),
        SolCard(7, SolSuit.hearts, faceUp: true),
        SolCard(6, SolSuit.clubs, faceUp: true),
      ]);
    e.tableau[1]
      ..clear()
      ..add(SolCard(9, SolSuit.hearts, faceUp: true));

    // نقل التسلسل [8♠..6♣] (index 1) فوق 9♥ — 8♠ أسود على 9♥ أحمر ✓
    expect(e.moveToTableau('t0', 1, 1), isTrue);
    expect(e.tableau[1].length, 4);
    expect(e.tableau[1].last.rank, 6);
    // البطاقة المكشوفة الجديدة في عمود 0 انقلبت
    expect(e.tableau[0].length, 1);
    expect(e.tableau[0].single.faceUp, isTrue);
  });

  test('الأساس: يبدأ بالآس ويصعد بنفس الشعار فقط', () {
    final e = fresh();
    e.waste.add(SolCard(5, SolSuit.hearts, faceUp: true));
    expect(e.moveToFoundation('w', 0), isFalse); // ليس آساً

    e.waste.removeLast();
    e.waste.add(SolCard(1, SolSuit.hearts, faceUp: true));
    expect(e.moveToFoundation('w', 0), isTrue);
    expect(e.foundations.any((f) => f.length == 1), isTrue);

    // 2♦ لون مختلف الشعار ✗ — لكن 2♥ ✓
    e.waste.add(SolCard(2, SolSuit.diamonds, faceUp: true));
    expect(e.moveToFoundation('w', 0), isFalse);
    e.waste.removeLast();
    e.waste.add(SolCard(2, SolSuit.hearts, faceUp: true));
    expect(e.moveToFoundation('w', 0), isTrue);
  });

  test('التراجع يعيد الحالة تماماً', () {
    final e = fresh();
    e.draw();
    e.draw();
    final stockLen = e.stock.length;
    e.undo();
    expect(e.waste.length, 1);
    expect(e.stock.length, stockLen + 1);
    e.undo();
    expect(e.waste, isEmpty);
    expect(e.stock.length, 24);
    expect(e.canUndo, isFalse);
  });

  test('التلميح يرجع حركة صالحة أو null', () {
    final e = fresh();
    final h = e.hint();
    // بداية اللعبة: دائماً يوجد سحب من المخزون على الأقل
    expect(h, isNotNull);
  });

  test('الفوز: ملء الأسس الأربعة يضبط won', () {
    final e = fresh();
    // أسس شبه مكتملة + آس أخير بالمهملات
    for (var i = 0; i < 3; i++) {
      for (var r = 1; r <= 13; r++) {
        e.foundations[i]
            .add(SolCard(r, SolSuit.values[i], faceUp: true));
      }
    }
    for (var r = 1; r <= 12; r++) {
      e.foundations[3].add(SolCard(r, SolSuit.spades, faceUp: true));
    }
    e.waste.add(SolCard(13, SolSuit.spades, faceUp: true));
    expect(e.won, isFalse);
    expect(e.moveToFoundation('w', 0), isTrue);
    expect(e.won, isTrue);
  });

  test('لعبة جديدة تصفّر كل شيء', () {
    final e = fresh();
    e.draw();
    e.draw();
    e.reset();
    expect(e.moves, 0);
    expect(e.won, isFalse);
    expect(e.stock.length, 24);
    expect(e.waste, isEmpty);
    for (var i = 0; i < 7; i++) {
      expect(e.tableau[i].length, i + 1);
    }
  });

  test('الإنهاء التلقائي متاح فقط عندما كل التابلو مكشوف', () {
    final e = fresh();
    expect(e.canAutoComplete, isFalse); // بداية اللعبة: بطاقات مقلوبة
    // اكشف كل التابلو يدوياً
    for (final t in e.tableau) {
      for (final c in t) {
        c.faceUp = true;
      }
    }
    expect(e.canAutoComplete, isTrue);
  });
}
