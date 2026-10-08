import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomeCategoryTile extends StatelessWidget {
  const HomeCategoryTile({
    super.key,
    required this.category,
    required this.onTap,
  });

  final CatalogCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Browse ${category.name}',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AbzioTheme.lightMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: category.iconUrl != null && category.iconUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: category.iconUrl!,
                        width: 42,
                        height: 42,
                        memCacheWidth: 126,
                        memCacheHeight: 126,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Icon(
                          Icons.home_repair_service_rounded,
                          size: 27,
                          color: AbzioTheme.accentColor,
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.home_repair_service_rounded,
                          size: 27,
                          color: AbzioTheme.accentColor,
                        ),
                      )
                    : const Icon(
                        Icons.home_repair_service_rounded,
                        size: 28,
                        color: AbzioTheme.accentColor,
                      ),
              ),
            ),
            const SizedBox(height: 4),
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
