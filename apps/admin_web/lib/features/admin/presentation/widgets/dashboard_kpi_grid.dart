import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:admin_web/features/ops/data/ops_api.dart';
import 'dashboard_shared.dart';

class DashboardKpiGrid extends StatelessWidget {
  final bool isCompact;
  final bool isLoading;
  final OpsOverviewSnapshot? snapshot;

  const DashboardKpiGrid({
    super.key,
    required this.isCompact,
    required this.isLoading,
    this.snapshot,
  });

  Widget _metricBox(BuildContext context, bool isCompact, {required Widget child}) {
    final width = isCompact ? MediaQuery.of(context).size.width - 40 : 320.0;
    return SizedBox(width: width, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _metricBox(context, isCompact,
          child: MetricCard(
            title: 'Revenue',
            value: '₹${snapshot!.summary.totalRevenue.toStringAsFixed(0)}',
            icon: Icons.payments_rounded,
            color: const Color(0xFF0F766E),
          ),
        ),
        _metricBox(context, isCompact,
          child: MetricCard(
            title: 'Bookings',
            value: '${snapshot!.summary.totalBookings}',
            icon: Icons.event_available_rounded,
            color: const Color(0xFF2563EB),
          ),
        ),
        _metricBox(context, isCompact,
          child: MetricCard(
            title: 'Cancellations',
            value: '${snapshot!.summary.cancelledBookingsCount}',
            icon: Icons.event_busy_rounded,
            color: const Color(0xFFEF4444),
            subtitle: 'Cancelled or refunded',
          ),
        ),
        _metricBox(context, isCompact,
          child: MetricCard(
            title: 'Workers',
            value: '${snapshot!.summary.activeWorkersCount}',
            icon: Icons.badge_rounded,
            color: const Color(0xFF8B5CF6),
            subtitle: 'Verified and approved',
          ),
        ),
        _metricBox(context, isCompact,
          child: MetricCard(
            title: 'Support Load',
            value: '${snapshot!.summary.openSupportTicketsCount}',
            icon: Icons.support_agent_rounded,
            color: const Color(0xFFF59E0B),
            subtitle: 'Open tickets',
          ),
        ),
        _metricBox(context, isCompact,
          child: MetricCard(
            title: 'Worker Approvals',
            value: '${snapshot!.summary.pendingWorkerReviewsCount}',
            icon: Icons.verified_user_rounded,
            color: const Color(0xFF0F766E),
            subtitle: 'Pending review',
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
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
                  borderRadius: BorderRadius.circular(12),
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                color: Colors.black45,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
