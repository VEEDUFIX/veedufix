import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../providers/earnings_provider.dart';
import '../../../../core/widgets/liquid_refresh.dart';
import '../../../../core/widgets/metallic_card.dart';

class EarningsPage extends ConsumerStatefulWidget {
  const EarningsPage({super.key});

  @override
  ConsumerState<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends ConsumerState<EarningsPage> {
  static const int _pageSize = 6;

  late final WorkerEarningsApi _api;
  final ScrollController _scrollController = ScrollController();

  WorkerEarningsSummary? _summary;
  final List<WorkerEarningsTransaction> _transactions = <WorkerEarningsTransaction>[];
  String? _loadError;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _api = WorkerEarningsApi(ref.read(apiClientProvider).dio);
    _scrollController.addListener(_handleScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _loadError = null;
      _summary = null;
      _transactions.clear();
      _page = 0;
      _hasMore = true;
      _loadingMore = false;
    });

    try {
      final summary = await _api.fetchSummary();
      final page = await _api.fetchTransactions(page: 1, limit: _pageSize);
      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _transactions
          ..clear()
          ..addAll(page.items);
        _page = page.page;
        _hasMore = page.hasMore;
        _loadingInitial = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error.toString();
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingInitial || _loadingMore || !_hasMore) {
      return;
    }

    setState(() => _loadingMore = true);

    try {
      final nextPage = _page + 1;
      final page = await _api.fetchTransactions(page: nextPage, limit: _pageSize);
      if (!mounted) {
        return;
      }

      setState(() {
        _transactions.addAll(page.items);
        _page = page.page;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingMore = false);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.extentAfter < 700) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial && _transactions.isEmpty) {
      return Scaffold(
        body: LiquidRefresh(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: const [
              SizedBox(height: 96),
              Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    if (_loadError != null && _transactions.isEmpty) {
      return Scaffold(
        body: LiquidRefresh(
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const SizedBox(height: 72),
              PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load earnings',
                subtitle: _loadError!,
                actionLabel: 'Try again',
                onAction: _reload,
              ),
            ],
          ),
        ),
      );
    }

    final summary = _summary;
    if (summary == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      body: LiquidRefresh(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Earnings',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                        ),
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                          ),
                          child: IconButton(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: PremiumStatCard(
                            label: 'Today',
                            value: _formatMoney(summary.todayTotal),
                            icon: Icons.today_rounded,
                            accentColor: const Color(0xFFC2A15E),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PremiumStatCard(
                            label: 'Weekly',
                            value: _formatMoney(summary.weeklyTotal),
                            icon: Icons.date_range_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PremiumStatCard(
                      label: 'Monthly',
                      value: _formatMoney(summary.monthlyTotal),
                      icon: Icons.payments_rounded,
                      accentColor: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 18),
                    const PremiumSectionHeader(
                      title: 'Performance snapshot',
                      subtitle: 'A calm overview of earnings, jobs, and payouts.',
                    ),
                    const SizedBox(height: 12),
                    PremiumGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'This week',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                const _LegendDot(color: Color(0xFF38BDF8), label: 'Daily earnings'),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _MiniChart(points: summary.chartData),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniMetric(
                                    title: 'Settled payouts',
                                    value: '${_transactions.where((entry) => entry.status == 'success').length}',
                                    icon: Icons.check_circle_outline_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _MiniMetric(
                                    title: 'Latest payout',
                                    value: _transactions.isNotEmpty
                                        ? _formatMoney(_transactions.first.amount)
                                        : 'Rs 0',
                                    icon: Icons.schedule_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TapScale(
                      onTap: () async {
                        try {
                          await ref.read(apiClientProvider).dio.post(
                                '/wallet/payout',
                                data: {'amount': 100},
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payout requested successfully!')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to request payout')),
                            );
                          }
                        }
                      },
                      child: const MetallicCard(
                        title: 'Instant Cashout',
                        subtitle: 'Powered by RazorpayX',
                        icon: Icons.account_balance_wallet_rounded,
                        baseColor: Color(0xFF14B8A6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const PremiumSectionHeader(
                      title: 'Transaction history',
                      subtitle: 'Recent settlements and payment updates.',
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_transactions.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: PremiumEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No transactions yet',
                    subtitle: 'Your completed jobs and payouts will appear here.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = _transactions[index];
                      return _TransactionTile(
                        title: entry.serviceName,
                        subtitle: _buildTransactionSubtitle(entry),
                        amount: _formatMoney(entry.amount),
                        positive: entry.status == 'success',
                      );
                    },
                    childCount: _transactions.length,
                  ),
                ),
              ),
            if (_loadingMore)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_hasMore && _transactions.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Scroll to load more transactions',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(double value) {
  return NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 0).format(value);
}

String _buildTransactionSubtitle(WorkerEarningsTransaction entry) {
  final bookingLabel =
      entry.bookingCode?.isNotEmpty == true ? 'Booking ${entry.bookingCode}' : 'Booking';
  final dateLabel = DateFormat('dd MMM yyyy').format(entry.date);
  final statusLabel = _formatStatusLabel(entry.status);
  return '$bookingLabel - $dateLabel - $statusLabel';
}

String _formatStatusLabel(String status) {
  switch (status) {
    case 'success':
      return 'Settled';
    case 'processing':
      return 'Processing';
    case 'pending':
      return 'Pending';
    case 'failed':
      return 'Failed';
    default:
      return status.replaceAll('_', ' ');
  }
}

class _MiniChart extends StatelessWidget {
  const _MiniChart({
    required this.points,
  });

  final List<WorkerEarningsChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxAmount = math.max(
      1,
      points.fold<double>(0, (highest, point) => math.max(highest, point.amount)).ceil(),
    );

    return SizedBox(
      height: 194,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 150,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        height: 150 * (point.amount / maxAmount),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    width: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('EEE').format(point.date),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.positive,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final accent = positive ? const Color(0xFF10B981) : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumGlassCard(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
            ),
            child: Icon(
              positive ? Icons.south_east_rounded : Icons.north_east_rounded,
              color: accent,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle),
          ),
          trailing: Text(
            amount,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
          ),
        ),
      ),
    );
  }
}
