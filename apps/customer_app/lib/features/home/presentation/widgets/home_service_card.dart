import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final imageUrl = _imageUrl;
    final priceLabel = service.startingPrice > 0
        ? 'starts at ₹${service.startingPrice.toInt()}'
        : 'price on request';

    return TapScale(
      onTap: () => context.push('/service?id=${service.slug}'),
      child: Semantics(
        button: true,
        label: '${service.name}, $priceLabel',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AbzioTheme.lightBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 118,
                width: double.infinity,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _PlaceholderImage(service: service),
                      )
                    : _PlaceholderImage(service: service),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_category.isNotEmpty) ...[
                        Text(
                          _category.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AbzioTheme.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AbzioTheme.lightTextPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (service.rating > 0) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AbzioTheme.accentColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              service.rating.toStringAsFixed(1),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AbzioTheme.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (service.startingPrice > 0) ...[
                                  Text(
                                    'Starts at',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AbzioTheme.lightTextSecondary,
                                    ),
                                  ),
                                  Text(
                                    '₹${service.startingPrice.toInt()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AbzioTheme.lightTextPrimary,
                                    ),
                                  ),
                                ] else
                                  Text(
                                    'Get a quote',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AbzioTheme.lightTextPrimary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE1E1E1),
                              ),
                            ),
                            child: Text(
                              'View',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AbzioTheme.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.service});

  final CatalogService service;

  IconData _icon() {
    final n = service.category?.name.toLowerCase() ?? '';
    if (n.contains('electric')) return Icons.electrical_services_rounded;
    if (n.contains('plumb')) return Icons.plumbing_rounded;
    if (n.contains('clean')) return Icons.cleaning_services_rounded;
    if (n.contains('ac') || n.contains('air')) return Icons.ac_unit_rounded;
    if (n.contains('paint')) return Icons.format_paint_rounded;
    if (n.contains('carpent')) return Icons.carpenter_rounded;
    return Icons.home_repair_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AbzioTheme.lightMuted,
      child: Center(
        child: Icon(_icon(), size: 38, color: AbzioTheme.accentColor),
      ),
    );
  }
}
