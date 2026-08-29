import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminAuditLogEntry {
  const AdminAuditLogEntry({
    required this.id,
    required this.adminId,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.createdAt,
    this.note,
    this.metadata,
  });

  final String id;
  final String adminId;
  final String action;
  final String targetType;
  final String targetId;
  final String? note;
  final dynamic metadata;
  final DateTime createdAt;

  factory AdminAuditLogEntry.fromJson(Map<String, dynamic> json) => AdminAuditLogEntry(
        id: json['id'] as String? ?? '',
        adminId: json['adminId'] as String? ?? '',
        action: json['action'] as String? ?? 'unknown',
        targetType: json['targetType'] as String? ?? 'unknown',
        targetId: json['targetId'] as String? ?? '',
        note: json['note'] as String?,
        metadata: json['metadata'],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

final adminAuditLogsProvider = FutureProvider.autoDispose.family<List<AdminAuditLogEntry>, String>((ref, search) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(
    '/admin/audit-logs',
    queryParameters: {
      if (search.trim().isNotEmpty) 'q': search.trim(),
    },
  );
  return (response['logs'] as List<dynamic>? ?? [])
      .map((item) => AdminAuditLogEntry.fromJson(item as Map<String, dynamic>))
      .toList();
});

final adminAuditLogDetailProvider = FutureProvider.autoDispose.family<AdminAuditLogEntry?, String>((ref, logId) async {
  final trimmedLogId = logId.trim();
  if (trimmedLogId.isEmpty) {
    return null;
  }

  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('/admin/audit-logs/$trimmedLogId');
    final payload = response['log'];
    if (payload is Map<String, dynamic>) {
      return AdminAuditLogEntry.fromJson(payload);
    }
  } catch (_) {
    return null;
  }

  return null;
});

class AuditLogsPage extends ConsumerStatefulWidget {
  const AuditLogsPage({super.key, this.initialSearch = ''});

  final String initialSearch;

