import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/disputes_api.dart';

class DisputesQueuePage extends ConsumerStatefulWidget {
  const DisputesQueuePage({super.key});

  @override
  ConsumerState<DisputesQueuePage> createState() => _DisputesQueuePageState();
}

class _DisputesQueuePageState extends ConsumerState<DisputesQueuePage> {
  late final DisputesApi _api;
  late Future<DisputeQueueResponse> _queueFuture;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _api = DisputesApi(ref.read(apiClientProvider).dio);
    _queueFuture = _api.fetchQueue(pageSize: 100);
  }

  Future<void> _reload() async {
    setState(() {
      _queueFuture = _api.fetchQueue(pageSize: 100);
    });
    await _queueFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Disputes queue',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<DisputeQueueResponse>(
        future: _queueFuture,
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

          final items = snapshot.data?.items ?? const <DisputeQueueItem>[];
          final filteredItems = _statusFilter == 'all'
              ? items
              : items
                  .where((item) => item.status == _statusFilter)
                  .toList(growable: false);

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
                            'Open disputes and under-review cases.',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review customer complaints, evidence, and refund decisions in one queue.',
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
                              _MiniStat(
                                  label: 'Total', value: '${items.length}'),
                              _MiniStat(
                                  label: 'Open',
                                  value:
                                      '${items.where((item) => item.status == 'open').length}'),
                              _MiniStat(
                                  label: 'Under review',
                                  value:
                                      '${items.where((item) => item.status == 'under_review').length}'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 280,
                            child: DropdownButtonFormField<String>(
                              initialValue: _statusFilter,
                              decoration: const InputDecoration(
                                labelText: 'Filter by status',
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'all', child: Text('All')),
                                DropdownMenuItem(
                                    value: 'open', child: Text('Open')),
                                DropdownMenuItem(
                                    value: 'under_review',
                                    child: Text('Under review')),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _statusFilter = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filteredItems.isEmpty)
                    const _SurfacePanel(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: PremiumEmptyState(
                          icon: Icons.gavel_rounded,
                          title: 'No disputes match this filter',
                          subtitle:
                              'Open or under-review disputes will appear here when customers raise them.',
                        ),
                      ),
                    )
                  else
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
                                DataColumn(label: Text('WORKER')),
                                DataColumn(label: Text('STATUS')),
                                DataColumn(label: Text('RAISED ON')),
                                DataColumn(label: Text('ACTION')),
                              ],
                              rows: filteredItems.map((item) {
                                return DataRow(
                                  onSelectChanged: (_) => context.go('/ops/disputes/${item.id}'),
                                  cells: [
                                    DataCell(Text(
                                      item.bookingCode,
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
                                        Text(item.customerName),
                                      ],
                                    )),
                                    DataCell(Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Color(0xFFF3F4F6),
                                          child: Icon(Icons.handyman_rounded, size: 16, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(item.workerName ?? 'Unknown'),
                                      ],
                                    )),
                                    DataCell(_GlowingStatusBadge(status: item.status)),
                                    DataCell(Text(MaterialLocalizations.of(context).formatMediumDate(item.createdAt))),
                                    const DataCell(Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8))),
                                  ],
                                );
                              }).toList(growable: false),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5D8C6)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.inter(
            color: const Color(0xFF13110F),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
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
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

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
              'Unable to load disputes',
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
