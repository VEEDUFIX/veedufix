import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));

    return serviceAsync.when(
      loading: () => Scaffold(
        backgroundColor: colorScheme.surface,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(width: double.infinity, height: 300, color: colorScheme.surfaceContainerHighest),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 200, height: 28, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 12),
                  Container(width: 100, height: 20, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 24),
                  Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 8),
                  Container(width: double.infinity, height: 16, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 8),
                  Container(width: 250, height: 16, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8))),
                ],
              ),
            ),
          ],
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(child: Text('Error: $err')),
      ),
      data: (service) {
        final serviceName = service.name;
        final servicePrice = service.startingPrice;
        final serviceRating = service.rating;
        final reviewCount = service.reviewCount;
        final description = service.description ?? service.shortDescription ?? 'Professional service.';
        
        // Use live inclusions/exclusions from the backend, with sensible defaults
        final inclusions = service.inclusions.isNotEmpty
            ? service.inclusions
            : const [
                'Professional equipment and cleaning supplies included',
                'Trained and background-verified professional',
                '30-day service warranty',
              ];
        final exclusions = service.exclusions.isNotEmpty
            ? service.exclusions
            : const [
                'Any civil or structural work',
                'Replacement of spare parts',
              ];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: colorScheme.surface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'service_$serviceId',
                    child: Container(
                      color: colorScheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.design_services_rounded, // Use matching icon logic if needed
                          size: 100,
                          color: colorScheme.primary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                  // Gradient fade to surface at bottom
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          colorScheme.surface,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: TapScale(
                onTap: () => context.pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: AbzioTheme.eliteShadow,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TapScale(
                  onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(serviceId),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: AbzioTheme.eliteShadow,
                    ),
                    child: Icon(
                      ref.watch(isFavoriteProvider(serviceId))
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: ref.watch(isFavoriteProvider(serviceId))
                          ? Colors.redAccent
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '₹${servicePrice.toInt()}',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Rating row
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 18, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                      '$serviceRating  ·  $reviewCount reviews',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Metadata chips row
                const Row(
                  children: [
                    _InfoChip(
                        icon: Icons.timer_rounded, label: '~2 hrs'),
                    SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.verified_rounded, label: 'Verified Pro'),
                    SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.shield_rounded, label: '30 day warranty'),
                  ],
                ),
                const SizedBox(height: 32),
                // Description
                const _SectionHeader(title: 'About this service'),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                // Inclusions
                const _SectionHeader(title: 'What\'s included'),
                const SizedBox(height: 16),
                ...inclusions
                    .map((e) => _CheckItem(title: e, isIncluded: true)),
                const SizedBox(height: 32),
                // Exclusions
                const _SectionHeader(title: 'Not included'),
                const SizedBox(height: 16),
                ...exclusions
                    .map((e) => _CheckItem(title: e, isIncluded: false)),
                const SizedBox(height: 32),
                // Cancellation
                const _SectionHeader(title: 'Cancellation policy'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Free cancellation before 2 hours of your scheduled slot. Late cancellations may incur a charge.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomSheet: _BookingBottomBar(
        price: servicePrice,
        service: service,
      ),
    );
      },
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.title, required this.isIncluded});
  final String title;
  final bool isIncluded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isIncluded ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 20,
            color: isIncluded ? cs.primary : cs.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBottomBar extends ConsumerWidget {
  const _BookingBottomBar({required this.service, required this.price});
  final CatalogService service;
  final double price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.paddingOf(context).bottom + 16),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starting from',
                    style: tt.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                Text(
                  '₹${price.toInt()}',
                  style: tt.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          TapScale(
            onTap: () {
              ref.read(cartProvider.notifier).addService(service);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Added to Cart!'),
                  action: SnackBarAction(
                    label: 'VIEW',
                    onPressed: () => context.push('/cart'),
                  ),
                ),
              );
            },
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  'Add to Cart',
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