  @override
  ConsumerState<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends ConsumerState<AuditLogsPage> {
  late final TextEditingController _searchController;
  late String _search;

  @override
  void initState() {
    super.initState();
    _search = widget.initialSearch.trim();
    _searchController = TextEditingController(text: _search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(adminAuditLogsProvider(_search));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(adminAuditLogsProvider(_search)),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operational history for admin actions and recovery flows.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search action, target, note, or admin id',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _search = '';
                                    });
                                  },
                                  icon: const Icon(Icons.clear_rounded),
                                ),
                        ),
                        onSubmitted: (value) {
                          setState(() {
                            _search = value.trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _search = _searchController.text.trim();
                        });
                      },
                      icon: const Icon(Icons.filter_alt_rounded),
                      label: const Text('Filter'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AuditFilterChip(
                      label: 'All',
                      selected: _search.isEmpty,
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _search = '';
                        });
                      },
                    ),
                    _AuditFilterChip(
                      label: 'Workers',
                      selected: _search.contains('worker'),
                      onTap: () {
                        setState(() {
                          _searchController.text = 'worker';
                          _search = 'worker';
                        });
                      },
                    ),
                    _AuditFilterChip(
                      label: 'Payments',
                      selected: _search.contains('refund') || _search.contains('payout'),
                      onTap: () {
                        setState(() {
                          _searchController.text = 'refund';
                          _search = 'refund';
                        });
                      },
                    ),
                    _AuditFilterChip(
                      label: 'Catalog',
                      selected: _search.contains('catalog'),
                      onTap: () {
                        setState(() {
                          _searchController.text = 'catalog';
                          _search = 'catalog';
                        });
                      },
                    ),
                    _AuditFilterChip(
                      label: 'Disputes',
                      selected: _search.contains('dispute'),
                      onTap: () {
                        setState(() {
                          _searchController.text = 'dispute';
                          _search = 'dispute';
                        });
                      },
                    ),
                    _AuditFilterChip(
                      label: 'Settings',
                      selected: _search.contains('setting'),
                      onTap: () {
                        setState(() {
                          _searchController.text = 'setting';
                          _search = 'setting';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load audit logs: $error', textAlign: TextAlign.center),
                ),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.manage_search_rounded, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          const SizedBox(height: 12),
                          Text('No audit logs found.', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(
                            _search.isEmpty
                                ? 'Once admins approve, refund, retry, or update content, the trail will appear here.'
                                : 'Try a broader search or clear the filter chips.',
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final isMoney = log.action.contains('refund') || log.action.contains('payout');
                    final isWorker = log.action.contains('worker');
                    final relatedRoute = _relatedRouteForLog(log);
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => context.push('/audit-logs/${log.id}', extra: log),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (isMoney ? const Color(0xFF0F766E) : isWorker ? const Color(0xFF7C3AED) : cs.primaryContainer)
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(log.action, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(log.targetType, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                                ),
                                const Spacer(),
                                Text(DateFormat('dd MMM, h:mm a').format(log.createdAt), style: tt.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Target: ${log.targetId}', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text('Admin: ${log.adminId}', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                            if (log.note != null && log.note!.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(log.note!, style: tt.bodyMedium),
                            ],
                            if (log.metadata != null) ...[
                              const SizedBox(height: 10),
                              SelectableText(
                                const JsonEncoder.withIndent('  ').convert(log.metadata),
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: log.targetId));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Target ID copied')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copy target ID'),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: log.id));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Log ID copied')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copy log ID'),
                                ),
                                if (relatedRoute != null)
                                  TextButton.icon(
                                    onPressed: () => context.push(relatedRoute),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                    label: Text('Open related ${_relatedLabelForLog(log)}'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AuditLogDetailPage extends ConsumerStatefulWidget {
  const AuditLogDetailPage({
    super.key,
    required this.logId,
    this.initialLog,
  });

  final String logId;
  final AdminAuditLogEntry? initialLog;

  @override
  ConsumerState<AuditLogDetailPage> createState() => _AuditLogDetailPageState();
}

class _AuditLogDetailPageState extends ConsumerState<AuditLogDetailPage> {
  bool _showSeed = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final detailAsync = ref.watch(adminAuditLogDetailProvider(widget.logId));
    final displayAsync = _showSeed && widget.initialLog != null && detailAsync.isLoading
        ? AsyncValue.data(widget.initialLog)
        : detailAsync;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log Detail'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _showSeed = false;
              });
              ref.invalidate(adminAuditLogDetailProvider(widget.logId));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: displayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load audit log: $error', textAlign: TextAlign.center),
          ),
        ),
        data: (log) {
          if (log == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_note_rounded, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text('Audit log not found.', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'This log may be older than the first few pages. Open it from the list view to carry the record through.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

          final metadataText = log.metadata == null ? null : const JsonEncoder.withIndent('  ').convert(log.metadata);
          final relatedRoute = _relatedRouteForLog(log);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log.action, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailChip(label: log.targetType, accent: cs.primary),
                        _DetailChip(label: log.targetId, accent: const Color(0xFF0F766E)),
                        _DetailChip(label: log.adminId, accent: const Color(0xFF7C3AED)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailLine(label: 'Log ID', value: log.id),
                    _DetailLine(label: 'Action', value: log.action),
                    _DetailLine(label: 'Target type', value: log.targetType),
                    _DetailLine(label: 'Target ID', value: log.targetId),
                    _DetailLine(label: 'Admin ID', value: log.adminId),
                    _DetailLine(label: 'Created', value: DateFormat('dd MMM yyyy, h:mm a').format(log.createdAt)),
                    if (log.note != null && log.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Note', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(log.note!, style: tt.bodyMedium),
                    ],
                    if (metadataText != null) ...[
                      const SizedBox(height: 12),
                      Text('Metadata', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SelectableText(
                          metadataText,
                          style: tt.bodySmall?.copyWith(fontFamily: 'monospace', color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                    if (relatedRoute != null) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => context.push(relatedRoute),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(
                            'Open related ${_relatedLabelForLog(log)}',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
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
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: accent),
      ),
    );
  }
}

class _AuditFilterChip extends StatelessWidget {
  const _AuditFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: tt.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

String? _relatedRouteForLog(AdminAuditLogEntry log) {
  final targetType = log.targetType.toLowerCase().trim();
  final targetId = log.targetId.trim();
  if (targetId.isEmpty) {
    return null;
  }

  if (targetType.contains('dispute')) {
    return '/ops/disputes/$targetId';
  }
  if (targetType.contains('payout')) {
    return '/finance/payouts/$targetId';
  }
  if (targetType.contains('refund')) {
    return '/finance/refunds/$targetId';
  }
  if (targetType.contains('worker') || targetType.contains('profile')) {
    return '/workers/$targetId';
  }
  if (targetType.contains('booking')) {
    return '/bookings/$targetId';
  }
  return null;
}

String _relatedLabelForLog(AdminAuditLogEntry log) {
  final targetType = log.targetType.toLowerCase().trim();
  if (targetType.contains('dispute')) {
    return 'dispute';
  }
  if (targetType.contains('payout')) {
    return 'payout';
  }
  if (targetType.contains('refund')) {
    return 'refund';
  }
  if (targetType.contains('worker') || targetType.contains('profile')) {
    return 'worker profile';
  }
  if (targetType.contains('booking')) {
    return 'booking';
  }
  return 'record';
}
