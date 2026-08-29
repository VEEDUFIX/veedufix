import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/worker_earnings_repository.dart';

import '../../domain/entities/worker_earnings.dart';
import '../providers/earnings_provider.dart';
import '../../../../core/widgets/liquid_refresh.dart';
import '../../../../core/widgets/metallic_card.dart';

final workerPayoutProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.get('/users/me');
});

class EarningsPage extends ConsumerStatefulWidget {
  const EarningsPage({super.key});

  @override
  ConsumerState<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends ConsumerState<EarningsPage> {
  static const int _pageSize = 6;

  late final WorkerEarningsRepository _repo;
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
    _repo = ref.read(workerEarningsRepositoryProvider);
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
      final summary = await _repo.fetchSummary();
      final page = await _repo.fetchTransactions(page: 1, limit: _pageSize);
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
      final page = await _repo.fetchTransactions(page: nextPage, limit: _pageSize);
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
    final payoutProfileAsync = ref.watch(workerPayoutProfileProvider);
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
    final payoutProfile = payoutProfileAsync.valueOrNull ?? const <String, dynamic>{};
    final userMap = (payoutProfile['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final workerProfile = (userMap['workerProfile'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final hasUpi = _nonEmpty(workerProfile['upiId']) != null;
    final hasBank = _nonEmpty(workerProfile['bankAccountNumber']) != null &&
        _nonEmpty(workerProfile['bankIfsc']) != null;
    final payoutSetupLabel = hasUpi || hasBank ? 'Ready for payout' : 'Add UPI or bank details';
    final payoutSetupSubtitle = hasUpi
        ? 'UPI is set for RazorpayX payouts.'
        : hasBank
            ? 'Bank transfer details are ready for RazorpayX payouts.'
            : 'Complete onboarding to enable worker payouts.';
    final latestStatus = _transactions.isNotEmpty ? _transactions.first.status : 'pending';
    final recentPayouts = _transactions.where((entry) => entry.status == 'success' || entry.status == 'processing').take(4).toList(growable: false);
    final recentFailures = _transactions.where((entry) => entry.status == 'failed').take(2).toList(growable: false);

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
                      title: 'Payout setup',
                      subtitle: 'Make sure the worker can receive automatic payouts.',
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
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    hasUpi || hasBank ? Icons.verified_rounded : Icons.warning_rounded,
                                    color: hasUpi || hasBank ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        payoutSetupLabel,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        payoutSetupSubtitle,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!hasUpi && !hasBank) ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => context.push('/profile/edit'),
                                  child: const Text('Set up payout'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetric(
                            title: 'Payout ready',
                            value: hasUpi || hasBank ? 'Yes' : 'No',
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniMetric(
                            title: 'Latest status',
                            value: _formatStatusLabel(latestStatus),
                            icon: Icons.history_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PremiumGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payout management',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Open the wallet, update payout details, or ask for help if a withdrawal is stuck.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.icon(
                                  onPressed: () => context.push('/wallet'),
                                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                                  label: const Text('Open wallet'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => context.push('/profile/edit'),
                                  icon: const Icon(Icons.person_rounded, size: 18),
                                  label: const Text('Edit payout details'),
                                ),
                                TextButton.icon(
                                  onPressed: () => context.push(
                                    '/support?autoCompose=true&initialCategory=payment&initialSubject=${Uri.encodeComponent('Payout or wallet issue')}&initialMessage=${Uri.encodeComponent('I need help with my worker payout setup or a withdrawal that needs attention.')}',
                                  ),
                                  icon: const Icon(Icons.support_agent_rounded, size: 18),
                                  label: const Text('Get support'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const PremiumSectionHeader(
                      title: 'Recent payouts',
                      subtitle: 'Track the most recent settlements and payout attempts.',
                    ),
                    const SizedBox(height: 12),
                    PremiumGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: recentPayouts.isEmpty
                            ? Text(
                                'No successful or processing payouts yet.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              )
                            : Column(
                                children: recentPayouts.map((entry) {
                                  final accent = entry.status == 'success'
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: TapScale(
                                      onTap: () => _showTransactionDetails(context, entry),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surface,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              height: 42,
                                              width: 42,
                                              decoration: BoxDecoration(
                                                color: accent.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: Icon(
                                                entry.status == 'success'
                                                    ? Icons.check_circle_outline_rounded
                                                    : Icons.schedule_rounded,
                                                color: accent,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    entry.bookingCode?.isNotEmpty == true
                                                        ? 'Booking ${entry.bookingCode}'
                                                        : entry.serviceName,
                                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${_formatMoney(entry.amount)} - ${_formatStatusLabel(entry.status)}',
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(growable: false),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (recentFailures.isNotEmpty)
                      PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payout issues',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                recentFailures.first.status == 'failed'
                                    ? 'A payout attempt needs attention.'
                                    : recentFailures.first.status,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
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
                                        : '₹0',
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
                      onTap: () => context.push('/wallet'),
                      child: const MetallicCard(
                        title: 'Withdraw Earnings',
                        subtitle: 'Open wallet to request a real payout',
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
                        onTap: () => _showTransactionDetails(context, entry),
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

String? _nonEmpty(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String _formatMoney(double value) {
  return NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
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
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool positive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = positive ? const Color(0xFF10B981) : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TapScale(
        onTap: onTap,
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
      ),
    );
  }
}

Future<void> _showTransactionDetails(BuildContext context, WorkerEarningsTransaction entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final tt = Theme.of(sheetContext).textTheme;
      final cs = Theme.of(sheetContext).colorScheme;
      final accent = entry.status == 'success' ? const Color(0xFF10B981) : cs.primary;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: Icon(
                      entry.status == 'success' ? Icons.check_circle_outline_rounded : Icons.receipt_long_rounded,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.serviceName, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(_formatStatusLabel(entry.status), style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Booking', value: entry.bookingCode?.isNotEmpty == true ? entry.bookingCode! : entry.bookingId),
              _DetailRow(label: 'Amount', value: _formatMoney(entry.amount)),
              _DetailRow(label: 'Commission', value: _formatMoney(entry.commissionAmount)),
              _DetailRow(label: 'Date', value: DateFormat('d MMM y, h:mm a').format(entry.date)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: entry.bookingId));
                        if (sheetContext.mounted) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('Booking ID copied')),
                          );
                        }
                      },
                      child: const Text('Copy booking ID'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
