import 'package:flutter/material.dart';

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
        return const Color(0xFFDC2626); // Ruby Red
      case OkeyTileColor.yellow:
        return const Color(0xFFD97706); // Golden Amber
      case OkeyTileColor.blue:
        return const Color(0xFF2563EB); // Royal Blue
      case OkeyTileColor.black:
        return const Color(0xFF1F2937); // Charcoal Black
    }
  }

  String get displayName {
    switch (this) {
      case OkeyTileColor.red:
        return 'أحمر';
      case OkeyTileColor.yellow:
        return 'أصفر';
      case OkeyTileColor.blue:
        return 'أزرق';
      case OkeyTileColor.black:
        return 'أسود';
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

  /// Whether this tile is identical to another (same color and value)
  bool isIdenticalTo(OkeyTile other) {
    return color == other.color && value == other.value && !isRealOkey && !other.isRealOkey;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OkeyTile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      isFalseJoker ? 'FakeJoker' : '${color.name}-$value${isRealOkey ? "(OKEY)" : ""}';
}

class OkeyPlayer {
  final String id;
  final String name;
  final String avatarUrl;
  final int level;
  int rating;
  int chips;
  final bool isHuman;
  final BotDifficulty botDifficulty;
  List<OkeyTile?> rackTiles; // 28 slots (0-13 top tier, 14-27 bottom tier)

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

  List<OkeyTile> get activeTiles => rackTiles.whereType<OkeyTile>().toList();

  int get tileCount => activeTiles.length;
}

/// Represents a grouped set or run of tiles for validation
class OkeyGroup {
  final List<OkeyTile> tiles;
  final bool isRun; // true = run (sequence same color), false = set (same number distinct colors)

  OkeyGroup({required this.tiles, required this.isRun});

  @override
  String toString() => '${isRun ? "Run" : "Set"}: ${tiles.map((t) => t.value).toList()}';
}
