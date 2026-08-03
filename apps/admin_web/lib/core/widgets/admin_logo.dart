import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AdminLogo extends StatelessWidget {
  const AdminLogo({
    super.key,
    this.height = 32,
    this.width,
    this.color,
  });

  final double height;
  final double? width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color;

    return SvgPicture.asset(
      'assets/logo.svg',
      height: height,
      width: width,
      fit: BoxFit.contain,
      colorFilter: tint != null ? ColorFilter.mode(tint, BlendMode.srcIn) : null,
    );
  }
}
