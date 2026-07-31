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
      backgroundColor: Colors.transparent,
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
          return RefreshIndicator(
            onRefresh: _reload,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Operations Overview',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track dispatches, active jobs, refunds, payouts, disputes, and worker reviews.',
                            style: GoogleFonts.inter(
                              color: Colors.black54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Quick Navigation Grid
                  const _SectionTitle(
                    title: 'Quick Navigation',
                    subtitle: 'Jump into the most common operational queues.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    children: [
                      _QuickActionCard(
                        icon: Icons.work_history_rounded,
                        color: const Color(0xFF2563EB),
                        title: 'Live Jobs',
                        subtitle: 'Inspect active bookings, photos, and checklist state.',
                        actionLabel: 'Open',
                        onPressed: () => context.go('/ops/live-jobs'),
                      ),
                      _QuickActionCard(
                        icon: Icons.priority_high_rounded,
                        color: const Color(0xFFEF4444),
                        title: 'Alerts',
                        subtitle: 'Retry failed payouts, refunds, and dispatches.',
                        actionLabel: 'Open',
                        onPressed: () => context.go('/ops/alerts'),
                      ),
                      _QuickActionCard(
                        icon: Icons.gavel_rounded,
                        color: const Color(0xFFB45309),
                        title: 'Disputes',
                        subtitle: 'Review customer complaints and resolve refund decisions.',
                        actionLabel: 'Open',
                        onPressed: () => context.go('/ops/disputes'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Metrics Grid
                  const _SectionTitle(
                    title: 'Live Ops at a Glance',
                    subtitle: 'Real-time counters for operational queues.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _StatCard(
                        label: 'Active jobs',
                        value: '${data.summary.activeJobsCount}',
                        icon: Icons.work_history_rounded,
                        color: const Color(0xFF2563EB),
                      ),
                      _StatCard(
                        label: 'Dispatch failures',
                        value: '${data.summary.dispatchFailuresCount}',
                        icon: Icons.notification_important_rounded,
                        color: const Color(0xFFEF4444),
                      ),
                      _StatCard(
                        label: 'Open disputes',
                        value: '${data.summary.openDisputesCount}',
                        icon: Icons.gavel_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                      _StatCard(
                        label: 'Failed payouts',
                        value: '${data.summary.failedPayoutsCount}',
                        icon: Icons.payments_outlined,
                        color: const Color(0xFF0F766E),
                      ),
                      _StatCard(
                        label: 'Failed refunds',
                        value: '${data.summary.failedRefundsCount}',
                        icon: Icons.undo_rounded,
                        color: const Color(0xFF8B5CF6),
                      ),
                      _StatCard(
                        label: 'Worker reviews',
                        value: '${data.summary.pendingWorkerReviewsCount}',
                        icon: Icons.verified_user_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Recent Live Jobs
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              title: 'Recent Live Jobs',
                              subtitle: 'The most recently updated active jobs.',
                            ),
                            const SizedBox(height: 16),
                            if (data.liveJobs.isEmpty)
                              const _SurfacePanel(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: PremiumEmptyState(
                                      icon: Icons.work_off_rounded,
                                      title: 'No active jobs',
                                      subtitle: 'Live jobs will appear here when active.',
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...data.liveJobs.take(5).map(
                                    (job) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _SurfacePanel(
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          leading: _StatusMark(status: job.status),
                                          title: Text(
                                            '${job.bookingCode} - ${job.customerName}',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                          ),
                                          subtitle: Text('${job.serviceLabel}\n${job.statusLabel} - ${job.elapsedLabel} active'),
                                          isThreeLine: true,
                                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                                          onTap: () => context.go('/ops/live-jobs'),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle(
                              title: 'Recent Alerts',
                              subtitle: 'Issues needing admin follow-up.',
                            ),
                            const SizedBox(height: 16),
                            if (data.alerts.isEmpty)
                              const _SurfacePanel(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: PremiumEmptyState(
                                      icon: Icons.check_circle_outline_rounded,
                                      title: 'No alerts',
                                      subtitle: 'Failed payouts, refunds, and dispatches will appear here.',
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...data.alerts.take(5).map(
                                    (alert) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _SurfacePanel(
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          leading: _AlertMark(kind: alert.kind),
                                          title: Text(
                                            alert.title,
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                                          ),
                                          subtitle: Text(
                                            [
                                              alert.message,
                                              if (alert.bookingCode != null) 'Booking ${alert.bookingCode}',
                                            ].join('\n'),
                                          ),
                                          isThreeLine: true,
                                          trailing: TextButton(
                                            onPressed: () => context.go('/ops/alerts'),
                                            child: const Text('Open'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              letterSpacing: -1,
            ),
          ),
        ],
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
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
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
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.timelapse_rounded, color: Color(0xFF2563EB)),
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
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.black45),
          const SizedBox(height: 16),
          Text(
            'Failed to load operations data',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(error, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
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
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(color: Colors.black54, fontSize: 14),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: child,
    );
  }
}
