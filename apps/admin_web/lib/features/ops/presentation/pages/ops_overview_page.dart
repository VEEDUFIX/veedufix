import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/ops_api.dart';

class OpsOverviewPage extends ConsumerStatefulWidget {
  const OpsOverviewPage({super.key});

  @override
  ConsumerState<OpsOverviewPage> createState() => _OpsOverviewPageState();
}

class _OpsOverviewPageState extends ConsumerState<OpsOverviewPage> {
  late final OpsApi _api;
  late Future<OpsOverviewSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _api = OpsApi(ref.read(apiClientProvider).dio);
    _snapshotFuture = _api.fetchOverview();
  }

  Future<void> _reload() async {
    setState(() {
      _snapshotFuture = _api.fetchOverview();
    });
    await _snapshotFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Operations overview',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<OpsOverviewSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final data = snapshot.data!;
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF9F5EC), Color(0xFFFFFCF8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _SurfacePanel(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Live ops at a glance',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: const Color(0xFF13110F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track dispatches, active jobs, refunds, payouts, disputes, and worker review queues from one screen.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B6256),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              PremiumStatCard(
                                label: 'Active jobs',
                                value: '${data.summary.activeJobsCount}',
                                icon: Icons.work_history_rounded,
                                accentColor: const Color(0xFF2563EB),
                              ),
                              PremiumStatCard(
                                label: 'Dispatch failures',
                                value: '${data.summary.dispatchFailuresCount}',
                                icon: Icons.notification_important_rounded,
                                accentColor: const Color(0xFFEF4444),
                              ),
                              PremiumStatCard(
                                label: 'Open disputes',
                                value: '${data.summary.openDisputesCount}',
                                icon: Icons.gavel_rounded,
                                accentColor: const Color(0xFFF59E0B),
                              ),
                              PremiumStatCard(
                                label: 'Failed payouts',
                                value: '${data.summary.failedPayoutsCount}',
                                icon: Icons.payments_outlined,
                                accentColor: const Color(0xFF0F766E),
                              ),
                              PremiumStatCard(
                                label: 'Failed refunds',
                                value: '${data.summary.failedRefundsCount}',
                                icon: Icons.undo_rounded,
                                accentColor: const Color(0xFF8B5CF6),
                              ),
                              PremiumStatCard(
                                label: 'Worker reviews',
                                value:
                                    '${data.summary.pendingWorkerReviewsCount}',
                                icon: Icons.verified_user_rounded,
                                accentColor: const Color(0xFFF59E0B),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle(
                    title: 'Quick navigation',
                    subtitle: 'Jump into the most common operational queues.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickActionCard(
                        icon: Icons.work_history_rounded,
                        title: 'Live jobs',
                        subtitle:
                            'Inspect active bookings, photos, and checklist state.',
                        actionLabel: 'Open',
                        onPressed: () => context.go('/ops/live-jobs'),
                      ),
                      _QuickActionCard(
                        icon: Icons.priority_high_rounded,
                        title: 'Alerts',
                        subtitle:
                            'Retry failed payouts, refunds, and dispatches.',
                        actionLabel: 'Open',
                        onPressed: () => context.go('/ops/alerts'),
                      ),
                      _QuickActionCard(
                        icon: Icons.gavel_rounded,
                        title: 'Disputes',
                        subtitle:
                            'Review customer complaints and resolve refund decisions.',
                        actionLabel: 'Open',
                        onPressed: () => context.go('/ops/disputes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle(
                    title: 'Recent live jobs',
                    subtitle:
                        'The most recently updated active jobs currently in progress.',
                  ),
                  const SizedBox(height: 12),
                  if (data.liveJobs.isEmpty)
                    const _SurfacePanel(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: PremiumEmptyState(
                          icon: Icons.work_off_rounded,
                          title: 'No active jobs right now',
                          subtitle:
                              'Once workers accept bookings, the live jobs queue will appear here.',
                        ),
                      ),
                    )
                  else
                    ...data.liveJobs.take(5).map(
                          (job) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SurfacePanel(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: _StatusMark(status: job.status),
                                title: Text(
                                  '${job.bookingCode} - ${job.customerName}',
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                    '${job.serviceLabel}\n${job.statusLabel} - ${job.elapsedLabel} active'),
                                isThreeLine: true,
                                trailing:
                                    const Icon(Icons.chevron_right_rounded),
                                onTap: () => context.go('/ops/live-jobs'),
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 16),
                  const _SectionTitle(
                    title: 'Recent alerts',
                    subtitle:
                        'A snapshot of the issues that need admin follow-up.',
                  ),
                  const SizedBox(height: 12),
                  if (data.alerts.isEmpty)
                    const _SurfacePanel(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: PremiumEmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'No alerts pending',
                          subtitle:
                              'Failed payouts, refunds, and dispatches will appear here when they need attention.',
                        ),
                      ),
                    )
                  else
                    ...data.alerts.take(5).map(
                          (alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SurfacePanel(
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: _AlertMark(kind: alert.kind),
                                title: Text(
                                  alert.title,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w800),
                                ),
                                subtitle: Text(
                                  [
                                    alert.message,
                                    if (alert.bookingCode != null)
                                      'Booking ${alert.bookingCode}',
                                  ].join('\n'),
                                ),
                                isThreeLine: true,
                                trailing: TextButton(
                                  onPressed: () => context.go('/ops/alerts'),
                                  child: const Text('Open queue'),
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: _SurfacePanel(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: onPressed, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.timelapse_rounded,
          color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _AlertMark extends StatelessWidget {
  const _AlertMark({required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      'payout_failure' => const Color(0xFF0F766E),
      'refund_failure' => const Color(0xFF8B5CF6),
      _ => const Color(0xFFEF4444),
    };

    final icon = switch (kind) {
      'payout_failure' => Icons.payments_rounded,
      'refund_failure' => Icons.undo_rounded,
      _ => Icons.notification_important_rounded,
    };

    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'Unable to load operations overview',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF13110F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: const Color(0xFF6B6256),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5D8C6)),
      ),
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: child,
    );
  }
}
