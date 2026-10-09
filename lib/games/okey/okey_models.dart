import 'package:flutter/material.dart';
import '../../l10n/app_lang.dart';

enum OkeyTileColor {
  red,
  yellow,
  blue,
  black,
}

extension OkeyTileColorExtension on OkeyTileColor {
  Color get color {
    switch (this) {
      case OkeyTileColor.red:
        return const Color(0xFFF03E3E); // أحمر زاهٍ
      case OkeyTileColor.yellow:
        return const Color(0xFFF2A900); // أصفر ذهبي واضح — لا يشبه الأحمر
      case OkeyTileColor.blue:
        return const Color(0xFF2B7FFF); // أزرق سماوي زاهٍ
      case OkeyTileColor.black:
        return const Color(0xFF2D2D33); // أسود فحمي
    }
  }

  /// نسخة مضيئة من اللون — مقروءة على السكنات الداكنة المتحركة
  /// (الأسود يصبح فضّياً أبيض يمثل لون الحجر الأسود)
  Color get brightColor {
    switch (this) {
      case OkeyTileColor.red:
        return const Color(0xFFFF5252); // Bright Coral Red
      case OkeyTileColor.yellow:
        return const Color(0xFFFFC94D); // Bright Gold
      case OkeyTileColor.blue:
        return const Color(0xFF5EB4FF); // Bright Sky Blue
      case OkeyTileColor.black:
        return const Color(0xFFECEFF4); // Silver White (Black tile)
    }
  }

  String get displayName {
    switch (this) {
      case OkeyTileColor.red:
        return 'أحمر'.tr;
      case OkeyTileColor.yellow:
        return 'أصفر'.tr;
      case OkeyTileColor.blue:
        return 'أزرق'.tr;
      case OkeyTileColor.black:
        return 'أسود'.tr;
    }
  }
}

enum OkeyGameState {
  lobby,
  dealing,
  yourTurn,
  opponentTurn,
  drawPhase,
  discardPhase,
  roundEnd,
  win,
}

enum BotDifficulty {
  easy,
  medium,
  hard,
}

/// أسلوب لعب اللاعب في الجولة
/// - normal: عادي (نزول بيرات بنقاط الافتتاح)
/// - konkan: كونكان — لا ينزل على الطاولة، يفوز بـ 10 متسلسلة بلون واحد + بير
/// - full:   فول — يفوز بلون واحد كامل 1→13→1، ومرمياته مخفية ولا تُؤخذ
enum OkeyPlayStyle { normal, konkan, full }

extension OkeyPlayStyleLabel on OkeyPlayStyle {
  String get label {
    switch (this) {
      case OkeyPlayStyle.normal:
        return 'عادي'.tr;
      case OkeyPlayStyle.konkan:
        return 'كونكان'.tr;
      case OkeyPlayStyle.full:
        return 'فول'.tr;
    }
  }
}

enum WinType {
  normal,
  sevenPairs, // Çift
  discardOkey,
}

class OkeyTile {
  final String id;
  final OkeyTileColor color;
  final int value; // 1 to 13 (or 0 for unassigned fake joker)
  final bool isFalseJoker;
  bool isRealOkey; // True if matches (Indicator + 1) in indicator color

  OkeyTile({
    required this.id,
    required this.color,
    required this.value,
    this.isFalseJoker = false,
    this.isRealOkey = false,
  });

  OkeyTile copyWith({bool? isRealOkey}) {
    return OkeyTile(
      id: id,
      color: color,
      value: value,
      isFalseJoker: isFalseJoker,
      isRealOkey: isRealOkey ?? this.isRealOkey,
    );
  }

  /// تسلسل للمزامنة الأونلاين — المعرّف ثابت ('tile_N') فيبقى
  /// مرجعاً فريداً عبر الأجهزة لأحجار الرمي والأخذ
  Map<String, dynamic> toMap() => {
        'i': id,
        'c': color.name,
        'v': value,
        'fj': isFalseJoker,
        'ok': isRealOkey,
      };

  factory OkeyTile.fromMap(Map<String, dynamic> m) => OkeyTile(
        id: m['i'] ?? '',
        color: OkeyTileColor.values.firstWhere((c) => c.name == m['c'],
            orElse: () => OkeyTileColor.black),
        value: m['v'] ?? 0,
        isFalseJoker: m['fj'] ?? false,
        isRealOkey: m['ok'] ?? false,
      );

  /// Whether this tile is identical to another (same color and value)
  bool isIdenticalTo(OkeyTile other) {
    return color == other.color &&
        value == other.value &&
        !isRealOkey &&
        !other.isRealOkey;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkeyTile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => isFalseJoker
      ? 'FakeJoker'
      : '${color.name}-$value${isRealOkey ? "(OKEY)" : ""}';
}

class OkeyPlayer {
  final String id;
  String name; // قابلة للتحديث — الأونلاين يملأ الاسم من وثيقة الغرفة
  String avatarUrl; // قابلة للتحديث عند مزامنة صورة الحساب الحقيقية

