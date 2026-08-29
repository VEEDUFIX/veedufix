import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_web/features/ops/data/ops_api.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'dashboard_shared.dart';

class DashboardOpsSnapshot extends StatelessWidget {
  final bool isLoading;
  final OpsOverviewSnapshot? snapshot;
  final String? error;
  final VoidCallback? onRetry;

  const DashboardOpsSnapshot({
    super.key,
    required this.isLoading,
    this.snapshot,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operations Snapshot',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),
        if (snapshot != null) ...[
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.inbox_rounded, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unified action inbox',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Triage support, finance, review, and dispute items from one queue before they grow.',
                          style: GoogleFonts.inter(
                            color: Colors.black54,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => context.go('/admin/action-inbox'),
                    child: const Text('Open inbox'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (isLoading)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SnapshotSkeletonRow(),
              SizedBox(height: 24),
              _SnapshotSkeletonRow(),
              SizedBox(height: 16),
              _SnapshotSkeletonRow(),
            ],
          )
        else if (error != null)
          PremiumEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load operations snapshot',
            subtitle:
                'The live operations metrics are unavailable right now. Please retry.',
            actionLabel: 'Retry',
            onAction: onRetry,
          )
        else if (snapshot != null) ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 800;
              final cards = [
                SnapshotCard(
                  label: 'Service completion rate',
                  value: '${snapshot!.summary.totalBookings > 0 ? ((snapshot!.summary.completedBookings / snapshot!.summary.totalBookings) * 100).toStringAsFixed(1) : 0}%',
                ),
                if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                SnapshotCard(
                  label: 'Open support tickets',
                  value: '${snapshot!.summary.openSupportTicketsCount} active',
                ),
                if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                SnapshotCard(
                  label: 'Today\'s new workers',
                  value: '${snapshot!.summary.todaysNewWorkers} apps',
                ),
              ];
              
              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cards,
                );
              }
              return Row(
                children: cards.map((c) => c is SizedBox ? c : Expanded(child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Operations Health',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 800;
              final cards = [
                SnapshotCard(
                  label: 'Live jobs',
                  value: '${snapshot!.summary.activeJobsCount}',
                ),
                if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                SnapshotCard(
                  label: 'Dispatch failures',
                  value: '${snapshot!.summary.dispatchFailuresCount}',
                ),
                if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                SnapshotCard(
                  label: 'Open disputes',
                  value: '${snapshot!.summary.openDisputesCount}',
                ),
              ];

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cards,
                );
              }
              return Row(
                children: cards.map((c) => c is SizedBox ? c : Expanded(child: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 800;
              final cards = [
                SnapshotCard(
                  label: 'Failed payouts',
                  value: '${snapshot!.summary.failedPayoutsCount}',
                ),
                if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                SnapshotCard(
                  label: 'Failed refunds',
                  value: '${snapshot!.summary.failedRefundsCount}',
                ),
                if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
                SnapshotCard(
                  label: 'Completion ratio',
                  value: '${snapshot!.summary.totalBookings > 0 ? ((snapshot!.summary.completedBookings / snapshot!.summary.totalBookings) * 100).toStringAsFixed(1) : 0}%',
                ),
              ];

              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: cards,
                );
              }
              return Row(
                children: cards.map((c) => c is SizedBox ? c : Expanded(child: c)).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}

class SnapshotCard extends StatelessWidget {
  const SnapshotCard({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotSkeletonRow extends StatelessWidget {
  const _SnapshotSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 800;
        final cards = [
          const _SnapshotSkeletonCard(),
          if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
          const _SnapshotSkeletonCard(),
          if (isSmall) const SizedBox(height: 24) else const SizedBox(width: 24),
          const _SnapshotSkeletonCard(),
        ];

        if (isSmall) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards,
          );
        }
        return Row(
          children: cards.map((c) => c is SizedBox ? c : Expanded(child: c)).toList(),
        );
      },
    );
  }
}

class _SnapshotSkeletonCard extends StatelessWidget {
  const _SnapshotSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShimmerWidget(width: 120, height: 14, radius: 8),
          ShimmerWidget(width: 48, height: 16, radius: 8),
        ],
      ),
    );
  }
}
