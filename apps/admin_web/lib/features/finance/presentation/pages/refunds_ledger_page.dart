import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/finance_api.dart';

class RefundsLedgerPage extends ConsumerStatefulWidget {
  const RefundsLedgerPage({super.key});

  @override
  ConsumerState<RefundsLedgerPage> createState() => _RefundsLedgerPageState();
}

class _RefundsLedgerPageState extends ConsumerState<RefundsLedgerPage> {
  late final FinanceApi _api;
  late Future<FinanceRefundQueueResponse> _refundsFuture;
  String _selectedStatus = 'all';
  bool _busy = false;
  int _page = 1;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _api = FinanceApi(ref.read(apiClientProvider).dio);
    _refundsFuture = _loadRefunds();
  }

  Future<FinanceRefundQueueResponse> _loadRefunds() {
    return _api.fetchRefunds(
      status: _selectedStatus,
      page: _page,
      pageSize: _pageSize,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _refundsFuture = _loadRefunds();
    });
    await _refundsFuture;
  }

  Future<void> _retry(String refundId) async {
    setState(() => _busy = true);
    try {
      await _api.retryRefund(refundId);
      if (!mounted) {
        return;
      }
      await _reload();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Refund retry queued')),
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
      final result = await _api.bulkRetryRefunds();
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
    final url = _api.refundsCsvUrl(status: _selectedStatus);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Refunds ledger'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
      body: FutureBuilder<FinanceRefundQueueResponse>(
        future: _refundsFuture,
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
              const FinanceRefundQueueResponse(
                  items: [], page: 1, pageSize: 20, total: 0);

          return Container(
            color: Colors.transparent,
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
                            'Refunds ledger',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Track customer refunds, review failure reasons, and retry failed refunds when required.',
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
                                label: 'Total refunds',
                                value: '${data.total}',
                                icon: Icons.receipt_long_rounded,
                                accentColor: const Color(0xFFEF4444),
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
                                  value: 'processed', child: Text('Processed')),
                              DropdownMenuItem(
                                  value: 'failed', child: Text('Failed')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value ?? 'all';
                                _page = 1;
                                _refundsFuture = _loadRefunds();
                              });
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
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                DataColumn(label: Text('CUSTOMER')),
                                DataColumn(label: Text('AMOUNT')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('CREATED')),
                                DataColumn(label: Text('REASON')),
                                DataColumn(label: Text('ACTION')),
                              ],
                              rows: data.items.map((refund) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(
                                      refund.bookingCode.isNotEmpty ? refund.bookingCode : refund.bookingId,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    )),
                                    DataCell(Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                          child: Icon(Icons.person_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(refund.customerName ?? 'Unknown'),
                                      ],
                                    )),
                                    DataCell(Text('Rs. ${refund.amount.toStringAsFixed(2)}')),
                                    DataCell(_GlowingStatusBadge(status: refund.status)),
                                    DataCell(Text(MaterialLocalizations.of(context).formatMediumDate(refund.createdAt))),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          refund.reason,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      refund.status == 'failed'
                                          ? TextButton.icon(
                                              onPressed: () => _retry(refund.id),
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
                  if (data.total > data.items.length) ...[
                    const SizedBox(height: 8),
                    _SurfacePanel(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              'Page ${data.page}',
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
                                        _refundsFuture = _loadRefunds();
                                      });
                                      await _refundsFuture;
                                    },
                              child: const Text('Previous'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: data.items.length < _pageSize
                                  ? null
                                  : () async {
                                      setState(() {
                                        _page += 1;
                                        _refundsFuture = _loadRefunds();
                                      });
                                      await _refundsFuture;
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
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
