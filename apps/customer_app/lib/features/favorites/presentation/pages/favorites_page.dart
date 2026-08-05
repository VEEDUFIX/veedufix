import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../providers/favorites_providers.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Favorites', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
      ),
      body: favoritesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text(
                  'Could not load favorites',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        data: (favorites) => favorites.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 48,
                        color: cs.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No favorites yet',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart icon on any service\nto save it here',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ListView.builder(
                  key: ValueKey(favorites.length),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  itemCount: favorites.length,
                  itemBuilder: (context, index) {
                    final serviceKey = favorites.elementAt(index);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FavoriteServiceCard(
                        serviceKey: serviceKey,
                        onRemove: () async {
                          await ref.read(favoritesProvider.notifier).toggleFavorite(serviceKey);
                        },
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _FavoriteServiceCard extends ConsumerWidget {
  const _FavoriteServiceCard({
    required this.serviceKey,
    required this.onRemove,
  });

  final String serviceKey;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final serviceAsync = ref.watch(serviceDetailProvider(serviceKey));

    return Dismissible(
      key: ValueKey(serviceKey),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        await onRemove();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from favorites'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(serviceKey);
              },
            ),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        ),
        child: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.shade200),
      ),
      child: TapScale(
        onTap: () => context.push('/service?id=$serviceKey'),
        child: serviceAsync.when(
          loading: () => Container(
            height: 132,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              boxShadow: AbzioTheme.eliteShadow,
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              boxShadow: AbzioTheme.eliteShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  ),
                  child: Icon(Icons.broken_image_rounded, color: cs.error),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Service unavailable', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        serviceKey,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.favorite_rounded, color: Colors.redAccent.shade200, size: 22),
              ],
            ),
          ),
          data: (service) {
            final price = service.pricingRules.isNotEmpty ? service.pricingRules.first.price : service.startingPrice;
            final heroImage = service.images.isNotEmpty
                ? service.images.firstWhere(
                    (item) => item.isPrimary,
                    orElse: () => service.images.first,
                  )
                : null;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: cs.primaryContainer.withValues(alpha: 0.25),
                      child: heroImage != null && heroImage.url.trim().isNotEmpty
                          ? Image.network(
                              heroImage.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.design_services_rounded, color: cs.primary),
                            )
                          : Icon(Icons.design_services_rounded, color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.subcategory?.name ?? service.category?.name ?? 'Saved service',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniPill(label: '₹${price.toInt()}'),
                            _MiniPill(label: service.rating > 0 ? service.rating.toStringAsFixed(1) : 'New'),
                            _MiniPill(label: '${service.estimatedDurationMins} mins'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.favorite_rounded, color: Colors.redAccent.shade200, size: 22),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
