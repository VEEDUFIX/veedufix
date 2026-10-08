import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../../core/widgets/shimmer_placeholder.dart';

class CategoryServicesSheet extends ConsumerStatefulWidget {
  const CategoryServicesSheet({
    super.key,
    required this.category,
    required this.onServiceTap,
  });

  final CatalogCategory category;
  final ValueChanged<CatalogService> onServiceTap;

  @override
  ConsumerState<CategoryServicesSheet> createState() =>
      _CategoryServicesSheetState();
}

class _CategoryServicesSheetState extends ConsumerState<CategoryServicesSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryAsync = ref.watch(
      catalogCategoryProvider(widget.category.slug),
    );
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: VeeduFixDesignSystem.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(VeeduFixDesignSystem.radiusLarge),
          ),
          border: Border.all(color: VeeduFixDesignSystem.border),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.category.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close category',
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              categoryAsync.when(
                loading: () => Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [_loadingGrid()],
                  ),
                ),
                error: (_, __) => Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 36),
                      Icon(
                        Icons.cloud_off_outlined,
                        size: 40,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Couldn't load this category.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: FilledButton.tonalIcon(
                          onPressed: () => ref.invalidate(
                            catalogCategoryProvider(widget.category.slug),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (category) {
                  final groups = category.subcategories
                      .where(
                        (group) => group.isActive && group.serviceCount > 0,
                      )
                      .toList(growable: false);
                  final totalServices = groups.fold<int>(
                    0,
                    (total, group) => total + group.serviceCount,
                  );
                  final visibleGroups = _filterGroups(groups);

                  return Expanded(
                    child: Column(
                      children: [
                        if (totalServices >= 8)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: SizedBox(
                              height: VeeduFixDesignSystem.inputHeight,
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {});
                                  _searchDebounce?.cancel();
                                  _searchDebounce = Timer(
                                    const Duration(milliseconds: 250),
                                    () {
                                      if (mounted) {
                                        setState(() => _query = value);
                                      }
                                    },
                                  );
                                },
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  hintText: 'Search in ${widget.category.name}',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                  ),
                                  suffixIcon: _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            _searchDebounce?.cancel();
                                            _searchController.clear();
                                            setState(() => _query = '');
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                  filled: true,
                                  fillColor: VeeduFixDesignSystem.ivory,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      VeeduFixDesignSystem.radiusMedium,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      VeeduFixDesignSystem.radiusMedium,
                                    ),
                                    borderSide: BorderSide(
                                      color: AbzioTheme.lightBorder.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: groups.isEmpty
                              ? ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    const SizedBox(height: 24),
                                    Icon(
                                      Icons.home_repair_service_outlined,
                                      size: 42,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'This service category is coming soon.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color:
                                                AbzioTheme.lightTextSecondary,
                                          ),
                                    ),
                                  ],
                                )
                              : visibleGroups.isEmpty
                              ? ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    Text(
                                      'No matching services. Try another search.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color:
                                                AbzioTheme.lightTextSecondary,
                                          ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    VeeduFixDesignSystem.space16,
                                    0,
                                    VeeduFixDesignSystem.space16,
                                    VeeduFixDesignSystem.space24,
                                  ),
                                  itemCount: visibleGroups.length,
                                  itemBuilder: (context, index) {
                                    final group = visibleGroups[index];
                                    final isFewGroups = groups.length <= 3;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: _ServiceGroup(
                                        key: ValueKey(
                                          '${group.subcategory.id}:${_query.trim()}',
                                        ),
                                        categorySlug: category.slug,
                                        group: group.subcategory,
                                        searchQuery: group.searchQuery,
                                        initiallyExpanded:
                                            isFewGroups ||
                                            _query.trim().isNotEmpty,
                                        onServiceTap: _openService,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_VisibleGroup> _filterGroups(List<CatalogSubcategory> groups) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return groups
          .map((group) => _VisibleGroup(group, ''))
          .toList(growable: false);
    }
    return groups
        .map(
          (group) => _VisibleGroup(
            group,
            group.name.toLowerCase().contains(query) ? '' : _query.trim(),
          ),
        )
        .toList(growable: false);
  }

  Widget _loadingGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        mainAxisExtent: 108,
      ),
      itemBuilder: (context, index) => const Column(
        children: [
          ShimmerPlaceholder(width: 64, height: 64, borderRadius: 14),
          SizedBox(height: 8),
          ShimmerPlaceholder(width: 60, height: 12, borderRadius: 6),
          SizedBox(height: 4),
          ShimmerPlaceholder(width: 42, height: 12, borderRadius: 6),
        ],
      ),
    );
  }

  void _openService(CatalogService service) {
    Navigator.of(context).pop();
    widget.onServiceTap(service);
  }
}

