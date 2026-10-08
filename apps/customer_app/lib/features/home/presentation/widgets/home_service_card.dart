import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeServiceCard extends StatelessWidget {
  const HomeServiceCard({super.key, required this.service});

  final CatalogService service;

  String? get _imageUrl {
    for (final image in service.images) {
      if (image.isPrimary) return image.url;
    }
    if (service.images.isNotEmpty) return service.images.first.url;
    if (service.iconUrl != null && service.iconUrl!.isNotEmpty) {
      return service.iconUrl;
    }
    return null;
  }

  String get _category {
    final cat = service.category?.name ?? '';
    return cat.isNotEmpty ? cat : service.hierarchyLabel;
  }

  @override
  Widget build(BuildContext context) {
    return VeeduFixServiceCard(
      title: service.name,
      imageUrl: _imageUrl,
      category: _category,
      rating: service.rating > 0 ? service.rating.toStringAsFixed(1) : null,
      priceLabel: service.startingPrice > 0
          ? 'Starts at ₹${service.startingPrice.toInt()}'
          : 'Get a quote',
      placeholderIcon: _serviceIcon(),
      onTap: () => context.push('/service?id=${service.slug}'),
    );
  }

  IconData _serviceIcon() {
    final name = service.category?.name.toLowerCase() ?? '';
    if (name.contains('electric')) return Icons.electrical_services_rounded;
    if (name.contains('plumb')) return Icons.plumbing_rounded;
    if (name.contains('clean')) return Icons.cleaning_services_rounded;
    if (name.contains('ac') || name.contains('air')) {
      return Icons.ac_unit_rounded;
    }
    if (name.contains('paint')) return Icons.format_paint_rounded;
    if (name.contains('carpent')) return Icons.carpenter_rounded;
    return Icons.home_repair_service_rounded;
  }
}
