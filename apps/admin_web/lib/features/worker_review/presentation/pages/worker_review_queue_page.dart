import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/worker_review_api.dart';

class WorkerReviewQueuePage extends ConsumerStatefulWidget {
  const WorkerReviewQueuePage({super.key});

  @override
  ConsumerState<WorkerReviewQueuePage> createState() => _WorkerReviewQueuePageState();
}

class _WorkerReviewQueuePageState extends ConsumerState<WorkerReviewQueuePage> {
  late final WorkerReviewApi _api;
  late Future<WorkerReviewQueueResponse> _queueFuture;
  late Future<List<CatalogCategory>> _categoriesFuture;

  final TextEditingController _cityController = TextEditingController();
  String? _selectedCategoryId;
  int _page = 1;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _api = WorkerReviewApi(ref.read(apiClientProvider).dio);
    _categoriesFuture = _api.fetchCategories();
    _queueFuture = _loadQueue();
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  Future<WorkerReviewQueueResponse> _loadQueue() {
    return _api.fetchPending(
      page: _page,
      limit: _limit,
      city: _cityController.text,
      categoryId: _selectedCategoryId,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _queueFuture = _loadQueue();
    });
    await _queueFuture;
  }

  Future<void> _openReview(WorkerReviewProfile profile) async {
    final result = await context.push<WorkerReviewProfile>(
      '/worker-review/${profile.id}',
      extra: profile,
    );
    if (result != null && mounted) {
      await _reload();
    }
  }

  Future<void> _applyFilters() async {
    setState(() {
      _page = 1;
      _queueFuture = _loadQueue();
    });
    await _queueFuture;
  }

  Future<void> _resetFilters() async {
    setState(() {
      _cityController.clear();
      _selectedCategoryId = null;
      _page = 1;
      _queueFuture = _loadQueue();
    });
    await _queueFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker review'),
        actions: [
          IconButton(
            onPressed: () => _reload(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<CatalogCategory>>(
        future: _categoriesFuture,
        builder: (context, categoriesSnapshot) {
          final categories = categoriesSnapshot.data ?? const <CatalogCategory>[];

          return FutureBuilder<WorkerReviewQueueResponse>(
            future: _queueFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
                          'Unable to load worker review queue',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
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

              final queue = snapshot.data ?? const WorkerReviewQueueResponse(
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
                    PremiumGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Worker review queue',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Review worker applications, verify documents, and move the right profiles forward quickly.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.74),
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                PremiumStatCard(
                                  label: 'Pending',
                                  value: '${queue.total}',
                                  icon: Icons.hourglass_top_rounded,
                                  accentColor: const Color(0xFFF59E0B),
                                ),
                                PremiumStatCard(
                                  label: 'City filter',
                                  value: _cityController.text.isEmpty ? 'All' : _cityController.text,
                                  icon: Icons.location_city_rounded,
                                  accentColor: const Color(0xFF2563EB),
                                ),
                                PremiumStatCard(
                                  label: 'Category filter',
                                  value: _selectedCategoryId == null
                                      ? 'All'
                                      : categories.firstWhere(
                                          (category) => category.id == _selectedCategoryId,
                                          orElse: () => const CatalogCategory(id: '', name: 'Selected', slug: ''),
                                        ).name,
                                  icon: Icons.category_rounded,
                                  accentColor: const Color(0xFF0F766E),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PremiumGlassCard(
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
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _applyFilters,
                                    child: const Text('Apply filters'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
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
                    if (queue.items.isEmpty)
                      const PremiumGlassCard(
                        child: Padding(
                          padding: EdgeInsets.all(22),
                          child: PremiumEmptyState(
                            icon: Icons.inbox_rounded,
                            title: 'No workers waiting',
                            subtitle: 'Pending applications will appear here once workers submit their onboarding forms.',
                          ),
                        ),
                      )
                    else
                      ...queue.items.map(
                        (profile) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: PremiumGlassCard(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () => _openReview(profile),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 52,
                                          width: 52,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.72),
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          child: Center(
                                            child: Text(
                                              profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : 'W',
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                profile.displayName,
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                profile.cityLabel,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            _QueueTag(
                                              label: profile.onboardingStatus.replaceAll('_', ' '),
                                              accent: const Color(0xFFF59E0B),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              profile.submittedShortDate,
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Requested categories',
                                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: profile.requestedCategoryNames.isEmpty
                                          ? [
                                              const _QueueTag(
                                                label: 'No categories listed',
                                                accent: Color(0xFF64748B),
                                              ),
                                            ]
                                          : [
                                              ...profile.requestedCategoryNames.take(3).map(
                                                    (name) => _QueueTag(
                                                      label: name,
                                                      accent: const Color(0xFF2563EB),
                                                    ),
                                                  ),
                                              if (profile.requestedCategoryNames.length > 3)
                                                _QueueTag(
                                                  label: '+${profile.requestedCategoryNames.length - 3} more',
                                                  accent: Theme.of(context).colorScheme.secondary,
                                                ),
                                            ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Open full review',
                                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (queue.totalPages > 1) ...[
                      const SizedBox(height: 16),
                      PremiumGlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text(
                                'Page ${queue.page} of ${queue.totalPages}',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const Spacer(),
                              OutlinedButton(
                                onPressed: queue.page > 1
                                    ? () {
                                        setState(() {
                                          _page = queue.page - 1;
                                          _queueFuture = _loadQueue();
                                        });
                                      }
                                    : null,
                                child: const Text('Previous'),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: queue.page < queue.totalPages
                                    ? () {
                                        setState(() {
                                          _page = queue.page + 1;
                                          _queueFuture = _loadQueue();
                                        });
                                      }
                                    : null,
                                child: const Text('Next'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueTag extends StatelessWidget {
  const _QueueTag({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: accent,
            ),
      ),
    );
  }
}
