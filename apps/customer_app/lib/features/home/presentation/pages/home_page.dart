import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/liquid_refresh.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';
import '../../../profile/presentation/providers/selected_location_provider.dart';
import '../../../search/presentation/widgets/ai_assistant_sheet.dart';
import '../../domain/entities/home_banner.dart';
import '../widgets/home_category_tile.dart';
import '../widgets/category_services_sheet.dart';
import '../widgets/home_header.dart';
import '../widgets/home_hero_banner.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/home_section_label.dart';
import '../widgets/home_service_card.dart';
import '../providers/home_banners_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _locationCheckFinished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(selectedLocationProvider.notifier)
            .detectCurrentLocationIfMissing()
            .whenComplete(() {
              if (mounted) setState(() => _locationCheckFinished = true);
            });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final selectedLocation = ref.watch(selectedLocationProvider);
    final catalogAsync = ref.watch(homeCatalogProvider);
    final sectionsAsync = ref.watch(homeCatalogSectionsProvider);
    final bannersAsync = ref.watch(homeBannersProvider);

    final categories = catalogAsync.valueOrNull?.categories ?? const [];
    final catalog = catalogAsync.valueOrNull;
    final mostBooked = catalog?.popular.isNotEmpty == true
        ? catalog!.popular
        : catalog?.trending ?? const [];
    final homeSections =
        sectionsAsync.valueOrNull ?? const <HomeCatalogSection>[];
    final isLoading = catalogAsync.isLoading;

    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      body: LiquidRefresh(
        onRefresh: () async {
          ref.invalidate(homeCatalogProvider);
          ref.invalidate(homeCatalogSectionsProvider);
          ref.invalidate(homeBannersProvider);
          try {
            await Future.wait([
              ref.read(homeCatalogProvider.future),
              ref.read(homeCatalogSectionsProvider.future),
              ref.read(homeBannersProvider.future),
            ]);
          } catch (_) {
            // Each section renders its own retry state from the provider error.
          }
        },
        child: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: 20,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  HomeHeader(
                    location: _locationLabel(
                      context,
                      session,
                      selectedLocation,
                      _locationCheckFinished,
                    ),
                  ),
                  const SizedBox(height: 14),
                  HomeSearchBar(
                    onVoiceTap: () => showAiAssistantSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (isLoading || categories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HomeSectionLabel(
                  title: appText(context, 'Services', 'சேவைகள்'),
                  onSeeAll: () => context.push('/search'),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: isLoading
                    ? _buildCategoryShimmerGrid()
                    : _buildCategoryGrid(categories),
              ),
            ],
            if (catalogAsync.hasError &&
                categories.isEmpty &&
                mostBooked.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: _CatalogErrorState(
                  onRetry: () => ref.invalidate(homeCatalogProvider),
                ),
              ),
            if (categories.isNotEmpty || isLoading) const SizedBox(height: 22),
            if (bannersAsync.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildBannerShimmer(),
              )
            else if (bannersAsync.valueOrNull?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HomeHeroBanner(
                  banners: bannersAsync.valueOrNull!,
                  onTap: _openBanner,
                ),
              ),
            if (bannersAsync.valueOrNull?.isNotEmpty == true ||
                bannersAsync.isLoading)
              const SizedBox(height: 26),
            if (isLoading || mostBooked.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HomeSectionLabel(
                  title: appText(
                    context,
                    'Most booked services',
                    'அதிகம் முன்பதிவு செய்யப்பட்டவை',
                  ),
                  onSeeAll: () => context.push('/search'),
                ),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                _buildServiceShimmerRail()
              else
                _buildServiceRail(mostBooked),
              const SizedBox(height: 24),
            ],
            if (sectionsAsync.isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: HomeSectionLabel(
                  title: appText(
                    context,
                    'More to explore',
                    'மேலும் ஆராயுங்கள்',
                  ),
                  onSeeAll: () => context.push('/search'),
                ),
              ),
              const SizedBox(height: 16),
              _buildServiceShimmerRail(),
              const SizedBox(height: 24),
            ] else if (sectionsAsync.hasError) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: _CatalogErrorState(
                  onRetry: () => ref.invalidate(homeCatalogSectionsProvider),
                ),
              ),
            ] else ...[
              for (final section in homeSections) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: HomeSectionLabel(
                    title: section.title,
                    onSeeAll: () => _openHomeSection(section),
                  ),
                ),
                if (section.subtitle?.trim().isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      section.subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AbzioTheme.lightTextSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _buildServiceRail(section.services),
                const SizedBox(height: 24),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _openBanner(HomeBanner banner) {
    final value = banner.destinationValue.trim();
    switch (banner.destinationType) {
      case 'service':
        if (value.isNotEmpty) {
          context.push(
            Uri(path: '/service', queryParameters: {'id': value}).toString(),
          );
        }
        return;
      case 'category':
        if (value.isNotEmpty) {
          context.push(
            Uri(
              path: '/search',
              queryParameters: {'categorySlug': value},
            ).toString(),
          );
        }
        return;
      case 'offer':
        context.push('/offers');
        return;
      case 'search':
        context.push(
          Uri(path: '/search', queryParameters: {'q': value}).toString(),
        );
        return;
      case 'custom_route':
        final uri = Uri.tryParse(value);
        if (uri != null &&
            uri.hasAuthority == false &&
            uri.scheme.isEmpty &&
            uri.path.startsWith('/') &&
            !uri.path.startsWith('//')) {
          context.push(uri.toString());
        }
        return;
    }
  }

  void _openHomeSection(HomeCatalogSection section) {
    final destination = Uri.tryParse(section.seeAllDestination);
    if (destination == null ||
        destination.hasAuthority ||
        destination.scheme.isNotEmpty ||
        !destination.path.startsWith('/') ||
        destination.path.startsWith('//')) {
      context.push('/search');
      return;
    }
    context.push(destination.toString());
  }

  Future<void> _openCategory(CatalogCategory category) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => CategoryServicesSheet(
        category: category,
        onServiceTap: (service) {
          if (!context.mounted) return;
          context.push(
            Uri(
              path: '/service',
              queryParameters: {'id': service.id},
            ).toString(),
          );
        },
      ),
    );
  }

  Widget _buildCategoryShimmerGrid() {
    final scaledCategoryLabelHeight = MediaQuery.textScalerOf(
      context,
    ).scale(12 * 1.18 * 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        mainAxisExtent: 68 + scaledCategoryLabelHeight + 4,
      ),
      itemBuilder: (context, _) => const Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ShimmerPlaceholder(width: 64, height: 64, borderRadius: 14),
          SizedBox(height: 4),
          ShimmerPlaceholder(width: 54, height: 12, borderRadius: 6),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(List<CatalogCategory> categories) {
    final visible = categories.take(7).toList(growable: false);
    final scaledCategoryLabelHeight = MediaQuery.textScalerOf(
      context,
    ).scale(12 * 1.18 * 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        mainAxisExtent: 68 + scaledCategoryLabelHeight + 4,
      ),
      itemBuilder: (context, i) => i < visible.length
          ? HomeCategoryTile(
              category: visible[i],
              onTap: () => _openCategory(visible[i]),
            )
          : _AllServicesTile(onTap: () => context.push('/search')),
    );
  }

  Widget _buildServiceShimmerRail() {
    return SizedBox(
      height: 272,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, _) =>
            const ShimmerPlaceholder(width: 156, height: 272, borderRadius: 18),
      ),
    );
  }

  Widget _buildServiceRail(List<CatalogService> services) {
    return SizedBox(
      height: 272,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 156,
          child: HomeServiceCard(service: services[index]),
        ),
      ),
    );
  }

  Widget _buildBannerShimmer() => LayoutBuilder(
    builder: (context, constraints) {
      final height = constraints.maxWidth < 308
          ? 160.0
          : constraints.maxWidth >= 360
          ? 176.0
          : 172.0;
      return ShimmerPlaceholder(
        width: double.infinity,
        height: height,
        borderRadius: 20,
      );
    },
  );

  String _locationLabel(
    BuildContext context,
    AuthSession? session,
    SelectedLocation? selectedLocation,
    bool locationCheckFinished,
  ) {
    if (selectedLocation != null) {
      return selectedLocation.title;
    }
    final cityId = session?.user.cityId?.trim() ?? '';
    if (cityId.isEmpty || RegExp(r'^[a-z0-9]{16,}$').hasMatch(cityId)) {
      return appText(
        context,
        locationCheckFinished ? 'Choose your area' : 'Finding your area…',
        locationCheckFinished
            ? 'உங்கள் பகுதியைத் தேர்ந்தெடுக்கவும்'
            : 'உங்கள் பகுதியைக் கண்டறிகிறது…',
      );
    }
    return cityId
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}

class _CatalogErrorState extends StatelessWidget {
  const _CatalogErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              appText(
                context,
                'Services could not load. Check your connection and try again.',
                'சேவைகளை ஏற்ற முடியவில்லை. இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
              ),
              style: text.bodySmall?.copyWith(color: colors.onSurface),
            ),
          ),
          IconButton(
            tooltip: 'Try again',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _AllServicesTile extends StatelessWidget {
  const _AllServicesTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: 'Browse all services',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AbzioTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 24,
                color: AbzioTheme.accentColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All services',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AbzioTheme.lightTextPrimary,
                fontWeight: FontWeight.w700,
                height: 1.18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