  /// اللقب المجهّز ومعرّف إطار الصورة — يُملآن من وثيقة الغرفة
  /// للاعبين البعيدين فيعرض الجميع ألقاب وإطارات بعضهم
  String title = '';
  String frameId = '';
  bool connected = true; // منقطع مؤقتاً = يلعب المضيف عنه
  final int level;
  int rating;
  int chips;

  /// «بشري» = مستخدم هذا الجهاز نفسه (المقعد المحلي 0). اللاعبون
  /// البعيدون في الأونلاين يبقون false — تفرّقهم remoteHumanSeats
  bool isHuman;
  BotDifficulty botDifficulty; // قابلة للتغيير — وضع التدريب يجعلها سهلة
  List<OkeyTile?> rackTiles; // 28 slots (0-13 top tier, 14-27 bottom tier)

  /// هل فتح اللاعب اللعب (أنزل ما مجموعه 101+ نقطة)؟
  bool hasOpened = false;
  int openedPoints = 0;

  OkeyPlayer({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.level,
    required this.rating,
    required this.chips,
    this.isHuman = false,
    this.botDifficulty = BotDifficulty.medium,
    List<OkeyTile?>? rackTiles,
  }) : rackTiles = rackTiles ?? List.filled(28, null);

  /// أسلوب اللعب المعلن (يُقفل بعد الاختيار أو التحويل التلقائي)
  OkeyPlayStyle playStyle = OkeyPlayStyle.normal;

  List<OkeyTile> get activeTiles => rackTiles.whereType<OkeyTile>().toList();

  int get tileCount => activeTiles.length;
}

/// Represents a grouped set or run of tiles for validation
class OkeyGroup {
  final List<OkeyTile> tiles;
  final bool
      isRun; // true = run (sequence same color), false = set (same number distinct colors)
  final int ownerIndex; // اللاعب صاحب النزول (0 = البشري)
  bool pending; // بانتظار اكتمال نقاط الافتتاح (101)

  OkeyGroup({
    required this.tiles,
    required this.isRun,
    this.ownerIndex = 0,
    this.pending = false,
  });

  /// النقاط بالقيمة التي يمثّلها كل حجر — الأوكي يُحتسب بقيمة موضعه
  /// في السلسلة أو بقيمة المجموعة، لا بالرقم المطبوع عليه
  int get points => okeyMeldPoints(tiles, isRun);

  @override
  String toString() =>
      '${isRun ? "Run" : "Set"}: ${tiles.map((t) => t.value).toList()}';
}

/// بداية سلسلة صحيحة موضعياً (قيمة أول خانة)، أو null إن لم تصح.
/// كل حجر غير أوكي يجب أن يساوي البداية + موضعه بالضبط — الأوكي يملأ
/// موضعه فقط (5-أوكي-9 مرفوضة). نفس اللون، ويُسمح بالتفاف 12-13-1
/// كآخر حجر فقط (القيمة 14 تمثّل الواحد بعد 13).
int? okeyRunStart(List<OkeyTile> tiles) {
  if (tiles.length < 3) return null;
  final firstIdx = tiles.indexWhere((t) => !t.isRealOkey);
  if (firstIdx == -1) return 1; // كلّها أوكي
  final color = tiles[firstIdx].color;
  if (tiles.any((t) => !t.isRealOkey && t.color != color)) return null;

  bool fits(int start) {
    if (start < 1) return false;
    final end = start + tiles.length - 1;
    if (end > 14) return false;
    for (var k = 0; k < tiles.length; k++) {
      final t = tiles[k];
      if (t.isRealOkey) continue;
      final e = start + k;
      if (e == 14) {
        if (t.value != 1) return false;
      } else if (t.value != e) {
        return false;
      }
    }
    return true;
  }

  final v0 = tiles[firstIdx].value;
  final s1 = v0 - firstIdx;
  if (fits(s1)) return s1;
  if (v0 == 1) {
    final s2 = 14 - firstIdx;
    if (fits(s2)) return s2;
  }
  return null;
}

/// قيمة المجموعة (Set) من أول حجر غير أوكي، أو 0 إن كانت كلّها أوكي
int okeySetValue(List<OkeyTile> tiles) {
  for (final t in tiles) {
    if (!t.isRealOkey) return t.value;
  }
  return 0;
}

/// مجموع نقاط بير بالقيم التي يمثّلها كل حجر (الأوكي بقيمة موضعه)
int okeyMeldPoints(List<OkeyTile> tiles, bool isRun) {
  if (tiles.isEmpty) return 0;
  if (isRun) {
    final start = okeyRunStart(tiles);
    if (start != null) {
      var sum = 0;
      for (var k = 0; k < tiles.length; k++) {
        final v = start + k;
        sum += v == 14 ? 1 : v;
      }
      return sum;
    }
  } else {
    final v = okeySetValue(tiles);
    if (v != 0) return v * tiles.length;
  }
  return tiles.fold(0, (sum, t) => sum + t.value);
}
