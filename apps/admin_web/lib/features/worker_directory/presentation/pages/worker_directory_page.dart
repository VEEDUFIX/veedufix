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
  late final WorkerDirectoryApi _api;
  late Future<WorkerDirectoryQueueResponse> _workersFuture;
  late Future<List<CatalogCategory>> _categoriesFuture;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  Timer? _searchDebounce;
  String? _selectedCategoryId;
  String _selectedStatus = 'all';
  int _page = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _api = WorkerDirectoryApi(ref.read(apiClientProvider).dio);
    _categoriesFuture = _api.fetchCategories();
    _workersFuture = _loadWorkers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<WorkerDirectoryQueueResponse> _loadWorkers() {
    return _api.fetchWorkers(
      page: _page,
      limit: _limit,
      city: _cityController.text,
      categoryId: _selectedCategoryId,
      status: _selectedStatus,
      search: _searchController.text,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _workersFuture = _loadWorkers();
    });
    await _workersFuture;
  }

  Future<void> _applyFilters() async {
    setState(() {
      _page = 1;
      _workersFuture = _loadWorkers();
    });
    await _workersFuture;
  }

  Future<void> _resetFilters() async {
    setState(() {
      _searchController.clear();
      _cityController.clear();
      _selectedCategoryId = null;
      _selectedStatus = 'all';
      _page = 1;
      _workersFuture = _loadWorkers();
    });
    await _workersFuture;
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

            return FutureBuilder<WorkerDirectoryQueueResponse>(
              future: _workersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

              if (snapshot.hasError) {
                return Center(
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
                        Text(snapshot.error.toString(),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final queue = snapshot.data ??
                  const WorkerDirectoryQueueResponse(
                    items: [],
                    page: 1,
                    limit: 20,
                    total: 0,
                    totalPages: 1,
                  );

                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Browse every worker profile, review performance history, and quickly reinstate suspended accounts when needed.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
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
                                  value: '${queue.total}',
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
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
                                    setState(() {
                                      _page = 1;
                                      _workersFuture = _loadWorkers();
                                    });
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
                                    value: 'all', child: Text('All statuses')),
                                DropdownMenuItem(
                                    value: 'approved', child: Text('Approved')),
                                DropdownMenuItem(
                                    value: 'suspended',
                                    child: Text('Suspended')),
                                DropdownMenuItem(
                                    value: 'rejected', child: Text('Rejected')),
                              ],
                              onChanged: (value) {
                                setState(
                                    () => _selectedStatus = value ?? 'all');
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${queue.items.length}/${queue.total} shown',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
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
                                        rows: queue.items.map((profile) {
                                          return DataRow(
                                            onSelectChanged: (_) => _openWorker(profile),
                                            cells: [
                                              DataCell(_WorkerNameCell(profile: profile)),
                                              DataCell(Text(profile.cityLabel)),
                                              DataCell(_GlowingStatusBadge(status: profile.onboardingStatus)),
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
                            if (queue.totalPages > 1) ...[
                              const SizedBox(height: 12),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      'Page ${queue.page} of ${queue.totalPages}',
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
                                                _workersFuture = _loadWorkers();
                                              });
                                              await _workersFuture;
                                            },
                                      child: const Text('Previous'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: _page >= queue.totalPages
                                          ? null
                                          : () async {
                                              setState(() {
                                                _page += 1;
                                                _workersFuture = _loadWorkers();
                                              });
                                              await _workersFuture;
                                            },
                                      child: const Text('Next'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    ],
                  ),
                );
              },
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
          CircleAvatar(
            radius: 18,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
            backgroundImage: avatarUrl != null && avatarUrl.trim().isNotEmpty
                ? NetworkImage(avatarUrl.trim())
                : null,
            child: avatarUrl == null || avatarUrl.trim().isEmpty
                ? Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
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
                      : profile.requestedCategoryNames.join(' • '),
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