class _VisibleGroup {
  const _VisibleGroup(this.subcategory, this.searchQuery);

  final CatalogSubcategory subcategory;
  final String searchQuery;
}

class _ServiceGroup extends ConsumerStatefulWidget {
  const _ServiceGroup({
    super.key,
    required this.categorySlug,
    required this.group,
    required this.searchQuery,
    required this.initiallyExpanded,
    required this.onServiceTap,
  });

  final String categorySlug;
  final CatalogSubcategory group;
  final String searchQuery;
  final bool initiallyExpanded;
  final ValueChanged<CatalogService> onServiceTap;

  @override
  ConsumerState<_ServiceGroup> createState() => _ServiceGroupState();
}

class _ServiceGroupState extends ConsumerState<_ServiceGroup> {
  late bool _expanded;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _expanded
        ? List<AsyncValue<CatalogServicePage>>.generate(
            _page,
            (index) => ref.watch(
              catalogSubcategoryServicesProvider(
                CatalogServiceQuery(
                  categorySlug: widget.categorySlug,
                  subcategorySlug: widget.group.slug,
                  search: widget.searchQuery,
                  page: index + 1,
                ),
              ),
            ),
          )
        : const <AsyncValue<CatalogServicePage>>[];
    final services = pages
        .map((page) => page.valueOrNull?.items ?? const <CatalogService>[])
        .expand((items) => items)
        .toList(growable: false);
    final total = pages.isEmpty ? 0 : pages.first.valueOrNull?.total ?? 0;
    final loading = pages.any((page) => page.isLoading);
    final error = pages.any((page) => page.hasError);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        onExpansionChanged: (expanded) => setState(() {
          _expanded = expanded;
          if (expanded) _page = 1;
        }),
        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '${widget.group.name}  ·  ${widget.group.serviceCount}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AbzioTheme.lightTextPrimary,
          ),
        ),
        trailing: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: AbzioTheme.lightTextSecondary,
        ),
        children: !_expanded
            ? const []
            : [
                if (loading && services.isEmpty)
                  _loadingGrid()
                else if (error && services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton.icon(
                      onPressed: () {
                        for (var page = 1; page <= _page; page++) {
                          ref.invalidate(
                            catalogSubcategoryServicesProvider(
                              CatalogServiceQuery(
                                categorySlug: widget.categorySlug,
                                subcategorySlug: widget.group.slug,
                                search: widget.searchQuery,
                                page: page,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text("Couldn't load services. Retry"),
                    ),
                  )
                else if (services.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      widget.searchQuery.isEmpty
                          ? 'Services are coming soon.'
                          : 'No matching services in this group.',
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: services.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 108,
                        ),
                    itemBuilder: (context, index) => _ServiceTile(
                      service: services[index],
                      onTap: () => widget.onServiceTap(services[index]),
                    ),
                  ),
                if (loading && services.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (error && services.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      for (var page = 1; page <= _page; page++) {
                        ref.invalidate(
                          catalogSubcategoryServicesProvider(
                            CatalogServiceQuery(
                              categorySlug: widget.categorySlug,
                              subcategorySlug: widget.group.slug,
                              search: widget.searchQuery,
                              page: page,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text("Couldn't load more. Retry"),
                  ),
                if (services.length < total && !loading)
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _page++),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Load more services'),
                    ),
                  ),
              ],
      ),
    );
  }

  Widget _loadingGrid() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 4,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 12,
      mainAxisExtent: 108,
    ),
    itemBuilder: (context, index) => const Column(
      children: [
        ShimmerPlaceholder(width: 64, height: 64, borderRadius: 14),
        SizedBox(height: 8),
        ShimmerPlaceholder(width: 60, height: 12, borderRadius: 6),
      ],
    ),
  );
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final CatalogService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String? imageUrl = service.iconUrl;
    for (final image in service.images) {
      if (image.isPrimary) {
        imageUrl = image.url;
        break;
      }
    }
    if ((imageUrl == null || imageUrl.isEmpty) && service.images.isNotEmpty) {
      imageUrl = service.images.first.url;
    }

    return Semantics(
      button: true,
      label: 'View ${service.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 64,
                  height: 64,
                  color: AbzioTheme.lightMuted,
                  child: imageUrl == null || imageUrl.isEmpty
                      ? const Icon(
                          Icons.home_repair_service_rounded,
                          color: AbzioTheme.accentColor,
                          size: 28,
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 192,
                          memCacheHeight: 192,
                          placeholder: (_, __) => const ShimmerPlaceholder(
                            width: 64,
                            height: 64,
                            borderRadius: 14,
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.home_repair_service_rounded,
                            color: AbzioTheme.accentColor,
                            size: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                service.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  height: 1.15,
                  color: AbzioTheme.lightTextPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
