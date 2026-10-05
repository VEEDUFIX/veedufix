import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeCategoryTile extends StatelessWidget {
  const HomeCategoryTile({super.key, required this.category});

  final CatalogCategory category;

  IconData _icon() {
    final n = category.name.toLowerCase();
    if (n.contains('electric')) return Icons.electrical_services_rounded;
    if (n.contains('plumb')) return Icons.plumbing_rounded;
    if (n.contains('clean')) return Icons.cleaning_services_rounded;
    if (n.contains('ac') || n.contains('air')) return Icons.ac_unit_rounded;
    if (n.contains('paint')) return Icons.format_paint_rounded;
    if (n.contains('carpent')) return Icons.carpenter_rounded;
    if (n.contains('pest')) return Icons.bug_report_rounded;
    if (n.contains('appliance') || n.contains('repair')) {
      return Icons.build_rounded;
    }
    return Icons.home_repair_service_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: () => context.push(
        Uri(
          path: '/search',
          queryParameters: {'categorySlug': category.slug},
        ).toString(),
      ),
      child: Semantics(
        button: true,
        label: 'Browse ${category.name}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AbzioTheme.lightMuted,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child:
                      category.iconUrl != null && category.iconUrl!.isNotEmpty
                      ? Image.network(
                          category.iconUrl!,
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            _icon(),
                            size: 28,
                            color: AbzioTheme.accentColor,
                          ),
                        )
                      : Icon(_icon(), size: 30, color: AbzioTheme.accentColor),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              category.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AbzioTheme.lightTextPrimary,
                height: 1.18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
