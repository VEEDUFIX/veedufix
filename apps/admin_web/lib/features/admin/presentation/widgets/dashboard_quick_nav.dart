import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'dashboard_shared.dart';

class DashboardQuickNav extends StatelessWidget {
  const DashboardQuickNav({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Navigation',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),

        const SectionTitle(title: 'Operations'),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            ActionCard(
              title: 'Ops Overview',
              subtitle: 'Monitor jobs, dispatch, and disputes',
              icon: Icons.monitor_heart_rounded,
              color: const Color(0xFF0F766E),
              onTap: () => context.go('/ops/overview'),
            ),
            ActionCard(
              title: 'Live Jobs',
              subtitle: 'Inspect active job execution states',
              icon: Icons.work_history_rounded,
              color: const Color(0xFF2563EB),
              onTap: () => context.go('/ops/live-jobs'),
            ),
            ActionCard(
              title: 'Alerts Queue',
              subtitle: 'Retry failed payouts and refunds',
              icon: Icons.priority_high_rounded,
              color: const Color(0xFFEF4444),
              onTap: () => context.go('/ops/alerts'),
            ),
            ActionCard(
              title: 'Disputes',
              subtitle: 'Review customer disputes',
              icon: Icons.gavel_rounded,
              color: const Color(0xFFB45309),
              onTap: () => context.go('/ops/disputes'),
            ),
          ],
        ),
        const SizedBox(height: 40),

        const SectionTitle(title: 'Catalog & Workers'),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            ActionCard(
              title: 'Catalog Manager',
              subtitle: 'Categories, services, pricing',
              icon: Icons.category_rounded,
              color: const Color(0xFF6366F1),
              onTap: () => context.go('/catalog'),
            ),
            ActionCard(
              title: 'Service Areas',
              subtitle: 'Launch zones and pincode coverage',
              icon: Icons.my_location_rounded,
              color: const Color(0xFF0F766E),
              onTap: () => context.go('/service-areas'),
            ),
            ActionCard(
              title: 'Worker Review',
              subtitle: 'Approve or reject onboarding',
              icon: Icons.verified_user_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => context.go('/worker-review'),
            ),
            ActionCard(
              title: 'Worker Directory',
              subtitle: 'Browse all workers and performance',
              icon: Icons.badge_rounded,
              color: const Color(0xFF0F766E),
              onTap: () => context.go('/workers'),
            ),
          ],
        ),
        const SizedBox(height: 40),

        const SectionTitle(title: 'Customers & Bookings'),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            ActionCard(
              title: 'Customer Management',
              subtitle: 'Search, view and ban customers',
              icon: Icons.people_rounded,
              color: const Color(0xFF3B82F6),
              onTap: () => context.go('/customers'),
            ),
            ActionCard(
              title: 'All Bookings',
              subtitle: 'Filter, track and review bookings',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF14B8A6),
              onTap: () => context.go('/admin-bookings'),
            ),
            ActionCard(
              title: 'Coupons',
              subtitle: 'Create and manage discount codes',
              icon: Icons.discount_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () => context.go('/coupons'),
            ),
          ],
        ),
        const SizedBox(height: 40),

        const SectionTitle(title: 'Finance & Analytics'),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: [
            ActionCard(
              title: 'Finance',
              subtitle: 'Payouts and refunds ledgers',
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFF0F766E),
              onTap: () => context.go('/finance'),
            ),
            ActionCard(
              title: 'Tax Summary',
              subtitle: 'GST and revenue export for CA review',
              icon: Icons.request_quote_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => context.go('/finance/tax-summary'),
            ),
            ActionCard(
              title: 'Platform Settings',
              subtitle: 'GSTIN, invoice sequence, commission rules',
              icon: Icons.tune_rounded,
              color: const Color(0xFF0F766E),
              onTap: () => context.go('/platform-settings'),
            ),
            ActionCard(
              title: 'Reports & Exports',
              subtitle: 'Download CSV reports for bookings, earnings, payouts',
              icon: Icons.download_rounded,
              color: const Color(0xFF64748B),
              onTap: () => context.go('/reports'),
            ),
            ActionCard(
              title: 'Push Notifications',
              subtitle: 'Broadcast alerts to customers and workers',
              icon: Icons.campaign_rounded,
              color: const Color(0xFFF43F5E),
              onTap: () => context.go('/push'),
            ),
            ActionCard(
              title: 'Analytics',
              subtitle: 'Marketplace performance trends',
              icon: Icons.insights_rounded,
              color: const Color(0xFF2563EB),
              onTap: () => context.go('/analytics'),
            ),
          ],
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
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
      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: AbzioTheme.eliteShadow,
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
