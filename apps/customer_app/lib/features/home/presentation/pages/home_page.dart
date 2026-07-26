import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hello, Asha'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What do you need help with today?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book trusted professionals, track visits, and manage every service from one place.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.74),
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search services, pros, or offers',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: PremiumStatCard(
                  label: 'Bookings this week',
                  value: '12',
                  icon: Icons.calendar_month_rounded,
                  accentColor: Color(0xFF0F766E),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Repeat customers',
                  value: '84%',
                  icon: Icons.thumb_up_alt_rounded,
                  accentColor: Color(0xFF14B8A6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const PremiumSectionHeader(
            title: 'Popular categories',
            subtitle: 'Fast access to the services people book most often.',
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _CategoryPill(icon: Icons.electrical_services_rounded, label: 'Electrician'),
              _CategoryPill(icon: Icons.plumbing_rounded, label: 'Plumber'),
              _CategoryPill(icon: Icons.format_paint_rounded, label: 'Painter'),
              _CategoryPill(icon: Icons.cleaning_services_rounded, label: 'Cleaning'),
              _CategoryPill(icon: Icons.ac_unit_rounded, label: 'AC Repair'),
              _CategoryPill(icon: Icons.computer_rounded, label: 'Laptop Repair'),
            ],
          ),
          const SizedBox(height: 20),
          PremiumSectionHeader(
            title: 'Nearby professionals',
            subtitle: 'Recommended by location, rating, and response time.',
            actionLabel: 'Map view',
            onAction: () {},
          ),
          const SizedBox(height: 12),
          const _WorkerCard(
            name: 'Ramesh Kumar',
            skill: 'Electrician',
            rating: '4.9',
            distance: '1.4 km away',
            price: 'Starts at Rs. 249',
          ),
          const SizedBox(height: 12),
          const _WorkerCard(
            name: 'Sanjay Patel',
            skill: 'AC Technician',
            rating: '4.8',
            distance: '2.1 km away',
            price: 'Starts at Rs. 349',
          ),
          const SizedBox(height: 20),
          const PremiumSectionHeader(
            title: 'Recently booked',
            subtitle: 'Quickly revisit your latest completed services.',
          ),
          const SizedBox(height: 12),
          const _RecentBookingTile(
            title: 'House cleaning',
            subtitle: 'Completed on 24 Jul 2026',
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  const _WorkerCard({
    required this.name,
    required this.skill,
    required this.rating,
    required this.distance,
    required this.price,
  });

  final String name;
  final String skill;
  final String rating;
  final String distance;
  final String price;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                name.isNotEmpty ? name[0] : 'V',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(skill),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _MetaChip(icon: Icons.star_rounded, label: rating),
                      _MetaChip(icon: Icons.place_rounded, label: distance),
                      _MetaChip(icon: Icons.payments_rounded, label: price),
                    ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _RecentBookingTile extends StatelessWidget {
  const _RecentBookingTile({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const Icon(Icons.receipt_long_rounded),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
