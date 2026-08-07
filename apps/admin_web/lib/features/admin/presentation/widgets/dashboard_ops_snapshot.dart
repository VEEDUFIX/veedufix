import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_web/features/ops/data/ops_api.dart';
import 'dashboard_shared.dart';

class DashboardOpsSnapshot extends StatelessWidget {
  final bool isLoading;
  final OpsOverviewSnapshot? snapshot;

  const DashboardOpsSnapshot({
    super.key,
    required this.isLoading,
    this.snapshot,
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
        if (isLoading)
          const Center(child: CircularProgressIndicator())
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
