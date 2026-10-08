import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';

class _SearchFilters {
  const _SearchFilters({
    required this.query,
    this.categorySlug,
    this.subcategorySlug,
  });

  final String query;
  final String? categorySlug;
  final String? subcategorySlug;

  @override
  bool operator ==(Object other) {
    return other is _SearchFilters &&
        other.query == query &&
        other.categorySlug == categorySlug &&
        other.subcategorySlug == subcategorySlug;
  }

  @override
  int get hashCode => Object.hash(query, categorySlug, subcategorySlug);
}

final searchCatalogFilteredProvider = FutureProvider.autoDispose
    .family<List<CatalogService>, _SearchFilters>((ref, filters) async {
      if (filters.query.trim().isEmpty &&
          filters.categorySlug == null &&
          filters.subcategorySlug == null) {
        return const [];
      }

      final apiClient = ref.watch(apiClientProvider);
      final queryParameters = <String, dynamic>{
        if (filters.query.trim().isNotEmpty) 'q': filters.query,
        if (filters.categorySlug != null && filters.categorySlug!.isNotEmpty)
          'categorySlug': filters.categorySlug,
        if (filters.subcategorySlug != null &&
            filters.subcategorySlug!.isNotEmpty)
          'subcategorySlug': filters.subcategorySlug,
      };
      final response = await apiClient.get(
        '/catalog/search',
        queryParameters: queryParameters,
      );
      final payload =
          response['items'] ??
          response['results'] ??
          response['data'] ??
          const [];
      if (payload is! List) {
        return const [];
      }
      return payload
          .whereType<Map<String, dynamic>>()
          .map(CatalogService.fromJson)
          .toList(growable: false);
    });

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    this.initialQuery = '',
    this.initialCategorySlug,
    this.initialSubcategorySlug,
  });

  final String initialQuery;
  final String? initialCategorySlug;
  final String? initialSubcategorySlug;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  String _inputQuery = '';
  Timer? _searchDebounce;
  String? _selectedCategorySlug;
  String? _selectedSubcategorySlug;

  // Session-scoped recent searches — mutable so clear/add works live
  final List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _query = widget.initialQuery;
    _inputQuery = widget.initialQuery;
    _selectedCategorySlug = widget.initialCategorySlug;
    _selectedSubcategorySlug = widget.initialSubcategorySlug;
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialCategorySlug != widget.initialCategorySlug ||
        oldWidget.initialSubcategorySlug != widget.initialSubcategorySlug) {
      _searchDebounce?.cancel();
      _controller.value = TextEditingValue(
        text: widget.initialQuery,
        selection: TextSelection.collapsed(offset: widget.initialQuery.length),
      );
      _inputQuery = widget.initialQuery;
      _query = widget.initialQuery;
      _selectedCategorySlug = widget.initialCategorySlug;
      _selectedSubcategorySlug = widget.initialSubcategorySlug;
    }
  }

  void _setQuery(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    _searchDebounce?.cancel();
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _addToRecent(query);
    setState(() {
      _inputQuery = query;
      _query = query;
    });
  }

  void _onQueryChanged(String value) {
    setState(() => _inputQuery = value);
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = _inputQuery);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _controller.clear();
    setState(() {
      _inputQuery = '';
      _query = '';
      _selectedCategorySlug = null;
      _selectedSubcategorySlug = null;
    });
    context.go('/search');
  }

  void _addToRecent(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    _recent.remove(trimmed);
    _recent.insert(0, trimmed);
    if (_recent.length > 8) _recent.removeLast();
  }

  void _goToSearch({
    String? query,
    String? categorySlug,
    String? subcategorySlug,
  }) {
    final params = <String, String>{};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    if (categorySlug != null && categorySlug.isNotEmpty) {
      params['categorySlug'] = categorySlug;
    }
    if (subcategorySlug != null && subcategorySlug.isNotEmpty) {
      params['subcategorySlug'] = subcategorySlug;
    }
    context.go(
      Uri(
        path: '/search',
        queryParameters: params.isEmpty ? null : params,
      ).toString(),
    );
  }

  bool get _hasBrowseSelection =>
      _selectedCategorySlug != null || _selectedSubcategorySlug != null;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final searchFilters = _SearchFilters(
      query: _query,
      categorySlug: _selectedCategorySlug,
      subcategorySlug: _selectedSubcategorySlug,
    );
    final searchAsync = ref.watch(searchCatalogFilteredProvider(searchFilters));
    final catalogAsync = ref.watch(homeCatalogProvider);
    final catalogCategories =
        catalogAsync.valueOrNull?.categories ?? const <CatalogCategory>[];
    final catalogSubcategories = catalogCategories
        .expand((category) => category.subcategories)
        .toList(growable: false);
    final categorySlugById = <String, String>{
      for (final category in catalogCategories) category.id: category.slug,
    };
    final activeFilterLabels = <String>[
      if (_selectedCategorySlug != null)
        ...catalogCategories
            .where((category) => category.slug == _selectedCategorySlug)
            .map((category) => category.name),
      if (_selectedSubcategorySlug != null)
        ...catalogSubcategories
            .where(
              (subcategory) => subcategory.slug == _selectedSubcategorySlug,
            )
            .map((subcategory) => subcategory.name),
    ];
    final showResults = _inputQuery.trim().isNotEmpty || _hasBrowseSelection;
    final isDebouncing = _inputQuery.trim() != _query.trim();
    final trendingItems = [
      ...catalogCategories.take(6).toList().asMap().entries.map((e) {
        final cat = e.value;
        return _SearchItem(
          title: cat.name,
          subtitle: '${cat.subcategories.length} subcategories',
          icon: Icons.home_repair_service_rounded,
          accent: AbzioTheme.accentColor,
          categorySlug: cat.slug,
        );
      }),
      ...catalogSubcategories.take(6).toList().asMap().entries.map((e) {
        final subcategory = e.value;
        return _SearchItem(
          title: subcategory.name,
          subtitle: '${subcategory.serviceCount} services',
          icon: Icons.view_module_rounded,
          accent: AbzioTheme.accentColor,
          categorySlug: categorySlugById[subcategory.categoryId],
          subcategorySlug: subcategory.slug,
        );
      }),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: TapScale(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                boxShadow: AbzioTheme.eliteShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Container(
          height: 48,
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              _onQueryChanged(v);
            },
            onSubmitted: _setQuery,
            decoration: InputDecoration(
              hintText: 'Search for services…',
              hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: cs.onSurfaceVariant,
              ),
              suffixIcon: _inputQuery.isNotEmpty
                  ? TapScale(
                      onTap: () {
                        _clearSearch();
                      },
                      child: Icon(
                        Icons.close_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: !showResults
          ? catalogAsync.when(
              data: (_) => _SearchHome(
                recent: _recent,
                trending: trendingItems,
                categories: catalogCategories,
                selectedCategorySlug: _selectedCategorySlug,
                selectedSubcategorySlug: _selectedSubcategorySlug,
                onCategoryTap: (slug) => _goToSearch(
                  categorySlug: _selectedCategorySlug == slug ? null : slug,
                ),
                onSubcategoryTap: (categorySlug, subcategorySlug) =>
                    _goToSearch(
                      categorySlug: categorySlug,
                      subcategorySlug:
                          _selectedSubcategorySlug == subcategorySlug
                          ? null
                          : subcategorySlug,
                    ),
                onTrendingTap: (item) => _goToSearch(
                  categorySlug: item.categorySlug,
                  subcategorySlug: item.subcategorySlug,
                ),
                onQueryTap: _setQuery,
                onClearRecent: () => setState(() => _recent.clear()),
              ),
              loading: () => const _SearchLoadingState(),
              error: (error, stackTrace) => PremiumRetryState(
                title: 'Could not load services',
                subtitle: 'Check your connection and try browsing again.',
                onRetry: () => ref.invalidate(homeCatalogProvider),
                onRefresh: () async {
                  await ref
                      .refresh(homeCatalogProvider.future)
                      .then<void>((_) {});
                },
              ),
            )
          : isDebouncing
          ? const _SearchLoadingState()
          : searchAsync.when(
              data: (results) => _SearchResults(
                results: results,
                query: _query,
                activeFilters: activeFilterLabels,
                onResultTap: _addToRecent,
                onClearSearch: _clearSearch,
              ),
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, _) => const ShimmerPlaceholder(
                  width: double.infinity,
                  height: 84,
                  borderRadius: 18,
                ),
              ),
              error: (err, stack) => PremiumRetryState(
                title: 'Could not load search results',
                subtitle: 'Check your connection and try your search again.',
                onRetry: () => ref.invalidate(
                  searchCatalogFilteredProvider(searchFilters),
                ),
                onRefresh: () async {
                  await ref
                      .refresh(
                        searchCatalogFilteredProvider(searchFilters).future,
                      )
                      .then<void>((_) {});
                },
              ),
            ),
    );
  }
}

