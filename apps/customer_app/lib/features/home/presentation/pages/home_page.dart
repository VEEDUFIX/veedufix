import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final professionals = professionalsAsync.valueOrNull ?? const [];
    final isLoading = catalogAsync.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF7),
      body: LiquidRefresh(
        onRefresh: () async {
          ref.invalidate(homeCatalogProvider);
          ref.invalidate(homeProfessionalsProvider);
          await Future.wait([
            ref.read(homeCatalogProvider.future),
            ref.read(homeProfessionalsProvider.future),
          ]);
        },
        child: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: 20,
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1597E8),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  HomeHeader(
                    location: _locationLabel(session, selectedLocation),
                    bright: true,
                  ),
                  const SizedBox(height: 18),
                  HomeSearchBar(
                    hint: 'Search for AC service',
                    onVoiceTap: () => showAiAssistantSheet(context),
                  ),
                  const SizedBox(height: 18),
                  HomeHeroBanner(
                    onTap: () => context.push('/search'),
                    services: featured,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            if (isLoading || categories.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(
                  title: 'What do you need?',
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _BigOfferCard(onTap: () => context.push('/search')),
            ),
            const SizedBox(height: 28),
            if (isLoading || trending.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(
                  title: 'Most booked',
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
            if (!isLoading && trending.length > 2) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(
                  title: 'Cleaning essentials',
                  subtitle: 'Monthly care for busy homes',
                  onSeeAll: () => context.push('/search'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 242,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: trending.skip(2).take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => SizedBox(
                    width: 168,
                    child: HomeServiceCard(
                      service: trending.skip(2).toList()[i],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
            ],
            if (!professionalsAsync.isLoading && professionals.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: HomeSectionLabel(title: 'Nearby professionals'),
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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.76,
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
  }

  Widget _buildCategoryGrid(List<CatalogCategory> categories) {
    final visible = categories.take(8).toList(growable: false);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, i) => HomeCategoryTile(category: visible[i]),
    );
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
    AuthSession? session,
    SelectedLocation? selectedLocation,
  ) {
    if (selectedLocation != null) {
      return selectedLocation.title;
    }
    final cityId = session?.user.cityId?.trim() ?? '';
    return cityId.isNotEmpty ? cityId.replaceAll('_', ' ') : 'Set your location';
  }
}

class _BigOfferCard extends StatelessWidget {
  const _BigOfferCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        height: 222,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFD59B61),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              bottom: -34,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: 28,
              bottom: 24,
              child: Icon(
                Icons.chair_rounded,
                size: 92,
                color: Colors.white.withValues(alpha: 0.62),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transform your space',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF101010),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deep cleaning, repairs and painting by verified pros.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF352211),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Explore services',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
