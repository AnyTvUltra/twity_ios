import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../okey_engine.dart';
import '../okey_models.dart';
import '../okey_skins.dart';

class Okey3DScene extends StatefulWidget {
  final OkeyEngine engine;

  const Okey3DScene({super.key, required this.engine});

  @override
  State<Okey3DScene> createState() => _Okey3DSceneState();
}

class _Okey3DSceneState extends State<Okey3DScene> {
  final Scene _scene = Scene();
  final OkeySkinController _skins = OkeySkinController();
  final Map<String, Node> _humanTiles = {};
  final Map<Node, int> _nodeSlots = {};
  final Map<String, double> _tileRotations = {};
  final List<List<Node>> _opponentTiles = [[], [], []];
  late final PerspectiveCamera _camera;
  Node? _tilePrototype;
  bool _ready = false;
  String? _error;
  int _loadGeneration = 0;
  Size _viewSize = Size.zero;
  int? _pressedSlot;
  int? _dragSlot;
  Offset _dragDelta = Offset.zero;
  vm.Vector3? _dragStartPosition;

  @override
  void initState() {
    super.initState();
    _camera = PerspectiveCamera(
      position: vm.Vector3(0, -11.8, 10.6),
      target: vm.Vector3(0, 0, 0.15),
      up: vm.Vector3(0, 0, 1),
      fovRadiansY: 39 * math.pi / 180,
      fovNear: 0.1,
      fovFar: 80,
    );
    _scene.camera = _camera;
    widget.engine.addListener(_syncFromEngine);
    _skins.addListener(_reloadForSkin);
    _loadScene();
  }