class _SearchHome extends StatelessWidget {
  const _SearchHome({
    required this.recent,
    required this.trending,
    required this.categories,
    required this.selectedCategorySlug,
    required this.selectedSubcategorySlug,
    required this.onCategoryTap,
    required this.onSubcategoryTap,
    required this.onTrendingTap,
    required this.onQueryTap,
    required this.onClearRecent,
  });
  final List<String> recent;
  final List<_SearchItem> trending;
  final List<CatalogCategory> categories;
  final String? selectedCategorySlug;
  final String? selectedSubcategorySlug;
  final ValueChanged<String> onCategoryTap;
  final void Function(String categorySlug, String subcategorySlug)
  onSubcategoryTap;
  final ValueChanged<_SearchItem> onTrendingTap;
  final ValueChanged<String> onQueryTap;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          'Browse services',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        if (categories.isNotEmpty) ...[
          Text(
            'Categories',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (category) => FilterChip(
                    label: Text(category.name),
                    selected: selectedCategorySlug == category.slug,
                    onSelected: (_) => onCategoryTap(category.slug),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 18),
          if (selectedCategorySlug != null)
            Builder(
              builder: (context) {
                final category = categories
                    .where((item) => item.slug == selectedCategorySlug)
                    .firstOrNull;
                final subcategories =
                    category?.subcategories ?? const <CatalogSubcategory>[];
                if (subcategories.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subcategories',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subcategories
                          .map(
                            (subcategory) => FilterChip(
                              label: Text(subcategory.name),
                              selected:
                                  selectedSubcategorySlug == subcategory.slug,
                              onSelected: (_) => onSubcategoryTap(
                                category!.slug,
                                subcategory.slug,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),
        ],
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'Recent searches',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(onPressed: onClearRecent, child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recent
                .map(
                  (r) => TapScale(
                    onTap: () => onQueryTap(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AbzioTheme.cardRadius,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              r,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
        ],
        Text(
          'Explore',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        if (trending.isEmpty)
          const PremiumEmptyState(
            icon: Icons.trending_up_rounded,
            title: 'No services available yet',
            subtitle: 'Please check back soon.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 400 ? 2 : 3;
              final itemWidth =
                  (constraints.maxWidth - (columns - 1) * 12) / columns;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: itemWidth / 180,
                ),
                itemCount: trending.length,
                itemBuilder: (context, i) {
                  final item = trending[i];
                  return TapScale(
                    onTap: () => onTrendingTap(item),
                    child: PremiumCard(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                color: item.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AbzioTheme.buttonRadius,
                                ),
                              ),
                              child: Icon(item.icon, color: item.accent),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (item.subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle!,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.query,
    required this.activeFilters,
    this.onResultTap,
    required this.onClearSearch,
  });
  final List<CatalogService> results;
  final String query;
  final List<String> activeFilters;
  final ValueChanged<String>? onResultTap;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.search_off_rounded,
                      color: cs.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    query.trim().isNotEmpty
                        ? 'No results for "$query"'
                        : 'No services in these filters',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try a different search or clear your filters.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Clear search'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: results.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) {
          final countLabel = results.length == 1 ? 'service' : 'services';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${results.length} $countLabel found',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (query.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
                if (activeFilters.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: activeFilters
                        .map(
                          (filter) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              filter,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ],
            ),
          );
        }

        final item = results[i - 1];
        const accent = AbzioTheme.accentColor;
        final imageUrl = item.images.isEmpty ? null : item.images.first.url;

        return TapScale(
          onTap: () {
            onResultTap?.call(item.name);
            context.push(
              Uri(
                path: '/service',
                queryParameters: {'id': item.id},
              ).toString(),
            );
          },
          child: PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: imageUrl == null
                        ? const Icon(
                            Icons.design_services_rounded,
                            color: accent,
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.design_services_rounded,
                              color: accent,
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (item.hierarchyLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.hierarchyLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                        if (item.startingPrice > 0 || item.rating > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (item.startingPrice > 0)
                                Expanded(
                                  child: Text(
                                    'From ₹${item.startingPrice.toInt()}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              if (item.rating > 0) ...[
                                if (item.startingPrice > 0)
                                  const SizedBox(width: 10),
                                const Icon(
                                  Icons.star_rounded,
                                  size: 15,
                                  color: AbzioTheme.accentColor,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.rating.toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchItem {
  const _SearchItem({
    required this.title,
    required this.icon,
    required this.accent,
    this.subtitle,
    this.categorySlug,
    this.subcategorySlug,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final String? subtitle;
  final String? categorySlug;
  final String? subcategorySlug;
}

class _SearchLoadingState extends StatelessWidget {
  const _SearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, _) => const ShimmerPlaceholder(
        width: double.infinity,
        height: 84,
        borderRadius: 18,
      ),
    );
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
