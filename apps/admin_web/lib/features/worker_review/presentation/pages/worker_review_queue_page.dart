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
  static const int _limit = 20;

  late final WorkerReviewApi _api;
  final ScrollController _scrollController = ScrollController();

  late Future<List<CatalogCategory>> _categoriesFuture;
  final List<WorkerReviewProfile> _items = <WorkerReviewProfile>[];
  final TextEditingController _cityController = TextEditingController();
  String? _selectedCategoryId;
  String? _loadError;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _api = WorkerReviewApi(ref.read(apiClientProvider).dio);
    _categoriesFuture = _api.fetchCategories();
    _scrollController.addListener(_handleScroll);
    _reload();
  }

  @override
  void dispose() {
    _cityController.dispose();
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
      final data = await _api.fetchPending(
        page: 1,
        limit: _limit,
        city: _cityController.text,
        categoryId: _selectedCategoryId,
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
      final data = await _api.fetchPending(
        page: _page + 1,
        limit: _limit,
        city: _cityController.text,
        categoryId: _selectedCategoryId,
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
    await _reload();
  }

  Future<void> _resetFilters() async {
    setState(() {
      _cityController.clear();
      _selectedCategoryId = null;
    });
    await _reload();
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
    if (_loadingInitial && _items.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null && _items.isEmpty) {
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
                  'Unable to load worker review queue',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker review'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<List<CatalogCategory>>(
        future: _categoriesFuture,
        builder: (context, categoriesSnapshot) {
          final categories = categoriesSnapshot.data ?? const <CatalogCategory>[];

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
                              value: '$_total',
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
                              value: _selectedCategoryLabel(categories),
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
                if (_items.isEmpty)
                  const _SurfaceCard(
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
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final profile = _items[index];
                      return _SurfaceCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
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
                                        borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
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
                                      ? const [
                                          _QueueTag(
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
                      );
                    },
                  ),
                const SizedBox(height: 12),
                if (_loadingMore)
                  const Center(child: CircularProgressIndicator())
                else if (_hasMore && _items.isNotEmpty)
                  Center(
                    child: Text(
                      'Scroll to load more',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else if (!_hasMore && _items.isNotEmpty)
                  Center(
                    child: Text(
                      'End of results',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
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

