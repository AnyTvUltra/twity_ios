import 'package:flutter/foundation.dart';

class OkeyTableSkin {
  final String id;
  final String name;
  final String assetPath;

  const OkeyTableSkin({
    required this.id,
    required this.name,
    required this.assetPath,
  });
}

class OkeyRackSkin {
  final String id;
  final String name;
  final String assetPath;

  const OkeyRackSkin({
    required this.id,
    required this.name,
    required this.assetPath,
  });
}

class OkeyTileSkin {
  final String id;
  final String name;
  final String assetPath;

  const OkeyTileSkin({
    required this.id,
    required this.name,
    required this.assetPath,
  });
}

class OkeySkinCatalog {
  static const tables = [
    OkeyTableSkin(
      id: 'emerald',
      name: 'Emerald',
      assetPath: 'assets/models/okey/table_emerald.glb',
    ),
    OkeyTableSkin(
      id: 'midnight',
      name: 'Midnight',
      assetPath: 'assets/models/okey/table_midnight.glb',
    ),
  ];

  static const racks = [
    OkeyRackSkin(
      id: 'royalGold',
      name: 'Royal Gold',
      assetPath: 'assets/models/okey/rack_royal_gold.glb',
    ),
    OkeyRackSkin(
      id: 'obsidian',
      name: 'Obsidian',
      assetPath: 'assets/models/okey/rack_obsidian.glb',
    ),
  ];

  static const tiles = [
    OkeyTileSkin(
      id: 'crystal',
      name: 'Crystal',
      assetPath: 'assets/models/okey/tile_crystal.glb',
    ),
    OkeyTileSkin(
      id: 'ivory',
      name: 'Ivory',
      assetPath: 'assets/models/okey/tile_ivory.glb',
    ),
  ];
}

class OkeySkinController extends ChangeNotifier {
  static final OkeySkinController _instance = OkeySkinController._();

  factory OkeySkinController() => _instance;

  OkeySkinController._();

  OkeyTableSkin table = OkeySkinCatalog.tables.first;
  OkeyRackSkin rack = OkeySkinCatalog.racks.first;
  OkeyTileSkin tile = OkeySkinCatalog.tiles.first;

  void selectTable(OkeyTableSkin value) {
    if (table.id == value.id) return;
    table = value;
    notifyListeners();
  }

  void selectRack(OkeyRackSkin value) {
    if (rack.id == value.id) return;
    rack = value;
    notifyListeners();
  }

  void selectTile(OkeyTileSkin value) {
    if (tile.id == value.id) return;
    tile = value;
    notifyListeners();
  }
}
