import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../data/review_moderation_api.dart';

class ReviewModerationPage extends ConsumerStatefulWidget {
  const ReviewModerationPage({super.key});

  @override
  ConsumerState<ReviewModerationPage> createState() =>
      _ReviewModerationPageState();
}

class _ReviewModerationPageState extends ConsumerState<ReviewModerationPage> {
  late final ReviewModerationApi _api;
  List<ReviewModerationItem> _items = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _workingIds = {};

  @override
  void initState() {
    super.initState();
    _api = ReviewModerationApi(ref.read(apiClientProvider).dio);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.fetchReports();
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load review reports. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _setVisibility(ReviewModerationItem item, bool visible) async {
    if (!_workingIds.add(item.reviewId)) return;
    setState(() {});
    try {
      await _api.setVisibility(item.reviewId, visible: visible);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(visible ? 'Review restored.' : 'Review hidden.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update review visibility.')),
        );
      }
    } finally {
      _workingIds.remove(item.reviewId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _dismissReport(ReviewModerationItem item) async {
    if (!_workingIds.add(item.reviewId)) return;
    setState(() {});
    try {
      await _api.dismissReport(item.reportId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report dismissed.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not dismiss this report.')),
        );
      }
    } finally {
      _workingIds.remove(item.reviewId);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Review moderation',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Customer reports',
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Review reported content and hide reviews that violate marketplace guidelines. Hidden reviews no longer affect public ratings.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 18),
                      if (_items.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('No review reports need attention.'),
                            ),
                          ),
                        ),
                      for (final item in _items)
                        _ReviewReportCard(
                          item: item,
                          working: _workingIds.contains(item.reviewId),
                          onHide: () => _setVisibility(item, false),
                          onRestore: () => _setVisibility(item, true),
                          onDismiss: () => _dismissReport(item),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _ReviewReportCard extends StatelessWidget {
  const _ReviewReportCard({
    required this.item,
    required this.working,
    required this.onHide,
    required this.onRestore,
    required this.onDismiss,
  });

  final ReviewModerationItem item;
  final bool working;
  final VoidCallback onHide;
  final VoidCallback onRestore;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final hidden = item.reviewStatus == 'hidden';
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(label: Text(hidden ? 'Hidden' : 'Reported')),
                Text('Booking ${item.bookingCode}'),
                Text('Professional: ${item.workerName}'),
                Text('Reviewer: ${item.reviewerName}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var index = 0; index < item.rating.clamp(0, 5); index++)
                  const Icon(Icons.star_rounded,
                      color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.comment?.trim().isNotEmpty == true
                        ? item.comment!
                        : 'No written comment',
                  ),
                ),
              ],
            ),
            if (item.workerResponse?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Professional response: ${item.workerResponse}'),
              ),
            ],
            const Divider(height: 24),
            Text('Report by ${item.reporterName}: ${item.reason}'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: working ? null : (hidden ? onRestore : onHide),
                    icon: working
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(hidden
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                    label: Text(hidden ? 'Restore review' : 'Hide review'),
                  ),
                  if (!hidden)
                    TextButton(
                      onPressed: working ? null : onDismiss,
                      child: const Text('Dismiss report'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
