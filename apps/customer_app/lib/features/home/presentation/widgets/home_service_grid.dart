import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeServiceCard extends StatelessWidget {
  const HomeServiceCard({super.key, required this.service});

  final CatalogService service;

  String get _subtitle => service.hierarchyLabel.isNotEmpty
      ? service.hierarchyLabel
      : (service.shortDescription ?? 'Professional service');

  IconData _serviceIcon() => Icons.design_services_rounded;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () {
        context.push('/service?id=${service.slug}');
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AbzioTheme.lightBorder,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AbzioTheme.lightMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _serviceIcon(),
                  size: 28,
                  color: AbzioTheme.accentColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              service.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AbzioTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: AbzioTheme.lightTextSecondary,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${service.startingPrice.toInt()}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AbzioTheme.lightTextPrimary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.rating.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AbzioTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
