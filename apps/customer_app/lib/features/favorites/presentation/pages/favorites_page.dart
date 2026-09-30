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
        title: Text(
          'Favorites',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
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
        error: (error, stack) => PremiumRetryState(
          title: 'Could not load favorites',
          subtitle: 'Check your connection and try again.',
          onRetry: () => ref.invalidate(favoritesProvider),
          onRefresh: () async {
            await ref.refresh(favoritesProvider.future).then<void>((_) {});
          },
        ),
        data: (favorites) => favorites.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save services you may want to book later.',
                        textAlign: TextAlign.center,
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => context.go('/app'),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Explore services'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: favorites.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Saved services',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${favorites.length} ${favorites.length == 1 ? 'service' : 'services'}',
                            style: tt.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final serviceKey = favorites.elementAt(index - 1);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FavoriteServiceCard(
                      serviceKey: serviceKey,
                      onRemove: () => _toggleFavorite(context, ref, serviceKey),
                    ),
                  );
                },
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
  final Future<bool> Function() onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final serviceAsync = ref.watch(serviceDetailProvider(serviceKey));

    return Dismissible(
      key: ValueKey(serviceKey),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        final removed = await onRemove();
        if (!context.mounted) return;
        if (!removed) {
          ref.invalidate(favoritesProvider);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from favorites'),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () {
                _toggleFavorite(context, ref, serviceKey);
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
        child: Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent.shade200,
        ),
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
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: AbzioTheme.eliteShadow,
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: AbzioTheme.eliteShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(
                      AbzioTheme.buttonRadius,
                    ),
                  ),
                  child: Icon(Icons.broken_image_rounded, color: cs.error),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service unavailable',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        serviceKey,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            ref.invalidate(serviceDetailProvider(serviceKey)),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.favorite_rounded,
                  color: Colors.redAccent.shade200,
                  size: 22,
                ),
              ],
            ),
          ),
          data: (service) {
            final price = service.pricingRules.isNotEmpty
                ? service.pricingRules.first.price
                : service.startingPrice;
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
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AbzioTheme.buttonRadius,
                    ),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: cs.primaryContainer.withValues(alpha: 0.25),
                      child:
                          heroImage != null && heroImage.url.trim().isNotEmpty
                          ? Image.network(
                              heroImage.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.design_services_rounded,
                                color: cs.primary,
                              ),
                            )
                          : Icon(
                              Icons.design_services_rounded,
                              color: cs.primary,
                            ),
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
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service.subcategory?.name ??
                              service.category?.name ??
                              'Saved service',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniPill(label: '₹${price.round()}'),
                            _MiniPill(
                              label: service.rating > 0
                                  ? service.rating.toStringAsFixed(1)
                                  : 'New',
                            ),
                            _MiniPill(
                              label: '${service.estimatedDurationMins} mins',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Remove from favorites',
                    onPressed: () async {
                      final removed = await onRemove();
                      if (!context.mounted) return;
                      if (!removed) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Removed from favorites'),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () {
                              _toggleFavorite(context, ref, serviceKey);
                            },
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.favorite_rounded,
                      color: Colors.redAccent.shade200,
                      size: 22,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<bool> _toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  String serviceId,
) async {
  try {
    await ref.read(favoritesProvider.notifier).toggleFavorite(serviceId);
    return true;
  } catch (_) {
    ref.invalidate(favoritesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update favorites. Try again.')),
      );
    }
    return false;
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
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
