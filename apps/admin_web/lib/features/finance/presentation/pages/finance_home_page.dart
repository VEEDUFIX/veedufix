import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../admin/presentation/widgets/admin_surface.dart';
import '../../data/finance_api.dart';

class FinanceHomePage extends ConsumerStatefulWidget {
  const FinanceHomePage({super.key});

  @override
  ConsumerState<FinanceHomePage> createState() => _FinanceHomePageState();
}

class _FinanceHomePageState extends ConsumerState<FinanceHomePage> {
  late final FinanceApi _api;
  late Future<_FinanceHomeSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _api = FinanceApi(ref.read(apiClientProvider).dio);
    _future = _load();
  }

  Future<_FinanceHomeSnapshot> _load() async {
    final payouts = await _api.fetchPayouts(limit: 10);
    final refunds = await _api.fetchRefunds(pageSize: 10);
    return _FinanceHomeSnapshot(payouts: payouts, refunds: refunds);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageShell(
      title: 'Finance',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: FutureBuilder<_FinanceHomeSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Finance overview unavailable',
                subtitle: snapshot.error.toString(),
                actionLabel: 'Try again',
                onAction: _refresh,
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const SizedBox.shrink();
          }

          final payoutItems = data.payouts.items;
          final refundItems = data.refunds.items;
          final failedPayouts = payoutItems.where((item) => item.status.toLowerCase().contains('fail')).length;
          final failedRefunds = refundItems.where((item) => item.status.toLowerCase().contains('fail')).length;
          final openPayouts = payoutItems.where((item) {
            final status = item.status.toLowerCase();
            return status.contains('pending') || status.contains('processing');
          }).length;
          final openRefunds = refundItems.where((item) {
            final status = item.status.toLowerCase();
            return status.contains('pending') || status.contains('processing');
          }).length;
          final attentionCount = failedPayouts + failedRefunds + openPayouts + openRefunds;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const AdminSurfacePanel(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ledger and recovery queues',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: kAdminInk,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Track worker payouts and customer refunds from one finance workspace.',
                        style: TextStyle(
                          color: kAdminMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Payout queue',
                    value: payoutItems.length.toString(),
                    subtitle: '$failedPayouts failing',
                    color: const Color(0xFF0F766E),
                    icon: Icons.payments_rounded,
                  ),
                  _MetricTile(
                    label: 'Refund queue',
                    value: refundItems.length.toString(),
                    subtitle: '$failedRefunds failing',
                    color: const Color(0xFFEF4444),
                    icon: Icons.receipt_long_rounded,
                  ),
                  _MetricTile(
                    label: 'Total payouts',
                    value: NumberFormat.compact().format(data.payouts.total),
                    subtitle: 'Fetched from the first page',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  _MetricTile(
                    label: 'Tax summary',
                    value: 'Open',
                    subtitle: 'GST + revenue view',
                    color: const Color(0xFF3B82F6),
                    icon: Icons.request_quote_rounded,
                    onTap: () => context.go('/finance/tax-summary'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const AdminSurfacePanel(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automation coverage',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kAdminInk,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Worker payouts trigger after completion OTP, refunds flow through Razorpay refund webhooks, and failed transfers stay visible in the ledgers.',
                        style: TextStyle(
                          color: kAdminMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricTile(
                    label: 'Attention queue',
                    value: attentionCount.toString(),
                    subtitle: 'Open or failed payout/refund items',
                    color: const Color(0xFF7C3AED),
                    icon: Icons.admin_panel_settings_rounded,
                  ),
                  const _MetricTile(
                    label: 'Webhook route',
                    value: '2',
                    subtitle: 'Payment + refund callbacks',
                    color: Color(0xFF2563EB),
                    icon: Icons.cable_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const AdminSurfacePanel(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Webhook & reconciliation',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: kAdminInk,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Payment webhook: /api/webhooks/razorpay. Refund webhook: /api/webhooks/razorpay. Review any open or failed payouts and refunds here if the callback lagged.',
                        style: TextStyle(
                          color: kAdminMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 360,
                    child: AdminSurfacePanel(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.payments_rounded, color: Color(0xFF0F766E)),
                        ),
                        title: const Text(
                          'Payouts ledger',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          payoutItems.isEmpty
                              ? 'No payout records on this page.'
                              : 'Latest: ${payoutItems.first.bookingCode.isEmpty ? 'queued item' : payoutItems.first.bookingCode}',
                        ),
                        trailing: TextButton(
                          onPressed: () => context.go('/finance/payouts'),
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: AdminSurfacePanel(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Color(0xFFEF4444)),
                        ),
                        title: const Text(
                          'Refunds ledger',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          refundItems.isEmpty
                              ? 'No refund records on this page.'
                              : 'Latest: ${refundItems.first.bookingCode.isEmpty ? 'queued item' : refundItems.first.bookingCode}',
                        ),
                        trailing: TextButton(
                          onPressed: () => context.go('/finance/refunds'),
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: AdminSurfacePanel(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.request_quote_rounded, color: Color(0xFF3B82F6)),
                        ),
                        title: const Text(
                          'Tax summary',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text('GST and revenue view for CA prep.'),
                        trailing: TextButton(
                          onPressed: () => context.go('/finance/tax-summary'),
                          child: const Text('Open'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _LatestFailureCard(
                      title: 'Recent payout failures',
                      icon: Icons.warning_rounded,
                      color: const Color(0xFF0F766E),
                      items: _toFailureItems(
                        payoutItems.where((item) => item.status.toLowerCase().contains('fail')).take(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _LatestFailureCard(
                      title: 'Recent refund failures',
                      icon: Icons.error_outline_rounded,
                      color: const Color(0xFFEF4444),
                      items: _toFailureItems(
                        refundItems.where((item) => item.status.toLowerCase().contains('fail')).take(4),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FinanceHomeSnapshot {
  const _FinanceHomeSnapshot({
    required this.payouts,
    required this.refunds,
  });

  final FinancePayoutQueueResponse payouts;
  final FinanceRefundQueueResponse refunds;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AdminSurfacePanel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12, color: kAdminMuted)),
                      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(subtitle, style: const TextStyle(fontSize: 12, color: kAdminMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LatestFailureCard extends StatelessWidget {
  const _LatestFailureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<_FinanceFailureItem> items;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return AdminSurfacePanel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('No failures on the first page yet.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
            else
              Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          '${item.bookingCode.isEmpty ? item.id : item.bookingCode} - ${item.failureReason ?? item.status}',
                          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinanceFailureItem {
  const _FinanceFailureItem({
    required this.id,
    required this.bookingCode,
    required this.failureReason,
    required this.status,
  });

  final String id;
  final String bookingCode;
  final String? failureReason;
  final String status;
}

List<_FinanceFailureItem> _toFailureItems(Iterable<Object?> items) {
  return items
      .map((item) {
        if (item is FinancePayoutItem) {
          return _FinanceFailureItem(
            id: item.id,
            bookingCode: item.bookingCode,
            failureReason: item.failureReason,
            status: item.status,
          );
        }
        if (item is FinanceRefundItem) {
          return _FinanceFailureItem(
            id: item.id,
            bookingCode: item.bookingCode,
            failureReason: item.failureReason,
            status: item.status,
          );
        }
        return const _FinanceFailureItem(id: '', bookingCode: '', failureReason: null, status: '');
      })
      .where((item) => item.id.isNotEmpty || item.bookingCode.isNotEmpty)
      .toList(growable: false);
}
