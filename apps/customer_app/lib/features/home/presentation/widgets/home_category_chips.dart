import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category});

  final CatalogCategory category;

  String get _title => category.name;
  IconData get _icon => Icons.home_repair_service_rounded;
  Color get _accent => const Color(0xFF6366F1);
  String get _subtitle => '${category.subcategories.length} subcategories';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 108,
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
          children: [
            Hero(
              tag: 'category_${category.id}',
              child: Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                  boxShadow: AbzioTheme.eliteShadow,
                ),
                child: Center(
                  child: Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AbzioTheme.cardRadius),
                    ),
                    child: Icon(_icon, color: _accent),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.84),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubcategoryChip extends StatelessWidget {
  const SubcategoryChip({super.key, required this.subcategory});

  final CatalogSubcategory subcategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 168,
      child: TapScale(
        onTap: () => context.push(
          Uri(
            path: '/search',
            queryParameters: {'subcategorySlug': subcategory.slug},
          ).toString(),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            boxShadow: AbzioTheme.eliteShadow,
            border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: Icon(Icons.view_module_rounded,
                        color: colorScheme.primary, size: 20),
                  ),
                  const Spacer(),
                  _SmallBadge(label: '${subcategory.serviceCount} services'),
                ],
              ),
              const Spacer(),
              Text(
                subcategory.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subcategory.description != null &&
                  subcategory.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subcategory.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.secondary,
            ),
      ),
    );
  }
}
