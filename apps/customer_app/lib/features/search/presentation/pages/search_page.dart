import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';
import '../../data/search_history_store.dart';

class _SearchFilters {
  const _SearchFilters({
    required this.query,
    this.page = 1,
    this.pincode,
    this.categorySlug,
    this.subcategorySlug,
  });

  final String query;
  final int page;
  final String? pincode;
  final String? categorySlug;
  final String? subcategorySlug;

  @override
  bool operator ==(Object other) {
    return other is _SearchFilters &&
        other.query == query &&
        other.page == page &&
        other.pincode == pincode &&
        other.categorySlug == categorySlug &&
        other.subcategorySlug == subcategorySlug;
  }

  @override
  int get hashCode =>
      Object.hash(query, page, pincode, categorySlug, subcategorySlug);
}

class CatalogSearchPageResult {
  const CatalogSearchPageResult({
    required this.items,
    required this.total,
    this.resultLimit,
  });

  final List<CatalogService> items;
  final int total;
  final int? resultLimit;
}

final searchCatalogFilteredProvider = FutureProvider.autoDispose
    .family<CatalogSearchPageResult, _SearchFilters>((ref, filters) async {
      if (filters.query.trim().isEmpty &&
          filters.categorySlug == null &&
          filters.subcategorySlug == null) {
        return const CatalogSearchPageResult(items: [], total: 0);
      }

      final apiClient = ref.watch(apiClientProvider);
      final cancelToken = CancelToken();
      ref.onDispose(() => cancelToken.cancel('Search results query changed'));
      final queryParameters = <String, dynamic>{
        if (filters.query.trim().isNotEmpty) 'q': filters.query,
        'page': filters.page,
        'pageSize': 20,
        if (filters.categorySlug != null && filters.categorySlug!.isNotEmpty)
          'categorySlug': filters.categorySlug,
        if (filters.subcategorySlug != null &&
            filters.subcategorySlug!.isNotEmpty)
          'subcategorySlug': filters.subcategorySlug,
        if (filters.pincode != null) 'pincode': filters.pincode,
      };
      final response = await apiClient.dio.get<Map<String, dynamic>>(
        '/catalog/search',
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
      final payloadData = response.data ?? const <String, dynamic>{};
      final payload =
          payloadData['items'] ??
          payloadData['results'] ??
          payloadData['data'] ??
          const [];
      if (payload is! List) {
        return const CatalogSearchPageResult(items: [], total: 0);
      }
      final items = payload
          .whereType<Map<String, dynamic>>()
          .map(CatalogService.fromJson)
          .toList(growable: false);
      return CatalogSearchPageResult(
        items: items,
        total: (payloadData['total'] as num?)?.toInt() ?? items.length,
        resultLimit: (payloadData['resultLimit'] as num?)?.toInt(),
      );
    });

final searchAutocompleteProvider = FutureProvider.autoDispose
    .family<List<CatalogSearchSuggestion>, String>((ref, rawQuery) async {
      final query = rawQuery.trim();
      if (query.length < 2) return const [];

      final cancelToken = CancelToken();
      ref.onDispose(() => cancelToken.cancel('Search query changed'));
      final pincode = ref.watch(selectedCatalogPincodeProvider);
      final response = await ref
          .watch(apiClientProvider)
          .dio
          .get<Map<String, dynamic>>(
            '/catalog/autocomplete',
            queryParameters: {
              'q': query,
              'limit': 8,
              if (pincode != null) 'pincode': pincode,
            },
            cancelToken: cancelToken,
          );
      final data = response.data ?? const <String, dynamic>{};
      final suggestions = <CatalogSearchSuggestion>[];
      for (final key in const ['services', 'categories', 'subcategories']) {
        final rawItems = data[key];
        if (rawItems is! List) continue;
        for (final rawItem in rawItems.whereType<Map>().take(4)) {
          final suggestion = CatalogSearchSuggestion.fromJson(
            rawItem.cast<String, dynamic>(),
          );
          if (suggestion.label.trim().isNotEmpty) suggestions.add(suggestion);
        }
      }
      return suggestions.take(12).toList(growable: false);
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
  int _page = 1;
  String? _pagePincode;
  String _inputQuery = '';
  String _suggestionQuery = '';
  Timer? _searchDebounce;
  Timer? _suggestionDebounce;
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchHasFocus = false;
  String? _selectedCategorySlug;
  String? _selectedSubcategorySlug;

  final CustomerSearchHistoryStore _historyStore = CustomerSearchHistoryStore();
  final List<String> _recent = [];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _query = widget.initialQuery;
    _inputQuery = widget.initialQuery;
    _selectedCategorySlug = widget.initialCategorySlug;
    _selectedSubcategorySlug = widget.initialSubcategorySlug;
    _searchFocusNode.addListener(_onFocusChanged);
    unawaited(_loadRecentSearches());
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
      _page = 1;
      _suggestionQuery = widget.initialQuery;
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
    _searchFocusNode.unfocus();
    setState(() {
      _inputQuery = query;
      _query = query;
      _page = 1;
      _suggestionQuery = '';
    });
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _searchHasFocus = _searchFocusNode.hasFocus);
  }

  void _onQueryChanged(String value) {
    setState(() {
      _inputQuery = value;
      _suggestionQuery = '';
    });
    _searchDebounce?.cancel();
    _suggestionDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _query = '';
        _page = 1;
        _suggestionQuery = '';
      });
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _suggestionQuery = value.trim());
    });
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = _inputQuery;
        _page = 1;
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _suggestionDebounce?.cancel();
    _controller.clear();
    setState(() {
      _inputQuery = '';
      _query = '';
      _page = 1;
      _suggestionQuery = '';
      _selectedCategorySlug = null;
      _selectedSubcategorySlug = null;
    });
    context.go('/search');
  }

  void _addToRecent(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    _recent.removeWhere(
      (value) => value.toLowerCase() == trimmed.toLowerCase(),
    );
    _recent.insert(0, trimmed);
    if (_recent.length > CustomerSearchHistoryStore.maxEntries) {
      _recent.removeRange(
        CustomerSearchHistoryStore.maxEntries,
        _recent.length,
      );
    }
    unawaited(_persistRecentSearches());
  }

  Future<void> _loadRecentSearches() async {
    try {
      final values = await _historyStore.load();
      if (!mounted) return;
      setState(() {
        _recent
          ..clear()
          ..addAll(values.where((value) => value.trim().isNotEmpty).take(8));
      });
    } catch (_) {
      // Search remains usable when local history storage is unavailable.
    }
  }

  Future<void> _persistRecentSearches() async {
    try {
      await _historyStore.replace(_recent);
    } catch (_) {
      // Local history is optional and never blocks search.
    }
  }

  void _removeRecentSearch(String query) {
    setState(() => _recent.remove(query));
    unawaited(_historyStore.remove(query));
  }

  void _clearRecentSearches() {
    setState(_recent.clear);
    unawaited(_historyStore.clear());
  }

  void _selectSuggestion(CatalogSearchSuggestion suggestion) {
    _searchDebounce?.cancel();
    _suggestionDebounce?.cancel();
    _addToRecent(suggestion.label);
    _controller.value = TextEditingValue(
      text: suggestion.label,
      selection: TextSelection.collapsed(offset: suggestion.label.length),
    );
    _searchFocusNode.unfocus();
    setState(() {
      _inputQuery = suggestion.label;
      _suggestionQuery = '';
      if (suggestion.kind == 'CATEGORY') {
        _controller.clear();
        _inputQuery = '';
        _query = '';
        _page = 1;
        _selectedCategorySlug = suggestion.slug;
        _selectedSubcategorySlug = null;
      } else if (suggestion.kind == 'SUBCATEGORY') {
        _controller.clear();
        _inputQuery = '';
        _query = '';
        _page = 1;
        _selectedCategorySlug = suggestion.categorySlug;
        _selectedSubcategorySlug = suggestion.slug;
      } else {
        _query = suggestion.label;
        _page = 1;
        _selectedCategorySlug = null;
        _selectedSubcategorySlug = null;
      }
    });
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
    _suggestionDebounce?.cancel();
    _searchFocusNode.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(selectedCatalogPincodeProvider, (previous, next) {
      if (previous != next) {
        _page = 1;
        _pagePincode = next;
      }
    });
    final selectedPincode = ref.watch(selectedCatalogPincodeProvider);
    final resultsPage = _pagePincode == selectedPincode ? _page : 1;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final searchFilters = _SearchFilters(
      query: _query,
      page: resultsPage,
      pincode: selectedPincode,
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
    final popularServices =
        catalogAsync.valueOrNull?.trending.isNotEmpty == true
        ? catalogAsync.valueOrNull!.trending
        : catalogAsync.valueOrNull?.popular ?? const <CatalogService>[];
    final trendingItems = popularServices
        .take(8)
        .map((service) {
          return _SearchItem(
            title: service.name,
            subtitle: service.hierarchyLabel,
            icon: Icons.home_repair_service_rounded,
            accent: AbzioTheme.accentColor,
            categorySlug:
                service.category?.slug ?? categorySlugById[service.categoryId],
            subcategorySlug: service.subcategory?.slug,
          );
        })
        .toList(growable: false);

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
            focusNode: _searchFocusNode,
            autofocus: true,
            maxLength: 120,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              _onQueryChanged(v);
            },
            onSubmitted: _setQuery,
            decoration: InputDecoration(
              hintText: 'Search for services…',
              hintStyle: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
              counterText: '',
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
      body:
          _searchHasFocus &&
              _inputQuery.trim().length >= 2 &&
              (_inputQuery.trim() != _query.trim() ||
                  _suggestionQuery.trim() == _inputQuery.trim())
          ? _suggestionQuery.isEmpty
                ? const _SearchLoadingState()
                : ref
                      .watch(searchAutocompleteProvider(_suggestionQuery))
                      .when(
                        data: (suggestions) => suggestions.isEmpty
                            ? _SearchSuggestionEmpty(
                                query: _suggestionQuery,
                                onBrowse: _clearSearch,
                              )
                            : _AutocompleteResults(
                                suggestions: suggestions,
                                onTap: _selectSuggestion,
                              ),
                        loading: () => const _SearchLoadingState(),
                        error: (error, stackTrace) => PremiumRetryState(
                          title: 'Could not load suggestions',
                          subtitle:
                              'Your search still works. Retry suggestions or submit the query.',
                          onRetry: () => ref.invalidate(
                            searchAutocompleteProvider(_suggestionQuery),
                          ),
                          onRefresh: () async {
                            await ref
                                .refresh(
                                  searchAutocompleteProvider(
                                    _suggestionQuery,
                                  ).future,
                                )
                                .then<void>((_) {});
                          },
                        ),
                      )
          : !showResults
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
                  query: item.title,
                  categorySlug: item.categorySlug,
                  subcategorySlug: item.subcategorySlug,
                ),
                onQueryTap: _setQuery,
                onClearRecent: _clearRecentSearches,
                onRemoveRecent: _removeRecentSearch,
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
              data: (resultPage) => _SearchResults(
                results: resultPage.items,
                total: resultPage.total,
                resultLimit: resultPage.resultLimit,
                page: resultsPage,
                onPageChanged: (nextPage) => setState(() {
                  _page = nextPage;
                  _pagePincode = selectedPincode;
                }),
                query: _query,
                activeFilters: activeFilterLabels,
                relatedServices: trendingItems,
                selectedPincode: ref.read(selectedCatalogPincodeProvider),
                onRelatedTap: _setQuery,
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

class _AutocompleteResults extends StatelessWidget {
  const _AutocompleteResults({required this.suggestions, required this.onTap});

  final List<CatalogSearchSuggestion> suggestions;
  final ValueChanged<CatalogSearchSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final kindLabel = switch (suggestion.kind.toUpperCase()) {
          'CATEGORY' => 'Category',
          'SUBCATEGORY' => 'Subcategory',
          'SERVICE' => 'Service',
          _ => 'Suggestion',
        };
        final icon = switch (suggestion.kind) {
          'CATEGORY' => Icons.grid_view_rounded,
          'SUBCATEGORY' => Icons.home_repair_service_outlined,
          _ => Icons.search_rounded,
        };
        return ListTile(
          minVerticalPadding: 8,
          leading: CircleAvatar(
            backgroundColor: colors.primary.withValues(alpha: 0.08),
            foregroundColor: colors.primary,
            child: Icon(icon, size: 20),
          ),
          title: Text(
            suggestion.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(kindLabel),
          trailing: const Icon(Icons.north_west_rounded, size: 17),
          onTap: () => onTap(suggestion),
        );
      },
    );
  }
}

