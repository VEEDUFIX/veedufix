import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/worker_directory_api.dart';

class WorkerDirectoryPage extends ConsumerStatefulWidget {
  const WorkerDirectoryPage({super.key});

  @override
  ConsumerState<WorkerDirectoryPage> createState() =>
      _WorkerDirectoryPageState();
}

class _WorkerDirectoryPageState extends ConsumerState<WorkerDirectoryPage> {
  static const int _limit = 20;

  late final WorkerDirectoryApi _api;
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  Timer? _searchDebounce;

  late Future<List<CatalogCategory>> _categoriesFuture;
  final List<WorkerDirectoryProfile> _workers = <WorkerDirectoryProfile>[];
  String? _selectedCategoryId;
  String _selectedStatus = 'all';
  String? _loadError;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _api = WorkerDirectoryApi(ref.read(apiClientProvider).dio);
    _categoriesFuture = _api.fetchCategories();
    _scrollController.addListener(_handleScroll);
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loadingInitial = true;
      _loadingMore = false;
      _loadError = null;
      _workers.clear();
      _page = 0;
      _total = 0;
      _hasMore = true;
    });

    try {
      final data = await _api.fetchWorkers(
        page: 1,
        limit: _limit,
        city: _cityController.text,
        categoryId: _selectedCategoryId,
        status: _selectedStatus,
        search: _searchController.text,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _workers
          ..clear()
          ..addAll(data.items);
        _page = data.page;
        _total = data.total;
        _hasMore = _workers.length < _total;
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
      final data = await _api.fetchWorkers(
        page: _page + 1,
        limit: _limit,
        city: _cityController.text,
        categoryId: _selectedCategoryId,
        status: _selectedStatus,
        search: _searchController.text,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _workers.addAll(data.items);
        _page = data.page;
        _total = data.total;
        _hasMore = _workers.length < _total;
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

  Future<void> _applyFilters() async {
    await _reload();
  }

  Future<void> _resetFilters() async {
    setState(() {
      _searchController.clear();
      _cityController.clear();
      _selectedCategoryId = null;
      _selectedStatus = 'all';
    });
    await _reload();
  }

  Future<void> _openWorker(WorkerDirectoryProfile profile) async {
    final result = await context.push<WorkerDirectoryProfile>(
      '/workers/${profile.id}',
      extra: profile,
    );
    if (result != null && mounted) {
      await _reload();
    }
  }

  String _selectedCategoryLabel(List<CatalogCategory> categories) {
    if (_selectedCategoryId == null) {
      return 'All';
    }
    return categories
        .where((category) => category.id == _selectedCategoryId)
        .map((category) => category.name)
        .cast<String?>()
        .firstWhere((value) => value != null && value.trim().isNotEmpty,
            orElse: () => 'Selected')!;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingInitial && _workers.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null && _workers.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Unable to load worker directory',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _reload,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F5EC),
        surfaceTintColor: Colors.transparent,
        title: const Text('Worker directory'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F5EC), Color(0xFFFFFCF8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FutureBuilder<List<CatalogCategory>>(
          future: _categoriesFuture,
          builder: (context, categoriesSnapshot) {
            final categories =
                categoriesSnapshot.data ?? const <CatalogCategory>[];

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _SurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Worker directory',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Browse every worker profile, review performance history, and quickly reinstate suspended accounts when needed.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.74),
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              PremiumStatCard(
                                label: 'Workers',
                                value: '$_total',
                                icon: Icons.groups_rounded,
                                accentColor: const Color(0xFF2563EB),
                              ),
                              PremiumStatCard(
                                label: 'City filter',
                                value: _cityController.text.isEmpty
                                    ? 'All'
                                    : _cityController.text,
                                icon: Icons.location_city_rounded,
                                accentColor: const Color(0xFF0F766E),
                              ),
                              PremiumStatCard(
                                label: 'Category filter',
                                value: _selectedCategoryLabel(categories),
                                icon: Icons.category_rounded,
                                accentColor: const Color(0xFFF59E0B),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filters',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search by name, email or phone',
                              prefixIcon: Icon(Icons.search_rounded),
                              hintText: 'e.g. Ravi Kumar or 9876543210',
                            ),
                            textInputAction: TextInputAction.search,
                            onChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 500),
                                () {
                                  _reload();
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              prefixIcon: Icon(Icons.location_city_rounded),
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _applyFilters(),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: _selectedCategoryId,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_rounded),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All categories'),
                              ),
                              ...categories.map(
                                (category) => DropdownMenuItem<String?>(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCategoryId = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              prefixIcon: Icon(Icons.verified_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All statuses'),
                              ),
                              DropdownMenuItem(
                                value: 'approved',
                                child: Text('Approved'),
                              ),
                              DropdownMenuItem(
                                value: 'suspended',
                                child: Text('Suspended'),
                              ),
                              DropdownMenuItem(
                                value: 'rejected',
                                child: Text('Rejected'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedStatus = value ?? 'all');
                            },
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: _applyFilters,
                                icon: const Icon(Icons.tune_rounded),
                                label: const Text('Apply filters'),
                              ),
                              TextButton(
                                onPressed: _resetFilters,
                                child: const Text('Reset'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Worker list',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                Text(
                                  '${_workers.length}/$_total shown',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
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
                                      headingTextStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        letterSpacing: 0.8,
                                      ),
                                      dataRowMinHeight: 72,
                                      dataRowMaxHeight: 72,
                                      dividerThickness: 1,
                                      horizontalMargin: 24,
                                      columns: const [
                                        DataColumn(label: Text('WORKER')),
                                        DataColumn(label: Text('CITY')),
                                        DataColumn(label: Text('STATUS')),
                                        DataColumn(label: Text('RATING')),
                                        DataColumn(label: Text('COMPLETED')),
                                        DataColumn(label: Text('NO-SHOWS')),
                                      ],
                                      rows: _workers.map((profile) {
                                        return DataRow(
                                          onSelectChanged: (_) => _openWorker(profile),
                                          cells: [
                                            DataCell(_WorkerNameCell(profile: profile)),
                                            DataCell(Text(profile.cityLabel)),
                                            DataCell(
                                              _GlowingStatusBadge(status: profile.onboardingStatus),
                                            ),
                                            DataCell(Text(profile.ratingAvg.toStringAsFixed(1))),
                                            DataCell(Text('${profile.jobsCompletedCount}')),
                                            DataCell(Text('${profile.noShowCount}')),
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                Text(
                                  'Showing ${_workers.length} of $_total',
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
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  )
                                else
                                  Text(
                                    'End of results',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loadError != null && _workers.isNotEmpty) ...[
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
            );
          },
        ),
      ),
    );
  }
}

class _WorkerNameCell extends StatelessWidget {
  const _WorkerNameCell({required this.profile});

  final WorkerDirectoryProfile profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;

    return SizedBox(
      width: 260,
      child: Row(
        children: [
          MarketplaceNetworkAvatar(
            imageUrl: avatarUrl,
            radius: 18,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            fallback: Icon(
              Icons.person_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.requestedCategoryNames.isEmpty
                      ? 'No categories listed'
                      : profile.requestedCategoryNames.join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});
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
