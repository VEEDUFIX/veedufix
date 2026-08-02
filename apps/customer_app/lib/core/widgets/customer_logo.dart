import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomerLogo extends StatelessWidget {
  const CustomerLogo({
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
      'assets/logo.svg',
      height: height,
      width: width,
      fit: BoxFit.contain, // perfectly fitted, not zoomed
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
