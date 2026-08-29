import 'package:flutter/services.dart';
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
  static const int _pageSize = 20;

  late final DisputesApi _api;
  final ScrollController _scrollController = ScrollController();

  final List<DisputeQueueItem> _items = <DisputeQueueItem>[];
  String _statusFilter = 'all';
  String? _loadError;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _api = DisputesApi(ref.read(apiClientProvider).dio);
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
      final data = await _api.fetchQueue(
        status: _statusFilter == 'all' ? null : _statusFilter,
        page: 1,
        pageSize: _pageSize,
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
        _hasMore = _items.length < _total;
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
      final data = await _api.fetchQueue(
        status: _statusFilter == 'all' ? null : _statusFilter,
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _items.addAll(data.items);
        _page = data.page;
        _total = data.total;
        _hasMore = _items.length < _total;
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

  Future<void> _openDispute(String id) async {
    context.go('/ops/disputes/$id');
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial && _items.isEmpty) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(24),
          child: _DisputesSkeleton(),
        ),
      );
    }

    if (_loadError != null && _items.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: PremiumEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load disputes',
              subtitle:
                  'The dispute queue is unavailable right now. Please retry.',
              actionLabel: 'Retry',
              onAction: _reload,
            ),
          ),
        ),
      );
    }

    final filteredItems = _items;

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
                          _MiniStat(label: 'Total', value: '$_total'),
                          _MiniStat(
                            label: 'Open',
                            value: '${filteredItems.where((item) => item.status == 'open').length}',
                          ),
                          _MiniStat(
                            label: 'Under review',
                            value: '${filteredItems.where((item) => item.status == 'under_review').length}',
                          ),
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
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(value: 'open', child: Text('Open')),
                            DropdownMenuItem(
                              value: 'under_review',
                              child: Text('Under review'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _statusFilter = value;
                            });
                            _reload();
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
                              DataColumn(label: Text('CUSTOMER')),
                              DataColumn(label: Text('WORKER')),
                              DataColumn(label: Text('STATUS')),
                              DataColumn(label: Text('RAISED ON')),
                              DataColumn(label: Text('ACTION')),
                            ],
                            rows: filteredItems.map((item) {
                              return DataRow(
                                onSelectChanged: (_) => _openDispute(item.id),
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.bookingCode,
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Copy booking code',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () async {
                                            await Clipboard.setData(ClipboardData(text: item.bookingCode));
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Booking code copied')),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.copy_rounded, size: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(Row(
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
                                      Text(item.customerName),
                                    ],
                                  )),
                                  DataCell(Row(
                                    children: [
                                      const CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Color(0xFFF3F4F6),
                                        child: Icon(
                                          Icons.handyman_rounded,
                                          size: 16,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(item.workerName ?? 'Unknown'),
                                    ],
                                  )),
                                  DataCell(_GlowingStatusBadge(status: item.status)),
                                  DataCell(Text(MaterialLocalizations.of(context).formatMediumDate(item.createdAt))),
                                  DataCell(
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _openDispute(item.id),
                                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                          label: const Text('Open'),
                                        ),
                                        TextButton.icon(
                                          onPressed: () => context.push('/audit-logs?search=${Uri.encodeComponent(item.bookingId)}'),
                                          icon: const Icon(Icons.manage_search_rounded, size: 16),
                                          label: const Text('Audit'),
                                        ),
                                      ],
                                  ),
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
                        'Showing ${filteredItems.length} of $_total',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const Spacer(),
                      if (_loadingMore)
                        const SizedBox(
                          width: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text('Loading more'),
                            ],
                          ),
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
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
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

class _DisputesSkeleton extends StatelessWidget {
  const _DisputesSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(width: 280, height: 28),
        SizedBox(height: 12),
        _SkeletonBlock(width: 500, height: 16),
        SizedBox(height: 24),
        _SkeletonBlock(width: double.infinity, height: 110),
        SizedBox(height: 12),
        _SkeletonBlock(width: double.infinity, height: 300),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ShimmerWidget(width: width, height: height, radius: 10);
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
