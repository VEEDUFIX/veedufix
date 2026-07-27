import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/finance_api.dart';

class PayoutsLedgerPage extends ConsumerStatefulWidget {
  const PayoutsLedgerPage({super.key});

  @override
  ConsumerState<PayoutsLedgerPage> createState() => _PayoutsLedgerPageState();
}

class _PayoutsLedgerPageState extends ConsumerState<PayoutsLedgerPage> {
  late final FinanceApi _api;
  late Future<FinancePayoutQueueResponse> _payoutsFuture;
  String _selectedStatus = 'all';
  bool _busy = false;
  int _page = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _api = FinanceApi(ref.read(apiClientProvider).dio);
    _payoutsFuture = _loadPayouts();
  }

  Future<FinancePayoutQueueResponse> _loadPayouts() {
    return _api.fetchPayouts(
      status: _selectedStatus,
      page: _page,
      limit: _limit,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _payoutsFuture = _loadPayouts();
    });
    await _payoutsFuture;
  }

  Future<void> _retry(String payoutId) async {
    setState(() => _busy = true);
    try {
      await _api.retryPayout(payoutId);
      if (!mounted) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout retry queued')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Color _badgeColors(String status) {
    return switch (status) {
      'pending' => const Color(0xFFF59E0B),
      'processing' => const Color(0xFF2563EB),
      'success' => const Color(0xFF0F766E),
      'failed' => const Color(0xFFEF4444),
      _ => const Color(0xFF64748B),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
        surfaceTintColor: Colors.transparent,
        title: const Text('Payouts ledger'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<FinancePayoutQueueResponse>(
        future: _payoutsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              error: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final data = snapshot.data ??
              const FinancePayoutQueueResponse(
                  items: [], page: 1, limit: 20, total: 0, totalPages: 1);

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF9F5EC), Color(0xFFFFFCF8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _SurfacePanel(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payouts ledger',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: const Color(0xFF13110F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review every worker payout attempt and retry failed transfers when needed.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF6B6256),
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              PremiumStatCard(
                                label: 'Total payouts',
                                value: '${data.total}',
                                icon: Icons.payments_rounded,
                                accentColor: const Color(0xFF2563EB),
                              ),
                              PremiumStatCard(
                                label: 'Status filter',
                                value: _selectedStatus == 'all'
                                    ? 'All'
                                    : _selectedStatus,
                                icon: Icons.filter_alt_rounded,
                                accentColor: const Color(0xFF0F766E),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SurfacePanel(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Filters',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (_busy) const SizedBox(width: 12),
                              if (_busy)
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              prefixIcon: Icon(Icons.flag_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'all', child: Text('All statuses')),
                              DropdownMenuItem(
                                  value: 'pending', child: Text('Pending')),
                              DropdownMenuItem(
                                  value: 'processing',
                                  child: Text('Processing')),
                              DropdownMenuItem(
                                  value: 'success', child: Text('Success')),
                              DropdownMenuItem(
                                  value: 'failed', child: Text('Failed')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value ?? 'all';
                                _page = 1;
                                _payoutsFuture = _loadPayouts();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...data.items.map(
                    (payout) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PayoutLedgerCard(
                        payout: payout,
                        badgeColor: _badgeColors(payout.status),
                        onRetry: payout.status == 'failed'
                            ? () => _retry(payout.id)
                            : null,
                      ),
                    ),
                  ),
                  if (data.totalPages > 1) ...[
                    const SizedBox(height: 8),
                    _SurfacePanel(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              'Page ${data.page} of ${data.totalPages}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _page <= 1
                                  ? null
                                  : () async {
                                      setState(() {
                                        _page -= 1;
                                        _payoutsFuture = _loadPayouts();
                                      });
                                      await _payoutsFuture;
                                    },
                              child: const Text('Previous'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: _page >= data.totalPages
                                  ? null
                                  : () async {
                                      setState(() {
                                        _page += 1;
                                        _payoutsFuture = _loadPayouts();
                                      });
                                      await _payoutsFuture;
                                    },
                              child: const Text('Next'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PayoutLedgerCard extends StatelessWidget {
  const _PayoutLedgerCard({
    required this.payout,
    required this.badgeColor,
    required this.onRetry,
  });

  final FinancePayoutItem payout;
  final Color badgeColor;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5D8C6)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payout.bookingCode.isNotEmpty
                          ? payout.bookingCode
                          : payout.bookingId,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payout.workerName ?? 'Unknown worker',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              _Badge(
                label: payout.status.replaceAll('_', ' '),
                color: badgeColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _InfoPill(
                  label: 'Amount',
                  value: 'Rs. ${payout.amount.toStringAsFixed(2)}'),
              _InfoPill(
                  label: 'Commission',
                  value: 'Rs. ${payout.commissionAmount.toStringAsFixed(2)}'),
              _InfoPill(
                  label: 'Created',
                  value: MaterialLocalizations.of(context)
                      .formatMediumDate(payout.createdAt)),
            ],
          ),
          if ((payout.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              payout.failureReason!.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFB45309),
                    height: 1.4,
                  ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9DED0)),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF13110F),
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(
              'Unable to load finance ledger',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
