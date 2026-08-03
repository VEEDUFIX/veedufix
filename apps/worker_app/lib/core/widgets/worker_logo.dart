import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WorkerLogo extends StatelessWidget {
  const WorkerLogo({
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
    return SvgPicture.asset(
      'assets/partner_logo.svg',
      height: height,
      width: width,
      fit: BoxFit.contain,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
