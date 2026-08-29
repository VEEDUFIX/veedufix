import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:admin_web/features/ops/data/ops_api.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../widgets/dashboard_header.dart';
import '../widgets/dashboard_kpi_grid.dart';
import '../widgets/dashboard_charts.dart';
import '../widgets/dashboard_quick_nav.dart';
import '../widgets/dashboard_ops_snapshot.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  late final OpsApi _api;
  OpsOverviewSnapshot? _snapshot;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _api = OpsApi(ref.read(apiClientProvider).dio);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final snapshot = await _api.fetchOverview();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherits from AppShell
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isCompact ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardHeader(isCompact: isCompact),
            const SizedBox(height: 32),
            _PriorityStrip(
              snapshot: _snapshot,
              isLoading: _isLoading,
              onOpenInbox: () => context.go('/admin/action-inbox'),
              onOpenLiveJobs: () => context.go('/ops/live-jobs'),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/admin/action-inbox'),
                  icon: const Icon(Icons.inbox_rounded),
                  label: const Text('Action inbox'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/audit-logs'),
                  icon: const Icon(Icons.manage_search_rounded),
                  label: const Text('Audit logs'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/support-tickets'),
                  icon: const Icon(Icons.support_agent_rounded),
                  label: const Text('Support'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/finance'),
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: const Text('Finance'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/worker-review'),
                  icon: const Icon(Icons.badge_rounded),
                  label: const Text('Worker review'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            DashboardKpiGrid(
              isCompact: isCompact,
              isLoading: _isLoading,
              snapshot: _snapshot,
              error: _error,
              onRetry: _loadData,
            ),
            const SizedBox(height: 32),
            
            DashboardCharts(
              isLoading: _isLoading,
              snapshot: _snapshot,
              error: _error,
              onRetry: _loadData,
            ),
            const SizedBox(height: 48),
            
            const DashboardQuickNav(),
            const SizedBox(height: 48),
            
            DashboardOpsSnapshot(
              isLoading: _isLoading,
              snapshot: _snapshot,
              error: _error,
              onRetry: _loadData,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityStrip extends StatelessWidget {
  const _PriorityStrip({
    required this.snapshot,
    required this.isLoading,
    required this.onOpenInbox,
    required this.onOpenLiveJobs,
  });

  final OpsOverviewSnapshot? snapshot;
  final bool isLoading;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenLiveJobs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final summary = snapshot?.summary;

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.priority_high_rounded,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today’s priorities',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Keep the marketplace moving by clearing the inbox first, then reviewing live jobs and payout issues.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PriorityMetricPill(
                  label: 'Open tickets',
                  value: isLoading ? '...' : '${summary?.openSupportTicketsCount ?? 0}',
                ),
                _PriorityMetricPill(
                  label: 'Live jobs',
                  value: isLoading ? '...' : '${summary?.activeJobsCount ?? 0}',
                ),
                _PriorityMetricPill(
                  label: 'Failed payouts',
                  value: isLoading ? '...' : '${summary?.failedPayoutsCount ?? 0}',
                ),
                _PriorityMetricPill(
                  label: 'Failed refunds',
                  value: isLoading ? '...' : '${summary?.failedRefundsCount ?? 0}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onOpenInbox,
                  icon: const Icon(Icons.inbox_rounded, size: 18),
                  label: const Text('Open inbox'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenLiveJobs,
                  icon: const Icon(Icons.work_history_rounded, size: 18),
                  label: const Text('Review live jobs'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityMetricPill extends StatelessWidget {
  const _PriorityMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
