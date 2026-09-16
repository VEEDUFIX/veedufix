import 'package:flutter/material.dart';

/// A widget that applies a press-scale animation to its child.
/// Identical in spirit to Abzio's TapScale widget.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 100),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    _ctrl.animateTo(1.0);
  }

  void _onTapUp(TapUpDetails _) {
    _ctrl.animateTo(0.0);
    widget.onTap?.call();
  }

  void _onTapCancel() => _ctrl.animateTo(0.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}