  @override
  void didUpdateWidget(covariant Okey3DScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine == widget.engine) return;
    oldWidget.engine.removeListener(_syncFromEngine);
    widget.engine.addListener(_syncFromEngine);
    _syncFromEngine();
  }

  @override
  void dispose() {
    widget.engine.removeListener(_syncFromEngine);
    _skins.removeListener(_reloadForSkin);
    _scene.removeAll();
    super.dispose();
  }

  void _reloadForSkin() {
    _loadScene();
  }

  Future<void> _loadScene() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _ready = false;
        _error = null;
      });
    }
    try {
      await Scene.initializeStaticResources();
      final assets = await Future.wait([
        Node.fromGlbAsset(_skins.table.assetPath),
        Node.fromGlbAsset(_skins.rack.assetPath),
        Node.fromGlbAsset(_skins.tile.assetPath),
        Node.fromGlbAsset('assets/models/okey/decoration_okey.glb'),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      _scene.removeAll();
      _humanTiles.clear();
      _nodeSlots.clear();
      for (final list in _opponentTiles) {
        list.clear();
      }

      final table = Node(name: 'table_${_skins.table.id}')..add(assets[0]);
      _markStatic(table);
      _scene.add(table);

      final rackPrototype = assets[1];
      _scene.add(_rackNode(
          'rack_human', rackPrototype, vm.Vector3(0, -2.72, 0.34), 0));
      _scene.add(_rackNode(
          'rack_top', rackPrototype, vm.Vector3(0, 2.72, 0.34), math.pi));
      _scene.add(_rackNode('rack_left', rackPrototype,
          vm.Vector3(-4.72, 0, 0.34), -math.pi / 2));
      _scene.add(_rackNode(
          'rack_right', rackPrototype, vm.Vector3(4.72, 0, 0.34), math.pi / 2));

      final decoration = Node(name: 'okey_decoration')
        ..position = vm.Vector3(0, 0.25, 0.22)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2)
        ..scale = vm.Vector3.all(0.72)
        ..add(assets[3]);
      decoration.raycastable = false;
      _scene.add(decoration);

      _tilePrototype = assets[2];
      _createOpponentTiles();
      _ready = true;
      _syncFromEngine();
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _ready = false;
      });
    }
  }

  Node _rackNode(
      String name, Node prototype, vm.Vector3 position, double rotation) {
    final node = Node(name: name)
      ..position = position
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), rotation)
      ..add(prototype.clone());
    _markStatic(node);
    return node;
  }

  void _markStatic(Node node) {
    node.shadowStatic = true;
    for (final child in node.children) {
      _markStatic(child);
    }
  }

  void _createOpponentTiles() {
    final prototype = _tilePrototype;
    if (prototype == null) return;
    for (int opponent = 0; opponent < 3; opponent++) {
      for (int index = 0; index < 14; index++) {
        final node = Node(name: 'opponent_${opponent}_tile_$index')
          ..scale = vm.Vector3.all(0.68)
          ..add(prototype.clone());
        _positionOpponentTile(node, opponent, index);
        _scene.add(node);
        _opponentTiles[opponent].add(node);
      }
    }
  }

  void _positionOpponentTile(Node node, int opponent, int index) {
    final offset = (index - 6.5) * 0.31;
    if (opponent == 0) {
      node.position = vm.Vector3(-offset, 2.66, 0.92);
      node.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi);
    } else if (opponent == 1) {
      node.position = vm.Vector3(-4.68, -offset * 0.78, 0.92);
      node.rotation =
          vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -math.pi / 2);
    } else {
      node.position = vm.Vector3(4.68, offset * 0.78, 0.92);
      node.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), math.pi / 2);
    }
  }

  vm.Vector3 _slotPosition(int slot) {
    final row = slot ~/ 14;
    final column = slot % 14;
    return vm.Vector3(
      (column - 6.5) * 0.385,
      row == 0 ? -2.46 : -2.88,
      row == 0 ? 0.91 : 0.70,
    );
  }

  void _syncFromEngine() {
    if (!_ready || _tilePrototype == null) return;
    final rack = widget.engine.players[0].rackTiles;
    final activeIds = <String>{};
    _nodeSlots.clear();
    for (int slot = 0; slot < rack.length; slot++) {
      final tile = rack[slot];
      if (tile == null) continue;
      activeIds.add(tile.id);
      final node = _humanTiles.putIfAbsent(tile.id, () {
        final created = Node(name: 'human_tile_${tile.id}')
          ..scale = vm.Vector3.all(0.78)
          ..add(_tilePrototype!.clone());
        _scene.add(created);
        return created;
      });
      node.visible = true;
      node.position = _slotPosition(slot);
      node.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 0, 1),
        _tileRotations[tile.id] ?? 0,
      );
      _setHighlight(
        node,
        widget.engine.selectedTileIndex == slot
            ? vm.Vector4(1, 0.76, 0.18, 1)
            : widget.engine.getHighlightedSlotIndices().contains(slot)
                ? vm.Vector4(0.15, 1, 0.55, 0.82)
                : null,
      );
      _nodeSlots[node] = slot;
    }
    for (final entry in _humanTiles.entries) {
      if (!activeIds.contains(entry.key)) entry.value.visible = false;
    }
    final opponents = [
      widget.engine.players[2],
      widget.engine.players[3],
      widget.engine.players[1]
    ];
    for (int opponent = 0; opponent < 3; opponent++) {
      for (int index = 0; index < _opponentTiles[opponent].length; index++) {
        _opponentTiles[opponent][index].visible =
            index < opponents[opponent].tileCount;
      }
    }
    if (mounted) setState(() {});
  }

  void _setHighlight(Node node, vm.Vector4? color) {
    node.highlightColor = color;
    for (final child in node.children) {
      _setHighlight(child, color);
    }
  }

  int? _slotFromNode(Node? node) {
    Node? current = node;
    while (current != null) {
      final slot = _nodeSlots[current];
      if (slot != null) return slot;
      current = current.parent;
    }
    return null;
  }

  int? _pickSlot(Offset position) {
    if (_viewSize.isEmpty) return null;
    final ray = _camera.screenPointToRay(position, _viewSize);
    return _slotFromNode(_scene.raycast(ray)?.node);
  }

  void _onTapDown(TapDownDetails details) {
    _pressedSlot = _pickSlot(details.localPosition);
  }

  void _onTap() {
    final slot = _pressedSlot;
    _pressedSlot = null;
    if (slot != null) widget.engine.selectTile(slot);
  }

  void _onPanStart(DragStartDetails details) {
    final slot = _pickSlot(details.localPosition);
    if (slot == null) return;
    _dragSlot = slot;
    _dragDelta = Offset.zero;
    final tile = widget.engine.players[0].rackTiles[slot];
    _dragStartPosition = tile == null ? null : _humanTiles[tile.id]?.position;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final slot = _dragSlot;
    final start = _dragStartPosition;
    if (slot == null || start == null) return;
    final tile = widget.engine.players[0].rackTiles[slot];
    if (tile == null) return;
    final node = _humanTiles[tile.id];
    if (node == null) return;
    _dragDelta += details.delta;
    node.position = vm.Vector3(
      start.x + _dragDelta.dx * 0.013,
      start.y + _dragDelta.dy * 0.004,
      start.z + 0.34 - _dragDelta.dy * 0.003,
    );
    node.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 0, 1),
      (_tileRotations[tile.id] ?? 0) + _dragDelta.dx * 0.0025,
    );
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    final fromSlot = _dragSlot;
    if (fromSlot == null) return;
    final spacing = (_viewSize.width * 0.55 / 14).clamp(18.0, 48.0);
    final columnShift = (_dragDelta.dx / spacing).round();
    final sourceRow = fromSlot ~/ 14;
    final targetRow =
        _dragDelta.dy.abs() > 24 ? (_dragDelta.dy < 0 ? 0 : 1) : sourceRow;
    final targetColumn = ((fromSlot % 14) + columnShift).clamp(0, 13);
    widget.engine.insertTile(fromSlot, targetRow * 14 + targetColumn);
    _dragSlot = null;
    _dragStartPosition = null;
    _dragDelta = Offset.zero;
    _syncFromEngine();
  }

  void _rotateTile(int slot) {
    final tile = widget.engine.players[0].rackTiles[slot];
    if (tile == null) return;
    _tileRotations[tile.id] = (_tileRotations[tile.id] ?? 0) + math.pi;
    _syncFromEngine();
  }

  List<Widget> _tileLabels(Size size) {
    final labels = <Widget>[];
    for (int slot = 0;
        slot < widget.engine.players[0].rackTiles.length;
        slot++) {
      final tile = widget.engine.players[0].rackTiles[slot];
      final node = tile == null ? null : _humanTiles[tile.id];
      if (tile == null || node == null || !node.visible) continue;
      final position = _camera.worldToScreen(
        node.position + vm.Vector3(0, -0.12, 0.12),
        size,
      );
      if (position == null) continue;
      labels.add(Positioned(
        left: position.dx - 12,
        top: position.dy - 17,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: _tileRotations[tile.id] ?? 0,
            child: SizedBox(
              width: 24,
              height: 30,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tile.isFalseJoker ? '★' : '${tile.value}',
                    style: TextStyle(
                      color: tile.isFalseJoker
                          ? const Color(0xFFD99116)
                          : tile.color.color,
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: tile.color.color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          '3D scene error\n$_error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      );
    }
    if (!_ready) {
      return const Center(
        child:
            CircularProgressIndicator(color: Color(0xFFFFD76A), strokeWidth: 2),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _viewSize = size;
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: _onTapDown,
              onTap: _onTap,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onDoubleTapDown: (details) {
                final slot = _pickSlot(details.localPosition);
                if (slot != null) _rotateTile(slot);
              },
              child: SceneView(
                _scene,
                camera: _camera,
                pixelRatio:
                    MediaQuery.devicePixelRatioOf(context).clamp(1.0, 1.5),
                warmUp: true,
              ),
            ),
            ..._tileLabels(size),
          ],
        );
      },
    );
  }
}
