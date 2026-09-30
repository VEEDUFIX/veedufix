import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/liquid_refresh.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';
import '../../../profile/presentation/providers/selected_location_provider.dart';
import '../../../search/presentation/widgets/ai_assistant_sheet.dart';
import '../widgets/home_category_tile.dart';
import '../widgets/home_header.dart';
import '../widgets/home_hero_banner.dart';
import '../widgets/home_professionals_section.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/home_section_label.dart';
import '../widgets/home_service_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final selectedLocation = ref.watch(selectedLocationProvider);
    final catalogAsync = ref.watch(homeCatalogProvider);
    final professionalsAsync = ref.watch(homeProfessionalsProvider);

    final categories = catalogAsync.valueOrNull?.categories ?? const [];
    final featured = catalogAsync.valueOrNull?.featured ?? const [];
    final trending = catalogAsync.valueOrNull?.trending ?? const [];
    final moreServices = trending.skip(8).take(8).toList(growable: false);
    final professionals = professionalsAsync.valueOrNull ?? const [];
    final isLoading = catalogAsync.isLoading;

    return Scaffold(
      backgroundColor: AbzioTheme.lightBackground,
      body: LiquidRefresh(
        onRefresh: () async {
          ref.invalidate(homeCatalogProvider);
          ref.invalidate(homeProfessionalsProvider);
          try {
            await Future.wait([
              ref.read(homeCatalogProvider.future),
              ref.read(homeProfessionalsProvider.future),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(
                children: [
                  HomeHeader(
                    location: _locationLabel(
                      context,
                      session,
                      selectedLocation,
                    ),
                  ),
                  const SizedBox(height: 16),
                  HomeSearchBar(
                    hint: appText(
                      context,
                      'Search for AC service',
                      'ஏசி சேவையைத் தேடுங்கள்',
                    ),
                    onVoiceTap: () => showAiAssistantSheet(context),
                  ),
                  const SizedBox(height: 20),
                  HomeHeroBanner(
                    onTap: (service) {
                      if (service == null) {
                        context.push('/search');
                        return;
                      }
                      context.push(
                        Uri(
                          path: '/service',
                          queryParameters: {'id': service.id},
                        ).toString(),
                      );
                    },
                    services: featured,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (catalogAsync.hasError && categories.isEmpty && trending.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _CatalogErrorState(
                  onRetry: () => ref.invalidate(homeCatalogProvider),
                ),
              ),
            if (isLoading || categories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(
                  title: appText(
                    context,
                    'What do you need?',
                    'உங்களுக்கு என்ன சேவை தேவை?',
                  ),
                  onSeeAll: () => context.push('/search'),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isLoading
                    ? _buildCategoryShimmerGrid()
                    : _buildCategoryGrid(categories),
              ),
              const SizedBox(height: 28),
            ],
            if (isLoading || trending.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(
                  title: appText(
                    context,
                    'Most booked',
                    'அதிகம் முன்பதிவு செய்யப்பட்டவை',
                  ),
                  onSeeAll: () => context.push('/search'),
                ),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildServiceShimmerRail(),
                )
              else
                SizedBox(
                  height: 242,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: trending.take(8).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) => SizedBox(
                      width: 168,
                      child: HomeServiceCard(service: trending[i]),
                    ),
                  ),
                ),
              const SizedBox(height: 28),
            ],
            if (!isLoading && moreServices.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(
                  title: appText(
                    context,
                    'More to explore',
                    'மேலும் சேவைகள்',
                  ),
                  subtitle: appText(
                    context,
                    'Find the right help for your home',
                    'உங்கள் வீட்டிற்கான சரியான சேவையைக் கண்டறியுங்கள்',
                  ),
                  onSeeAll: () => context.push('/search'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 242,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: moreServices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => SizedBox(
                    width: 168,
                    child: HomeServiceCard(service: moreServices[i]),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
            if (!professionalsAsync.isLoading && professionals.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(
                  title: appText(
                    context,
                    'Available professionals',
                    'அருகிலுள்ள நிபுணர்கள்',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 224,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: professionals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) =>
                      ProfessionalCard(professional: professionals[i]),
                ),
              ),
              const SizedBox(height: 28),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryShimmerGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _categoryGridMetrics(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 8,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            mainAxisExtent: metrics.itemHeight,
          ),
          itemBuilder: (context, _) => const Column(
            children: [
              ShimmerPlaceholder(
                width: double.infinity,
                height: 70,
                borderRadius: 18,
              ),
              SizedBox(height: 9),
              ShimmerPlaceholder(width: 58, height: 12, borderRadius: 6),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryGrid(List<CatalogCategory> categories) {
    final visible = categories.take(8).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _categoryGridMetrics(constraints.maxWidth);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: metrics.columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            mainAxisExtent: metrics.itemHeight,
          ),
          itemBuilder: (context, i) => HomeCategoryTile(category: visible[i]),
        );
      },
    );
  }

  ({int columns, double itemHeight}) _categoryGridMetrics(double width) {
    final columns = width < 350 ? 3 : 4;
    final tileWidth = (width - 14 * (columns - 1)) / columns;
    return (columns: columns, itemHeight: tileWidth + 40);
  }

  Widget _buildServiceShimmerRail() {
    return const Row(
      children: [
        Expanded(
          child: ShimmerPlaceholder(
            width: double.infinity,
            height: 232,
            borderRadius: 18,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: ShimmerPlaceholder(
            width: double.infinity,
            height: 232,
            borderRadius: 18,
          ),
        ),
      ],
    );
  }

  String _locationLabel(
    BuildContext context,
    AuthSession? session,
    SelectedLocation? selectedLocation,
  ) {
    if (selectedLocation != null) {
      return selectedLocation.title;
    }
    final cityId = session?.user.cityId?.trim() ?? '';
    if (cityId.isEmpty || RegExp(r'^[a-z0-9]{16,}$').hasMatch(cityId)) {
      return appText(
        context,
        'Set your location',
        'உங்கள் இருப்பிடத்தை அமைக்கவும்',
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
