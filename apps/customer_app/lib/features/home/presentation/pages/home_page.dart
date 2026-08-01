import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';
import '../../../../core/widgets/metallic_card.dart';
import '../../../../core/widgets/liquid_refresh.dart';
import '../../../search/presentation/widgets/ai_assistant_sheet.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userName = ref.watch(authControllerProvider.select((s) => s.valueOrNull?.user.name)) ?? 'Abdul';
    final firstName = userName.trim().split(RegExp(r'\s+')).first;
    final colorScheme = Theme.of(context).colorScheme;

    final catalogAsync = ref.watch(homeCatalogProvider);
    final professionalsAsync = ref.watch(homeProfessionalsProvider);
    final catalogCategories = catalogAsync.valueOrNull?.categories ?? const <CatalogCategory>[];
    final catalogSubcategories = catalogCategories.expand((category) => category.subcategories).toList(growable: false);

    return Scaffold(
      body: LiquidRefresh(
        onRefresh: () async {
          await Future.wait([
            ref.refresh(homeCatalogProvider.future),
            ref.refresh(homeProfessionalsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _HomeHeader(
              greeting: _greeting(),
              name: firstName,
              location: 'Anna Nagar, Chennai',
            ),
            const SizedBox(height: 18),
            _SearchBar(
              hint: 'What service do you need?',
              onVoiceTap: () => showAiAssistantSheet(context),
            ),
            const SizedBox(height: 18),
            const _SectionLabel(
              title: 'Quick categories',
              subtitle: 'The most requested services in your area.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: catalogAsync.isLoading
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => const Column(
                        children: [
                          ShimmerPlaceholder(width: 72, height: 72, borderRadius: 28),
                          SizedBox(height: 10),
                          ShimmerPlaceholder(width: 60, height: 12, borderRadius: 6),
                        ],
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: catalogCategories.isNotEmpty ? catalogCategories.length : _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final hasData = catalogCategories.isNotEmpty;
                        final category = hasData
                            ? catalogCategories[index]
                            : _categories[index];
                        return _CategoryChip(
                          category: category,
                        );
                      },
                    ),
            ),
            if (catalogSubcategories.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionLabel(
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
                  itemBuilder: (context, index) => _SubcategoryChip(subcategory: catalogSubcategories[index]),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _FeaturedBanner(
              title: 'Trusted Professionals',
              subtitle: 'Book verified experts near you.',
              actionLabel: 'Book Now',
              onAction: () {},
            ),
            const SizedBox(height: 20),
            const _SectionLabel(
              title: 'Popular services',
              subtitle: 'Curated for fast booking and transparent pricing.',
            ),
            const SizedBox(height: 12),
            catalogAsync.isLoading
                ? GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (catalogAsync.valueOrNull?.trending.length ?? 0) > 0
                        ? catalogAsync.valueOrNull!.trending.length
                        : _services.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.88,
                    ),
                    itemBuilder: (context, index) {
                      final hasData = (catalogAsync.valueOrNull?.trending.length ?? 0) > 0;
                      final service = hasData
                          ? catalogAsync.valueOrNull!.trending[index]
                          : _services[index];
                      return _ServiceCard(
                        service: service,
                        // If it's a real API model, map it. The widget expects a Map mock currently.
                      );
                    },
                  ),
            const SizedBox(height: 20),
            const _SectionLabel(
              title: 'Nearby professionals',
              subtitle: 'Available now and ready to be booked.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 238,
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
                  : (professionalsAsync.valueOrNull ?? const <HomeProfessional>[]).isEmpty
                      ? const Center(
                          child: Text(
                            'No professionals available right now.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: professionalsAsync.valueOrNull!.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return _ProfessionalCard(
                              professional: professionalsAsync.valueOrNull![index],
                            );
                          },
                        ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel(
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
                itemCount: (professionalsAsync.valueOrNull ?? const <HomeProfessional>[]).length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final professional = professionalsAsync.valueOrNull![index];
                  return _TopRatedCard(professional: professional);
                },
              ),
            const SizedBox(height: 8),
            const _SectionLabel(
              title: 'Offers',
              subtitle: 'Savings, coupons, and referral rewards.',
            ),
            const SizedBox(height: 12),
            MetallicCard(
              title: 'Festival offers',
              subtitle: 'Up to 25% off on essential home services this week.',
              icon: Icons.local_activity_rounded,
              baseColor: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const MetallicCard(
              title: 'Referral rewards',
              subtitle: 'Invite friends and earn credits on your next booking.',
              icon: Icons.card_giftcard_rounded,
              baseColor: Color(0xFF10B981),
            ),
          ],
        ),
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
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.name,
    required this.location,
  });

  final String greeting;
  final String name;
  final String location;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$name 👋',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 12),
              _LocationChip(location: location),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            boxShadow: AbzioTheme.eliteShadow,
          ),
          child: IconButton(
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              location,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.hint,
    required this.onVoiceTap,
  });

  final String hint;
  final VoidCallback onVoiceTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: () => context.push('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hint,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onVoiceTap,
            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              ),
              child: Icon(Icons.mic_none_rounded, color: colorScheme.primary),
            ),
          ),
        ],
      ),
    ));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionHeader(
      title: title,
      subtitle: subtitle,
    );
  }
}

