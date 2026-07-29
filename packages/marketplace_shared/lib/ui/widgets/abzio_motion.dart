import 'dart:math' show sin;
import 'package:flutter/material.dart';

class AbzioMotion {
  const AbzioMotion._();

  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 340);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve emphasisCurve = Curves.easeOutBack;
  static const double tapScale = 0.95;
  static const double cardLift = -4;
}

class AbzioSlideFadePageRoute<T> extends PageRouteBuilder<T> {
  AbzioSlideFadePageRoute({super.settings, required WidgetBuilder builder})
    : super(
        transitionDuration: AbzioMotion.medium,
        reverseTransitionDuration: AbzioMotion.fast,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide =
              Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: AbzioMotion.curve),
              );
          final fade = CurvedAnimation(
            parent: animation,
            curve: AbzioMotion.curve,
          );
          final previousFade = Tween<double>(begin: 1, end: 0.92).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: AbzioMotion.curve,
            ),
          );
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: FadeTransition(opacity: previousFade, child: child),
            ),
          );
        },
      );
}

class AbzioPageTransitionsBuilder extends PageTransitionsBuilder {
  const AbzioPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(0.055, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: AbzioMotion.curve));
    final fade = CurvedAnimation(parent: animation, curve: AbzioMotion.curve);
    final previousFade = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: AbzioMotion.curve),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(opacity: previousFade, child: child),
      ),
    );
  }
}

class AbzioAnimatedCard extends StatefulWidget {
  const AbzioAnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.decoration,
    this.duration = AbzioMotion.medium,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;
  final Duration duration;

  @override
  State<AbzioAnimatedCard> createState() => _AbzioAnimatedCardState();
}

class _AbzioAnimatedCardState extends State<AbzioAnimatedCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final decoration =
        widget.decoration ??
        BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      child: AnimatedContainer(
        duration: widget.duration,
        curve: AbzioMotion.curve,
        padding: widget.padding,
        transform: Matrix4.identity()
          ..translateByDouble(
            0.0,
            _pressed ? AbzioMotion.cardLift : 0.0,
            0.0,
            1.0,
          ),
        decoration: decoration.copyWith(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.09 : 0.05),
              blurRadius: _pressed ? 20 : 14,
              offset: Offset(0, _pressed ? 14 : 8),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class AbzioStaggerItem extends StatelessWidget {
  const AbzioStaggerItem({
    super.key,
    required this.index,
    required this.child,
    this.offsetY = 18,
  });

  final int index;
  final double offsetY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: 240 + (index * 55));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: AbzioMotion.curve,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offsetY),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class AbzioShake extends StatefulWidget {
  const AbzioShake({super.key, required this.child, required this.shakeKey});

  final Widget child;
  final ValueKey<int> shakeKey;

  @override
  State<AbzioShake> createState() => _AbzioShakeState();
}

class _AbzioShakeState extends State<AbzioShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  @override
  void didUpdateWidget(covariant AbzioShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shakeKey != widget.shakeKey) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final offset =
            sin(_controller.value * 6 * 3.141592653589793) *
            (1 - _controller.value) *
            10;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
    );
  }
}

Future<T?> showAbzioBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    transitionAnimationController: BottomSheet.createAnimationController(
      Navigator.of(context),
    )..duration = AbzioMotion.medium,
    builder: (sheetContext) {
      return Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.20)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AbzioMotion.medium,
              curve: AbzioMotion.curve,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: builder(sheetContext),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
