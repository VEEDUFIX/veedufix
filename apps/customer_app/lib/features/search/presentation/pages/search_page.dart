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

final searchCatalogFilteredProvider = FutureProvider.autoDispose.family<List<CatalogService>, _SearchFilters>((ref, filters) async {
  if (filters.query.trim().isEmpty && filters.categorySlug == null && filters.subcategorySlug == null) {
    return const [];
  }

  final apiClient = ref.watch(apiClientProvider);
  final queryParameters = <String, dynamic>{
    if (filters.query.trim().isNotEmpty) 'q': filters.query,
    if (filters.categorySlug != null && filters.categorySlug!.isNotEmpty) 'categorySlug': filters.categorySlug,
    if (filters.subcategorySlug != null && filters.subcategorySlug!.isNotEmpty) 'subcategorySlug': filters.subcategorySlug,
  };
  final response = await apiClient.get(
    '/catalog/search',
    queryParameters: queryParameters,
  );
  final payload = response['items'] ?? response['results'] ?? response['data'] ?? const [];
  if (payload is! List) {
    return const [];
  }
  return payload.whereType<Map<String, dynamic>>().map(CatalogService.fromJson).toList(growable: false);
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
  String? _selectedCategorySlug;
  String? _selectedSubcategorySlug;

  // Session-scoped recent searches — mutable so clear/add works live
  final List<String> _recent = [];

  static const List<Color> _accentCycle = [
    Color(0xFFC2A15E), Color(0xFF10B981), Color(0xFF60A5FA),
    Color(0xFFF59E0B), Color(0xFF38BDF8), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF14B8A6), Color(0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _query = widget.initialQuery;
    _selectedCategorySlug = widget.initialCategorySlug;
    _selectedSubcategorySlug = widget.initialSubcategorySlug;
  }

  void _setQuery(String q) {
    if (q.trim().isEmpty) return;
    _controller.text = q;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: q.length),
    );
    _addToRecent(q);
    setState(() => _query = q);
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
    context.go(Uri(path: '/search', queryParameters: params.isEmpty ? null : params).toString());
  }

  bool get _hasBrowseSelection => _selectedCategorySlug != null || _selectedSubcategorySlug != null;

  String _browseLabel(List<CatalogCategory> categories) {
    if (_selectedSubcategorySlug != null) {
      final subcategory = categories
          .expand((category) => category.subcategories)
          .where((item) => item.slug == _selectedSubcategorySlug)
          .firstOrNull;
      if (subcategory != null) {
        return subcategory.name;
      }
    }
    if (_selectedCategorySlug != null) {
      final category = categories.where((item) => item.slug == _selectedCategorySlug).firstOrNull;
      if (category != null) {
        return category.name;
      }
    }
    return 'Browse';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final searchAsync = ref.watch(
      searchCatalogFilteredProvider(
        _SearchFilters(
          query: _query,
          categorySlug: _selectedCategorySlug,
          subcategorySlug: _selectedSubcategorySlug,
        ),
      ),
    );
    final catalogAsync = ref.watch(homeCatalogProvider);
    final catalogCategories = catalogAsync.valueOrNull?.categories ?? const <CatalogCategory>[];
    final catalogSubcategories = catalogCategories.expand((category) => category.subcategories).toList(growable: false);
    final categorySlugById = <String, String>{
      for (final category in catalogCategories) category.id: category.slug,
    };
    final showResults = _query.trim().isNotEmpty || _hasBrowseSelection;
    final browseLabel = _browseLabel(catalogCategories);

    final trendingItems = [
      ...catalogCategories.take(6).toList().asMap().entries.map((e) {
        final cat = e.value;
        final color = _accentCycle[e.key % _accentCycle.length];
        return _SearchItem(
          title: cat.name,
          subtitle: '${cat.subcategories.length} subcategories',
          icon: Icons.home_repair_service_rounded,
          accent: color,
          categorySlug: cat.slug,
        );
      }),
      ...catalogSubcategories.take(6).toList().asMap().entries.map((e) {
        final subcategory = e.value;
        final color = _accentCycle[(e.key + 3) % _accentCycle.length];
        return _SearchItem(
          title: subcategory.name,
          subtitle: '${subcategory.serviceCount} services',
          icon: Icons.view_module_rounded,
          accent: color,
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
              _addToRecent(v);
              setState(() => _query = v);
            },
            onSubmitted: _setQuery,
            decoration: InputDecoration(
              hintText: 'Search for services…',
              hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
              suffixIcon: _query.isNotEmpty
                  ? TapScale(
                      onTap: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      child: Icon(Icons.close_rounded,
                          color: cs.onSurfaceVariant),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: !showResults
          ? _SearchHome(
              recent: _recent,
              trending: trendingItems,
              categories: catalogCategories,
              selectedCategorySlug: _selectedCategorySlug,
              selectedSubcategorySlug: _selectedSubcategorySlug,
              onCategoryTap: (slug) => _goToSearch(
                categorySlug: _selectedCategorySlug == slug ? null : slug,
              ),
              onSubcategoryTap: (categorySlug, subcategorySlug) => _goToSearch(
                categorySlug: categorySlug,
                subcategorySlug: _selectedSubcategorySlug == subcategorySlug ? null : subcategorySlug,
              ),
              onTrendingTap: (item) => _goToSearch(
                categorySlug: item.categorySlug,
                subcategorySlug: item.subcategorySlug,
              ),
              onQueryTap: _setQuery,
              onClearRecent: () => setState(() => _recent.clear()),
            )
          : searchAsync.when(
              data: (results) => _SearchResults(
                results: results,
                query: _query.isNotEmpty ? _query : browseLabel,
                categorySlug: _selectedCategorySlug,
                subcategorySlug: _selectedSubcategorySlug,
                onResultTap: _addToRecent,
              ),
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, _) => const ShimmerPlaceholder(
                  width: double.infinity,
                  height: 84,
                  borderRadius: 24,
                ),
              ),
              error: (err, stack) => Center(child: Text('Error: $err')),
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
  final void Function(String categorySlug, String subcategorySlug) onSubcategoryTap;
  final ValueChanged<_SearchItem> onTrendingTap;
  final ValueChanged<String> onQueryTap;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (categories.isNotEmpty) ...[
          Text('Categories',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                final category = categories.where((item) => item.slug == selectedCategorySlug).firstOrNull;
                final subcategories = category?.subcategories ?? const <CatalogSubcategory>[];
                if (subcategories.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subcategories',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subcategories
                          .map(
                            (subcategory) => FilterChip(
                              label: Text(subcategory.name),
                              selected: selectedSubcategorySlug == subcategory.slug,
                              onSelected: (_) => onSubcategoryTap(category!.slug, subcategory.slug),
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
              Text('Recent Searches',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              TapScale(
                onTap: onClearRecent,
                child: Text('Clear',
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recent
                .map((r) => TapScale(
                      onTap: () => onQueryTap(r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded,
                                size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Text(r,
                                style: tt.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
        ],
        Text('Trending Now', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (trending.isEmpty)
          const PremiumEmptyState(
            icon: Icons.trending_up_rounded,
            title: 'No trending services yet',
            subtitle: 'We’ll surface popular searches here once the catalog has enough activity.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.95,
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
                            borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                          ),
                          child: Icon(item.icon, color: item.accent),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (item.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.subtitle!,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
    this.categorySlug,
    this.subcategorySlug,
    this.onResultTap,
  });
  final List<CatalogService> results;
  final String query;
  final String? categorySlug;
  final String? subcategorySlug;
  final ValueChanged<String>? onResultTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (results.isEmpty) {
      return Center(
        child: PremiumEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results for "$query"',
          subtitle: 'Try searching for something else.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final item = results[i];
        const accent = Color(0xFF6366F1);
        
        return TapScale(
          onTap: () {
            onResultTap?.call(item.name);
            context.push('/service?id=${item.slug}');
          },
          child: PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                    ),
                    child: const Icon(Icons.design_services_rounded, color: accent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                        if (item.hierarchyLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.hierarchyLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                        ],
                        if (item.startingPrice > 0)
                          Text(
                            'From Rs ${item.startingPrice.toInt()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: cs.onSurfaceVariant),
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

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
