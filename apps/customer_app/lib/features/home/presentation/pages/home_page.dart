import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';
import '../../../../core/widgets/liquid_refresh.dart';
import '../../../search/presentation/widgets/ai_assistant_sheet.dart';

import '../widgets/home_header.dart';
import '../widgets/home_backdrop.dart';
import '../widgets/home_hero_card.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/home_section_label.dart';
import '../widgets/home_category_chips.dart';
import '../widgets/home_service_grid.dart';
import '../widgets/home_professionals_section.dart';
import '../widgets/home_featured_banner.dart';
import '../widgets/home_offers_section.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final firstName = _firstName(session?.user.name);
    final locationLabel = _locationLabel(session);

    final catalogAsync = ref.watch(homeCatalogProvider);
    final professionalsAsync = ref.watch(homeProfessionalsProvider);
    final catalogCategories =
        catalogAsync.valueOrNull?.categories ?? const <CatalogCategory>[];
    final catalogSubcategories = catalogCategories
        .expand((category) => category.subcategories)
        .toList(growable: false);

    final featuredCategoryCount = catalogCategories.length;
    final professionalCount = professionalsAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const HomeBackdrop(),
          LiquidRefresh(
            onRefresh: () async {
              await Future.wait([
                ref.refresh(homeCatalogProvider.future),
                ref.refresh(homeProfessionalsProvider.future),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                HomeHeader(
                  greeting: _greeting(),
                  name: firstName,
                  location: locationLabel,
                ),
                const SizedBox(height: 16),
                HomeHeroCard(
                  name: firstName,
                  featuredCategories: featuredCategoryCount,
                  nearbyProfessionals: professionalCount,
                  location: locationLabel,
                ),
                const SizedBox(height: 18),
                PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Book with confidence',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Compare services, check trusted professionals, and get help instantly if you get stuck.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HomeTrustPill(
                                    icon: Icons.verified_rounded,
                                    label: 'Verified pros',
                                  ),
                                  _HomeTrustPill(
                                    icon: Icons.location_on_rounded,
                                    label: 'Local pricing',
                                  ),
                                  _HomeTrustPill(
                                    icon: Icons.support_agent_rounded,
                                    label: 'Live support',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                HomeSearchBar(
                  hint: 'What service do you need?',
                  onVoiceTap: () => showAiAssistantSheet(context),
                ),
                const SizedBox(height: 18),
                const HomeSectionLabel(
                  title: 'Quick categories',
                  subtitle: 'The most requested services in your area.',
                ),
                const SizedBox(height: 12),
                if (catalogAsync.isLoading)
                  SizedBox(
                    height: 124,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => const Column(
                        children: [
                          ShimmerPlaceholder(
                              width: 72, height: 72, borderRadius: 28),
                          SizedBox(height: 10),
                          ShimmerPlaceholder(
                              width: 60, height: 12, borderRadius: 6),
                        ],
                      ),
                    ),
                  )
                else if (catalogCategories.isNotEmpty)
                  SizedBox(
                    height: 124,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: catalogCategories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) =>
                          CategoryChip(category: catalogCategories[index]),
                    ),
                  )
                else
                  const PremiumEmptyState(
                    icon: Icons.category_rounded,
                    title: 'No featured categories right now',
                    subtitle:
                        'Check back soon for fresh service groups in your area.',
                  ),
                if (catalogSubcategories.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const HomeSectionLabel(
                    title: 'Subcategories',
                    subtitle: 'Jump directly into specific service types.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: catalogSubcategories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => SubcategoryChip(
                          subcategory: catalogSubcategories[index]),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                HomeFeaturedBanner(
                  title: 'Trusted Professionals',
                  subtitle: 'Book verified experts near you.',
                  actionLabel: 'Book Now',
                  onAction: () => context.push('/search'),
                ),
                const SizedBox(height: 20),
                const HomeSectionLabel(
                  title: 'Popular services',
                  subtitle: 'Curated for fast booking and transparent pricing.',
                ),
                const SizedBox(height: 12),
                catalogAsync.isLoading
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 4,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.88,
                        ),
                        itemBuilder: (context, index) => const ShimmerPlaceholder(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 24,
                        ),
                      )
                    : (catalogAsync.valueOrNull?.trending.isNotEmpty ?? false)
                        ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: catalogAsync.valueOrNull!.trending.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.88,
                            ),
                            itemBuilder: (context, index) {
                              final service =
                                  catalogAsync.valueOrNull!.trending[index];
                              return HomeServiceCard(service: service);
                            },
                          )
                        : const PremiumEmptyState(
                            icon: Icons.design_services_rounded,
                            title: 'No featured services right now',
                            subtitle:
                                'Check back soon for fresh recommendations and offers.',
                          ),
                const SizedBox(height: 20),
                const HomeSectionLabel(
                  title: 'Nearby professionals',
                  subtitle: 'Available now and ready to be booked.',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 280,
                  child: professionalsAsync.isLoading
                      ? ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, __) => const ShimmerPlaceholder(
                            width: 240,
                            height: 238,
                            borderRadius: 24,
                          ),
                        )
                      : (professionalsAsync.valueOrNull ??
                                    const <HomeProfessional>[])
                                .isEmpty
                          ? const PremiumEmptyState(
                              icon: Icons.groups_rounded,
                              title: 'No professionals available right now',
                              subtitle:
                                  'We’ll show nearby experts here as soon as they come online.',
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: professionalsAsync.valueOrNull!.length,
                          separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                                return ProfessionalCard(
                                  professional:
                                      professionalsAsync.valueOrNull![index],
                                );
                              },
                            ),
                ),
                const SizedBox(height: 20),
                const HomeSectionLabel(
                  title: 'Top rated professionals',
                  subtitle: 'Highly reviewed specialists with completed jobs.',
                ),
                const SizedBox(height: 12),
                if (professionalsAsync.isLoading)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 2,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const ShimmerPlaceholder(
                      width: double.infinity,
                      height: 80,
                      borderRadius: 24,
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (professionalsAsync.valueOrNull ??
                            const <HomeProfessional>[])
                        .length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final professional = professionalsAsync.valueOrNull![index];
                      return TopRatedCard(professional: professional);
                    },
                  ),
                if (!professionalsAsync.isLoading &&
                    (professionalsAsync.valueOrNull ?? const <HomeProfessional>[]).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: PremiumEmptyState(
                      icon: Icons.star_border_rounded,
                      title: 'No top-rated professionals yet',
                      subtitle:
                          'We’ll highlight highly reviewed experts here once the network grows.',
                    ),
                  ),
                const SizedBox(height: 8),
                const HomeSectionLabel(
                  title: 'Offers',
                  subtitle: 'Savings, coupons, and referral rewards.',
                ),
                const SizedBox(height: 12),
                const HomeOffersSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    }
    if (hour < 17) {
      return 'Good Afternoon,';
    }
    return 'Good Evening,';
  }

  String _firstName(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'there';
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _locationLabel(AuthSession? session) {
    final cityId = session?.user.cityId?.trim() ?? '';
    if (cityId.isNotEmpty) {
      return 'Your selected service area';
    }
    return 'Set your location for local pricing';
  }
}

class _HomeTrustPill extends StatelessWidget {
  const _HomeTrustPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