class _SearchSuggestionEmpty extends StatelessWidget {
  const _SearchSuggestionEmpty({required this.query, required this.onBrowse});

  final String query;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No suggestions for "$query"',
          subtitle:
              'You can still submit this search to see matching services.',
          actionLabel: 'Browse all services',
          onAction: onBrowse,
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
    required this.onRemoveRecent,
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
  final ValueChanged<String> onRemoveRecent;

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
                  (r) => InputChip(
                    avatar: Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                    label: ConstrainedBox(
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
                    onPressed: () => onQueryTap(r),
                    onDeleted: () => onRemoveRecent(r),
                    deleteButtonTooltipMessage: 'Remove $r',
                    deleteIcon: const Icon(Icons.close_rounded, size: 16),
                    backgroundColor: cs.surfaceContainerHighest,
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
        ],
        Text(
          'Trending services',
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
    required this.total,
    required this.resultLimit,
    required this.page,
    required this.onPageChanged,
    required this.query,
    required this.activeFilters,
    required this.relatedServices,
    required this.selectedPincode,
    required this.onRelatedTap,
    this.onResultTap,
    required this.onClearSearch,
  });
  final List<CatalogService> results;
  final int total;
  final int? resultLimit;
  final int page;
  final ValueChanged<int> onPageChanged;
  final String query;
  final List<String> activeFilters;
  final List<_SearchItem> relatedServices;
  final String? selectedPincode;
  final ValueChanged<String> onRelatedTap;
  final ValueChanged<String>? onResultTap;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumGlassCard(
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
                    selectedPincode?.isNotEmpty == true
                        ? 'No matching service is available in $selectedPincode right now. Try another search or browse these available services.'
                        : 'Try a different search or clear your filters.',
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
                  if (page > 1) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => onPageChanged(1),
                      icon: const Icon(Icons.first_page_rounded),
                      label: const Text('Return to first page'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (relatedServices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Available services you can explore',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: relatedServices
                  .take(8)
                  .map((service) {
                    return ActionChip(
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          service.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: () => onRelatedTap(service.title),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ],
      );
    }
    return ListView.separated(
      key: ValueKey<int>(page),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: results.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == 0) {
          final countLabel = total == 1 ? 'service' : 'services';
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        total > (resultLimit ?? total)
                            ? 'Showing top $resultLimit of $total $countLabel · Page $page'
                            : '$total $countLabel found · Page $page',
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

        if (i == results.length + 1) {
          final visibleTotal = resultLimit == null
              ? total
              : total.clamp(0, resultLimit!);
          final pageCount = (visibleTotal / 20).ceil();
          if (pageCount <= 1) return const SizedBox.shrink();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Previous'),
              ),
              Text(
                '$page of $pageCount',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              TextButton.icon(
                onPressed: page < pageCount
                    ? () => onPageChanged(page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
                iconAlignment: IconAlignment.end,
              ),
            ],
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
