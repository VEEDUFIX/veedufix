import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/job_execution_provider.dart';

class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedTab = GoRouterState.of(context).uri.queryParameters['tab'];
    final initialIndex = switch (selectedTab) {
      'accepted' => 1,
      'active' => 2,
      'completed' => 3,
      _ => 0,
    };
    void showActionSnackBar(String message) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    final acceptedJob = _JobCardData(
      customer: 'Salim Basha',
      distance: '2.0 km away',
      price: 'Rs 1,049',
      summary: 'AC service confirmed for afternoon slot.',
      accent: const Color(0xFF38BDF8),
      onPrimaryAction: () {
        context.push(
          '/job-execution',
        extra: const JobExecutionBooking(
          bookingId: 'booking-accepted-001',
          bookingCode: 'VF-20481',
          serviceId: 'service-ac-001',
          serviceName: 'AC Service',
            customerName: 'Salim Basha',
            locationLabel: 'Anna Nagar, Chennai',
            earningsLabel: 'Rs 1,049',
            summary: 'AC service confirmed for afternoon slot.',
            accentColor: Color(0xFF38BDF8),
          ),
        );
      },
      onSecondaryAction: () => showActionSnackBar('Call customer coming soon.'),
    );

    return DefaultTabController(
      length: 4,
      initialIndex: initialIndex,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jobs',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review incoming requests, manage active jobs, and close completed work smoothly.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 18),
                    const TabBar(
                      isScrollable: true,
                      tabs: [
                        Tab(text: 'Incoming'),
                        Tab(text: 'Accepted'),
                        Tab(text: 'Active'),
                        Tab(text: 'Completed'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _JobList(
                      jobs: [
                        _JobCardData(
                          customer: 'Ravi Kumar',
                          distance: '1.2 km away',
                          price: 'Rs 799',
                          summary: 'Bathroom sink leak and tap replacement.',
                          accent: const Color(0xFFC2A15E),
                          onPrimaryAction: () => showActionSnackBar('Accepting Ravi Kumar coming soon.'),
                          onSecondaryAction: () => showActionSnackBar('Decline request coming soon.'),
                        ),
                        _JobCardData(
                          customer: 'Asha Priya',
                          distance: '2.5 km away',
                          price: 'Rs 599',
                          summary: 'Ceiling fan installation with wiring check.',
                          accent: const Color(0xFF10B981),
                          onPrimaryAction: () => showActionSnackBar('Accepting Asha Priya coming soon.'),
                          onSecondaryAction: () => showActionSnackBar('Decline request coming soon.'),
                        ),
                      ],
                      emptyTitle: 'No incoming jobs',
                      emptySubtitle: 'New requests will appear here when customers book your services.',
                      showActions: true,
                      primaryAction: 'Accept',
                      secondaryAction: 'Decline',
                    ),
                    _JobList(
                      jobs: [acceptedJob],
                      emptyTitle: 'No accepted jobs',
                      emptySubtitle: 'Accepted jobs will remain here until the customer arrives or you start the visit.',
                      showActions: true,
                      primaryAction: 'Open flow',
                      secondaryAction: 'Call customer',
                    ),
                    _JobList(
                      jobs: [
                        _JobCardData(
                          customer: 'Karthik',
                          distance: '0.8 km away',
                          price: 'Rs 899',
                          summary: 'Kitchen plumbing repair with parts included.',
                          accent: const Color(0xFFF59E0B),
                          onPrimaryAction: () => showActionSnackBar('Starting Karthik job coming soon.'),
                          onSecondaryAction: () => showActionSnackBar('Call customer coming soon.'),
                        ),
                        _JobCardData(
                          customer: 'Meera',
                          distance: '1.9 km away',
                          price: 'Rs 1,299',
                          summary: 'Water heater inspection and service.',
                          accent: const Color(0xFFEF4444),
                          onPrimaryAction: () => showActionSnackBar('Starting Meera job coming soon.'),
                          onSecondaryAction: () => showActionSnackBar('Call customer coming soon.'),
                        ),
                      ],
                      emptyTitle: 'No active jobs',
                      emptySubtitle: 'Start a job once you reach the customer location.',
                      showActions: true,
                      primaryAction: 'Start job',
                      secondaryAction: 'Call customer',
                    ),
                    _JobList(
                      jobs: [
                        _JobCardData(
                          customer: 'Janani',
                          distance: 'Completed today',
                          price: 'Rs 499',
                          summary: 'Door hinge repair and quick finishing touch.',
                          accent: const Color(0xFF10B981),
                          onPrimaryAction: () => showActionSnackBar('Opening Janani invoice coming soon.'),
                          onSecondaryAction: () => showActionSnackBar('Repeat booking coming soon.'),
                        ),
                        _JobCardData(
                          customer: 'Suresh',
                          distance: 'Completed yesterday',
                          price: 'Rs 699',
                          summary: 'Fan replacement and safety check.',
                          accent: const Color(0xFFC2A15E),
                          onPrimaryAction: () => showActionSnackBar('Opening Suresh invoice coming soon.'),
                          onSecondaryAction: () => showActionSnackBar('Repeat booking coming soon.'),
                        ),
                      ],
                      emptyTitle: 'No completed jobs',
                      emptySubtitle: 'Completed work will show ratings, payment status, and invoice details here.',
                      showActions: true,
                      primaryAction: 'Invoice',
                      secondaryAction: 'Repeat booking',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({
    required this.jobs,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.showActions,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final List<_JobCardData> jobs;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showActions;
  final String primaryAction;
  final String secondaryAction;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          PremiumEmptyState(
            icon: Icons.event_busy_rounded,
            title: emptyTitle,
            subtitle: emptySubtitle,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: jobs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _JobCard(
          data: jobs[index],
          showActions: showActions,
          primaryAction: primaryAction,
          secondaryAction: secondaryAction,
        );
      },
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.data,
    required this.showActions,
    required this.primaryAction,
    required this.secondaryAction,
  });

  final _JobCardData data;
  final bool showActions;
  final String primaryAction;
  final String secondaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: data.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(Icons.person_rounded, color: data.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data.customer,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          _StatusChip(label: 'New', accent: data.accent),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.location_on_outlined,
                    label: data.distance,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.payments_rounded,
                    label: data.price,
                  ),
                ),
              ],
            ),
            if (showActions) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: data.onPrimaryAction,
                      child: Text(primaryAction),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: data.onSecondaryAction,
                      child: Text(secondaryAction),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCardData {
  const _JobCardData({
    required this.customer,
    required this.distance,
    required this.price,
    required this.summary,
    required this.accent,
    this.onPrimaryAction,
    this.onSecondaryAction,
  });

  final String customer;
  final String distance;
  final String price;
  final String summary;
  final Color accent;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onSecondaryAction;
}
