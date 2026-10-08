import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeSectionLabel extends StatelessWidget {
  const HomeSectionLabel({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return VeeduFixSectionHeader(
      title: title,
      subtitle: subtitle,
      actionLabel: onSeeAll == null ? null : 'See all',
      onAction: onSeeAll,
    );
  }
}
