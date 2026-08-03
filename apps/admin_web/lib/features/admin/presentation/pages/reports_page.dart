import 'package:flutter/material.dart';
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
            TapScale(
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
          ],
        ),
      ),
    );
  }
}
