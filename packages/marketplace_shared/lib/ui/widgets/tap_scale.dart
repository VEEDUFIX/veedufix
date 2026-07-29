import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'abzio_motion.dart';

class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.scale = AbzioMotion.tapScale,
    this.duration = AbzioMotion.fast,
    this.borderRadius,
    this.haptic = true,
    this.behavior = HitTestBehavior.deferToChild,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final double scale;
  final Duration duration;
  final BorderRadius? borderRadius;
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.haptic) {
      HapticFeedback.lightImpact();
    }
    widget.onTapDown?.call();
    if (!_pressed) {
      setState(() => _pressed = true);
    }
  }

  void _handleTapEnd() {
    widget.onTapUp?.call();
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: widget.duration,
      curve: AbzioMotion.curve,
      child: widget.child,
    );

    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : _handleTapDown,
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              _handleTapEnd();
            },
      onTapCancel: widget.onTap == null ? null : _handleTapEnd,
      child: child,
    );
  }
}
