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
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
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
                            'Open disputes and under-review cases.',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color: const Color(0xFF13110F),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review customer complaints, evidence, and refund decisions in one queue.',
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
                    ...filteredItems.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _SurfacePanel(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: _StatusMark(status: item.status),
                            title: Text(
                              item.bookingCode,
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              [
                                'Customer: ${item.customerName}',
                                'Worker: ${item.workerName ?? 'Not returned by API'}',
                                'Reason: ${_truncate(item.reason)}',
                                'Raised: ${MaterialLocalizations.of(context).formatMediumDate(item.createdAt)}',
                              ].join('\n'),
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.go('/ops/disputes/${item.id}'),
                          ),
                        ),
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

String _truncate(String value, {int maxLength = 110}) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return '${normalized.substring(0, maxLength - 1)}…';
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

class _StatusMark extends StatelessWidget {
  const _StatusMark({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'under_review'
        ? const Color(0xFFF59E0B)
        : const Color(0xFF2563EB);
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.gavel_rounded, color: color),
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
