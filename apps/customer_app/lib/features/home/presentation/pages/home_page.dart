import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final userName = auth?.user.name ?? 'Abdul';
    final firstName = userName.trim().split(RegExp(r'\s+')).first;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {},
        color: colorScheme.primary,
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
              onVoiceTap: () {},
            ),
            const SizedBox(height: 18),
            const _SectionLabel(
              title: 'Quick categories',
              subtitle: 'The most requested services in your area.',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _CategoryChip(category: category);
                },
              ),
            ),
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _services.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (context, index) {
                return _ServiceCard(service: _services[index]);
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
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _professionals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _ProfessionalCard(professional: _professionals[index]);
                },
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel(
              title: 'Top rated professionals',
              subtitle: 'Highly reviewed specialists with completed jobs.',
            ),
            const SizedBox(height: 12),
            ..._topRated.map(
              (professional) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TopRatedCard(professional: professional),
              ),
            ),
            const SizedBox(height: 8),
            const _SectionLabel(
              title: 'Offers',
              subtitle: 'Savings, coupons, and referral rewards.',
            ),
            const SizedBox(height: 12),
            _OfferBanner(
              title: 'Festival offers',
              subtitle: 'Up to 25% off on essential home services this week.',
              icon: Icons.local_activity_rounded,
              accent: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const _OfferBanner(
              title: 'Referral rewards',
              subtitle: 'Invite friends and earn credits on your next booking.',
              icon: Icons.card_giftcard_rounded,
              accent: Color(0xFF10B981),
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
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {},
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
    );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
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
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.mic_none_rounded, color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
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

  final _Category category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Center(
              child: Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: category.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(category.icon, color: category.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            category.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.84),
                ),
          ),
        ],
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

  final _Service service;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 96,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    service.accent.withValues(alpha: 0.22),
                    service.accent.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(service.icon, size: 38, color: service.accent),
            ),
            const SizedBox(height: 12),
            Text(
              service.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  service.price,
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
                    service.rating.toStringAsFixed(1),
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
              service.jobs,
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

class _Professional {
  const _Professional({
    required this.name,
    required this.role,
    required this.experience,
    required this.rating,
    required this.distance,
    required this.price,
    required this.verified,
    required this.accent,
  });

  final String name;
  final String role;
  final String experience;
  final double rating;
  final String distance;
  final String price;
  final bool verified;
  final Color accent;
}

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.professional});

  final _Professional professional;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: PremiumGlassCard(
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
                  borderRadius: BorderRadius.circular(22),
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

  final _Professional professional;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumGlassCard(
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
    return PremiumGlassCard(
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
          borderRadius: BorderRadius.circular(28),
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

class _OfferBanner extends StatelessWidget {
  const _OfferBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: colorScheme.onSurfaceVariant),
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

const List<_Professional> _professionals = <_Professional>[
  _Professional(
    name: 'Imran Khan',
    role: 'AC Technician',
    experience: '8 years experience',
    rating: 4.9,
    distance: '1.8 km away',
    price: '₹799 / visit',
    verified: true,
    accent: Color(0xFF38BDF8),
  ),
  _Professional(
    name: 'Suresh Babu',
    role: 'Electrician',
    experience: '11 years experience',
    rating: 4.8,
    distance: '2.4 km away',
    price: '₹699 / visit',
    verified: true,
    accent: Color(0xFFC2A15E),
  ),
  _Professional(
    name: 'Fazila Noor',
    role: 'Home Cleaning',
    experience: '6 years experience',
    rating: 4.9,
    distance: '2.9 km away',
    price: '₹899 / visit',
    verified: true,
    accent: Color(0xFF10B981),
  ),
];

const List<_Professional> _topRated = <_Professional>[
  _Professional(
    name: 'Arun Raj',
    role: 'Plumber',
    experience: '420 completed jobs',
    rating: 4.9,
    distance: '3.2 km away',
    price: '₹649 / visit',
    verified: true,
    accent: Color(0xFF10B981),
  ),
  _Professional(
    name: 'Kavya Nair',
    role: 'Painter',
    experience: '368 completed jobs',
    rating: 4.8,
    distance: '1.7 km away',
    price: '₹549 / visit',
    verified: true,
    accent: Color(0xFFEF4444),
  ),
  _Professional(
    name: 'Mohamed Ali',
    role: 'Laptop Repair',
    experience: '512 completed jobs',
    rating: 4.9,
    distance: '4.0 km away',
    price: '₹1,199 / visit',
    verified: true,
    accent: Color(0xFF8B5CF6),
  ),
];
