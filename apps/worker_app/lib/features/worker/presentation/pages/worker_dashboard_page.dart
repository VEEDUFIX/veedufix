import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class WorkerDashboardPage extends StatelessWidget {
  const WorkerDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Dashboard'),
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
                    'You are fully booked for today.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stay on top of jobs, keep customers updated, and track earnings in real time.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.74),
                          height: 1.45,
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
                  label: 'Today',
                  value: '6 jobs',
                  icon: Icons.work_history_rounded,
                  accentColor: Color(0xFF0F766E),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Rating',
                  value: '4.9',
                  icon: Icons.star_rounded,
                  accentColor: Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const PremiumStatCard(
            label: 'This week earnings',
            value: 'Rs. 8,420',
            icon: Icons.payments_rounded,
            accentColor: Color(0xFF14B8A6),
          ),
          const SizedBox(height: 20),
          const PremiumSectionHeader(
            title: 'Today\'s route',
            subtitle: 'Upcoming visits and active jobs in one view.',
          ),
          const SizedBox(height: 12),
          const _JobCard(
            title: 'Kitchen sink repair',
            status: 'Accepted',
            time: 'Today, 2:00 PM',
          ),
          const SizedBox(height: 12),
          const _JobCard(
            title: 'AC installation',
            status: 'En route',
            time: 'Today, 4:30 PM',
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.title,
    required this.status,
    required this.time,
  });

  final String title;
  final String status;
  final String time;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(time),
        trailing: Chip(label: Text(status)),
      ),
    );
  }
}
