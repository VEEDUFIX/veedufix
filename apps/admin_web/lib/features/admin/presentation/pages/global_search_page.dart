import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminSearchResult {
  const AdminSearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    this.avatarUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String route;
  final String? avatarUrl;

  factory AdminSearchResult.fromJson(Map<String, dynamic> json) {
    return AdminSearchResult(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      route: json['route'] as String? ?? '/admin',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class AdminSearchResults {
  const AdminSearchResults({
    required this.customers,
    required this.workers,
    required this.bookings,
    required this.tickets,
  });

  final List<AdminSearchResult> customers;
  final List<AdminSearchResult> workers;
  final List<AdminSearchResult> bookings;
  final List<AdminSearchResult> tickets;

  factory AdminSearchResults.fromJson(Map<String, dynamic> json) {
    List<AdminSearchResult> decodeList(dynamic value) {
      if (value is! List) {
        return const [];
      }
      return value
          .whereType<Map<String, dynamic>>()
          .map(AdminSearchResult.fromJson)
          .toList(growable: false);
    }

    return AdminSearchResults(
      customers: decodeList(json['customers']),
      workers: decodeList(json['workers']),
      bookings: decodeList(json['bookings']),
      tickets: decodeList(json['tickets']),
    );
  }
}

final adminGlobalSearchProvider = FutureProvider.autoDispose.family<AdminSearchResults, String>((ref, query) async {
  final normalized = query.trim();
  if (normalized.isEmpty) {
    return const AdminSearchResults(customers: [], workers: [], bookings: [], tickets: []);
  }

  final api = ref.watch(apiClientProvider);
  final response = await api.get(
    '/admin/search',
    queryParameters: {'q': normalized},
  );
  return AdminSearchResults.fromJson(response);
});

class AdminGlobalSearchPage extends ConsumerStatefulWidget {
  const AdminGlobalSearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<AdminGlobalSearchPage> createState() => _AdminGlobalSearchPageState();
}

class _AdminGlobalSearchPageState extends ConsumerState<AdminGlobalSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    _query = widget.initialQuery;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final resultsAsync = ref.watch(adminGlobalSearchProvider(_query));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        title: Text('Global Search', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Search booking IDs, ticket IDs, customers, workers, phones, or services...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                if (mounted) {
                  setState(() => _query = value);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          if (_query.trim().isEmpty)
            const _SearchHintCard(
              title: 'Search across the admin panel',
              subtitle: 'Try a booking code, customer phone, worker name, or ticket subject.',
            )
          else
            resultsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: _GlobalSearchSkeleton(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: PremiumEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load search results',
                  subtitle:
                      'Admin search is unavailable right now. Please retry.',
                  actionLabel: 'Retry',
                  onAction: () {
                    unawaited(ref.refresh(adminGlobalSearchProvider(_query).future));
                  },
                ),
              ),
              data: (results) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SearchSection(
                      title: 'Customers',
                      results: results.customers,
                      onTap: (item) => context.go(item.route),
                    ),
                    const SizedBox(height: 16),
                    _SearchSection(
                      title: 'Workers',
                      results: results.workers,
                      onTap: (item) => context.go(item.route),
                    ),
                    const SizedBox(height: 16),
                    _SearchSection(
                      title: 'Bookings',
                      results: results.bookings,
                      onTap: (item) => context.go(item.route),
                    ),
                    const SizedBox(height: 16),
                    _SearchSection(
                      title: 'Support Tickets',
                      results: results.tickets,
                      onTap: (item) => context.go(item.route),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SearchHintCard extends StatelessWidget {
  const _SearchHintCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.results,
    required this.onTap,
  });

  final String title;
  final List<AdminSearchResult> results;
  final void Function(AdminSearchResult item) onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (results.isEmpty)
          Text('No matches', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
        else
          ...results.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TapScale(
                onTap: () => onTap(item),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.primaryContainer,
                        backgroundImage: item.avatarUrl == null ? null : NetworkImage(item.avatarUrl!),
                        child: item.avatarUrl == null
                            ? Text(
                                item.title.isNotEmpty ? item.title[0].toUpperCase() : '?',
                                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(item.subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy ID',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: item.id));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GlobalSearchSkeleton extends StatelessWidget {
  const _GlobalSearchSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(width: 220, height: 24),
        SizedBox(height: 20),
        _SkeletonBlock(width: double.infinity, height: 84),
        SizedBox(height: 12),
        _SkeletonBlock(width: double.infinity, height: 84),
        SizedBox(height: 12),
        _SkeletonBlock(width: double.infinity, height: 84),
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
    return ShimmerWidget(width: width, height: height, radius: 12);
  }
}
