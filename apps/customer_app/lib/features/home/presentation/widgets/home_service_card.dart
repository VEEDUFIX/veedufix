import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeServiceCard extends StatelessWidget {
  const HomeServiceCard({super.key, required this.service});

  final CatalogService service;

  String? get _imageUrl {
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

    return TapScale(
      onTap: () => context.push('/service?id=${service.slug}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEDED), width: 1),
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
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: const Color(0xFF7A7A7A),
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      service.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
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
                            color: Color(0xFF111111),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            service.rating.toStringAsFixed(2),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF444444),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Starts at',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF777777),
                              ),
                            ),
                            Text(
                              '₹${service.startingPrice.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111111),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE1E1E1)),
                          ),
                          child: Text(
                            'Add',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF6D3FEA),
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
      color: const Color(0xFFF3F0E9),
      child: Center(
        child: Icon(_icon(), size: 38, color: const Color(0xFFC6A769)),
      ),
    );
  }
}
