import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../admin/presentation/widgets/admin_surface.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final api = ref.read(apiClientProvider);

    // Build base URL from ApiClient's base URL (remove /api to get to root if needed, or just append)
    final baseUrl = api.dio.options.baseUrl.replaceAll(RegExp(r'/api$'), '');

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text('Reports & Exports', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.summarize_rounded, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports command center',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Export bookings, payouts, and earnings without hunting through multiple screens.',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _ReportPill(label: 'Bookings CSV', icon: Icons.receipt_long_rounded),
                            _ReportPill(label: 'Finance exports', icon: Icons.payments_rounded),
                            _ReportPill(label: 'Audit-ready', icon: Icons.verified_rounded),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const PremiumSectionHeader(title: 'CSV Downloads'),
          const SizedBox(height: 12),
          AdminSurfacePanel(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saved report presets', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _download('$baseUrl/api/admin/reports/bookings?status=COMPLETED'),
                        child: const Text('Completed bookings'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _download('$baseUrl/api/admin/reports/payouts?status=pending'),
                        child: const Text('Pending payouts'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _download('$baseUrl/api/admin/reports/payouts?status=failed'),
                        child: const Text('Failed payouts'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.go('/finance'),
                        icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                        label: const Text('Finance hub'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/audit-logs'),
                        icon: const Icon(Icons.manage_search_rounded, size: 16),
                        label: const Text('Audit logs'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: '$baseUrl/api/admin/reports/bookings'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bookings export URL copied')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy bookings URL'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Bookings Report',
            subtitle: 'All bookings with status, customer, worker, amount',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF6366F1),
            onDownload: () => _download('$baseUrl/api/admin/reports/bookings'),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Earnings Report',
            subtitle: 'Worker credit transactions and balances',
            icon: Icons.payments_rounded,
            color: const Color(0xFF10B981),
            onDownload: () => _download('$baseUrl/api/admin/reports/earnings'),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Payout Requests',
            subtitle: 'Pending UPI payout requests from workers',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFFF59E0B),
            onDownload: () => _download('$baseUrl/api/admin/reports/payouts'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onDownload,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Tooltip(
              message: 'Download CSV',
              child: TapScale(
                onTap: onDownload,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.download_rounded, color: color, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPill extends StatelessWidget {
  const _ReportPill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
