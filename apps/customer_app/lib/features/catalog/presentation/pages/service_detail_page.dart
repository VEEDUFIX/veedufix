import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../checkout/presentation/pages/checkout_page.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';
import '../../../favorites/presentation/providers/favorites_providers.dart';
import '../../../home/presentation/widgets/home_service_card.dart';

final serviceReviewsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, slug) async {
      final apiClient = ref.watch(apiClientProvider);
      final payload = await apiClient.get(
        '/catalog/services/${Uri.encodeComponent(slug)}/reviews',
      );
      final reviews = payload['reviews'];
      return reviews is Map<String, dynamic> ? reviews : const {};
    });

final relatedCatalogServicesProvider = FutureProvider.autoDispose
    .family<List<CatalogService>, String>((ref, categorySlug) async {
      if (categorySlug.trim().isEmpty) return const [];
      final payload = await ref
          .watch(apiClientProvider)
          .get(
            '/catalog/search',
            queryParameters: {'categorySlug': categorySlug, 'pageSize': 8},
          );
      final raw = payload['items'] ?? payload['results'] ?? payload['services'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(CatalogService.fromJson)
          .toList(growable: false);
    });

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceDetailProvider(serviceId));
    final colorScheme = Theme.of(context).colorScheme;

    return serviceAsync.when(
      loading: () => _ServiceDetailLoading(colorScheme: colorScheme),
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
                  "Couldn't load this service.",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again.',
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

class _ServiceDetailView extends ConsumerStatefulWidget {
  const _ServiceDetailView({required this.service});

  final CatalogService service;

  @override
  ConsumerState<_ServiceDetailView> createState() => _ServiceDetailViewState();
}

class _ServiceDetailViewState extends ConsumerState<_ServiceDetailView> {
  final PageController _galleryController = PageController();
  int _galleryIndex = 0;
  String? _selectedVariantId;
  final Set<String> _selectedAddonIds = <String>{};

  @override
  void didUpdateWidget(covariant _ServiceDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service.id != widget.service.id) {
      _selectedVariantId = null;
      _selectedAddonIds.clear();
      _galleryIndex = 0;
      if (_galleryController.hasClients) _galleryController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final galleryImages = [
      ...service.images.where((image) => image.isPrimary),
      ...service.images.where((image) => !image.isPrimary),
    ];
    CatalogServiceVariant? selectedVariant;
    for (final variant in service.variants) {
      if (variant.id == _selectedVariantId) {
        selectedVariant = variant;
        break;
      }
    }
    final selectedAddons = service.addons
        .where((addon) => _selectedAddonIds.contains(addon.id))
        .toList(growable: false);
    final variantStartingPrice = service.variants.isEmpty
        ? service.startingPrice
        : service.variants
              .map((variant) => variant.price)
              .reduce((a, b) => a < b ? a : b);
    final basePrice = selectedVariant?.price ?? variantStartingPrice;
    final price =
        basePrice +
        selectedAddons.fold<double>(0, (total, addon) => total + addon.price);
    final canBook = service.variants.isEmpty || selectedVariant != null;
    final isFavorite = ref.watch(isFavoriteProvider(service.id));
    final longDescription = service.description?.trim();
    final shortDescription = service.shortDescription?.trim();
    final description =
        longDescription?.isNotEmpty == true &&
            longDescription != shortDescription
        ? longDescription
        : null;
    final serviceReviews = ref.watch(serviceReviewsProvider(service.slug));
    final relatedServices = ref
        .watch(relatedCatalogServicesProvider(service.category?.slug ?? ''))
        .valueOrNull
        ?.where((related) => related.id != service.id && related.isActive)
        .take(4)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
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
                  child: Semantics(
                    button: true,
                    label: isFavorite
                        ? 'Remove from favorites'
                        : 'Save to favorites',
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: AbzioTheme.eliteShadow,
                      ),
                      child: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorite
                            ? Colors.redAccent
                            : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (galleryImages.isEmpty)
                      _HeroFallback(colorScheme: colorScheme, service: service)
                    else
                      PageView.builder(
                        controller: _galleryController,
                        itemCount: galleryImages.length,
                        onPageChanged: (index) =>
                            setState(() => _galleryIndex = index),
                        itemBuilder: (context, index) => Image.network(
                          galleryImages[index].url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _HeroFallback(
                                colorScheme: colorScheme,
                                service: service,
                              ),
                        ),
                      ),
                    if (galleryImages.length > 1)
                      Positioned(
                        right: 16,
                        bottom: 18,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.54),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_galleryIndex + 1} / ${galleryImages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 124),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                if ((service.category?.name ?? '').trim().isNotEmpty) ...[
                  Text(
                    service.category!.name.toUpperCase(),
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  service.name,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                _ServiceRatingLine(
                  catalogRating: service.rating,
                  catalogReviewCount: service.reviewCount,
                  reviews: serviceReviews,
                ),
                if (shortDescription?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    shortDescription!,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (service.estimatedDurationMins > 0)
                      _MetaChip(
                        icon: Icons.timer_rounded,
                        label: '${service.estimatedDurationMins} mins',
                      ),
                    if (service.gstApplicable)
                      const _MetaChip(
                        icon: Icons.receipt_long_rounded,
                        label: 'GST may apply',
                      ),
                    if (!service.gstApplicable)
                      const _MetaChip(
                        icon: Icons.receipt_long_rounded,
                        label: 'GST not applicable',
                      ),
                    if (service.homeVisit)
                      const _MetaChip(
                        icon: Icons.home_work_rounded,
                        label: 'At your home',
                      ),
                    if (service.emergencyAvailable)
                      const _MetaChip(
                        icon: Icons.flash_on_rounded,
                        label: 'Emergency available',
                      ),
                  ],
                ),
                if (service.variants.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _SectionCard(
                    title: 'Choose an option',
                    icon: Icons.tune_rounded,
                    accent: colorScheme.primary,
                    child: Column(
                      children: service.variants
                          .map((variant) {
                            final selected = variant.id == _selectedVariantId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: selected
                                    ? colorScheme.primaryContainer.withValues(
                                        alpha: 0.55,
                                      )
                                    : colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(
                                    () => _selectedVariantId = variant.id,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selected
                                              ? Icons
                                                    .radio_button_checked_rounded
                                              : Icons.radio_button_off_rounded,
                                          color: selected
                                              ? colorScheme.primary
                                              : colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                variant.name,
                                                style: textTheme.titleSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              if ((variant.description ?? '')
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  variant.description!.trim(),
                                                  style: textTheme.bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                              if ((variant.estimatedDurationMins ??
                                                      0) >
                                                  0) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  '${variant.estimatedDurationMins} mins',
                                                  style: textTheme.labelSmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '₹${_formatRupees(variant.price)}',
                                          style: textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
                if (service.addons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Optional add-ons',
                    icon: Icons.add_circle_outline_rounded,
                    accent: colorScheme.tertiary,
                    child: Column(
                      children: service.addons
                          .map((addon) {
                            final selected = _selectedAddonIds.contains(
                              addon.id,
                            );
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: selected,
                              title: Text(
                                addon.name,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: (addon.description ?? '').trim().isEmpty
                                  ? (addon.estimatedDurationMins ?? 0) > 0
                                        ? Text(
                                            '${addon.estimatedDurationMins} mins',
                                          )
                                        : null
                                  : Text(
                                      '${addon.description!.trim()}${(addon.estimatedDurationMins ?? 0) > 0 ? ' · ${addon.estimatedDurationMins} mins' : ''}',
                                    ),
                              secondary: Text(
                                '+ ₹${_formatRupees(addon.price)}',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onChanged: (checked) => setState(() {
                                if (checked ?? false) {
                                  _selectedAddonIds.add(addon.id);
                                } else {
                                  _selectedAddonIds.remove(addon.id);
                                }
                              }),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                ],
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
                        Flexible(
                          child: Text(
                            'A site visit is needed before final pricing.',
                            style: TextStyle(
                              color: Color(0xFF0D9488),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (description != null) ...[
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'About this service',
                    subtitle: description,
                  ),
                ],
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
                if (service.requirements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Before booking',
                    icon: Icons.info_outline_rounded,
                    accent: colorScheme.tertiary,
                    child: _BulletList(
                      items: service.requirements,
                      positive: true,
                    ),
                  ),
                ],
                if (service.warrantyDays > 0 ||
                    (service.warrantyText ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Service warranty',
                    icon: Icons.verified_user_outlined,
                    accent: colorScheme.primary,
                    child: Text(
                      (service.warrantyText ?? '').trim().isNotEmpty
                          ? service.warrantyText!.trim()
                          : '${service.warrantyDays} days',
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
                if ((service.cancellationPolicy ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Cancellation policy',
                    icon: Icons.info_outline_rounded,
                    accent: colorScheme.tertiary,
                    child: Text(
                      service.cancellationPolicy!.trim(),
                      style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _CustomerReviewsSection(reviews: serviceReviews),
                if (relatedServices?.isNotEmpty == true) ...[
                  const SizedBox(height: 28),
                  Text(
                    'Related services',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 260,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: relatedServices!.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SizedBox(
                        width: 172,
                        child: HomeServiceCard(service: relatedServices[index]),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _BookingBottomBar(
          service: service,
          price: price,
          variantId: selectedVariant?.id,
          addonIds: selectedAddons.map((addon) => addon.id).toList(),
          configurationLabel: [
            if (selectedVariant != null) selectedVariant.name,
            ...selectedAddons.map((addon) => addon.name),
          ].join(' · '),
          canBook: canBook,
        ),
      ),
    );
  }
}

String _formatRupees(double amount) => amount == amount.truncateToDouble()
    ? amount.toStringAsFixed(0)
    : amount.toStringAsFixed(2);

class _ServiceDetailLoading extends StatelessWidget {
  const _ServiceDetailLoading({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: colorScheme.surfaceContainerHighest),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(
              children: [
                const ShimmerPlaceholder(
                  width: 120,
                  height: 12,
                  borderRadius: 6,
                ),
                const SizedBox(height: 12),
                const ShimmerPlaceholder(
                  width: double.infinity,
                  height: 32,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                const ShimmerPlaceholder(
                  width: 160,
                  height: 16,
                  borderRadius: 8,
                ),
                const SizedBox(height: 24),
                const ShimmerPlaceholder(
                  width: double.infinity,
                  height: 86,
                  borderRadius: 18,
                ),
                const SizedBox(height: 24),
                const ShimmerPlaceholder(
                  width: 180,
                  height: 22,
                  borderRadius: 8,
                ),
                const SizedBox(height: 12),
                const ShimmerPlaceholder(
                  width: double.infinity,
                  height: 76,
                  borderRadius: 16,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: const ShimmerPlaceholder(
            width: double.infinity,
            height: 56,
            borderRadius: 16,
          ),
        ),
      ),
    );
  }
}

class _ServiceRatingLine extends StatelessWidget {
  const _ServiceRatingLine({
    required this.catalogRating,
    required this.catalogReviewCount,
    required this.reviews,
  });

  final double catalogRating;
  final int catalogReviewCount;
  final AsyncValue<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) {
    final live = reviews.valueOrNull;
    final rating =
        (live?['averageRating'] as num?)?.toDouble() ?? catalogRating;
    final count = (live?['total'] as num?)?.toInt() ?? catalogReviewCount;
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF59E0B)),
        const SizedBox(width: 4),
        Text(
          count > 0 && rating > 0 ? rating.toStringAsFixed(1) : 'New',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        Text(
          count == 0
              ? 'No reviews yet'
              : '$count ${count == 1 ? 'review' : 'reviews'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CustomerReviewsSection extends StatelessWidget {
  const _CustomerReviewsSection({required this.reviews});

  final AsyncValue<Map<String, dynamic>> reviews;

  @override
  Widget build(BuildContext context) {
    final data = reviews.valueOrNull;
    final total = (data?['total'] as num?)?.toInt() ?? 0;
    final rating = (data?['averageRating'] as num?)?.toDouble() ?? 0;
    final breakdown = data?['breakdown'] is Map
        ? data!['breakdown'] as Map
        : const <dynamic, dynamic>{};
    final items = data?['reviews'] is List
        ? (data!['reviews'] as List).whereType<Map>().toList(growable: false)
        : const <Map>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer reviews',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        if (reviews.isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else if (reviews.hasError)
          Text(
            'Reviews are temporarily unavailable.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else if (total == 0)
          Text(
            'No reviews yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 82,
                child: Column(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
                    Text(
                      '$total reviews',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1]
                      .map((stars) {
                        final rawCount =
                            breakdown[stars] ?? breakdown['$stars'];
                        final starCount = rawCount is num
                            ? rawCount.toDouble()
                            : 0.0;
                        final fraction = total == 0 ? 0.0 : starCount / total;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(width: 18, child: Text('$stars')),
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: fraction.clamp(0, 1).toDouble(),
                                    minHeight: 6,
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    color: const Color(0xFFC2A15E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ],
          ),
          for (final review in items) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${review['rating'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        review['reviewerName']?.toString() ?? 'Customer',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  if ((review['comment']?.toString() ?? '')
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      review['comment'].toString(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

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
  const _BookingBottomBar({
    required this.service,
    required this.price,
    required this.variantId,
    required this.addonIds,
    required this.configurationLabel,
    required this.canBook,
  });

  final CatalogService service;
  final double price;
  final String? variantId;
  final List<String> addonIds;
  final String configurationLabel;
  final bool canBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isAvailable = service.isActive && service.bookingEnabled;
    final pricePrefix = service.priceType == 'FROM' ? 'From ₹' : '₹';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.variants.isNotEmpty && variantId != null
                      ? 'Selected option'
                      : service.priceType == 'FIXED'
                      ? 'Service price'
                      : service.priceType == 'QUOTE'
                      ? 'Pricing'
                      : 'Starting from',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  !canBook
                      ? 'Choose an option'
                      : price > 0 && service.priceType != 'QUOTE'
                      ? (variantId != null ? '₹' : pricePrefix) +
                            _formatRupees(price)
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
          Flexible(
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: FilledButton(
                onPressed: isAvailable && canBook
                    ? () {
                        final session = ref
                            .read(authControllerProvider)
                            .valueOrNull;
                        context.push(
                          '/checkout',
                          extra: {
                            'cityId': session?.user.cityId ?? '',
                            'items': [
                              CheckoutItem(
                                serviceId: service.id,
                                serviceName: service.name,
                                price: price,
                                variantId: variantId,
                                addonIds: addonIds,
                                configurationLabel: configurationLabel,
                              ),
                            ],
                          },
                        );
                      }
                    : null,
                child: Text(
                  !canBook
                      ? 'Choose an option'
                      : isAvailable
                      ? service.ctaLabel.trim().isEmpty
                            ? 'Book service'
                            : service.ctaLabel.trim()
                      : 'Currently unavailable',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