class _Category {
  const _Category({
    required this.title,
    required this.icon,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color accent;
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final Object category;

  String get _title => category is CatalogCategory ? (category as CatalogCategory).name : (category as _Category).title;
  IconData get _icon => category is CatalogCategory ? Icons.home_repair_service_rounded : (category as _Category).icon;
  Color get _accent => category is CatalogCategory ? const Color(0xFF6366F1) : (category as _Category).accent;
  String get _subtitle {
    if (category is CatalogCategory) {
      final catalogCategory = category as CatalogCategory;
      return '${catalogCategory.subcategories.length} subcategories';
    }
    return 'Popular pick';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 108,
      child: TapScale(
        onTap: () {},
        child: Column(
          children: [
            Hero(
              tag: 'category_${category is CatalogCategory ? (category as CatalogCategory).id : (category as _Category).title}',
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
                      borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
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

class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({required this.subcategory});

  final CatalogSubcategory subcategory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 168,
      child: TapScale(
        onTap: () => context.push('/search'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
            boxShadow: AbzioTheme.eliteShadow,
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.45)),
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
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: Icon(Icons.view_module_rounded, color: colorScheme.primary, size: 20),
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
              if (subcategory.description != null && subcategory.description!.trim().isNotEmpty) ...[
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

class _Service {
  const _Service({
    required this.title,
    required this.price,
    required this.rating,
    required this.jobs,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String price;
  final double rating;
  final String jobs;
  final IconData icon;
  final Color accent;
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final Object service;

  String get _title => service is CatalogService ? (service as CatalogService).name : (service as _Service).title;
  String get _price => service is CatalogService ? 'Rs ${(service as CatalogService).startingPrice.toInt()}' : (service as _Service).price;
  double get _rating => service is CatalogService ? (service as CatalogService).rating : (service as _Service).rating;
  String get _jobs => service is CatalogService ? '${(service as CatalogService).reviewCount} reviews' : (service as _Service).jobs;
  IconData get _icon => service is CatalogService ? Icons.design_services_rounded : (service as _Service).icon;
  Color get _accent => service is CatalogService ? const Color(0xFF6366F1) : (service as _Service).accent;
  String get _subtitle => service is CatalogService
      ? ((service as CatalogService).hierarchyLabel.isNotEmpty
          ? (service as CatalogService).hierarchyLabel
          : ((service as CatalogService).shortDescription ?? 'Premium service'))
      : (service as _Service).jobs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumCard(
      onTap: () {
        if (service is CatalogService) {
          context.push('/service?id=${(service as CatalogService).slug}');
        } else {
          context.push('/service');
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'service_${service is CatalogService ? (service as CatalogService).slug : (service as _Service).title}',
              child: Container(
                height: 96,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accent.withValues(alpha: 0.22),
                      _accent.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                ),
                child: Icon(_icon, size: 38, color: _accent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _price,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text(
                    _rating.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _jobs,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.professional});

  final HomeProfessional professional;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: PremiumCard(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      professional.accent.withValues(alpha: 0.22),
                      professional.accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person_rounded,
                      color: professional.accent,
                      size: 30,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      professional.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (professional.verified)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.verified_rounded, size: 18, color: Color(0xFF10B981)),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                professional.role,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              _CompactMetric(icon: Icons.workspace_premium_rounded, label: professional.experience),
              const SizedBox(height: 8),
              _CompactMetric(
                icon: Icons.star_rounded,
                label: '${professional.rating.toStringAsFixed(1)} · ${professional.distance}',
              ),
              const SizedBox(height: 8),
              _CompactMetric(
                icon: Icons.payments_rounded,
                label: professional.price,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopRatedCard extends StatelessWidget {
  const _TopRatedCard({required this.professional});

  final HomeProfessional professional;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumCard(
      onTap: () {},
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: professional.accent.withValues(alpha: 0.14),
          child: Text(
            professional.name.substring(0, 1),
            style: TextStyle(
              color: professional.accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                professional.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (professional.verified)
              Icon(Icons.verified_rounded, size: 18, color: colorScheme.secondary),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${professional.role} · ${professional.experience}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              professional.price,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  professional.rating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumCard(
      onTap: onAction,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.16),
              colorScheme.primaryContainer.withValues(alpha: 0.45),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: colorScheme.onSurface.withValues(alpha: 0.76),
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onAction,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 124,
              width: 124,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.surface.withValues(alpha: 0.58),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 88,
                    width: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary.withValues(alpha: 0.16),
                    ),
                  ),
                  Icon(
                    Icons.verified_user_rounded,
                    size: 52,
                    color: colorScheme.primary,
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



const List<_Category> _categories = <_Category>[
  _Category(title: 'Electrician', icon: Icons.electrical_services_rounded, accent: Color(0xFFC2A15E)),
  _Category(title: 'Plumber', icon: Icons.plumbing_rounded, accent: Color(0xFF10B981)),
  _Category(title: 'Cleaning', icon: Icons.cleaning_services_rounded, accent: Color(0xFF60A5FA)),
  _Category(title: 'Carpenter', icon: Icons.handyman_rounded, accent: Color(0xFFF59E0B)),
  _Category(title: 'AC Repair', icon: Icons.ac_unit_rounded, accent: Color(0xFF38BDF8)),
  _Category(title: 'Painter', icon: Icons.format_paint_rounded, accent: Color(0xFFEF4444)),
  _Category(title: 'Laptop Repair', icon: Icons.computer_rounded, accent: Color(0xFF8B5CF6)),
  _Category(title: 'Mobile Repair', icon: Icons.phone_android_rounded, accent: Color(0xFF14B8A6)),
  _Category(title: 'View All', icon: Icons.apps_rounded, accent: Color(0xFFC2A15E)),
];

const List<_Service> _services = <_Service>[
  _Service(
    title: 'Bathroom deep cleaning',
    price: 'From ₹799',
    rating: 4.8,
    jobs: '1.4k bookings',
    icon: Icons.cleaning_services_rounded,
    accent: Color(0xFF10B981),
  ),
  _Service(
    title: 'AC service and gas refill',
    price: 'From ₹999',
    rating: 4.9,
    jobs: '2.1k bookings',
    icon: Icons.ac_unit_rounded,
    accent: Color(0xFF38BDF8),
  ),
  _Service(
    title: 'Electrical wiring',
    price: 'From ₹699',
    rating: 4.7,
    jobs: '980 bookings',
    icon: Icons.electrical_services_rounded,
    accent: Color(0xFFC2A15E),
  ),
  _Service(
    title: 'Furniture and carpentry',
    price: 'From ₹499',
    rating: 4.8,
    jobs: '860 bookings',
    icon: Icons.home_repair_service_rounded,
    accent: Color(0xFFF59E0B),
  ),
];


