import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerWidget extends StatelessWidget {
  const ShimmerWidget({
    super.key,
    this.width,
    this.height,
    this.radius = 16,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1350),
    this.child,
  });

  final double? width;
  final double? height;
  final double radius;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final resolvedBaseColor =
        baseColor ??
        (brightness == Brightness.dark
            ? const Color(0xFF222222)
            : const Color(0xFFECE8E1));
    final resolvedHighlightColor =
        highlightColor ??
        (brightness == Brightness.dark
            ? const Color(0xFF303030)
            : const Color(0xFFF7F5F1));

    final content =
        child ??
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: resolvedBaseColor,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return Shimmer.fromColors(
      baseColor: resolvedBaseColor,
      highlightColor: resolvedHighlightColor,
      period: period,
      child: content,
    );
  }
}
