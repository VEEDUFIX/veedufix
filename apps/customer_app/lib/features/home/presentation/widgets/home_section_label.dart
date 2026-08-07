import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionHeader(
      title: title,
      subtitle: subtitle,
    );
  }
}
