import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeServiceCard extends StatelessWidget {
  const HomeServiceCard({super.key, required this.service});

  final CatalogService service;

  String get _subtitle => service.hierarchyLabel.isNotEmpty
      ? service.hierarchyLabel
      : (service.shortDescription ?? 'Professional service');

  @override
  Widget build(BuildContext context) {
    return VeeduFixServiceCard(
      compact: true,
      title: service.name,
      subtitle: _subtitle,
      rating: service.rating > 0 ? service.rating.toStringAsFixed(1) : null,
      priceLabel: service.startingPrice > 0
          ? '₹${service.startingPrice.toInt()}'
          : 'Get a quote',
      onTap: () => context.push('/service?id=${service.slug}'),
    );
  }
}
