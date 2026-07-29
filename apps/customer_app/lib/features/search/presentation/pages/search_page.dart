import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import '../../../../core/widgets/shimmer_placeholder.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  // Session-scoped recent searches — mutable so clear/add works live
  final List<String> _recent = [];

  static const List<_SearchItem> _fallbackTrending = [
    _SearchItem(title: 'AC Gas Refill', icon: Icons.ac_unit_rounded, accent: Color(0xFF38BDF8)),
    _SearchItem(title: 'Deep Cleaning', icon: Icons.cleaning_services_rounded, accent: Color(0xFF10B981)),
    _SearchItem(title: 'Pest Control', icon: Icons.bug_report_rounded, accent: Color(0xFFF59E0B)),
    _SearchItem(title: 'Plumbing', icon: Icons.plumbing_rounded, accent: Color(0xFF8B5CF6)),
    _SearchItem(title: 'Painting', icon: Icons.format_paint_rounded, accent: Color(0xFFEF4444)),
    _SearchItem(title: 'Carpentry', icon: Icons.handyman_rounded, accent: Color(0xFFC2A15E)),
  ];

  static const List<Color> _accentCycle = [
    Color(0xFFC2A15E), Color(0xFF10B981), Color(0xFF60A5FA),
    Color(0xFFF59E0B), Color(0xFF38BDF8), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF14B8A6), Color(0xFFEC4899),
  ];

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final searchAsync = ref.watch(searchCatalogProvider(_query));
    final catalogAsync = ref.watch(homeCatalogProvider);

    // Build trending items: real categories from API if available, else fallback
    final trendingItems = catalogAsync.maybeWhen(
      data: (data) => data.categories.isEmpty
          ? _fallbackTrending
          : data.categories.take(9).toList().asMap().entries.map((e) {
              final cat = e.value;
              final color = _accentCycle[e.key % _accentCycle.length];
              return _SearchItem(
                title: cat.name,
                icon: Icons.home_repair_service_rounded,
                accent: color,
                slug: cat.slug,
              );
            }).toList(),
      orElse: () => _fallbackTrending,
    );

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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
            borderRadius: BorderRadius.circular(16),
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
      body: _query.isEmpty
          ? _SearchHome(
              recent: _recent,
              trending: trendingItems,
              onQueryTap: _setQuery,
              onClearRecent: () => setState(() => _recent.clear()),
            )
          : searchAsync.when(
              data: (results) => _SearchResults(
                results: results,
                query: _query,
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
    required this.onQueryTap,
    required this.onClearRecent,
  });
  final List<String> recent;
  final List<_SearchItem> trending;
  final ValueChanged<String> onQueryTap;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
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
                          borderRadius: BorderRadius.circular(20),
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
        Text('Trending Now',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
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
              onTap: () => onQueryTap(item.title),
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
                          borderRadius: BorderRadius.circular(16),
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
    this.onResultTap,
  });
  final List<CatalogService> results;
  final String query;
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
                      borderRadius: BorderRadius.circular(16),
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
                        if (item.startingPrice > 0)
                          Text(
                            'From ₹${item.startingPrice.toInt()}',
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
    this.slug,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final String? slug;
}
