import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));
    final colorScheme = Theme.of(context).colorScheme;

    return serviceAsync.when(
      loading: () => Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Unable to load service',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(serviceDetailProvider(serviceId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (service) => _ServiceDetailView(service: service),
    );
  }
}

class _ServiceDetailView extends ConsumerWidget {
  const _ServiceDetailView({required this.service});

  final CatalogService service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final heroImage = service.images.isNotEmpty
        ? service.images.firstWhere(
            (item) => item.isPrimary,
            orElse: () => service.images.first,
          )
        : null;
    final price = service.startingPrice;
    final description = service.description?.trim().isNotEmpty == true
        ? service.description!.trim()
        : service.shortDescription?.trim().isNotEmpty == true
        ? service.shortDescription!.trim()
        : 'Professional service with verified delivery standards and transparent pricing.';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: colorScheme.surface,
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
                  onTap: () => ref
                      .read(favoritesProvider.notifier)
                      .toggleFavorite(service.id),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: AbzioTheme.eliteShadow,
                    ),
                    child: Icon(
                      ref.watch(isFavoriteProvider(service.id))
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: ref.watch(isFavoriteProvider(service.id))
                          ? Colors.redAccent
                          : colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (heroImage != null && heroImage.url.trim().isNotEmpty)
                    Image.network(
                      heroImage.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => _HeroFallback(
                        colorScheme: colorScheme,
                        service: service,
                      ),
                    )
                  else
                    _HeroFallback(colorScheme: colorScheme, service: service),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          colorScheme.surface.withValues(alpha: 0.1),
                          colorScheme.surface,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                if (service.hierarchyLabel.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.category_rounded,
                        label: service.category?.name ?? 'Category',
                      ),
                      if (service.subcategory != null)
                        _MetaChip(
                          icon: Icons.subdirectory_arrow_right_rounded,
                          label: service.subcategory!.name,
                        ),
                      if (service.code.trim().isNotEmpty)
                        _MetaChip(
                          icon: Icons.badge_rounded,
                          label: service.code,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  service.name,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.rating > 0
                          ? service.rating.toStringAsFixed(1)
                          : 'New',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${service.reviewCount} reviews)',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaChip(
                      icon: Icons.payments_rounded,
                      label: price > 0
                          ? 'From ₹${_formatRupees(price)}'
                          : service.requiresSiteVisit
                          ? 'Price after assessment'
                          : 'Price on request',
                    ),
                    if (service.estimatedDurationMins > 0)
                      _MetaChip(
                        icon: Icons.timer_rounded,
                        label: '${service.estimatedDurationMins} mins',
                      ),
                    _MetaChip(
                      icon: Icons.receipt_long_rounded,
                      label: service.gstApplicable ? 'GST may apply' : 'No GST',
                    ),
                    _MetaChip(
                      icon: Icons.home_work_rounded,
                      label: service.homeVisit
                          ? 'At your home'
                          : 'Service location',
                    ),
                    if (service.emergencyAvailable)
                      const _MetaChip(
                        icon: Icons.flash_on_rounded,
                        label: 'Emergency available',
                      ),
                    if (service.warrantyDays > 0)
                      _MetaChip(
                        icon: Icons.shield_rounded,
                        label: '${service.warrantyDays} day warranty',
                      ),
                  ],
                ),
                if (service.requiresSiteVisit)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.home_repair_service_rounded,
                          size: 16,
                          color: Color(0xFF0D9488),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'A site visit is needed before final pricing.',
                          style: TextStyle(
                            color: Color(0xFF0D9488),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'About this service',
                  subtitle: description,
                ),
                const SizedBox(height: 20),
                if (service.inclusions.isNotEmpty)
                  _SectionCard(
                    title: 'What is included',
                    icon: Icons.check_circle_rounded,
                    accent: const Color(0xFF10B981),
                    child: _BulletList(
                      items: service.inclusions,
                      positive: true,
                    ),
                  ),
                if (service.inclusions.isNotEmpty &&
                    service.exclusions.isNotEmpty)
                  const SizedBox(height: 16),
                if (service.exclusions.isNotEmpty)
                  _SectionCard(
                    title: 'What is not included',
                    icon: Icons.cancel_rounded,
                    accent: colorScheme.error,
                    child: _BulletList(
                      items: service.exclusions,
                      positive: false,
                    ),
                  ),
                if (service.inclusions.isNotEmpty ||
                    service.exclusions.isNotEmpty)
                  const SizedBox(height: 16),
                if (service.requiredSkills.isNotEmpty ||
                    service.requiredTools.isNotEmpty ||
                    service.requiredDocuments.isNotEmpty)
                  _SectionCard(
                    title: 'Preparation checklist',
                    icon: Icons.fact_check_rounded,
                    accent: colorScheme.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (service.requiredSkills.isNotEmpty) ...[
                          Text(
                            'Skills',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: service.requiredSkills
                                .map(
                                  (item) => _MetaChip(
                                    icon: Icons.workspace_premium_rounded,
                                    label: item.name,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (service.requiredTools.isNotEmpty) ...[
                          Text(
                            'Tools',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: service.requiredTools
                                .map(
                                  (item) => _MetaChip(
                                    icon: Icons.handyman_rounded,
                                    label: item.name,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (service.requiredDocuments.isNotEmpty) ...[
                          Text(
                            'Documents',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: service.requiredDocuments
                                .map(
                                  (item) => _MetaChip(
                                    icon: Icons.description_rounded,
                                    label: item.name,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Cancellation policy',
                  icon: Icons.info_outline_rounded,
                  accent: colorScheme.tertiary,
                  child: Text(
                    service.cancellationPolicy?.trim().isNotEmpty == true
                        ? service.cancellationPolicy!.trim()
                        : 'You can cancel from My Bookings. If a payment was captured, refund eligibility is reviewed separately; cancellation does not issue a refund automatically.',
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _BookingBottomBar(service: service, price: price),
      ),
    );
  }
}

String _formatRupees(double amount) => amount == amount.truncateToDouble()
    ? amount.toStringAsFixed(0)
    : amount.toStringAsFixed(2);

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.colorScheme, required this.service});

  final ColorScheme colorScheme;
  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.design_services_rounded,
          size: 108,
          color: colorScheme.primary.withValues(alpha: 0.32),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, required this.positive});

  final List<String> items;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    positive
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_rounded,
                    size: 18,
                    color: positive ? colorScheme.primary : colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BookingBottomBar extends ConsumerWidget {
  const _BookingBottomBar({required this.service, required this.price});

  final CatalogService service;
  final double price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price > 0 ? 'Starting from' : 'Pricing',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price > 0
                      ? '₹${_formatRupees(price)}'
                      : service.requiresSiteVisit
                      ? 'After assessment'
                      : 'On request',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: service.isActive
                  ? () {
                      ref.read(cartProvider.notifier).addService(service);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Added to cart'),
                          action: SnackBarAction(
                            label: 'VIEW CART',
                            onPressed: () => context.push('/cart'),
                          ),
                        ),
                      );
                    }
                  : null,
              child: Text(service.isActive ? 'Add to Cart' : 'Unavailable'),
            ),
          ),
        ],
      ),
    );
  }
}
