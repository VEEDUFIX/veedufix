import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/finance_api.dart';

class PayoutsLedgerPage extends ConsumerStatefulWidget {
  const PayoutsLedgerPage({super.key});

  @override
  ConsumerState<PayoutsLedgerPage> createState() => _PayoutsLedgerPageState();
}

class _PayoutsLedgerPageState extends ConsumerState<PayoutsLedgerPage> {
  static const int _limit = 20;

  late final FinanceApi _api;
  final ScrollController _scrollController = ScrollController();

  final List<FinancePayoutItem> _items = <FinancePayoutItem>[];
  String _selectedStatus = 'all';
  String? _loadError;
  bool _busy = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _api = FinanceApi(ref.read(apiClientProvider).dio);
    _scrollController.addListener(_handleScroll);
    _reload();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _loadError = null;
      _items.clear();
      _page = 0;
      _total = 0;
      _hasMore = true;
    });

    try {
      final data = await _api.fetchPayouts(
        status: _selectedStatus,
        page: 1,
        limit: _limit,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _items
          ..clear()
          ..addAll(data.items);
        _page = data.page;
        _total = data.total;
        _hasMore = data.page < data.totalPages;
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
      final data = await _api.fetchPayouts(
        status: _selectedStatus,
        page: _page + 1,
        limit: _limit,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _items.addAll(data.items);
        _page = data.page;
        _total = data.total;
        _hasMore = data.page < data.totalPages;
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

  Future<void> _bulkRetry() async {
    setState(() => _busy = true);
    try {
      final result = await _api.bulkRetryPayouts();
      if (!mounted) return;
      final attempted = result['attempted'] ?? 0;
      final succeeded = result['succeeded'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk retry complete: $succeeded/$attempted succeeded'),
        ),
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    final url = _api.payoutsCsvUrl(status: _selectedStatus);
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open CSV download link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial && _items.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null && _items.isEmpty) {
      return Scaffold(
        body: _ErrorState(
          error: _loadError!,
          onRetry: _reload,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Payouts ledger'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            TextButton.icon(
              onPressed: _exportCsv,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export CSV'),
            ),
            TextButton.icon(
              onPressed: _bulkRetry,
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: const Text('Retry all failed'),
            ),
          ],
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        color: Colors.transparent,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            controller: _scrollController,
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
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review every worker payout attempt and retry failed transfers when needed.',
                        style: GoogleFonts.inter(
                          color: Colors.black54,
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
                            value: '$_total',
                            icon: Icons.payments_rounded,
                            accentColor: const Color(0xFF2563EB),
                          ),
                          PremiumStatCard(
                            label: 'Status filter',
                            value: _selectedStatus == 'all' ? 'All' : _selectedStatus,
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
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
                            value: 'all',
                            child: Text('All statuses'),
                          ),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'processing',
                            child: Text('Processing'),
                          ),
                          DropdownMenuItem(
                            value: 'success',
                            child: Text('Success'),
                          ),
                          DropdownMenuItem(
                            value: 'failed',
                            child: Text('Failed'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value ?? 'all';
                          });
                          _reload();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  boxShadow: AbzioTheme.eliteShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: constraints.maxWidth > 800 ? constraints.maxWidth : 800,
                        child: DataTable(
                          headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
                          headingTextStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.8,
                          ),
                          dataRowMinHeight: 72,
                          dataRowMaxHeight: 72,
                          dividerThickness: 1,
                          horizontalMargin: 24,
                          columns: const [
                            DataColumn(label: Text('REFERENCE')),
                            DataColumn(label: Text('WORKER')),
                            DataColumn(label: Text('AMOUNT')),
                            DataColumn(label: Text('COMMISSION')),
                            DataColumn(label: Text('STATUS')),
                            DataColumn(label: Text('CREATED')),
                            DataColumn(label: Text('ACTION')),
                          ],
                          rows: _items.map((payout) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    payout.bookingCode.isNotEmpty
                                        ? payout.bookingCode
                                        : payout.bookingId,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.12),
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(payout.workerName ?? 'Unknown'),
                                    ],
                                  ),
                                ),
                                DataCell(Text('Rs. ${payout.amount.toStringAsFixed(2)}')),
                                DataCell(Text('Rs. ${payout.commissionAmount.toStringAsFixed(2)}')),
                                DataCell(_GlowingStatusBadge(status: payout.status)),
                                DataCell(
                                  Text(MaterialLocalizations.of(context).formatMediumDate(payout.createdAt)),
                                ),
                                DataCell(
                                  payout.status == 'failed'
                                      ? TextButton.icon(
                                          onPressed: () => _retry(payout.id),
                                          icon: const Icon(Icons.refresh_rounded, size: 16),
                                          label: const Text('Retry'),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _SurfacePanel(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Showing ${_items.length} of $_total',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const Spacer(),
                      if (_loadingMore)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_hasMore)
                        Text(
                          'Scroll to load more',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        )
                      else
                        Text(
                          'End of results',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_loadError != null && _items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Last refresh failed: $_loadError',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowingStatusBadge extends StatelessWidget {
  const _GlowingStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final (color, bgColor) = switch (normalized) {
      'approved' || 'success' || 'processed' => (const Color(0xFF10B981), const Color(0xFFD1FAE5)),
      'suspended' || 'pending' || 'under_review' => (const Color(0xFFF59E0B), const Color(0xFFFEF3C7)),
      'rejected' || 'failed' => (const Color(0xFFEF4444), const Color(0xFFFEE2E2)),
      'disputed' => (const Color(0xFF8B5CF6), const Color(0xFFEDE9FE)),
      _ => (const Color(0xFF64748B), const Color(0xFFF1F5F9)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: AbzioTheme.eliteShadow,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            normalized.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
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

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: AbzioTheme.eliteShadow,
      ),
      child: child,
    );
  }
}
