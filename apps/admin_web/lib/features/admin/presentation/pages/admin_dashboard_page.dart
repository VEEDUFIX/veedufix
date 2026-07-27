import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Admin Dashboard',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F5EC), Color(0xFFFFFCF8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _SurfacePanel(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'City operations stay visible all day.',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: const Color(0xFF13110F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monitor revenue, support, worker approvals, and marketplace health from one control center.',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF6B6256),
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
              title: 'Navigation',
              subtitle: 'Open the right area quickly without scanning a long list of routes.',
            ),
            const SizedBox(height: 12),
            _NavSection(
              title: 'Operations',
              children: [
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.monitor_heart_rounded,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      'Ops Overview',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Monitor active jobs, dispatch failures, disputes, and failed payments in one place.'),
                    trailing: FilledButton(
                      onPressed: () => context.go('/ops/overview'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.work_history_rounded,
                          color: Color(0xFF2563EB)),
                    ),
                    title: const Text(
                      'Live Jobs',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle:
                        const Text('Inspect active job execution states.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/ops/live-jobs'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.priority_high_rounded,
                          color: Color(0xFFEF4444)),
                    ),
                    title: const Text(
                      'Alerts Queue',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Retry failed payouts, refunds, and dispatches.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/ops/alerts'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFB45309).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.gavel_rounded,
                          color: Color(0xFFB45309)),
                    ),
                    title: const Text(
                      'Disputes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Review customer disputes and resolve refund decisions.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/ops/disputes'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _NavSection(
              title: 'Catalog',
              children: [
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.category_rounded,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(
                      'Catalog Manager',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Create categories, services, images, pricing rules, and imports.'),
                    trailing: FilledButton(
                      onPressed: () => context.go('/catalog'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _NavSection(
              title: 'Workers',
              children: [
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.verified_user_rounded,
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.95)),
                    ),
                    title: Text(
                      'Worker Review Queue',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Approve, reject, or pause worker onboarding requests from one queue.'),
                    trailing: FilledButton(
                      onPressed: () => context.go('/worker-review'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.badge_rounded,
                          color: Color(0xFF0F766E)),
                    ),
                    title: const Text(
                      'Worker Directory',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Browse all workers, performance data, and suspension history.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/workers'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _NavSection(
              title: 'Finance',
              children: [
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Color(0xFF0F766E)),
                    ),
                    title: const Text(
                      'Finance',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Open payouts and refunds ledgers in one place.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/finance'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.payments_rounded,
                          color: Color(0xFF0F766E)),
                    ),
                    title: const Text(
                      'Payouts Ledger',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Review worker payout status and retry failed transfers.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/finance/payouts'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: Color(0xFFEF4444)),
                    ),
                    title: const Text(
                      'Refunds Ledger',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Review refund processing and retry failures.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/finance/refunds'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _NavSection(
              title: 'Analytics',
              children: [
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.insights_rounded,
                          color: Color(0xFF2563EB)),
                    ),
                    title: const Text(
                      'Analytics',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Inspect marketplace performance and trend reporting.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/analytics'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _NavSection(
              title: 'Account',
              children: [
                _SurfacePanel(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: Color(0xFF334155)),
                    ),
                    title: const Text(
                      'Profile',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                        'Open your account profile and session details.'),
                    trailing: TextButton(
                      onPressed: () => context.go('/profile'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const PremiumSectionHeader(
              title: 'Operations snapshot',
              subtitle: 'Key numbers and queues that need attention now.',
            ),
            const SizedBox(height: 12),
            const _AdminMetric(
                label: 'Service completion rate', value: '96.2%'),
            const SizedBox(height: 12),
            const _AdminMetric(
                label: 'Open support tickets', value: '07 active'),
            const SizedBox(height: 12),
            const _AdminMetric(
                label: 'Today\'s new workers', value: '11 applicants'),
          ],
        ),
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
    return _SurfacePanel(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        trailing: Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF13110F),
          ),
        ),
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  const _NavSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF13110F),
            ),
          ),
        ),
        ...children.map(
          (child) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: child,
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
