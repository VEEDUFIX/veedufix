import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherits from AppShell
      body: SingleChildScrollView(
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
                      'Admin Dashboard',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monitor revenue, support, worker approvals, and marketplace health.',
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Customize'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Top Metrics
            LayoutBuilder(
              builder: (context, constraints) {

                return const Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Revenue',
                        value: 'Rs. 12.8L',
                        icon: Icons.payments_rounded,
                        color: Color(0xFF0F766E),
                        trend: '+12.5%',
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: _MetricCard(
                        title: 'Bookings',
                        value: '1,248',
                        icon: Icons.event_available_rounded,
                        color: Color(0xFF2563EB),
                        trend: '+5.2%',
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: _MetricCard(
                        title: 'Worker Approvals',
                        value: '18',
                        icon: Icons.verified_user_rounded,
                        color: Color(0xFFF59E0B),
                        subtitle: 'Pending review',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 48),

            // Navigation Grid Sections
            Text(
              'Quick Navigation',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            const _SectionTitle(title: 'Operations'),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _ActionCard(
                  title: 'Ops Overview',
                  subtitle: 'Monitor jobs, dispatch, and disputes',
                  icon: Icons.monitor_heart_rounded,
                  color: const Color(0xFF0F766E),
                  onTap: () => context.go('/ops/overview'),
                ),
                _ActionCard(
                  title: 'Live Jobs',
                  subtitle: 'Inspect active job execution states',
                  icon: Icons.work_history_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => context.go('/ops/live-jobs'),
                ),
                _ActionCard(
                  title: 'Alerts Queue',
                  subtitle: 'Retry failed payouts and refunds',
                  icon: Icons.priority_high_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => context.go('/ops/alerts'),
                ),
                _ActionCard(
                  title: 'Disputes',
                  subtitle: 'Review customer disputes',
                  icon: Icons.gavel_rounded,
                  color: const Color(0xFFB45309),
                  onTap: () => context.go('/ops/disputes'),
                ),
              ],
            ),
            const SizedBox(height: 40),

            const _SectionTitle(title: 'Catalog & Workers'),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _ActionCard(
                  title: 'Catalog Manager',
                  subtitle: 'Categories, services, pricing',
                  icon: Icons.category_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: () => context.go('/catalog'),
                ),
                _ActionCard(
                  title: 'Worker Review',
                  subtitle: 'Approve or reject onboarding',
                  icon: Icons.verified_user_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => context.go('/worker-review'),
                ),
                _ActionCard(
                  title: 'Worker Directory',
                  subtitle: 'Browse all workers and performance',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF0F766E),
                  onTap: () => context.go('/workers'),
                ),
              ],
            ),
            const SizedBox(height: 40),

            const _SectionTitle(title: 'Finance & Analytics'),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                _ActionCard(
                  title: 'Finance',
                  subtitle: 'Payouts and refunds ledgers',
                  icon: Icons.account_balance_wallet_rounded,
                  color: const Color(0xFF0F766E),
                  onTap: () => context.go('/finance'),
                ),
                _ActionCard(
                  title: 'Analytics',
                  subtitle: 'Marketplace performance trends',
                  icon: Icons.insights_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => context.go('/analytics'),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            Text(
              'Operations Snapshot',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(child: _SnapshotCard(label: 'Service completion rate', value: '96.2%')),
                SizedBox(width: 24),
                Expanded(child: _SnapshotCard(label: 'Open support tickets', value: '07 active')),
                SizedBox(width: 24),
                Expanded(child: _SnapshotCard(label: 'Today\'s new workers', value: '11 apps')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trend;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
          if (trend != null || subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              trend ?? subtitle!,
              style: GoogleFonts.inter(
                color: trend != null ? const Color(0xFF059669) : Colors.black45,
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
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

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
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
