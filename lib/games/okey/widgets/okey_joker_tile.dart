import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../okey_models.dart';
import 'okey_tile_widget.dart';

/// الجوكر في رفّك يظهر مقلوباً (أبيض) — لمسة واحدة تقلبه ليظهر وجهه
/// لمدة ثانيتين ثم ينقلب ظهراً من جديد
class OkeyJokerTile extends StatefulWidget {
  final OkeyTile tile;
  final double width;
  final double height;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onTap;

  const OkeyJokerTile({
    super.key,
    required this.tile,
    required this.width,
    required this.height,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onTap,
  });

  @override
  State<OkeyJokerTile> createState() => _OkeyJokerTileState();
}

class _OkeyJokerTileState extends State<OkeyJokerTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _flip.dispose();
    super.dispose();
  }

  void _reveal() {
    widget.onTap?.call();
    _hideTimer?.cancel();
    _flip.forward();
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _flip.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _reveal,
      child: AnimatedBuilder(
        animation: _flip,
        builder: (context, _) {
          final v = _flip.value;
          final showFace = v >= 0.5;
          // دوران حول المحور الرأسي: 0 → 90° (الظهر) ثم 90° → 0 (الوجه)
          final angle = (showFace ? 1 - v : v) * math.pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateY(angle),
            child: showFace
                ? OkeyTileWidget(
                    tile: widget.tile,
                    isSelected: widget.isSelected,
                    isHighlighted: widget.isHighlighted,
                    width: widget.width,
                    height: widget.height,
                  )
                : _back(),
          );
        },
      ),
    );
  }

  /// ظهر الجوكر: حجر أبيض ناصع بإطار ذهبي خفيف
  Widget _back() {
    final w = widget.width, h = widget.height;
    final selected = widget.isSelected;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F1EA), Color(0xFFE2DCCD)],
        ),
        borderRadius: BorderRadius.circular(w * 0.12),
        border: Border.all(
          color: selected ? const Color(0xFFFFD54F) : const Color(0xFFD9CFB8),
          width: selected ? 2 : 0.9,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 3,
              offset: const Offset(0, 2)),
          if (widget.isHighlighted)
            BoxShadow(
                color: const Color(0xFF4ADE80).withOpacity(0.5),
                blurRadius: 8),
        ],
      ),
      child: Center(
        child: Icon(Icons.auto_awesome_rounded,
            size: w * 0.42, color: const Color(0xFFE8D9A8)),
      ),
    );
  }
}
