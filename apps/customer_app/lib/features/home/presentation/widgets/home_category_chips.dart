import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeCategoryChip extends StatelessWidget {
  const HomeCategoryChip({super.key, required this.category});

  final CatalogCategory category;

  IconData _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('electric')) {
      return Icons.electrical_services_rounded;
    }
    if (lower.contains('plumb')) {
      return Icons.plumbing_rounded;
    }
    if (lower.contains('clean')) {
      return Icons.cleaning_services_rounded;
    }
    if (lower.contains('ac') || lower.contains('air')) {
      return Icons.ac_unit_rounded;
    }
    if (lower.contains('paint')) {
      return Icons.format_paint_rounded;
    }
    if (lower.contains('carpent')) {
      return Icons.carpenter_rounded;
    }
    return Icons.home_repair_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TapScale(
        onTap: () {
          context.push(
            Uri(
              path: '/search',
              queryParameters: {'categorySlug': category.slug},
            ).toString(),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8E5DE)),
              ),
              child: Center(
                child: Icon(
                  _categoryIcon(category.name),
                  size: 24,
                  color: const Color(0xFFC6A769),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111111),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
