import 'package:flutter/material.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
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
                    'City operations stay visible all day.',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monitor revenue, support, worker approvals, and marketplace health from one control center.',
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
                  label: 'Revenue',
                  value: 'Rs. 12.8L',
                  icon: Icons.payments_rounded,
                  accentColor: Color(0xFF0F766E),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: PremiumStatCard(
                  label: 'Bookings',
                  value: '1,248',
                  icon: Icons.event_available_rounded,
                  accentColor: Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const PremiumStatCard(
            label: 'Worker approvals',
            value: '18 pending',
            icon: Icons.verified_user_rounded,
            accentColor: Color(0xFFF59E0B),
          ),
          const SizedBox(height: 20),
          const PremiumSectionHeader(
            title: 'Operations snapshot',
            subtitle: 'Key numbers and queues that need attention now.',
          ),
          const SizedBox(height: 12),
          const _AdminMetric(label: 'Service completion rate', value: '96.2%'),
          const SizedBox(height: 12),
          const _AdminMetric(label: 'Open support tickets', value: '07 active'),
          const SizedBox(height: 12),
          const _AdminMetric(label: 'Today\'s new workers', value: '11 applicants'),
        ],
      ),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumGlassCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
