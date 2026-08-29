import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

final recentBroadcastsProvider =
    FutureProvider.autoDispose<List<AdminBroadcastSummary>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/admin/notifications/broadcasts');
  return (response['broadcasts'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(AdminBroadcastSummary.fromJson)
      .toList(growable: false);
});

final adminBroadcastDetailProvider = FutureProvider.autoDispose.family<AdminBroadcastDetail?, String>((ref, broadcastId) async {
  final trimmedBroadcastId = broadcastId.trim();
  if (trimmedBroadcastId.isEmpty) {
    return null;
  }

  final api = ref.watch(apiClientProvider);
  try {
    final response = await api.get('/admin/notifications/broadcasts/$trimmedBroadcastId');
    final payload = response['broadcast'];
    if (payload is Map<String, dynamic>) {
      final deliveries = (response['deliveries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminBroadcastDelivery.fromJson)
          .toList(growable: false);
      return AdminBroadcastDetail.fromJson(payload, deliveries);
    }
  } catch (_) {
    return null;
  }

  return null;
});

class AdminBroadcastSummary {
  const AdminBroadcastSummary({
    required this.broadcastId,
    required this.title,
    required this.body,
    required this.route,
    required this.targetRole,
    required this.recipientCount,
    required this.sentAt,
  });

  final String broadcastId;
  final String title;
  final String body;
  final String? route;
  final String? targetRole;
  final int recipientCount;
  final DateTime sentAt;

  factory AdminBroadcastSummary.fromJson(Map<String, dynamic> json) {
    return AdminBroadcastSummary(
      broadcastId: json['broadcastId'] as String? ?? '',
      title: json['title'] as String? ?? 'Broadcast',
      body: json['body'] as String? ?? '',
      route: json['route'] as String?,
      targetRole: json['targetRole'] as String?,
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? 0,
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AdminBroadcastDelivery {
  const AdminBroadcastDelivery({
    required this.title,
    required this.body,
    required this.sentAt,
    this.route,
    this.targetRole,
  });

  final String title;
  final String body;
  final String? route;
  final String? targetRole;
  final DateTime sentAt;

  factory AdminBroadcastDelivery.fromJson(Map<String, dynamic> json) {
    return AdminBroadcastDelivery(
      title: json['title'] as String? ?? 'Broadcast',
      body: json['body'] as String? ?? '',
      route: json['route'] as String?,
      targetRole: json['targetRole'] as String?,
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AdminBroadcastDetail {
  const AdminBroadcastDetail({
    required this.broadcastId,
    required this.title,
    required this.body,
    required this.route,
    required this.targetRole,
    required this.recipientCount,
    required this.sentAt,
    required this.deliveries,
  });

  final String broadcastId;
  final String title;
  final String body;
  final String? route;
  final String? targetRole;
  final int recipientCount;
  final DateTime sentAt;
  final List<AdminBroadcastDelivery> deliveries;

  factory AdminBroadcastDetail.fromJson(Map<String, dynamic> json, List<AdminBroadcastDelivery> deliveries) {
    return AdminBroadcastDetail(
      broadcastId: json['broadcastId'] as String? ?? '',
      title: json['title'] as String? ?? 'Broadcast',
      body: json['body'] as String? ?? '',
      route: json['route'] as String?,
      targetRole: json['targetRole'] as String?,
      recipientCount: (json['recipientCount'] as num?)?.toInt() ?? deliveries.length,
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? '') ?? DateTime.now(),
      deliveries: deliveries,
    );
  }
}

class PushSenderPage extends ConsumerStatefulWidget {
  const PushSenderPage({super.key});

  @override
  ConsumerState<PushSenderPage> createState() => _PushSenderPageState();
}

class _PushSenderPageState extends ConsumerState<PushSenderPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  String _targetRole = 'ALL';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _routeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/admin/notifications/broadcast', data: {
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'targetRole': _targetRole,
        if (_routeCtrl.text.trim().isNotEmpty) 'route': _routeCtrl.text.trim(),
      });

      if (!mounted) return;

      final data = response;
      final successCount = data['successCount'] ?? 0;
      final failureCount = data['failureCount'] ?? 0;
      final total = data['totalCount'] ?? data['notificationCount'] ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Broadcast sent to $successCount/$total recipients ($failureCount failed).')),
      );

      _titleCtrl.clear();
      _bodyCtrl.clear();
      _routeCtrl.clear();
      ref.invalidate(recentBroadcastsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send broadcast: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final broadcastsAsync = ref.watch(recentBroadcastsProvider);

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
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
          ),
        ),
        title: Text('Broadcast Notification', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PremiumSectionHeader(title: 'Compose Message'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _targetRole,
                decoration: InputDecoration(
                  labelText: 'Target Audience',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Users (Customers & Professionals)')),
                  DropdownMenuItem(value: 'CUSTOMER', child: Text('Customers Only')),
                  DropdownMenuItem(value: 'WORKER', child: Text('Professionals Only')),
                ],
                onChanged: (val) => setState(() => _targetRole = val ?? 'ALL'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Notification Title',
                  hintText: 'e.g. Flash Sale',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message Body',
                  hintText: 'e.g. Get 50% off all cleaning services this weekend.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Message is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _routeCtrl,
                decoration: InputDecoration(
                  labelText: 'Deep Link Route (Optional)',
                  hintText: 'e.g. /offers or /category/cleaning',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _sendBroadcast,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text(
                    'Send Broadcast',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const PremiumSectionHeader(title: 'Recent Broadcasts'),
              const SizedBox(height: 12),
              broadcastsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text('Unable to load broadcast history: $error'),
                  ),
                ),
                data: (broadcasts) {
                  if (broadcasts.isEmpty) {
                    return const PremiumEmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'No broadcasts yet',
                      subtitle: 'Sent messages will appear here with recipient counts and target routes.',
                    );
                  }

                  return Column(
                    children: broadcasts
                        .map(
                          (broadcast) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _BroadcastHistoryCard(
                              broadcast: broadcast,
                              onTap: () => context.push('/push/broadcasts/${broadcast.broadcastId}', extra: broadcast),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastHistoryCard extends StatelessWidget {
  const _BroadcastHistoryCard({
    required this.broadcast,
    required this.onTap,
  });

  final AdminBroadcastSummary broadcast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return TapScale(
      onTap: onTap,
      child: PremiumGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      broadcast.title,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${broadcast.recipientCount} recipients',
                      style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                broadcast.body,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BroadcastMetaChip(label: broadcast.targetRole ?? 'ALL', icon: Icons.group_rounded),
                  if (broadcast.route != null && broadcast.route!.trim().isNotEmpty)
                    _BroadcastMetaChip(label: broadcast.route!, icon: Icons.open_in_new_rounded),
                  _BroadcastMetaChip(
                    label: DateFormat('d MMM, h:mm a').format(broadcast.sentAt),
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BroadcastMetaChip extends StatelessWidget {
  const _BroadcastMetaChip({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class BroadcastDetailPage extends ConsumerStatefulWidget {
  const BroadcastDetailPage({
    super.key,
    required this.broadcastId,
    this.initialBroadcast,
  });

  final String broadcastId;
  final AdminBroadcastSummary? initialBroadcast;

  @override
  ConsumerState<BroadcastDetailPage> createState() => _BroadcastDetailPageState();
}

class _BroadcastDetailPageState extends ConsumerState<BroadcastDetailPage> {
  bool _showSeed = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final detailAsync = ref.watch(adminBroadcastDetailProvider(widget.broadcastId));
    final displayAsync = _showSeed && widget.initialBroadcast != null && detailAsync.isLoading
        ? AsyncValue.data(
            AdminBroadcastDetail.fromJson(
              <String, dynamic>{
                'broadcastId': widget.initialBroadcast!.broadcastId,
                'title': widget.initialBroadcast!.title,
                'body': widget.initialBroadcast!.body,
                'route': widget.initialBroadcast!.route,
                'targetRole': widget.initialBroadcast!.targetRole,
                'recipientCount': widget.initialBroadcast!.recipientCount,
                'sentAt': widget.initialBroadcast!.sentAt.toIso8601String(),
              },
              const [],
            ),
          )
        : detailAsync;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast Detail'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _showSeed = false);
              ref.invalidate(adminBroadcastDetailProvider(widget.broadcastId));
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
            child: Text('Could not load broadcast: $error', textAlign: TextAlign.center),
          ),
        ),
        data: (broadcast) {
          if (broadcast == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                    const SizedBox(height: 12),
                    Text('Broadcast not found.', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'This broadcast may be older than the current list window. Open it from Recent Broadcasts to keep the record attached.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            );
          }

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
                    Text(broadcast.title, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(broadcast.body, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _BroadcastMetaChip(label: broadcast.targetRole ?? 'ALL', icon: Icons.group_rounded),
                        if (broadcast.route != null && broadcast.route!.trim().isNotEmpty)
                          _BroadcastMetaChip(label: broadcast.route!, icon: Icons.open_in_new_rounded),
                        _BroadcastMetaChip(
                          label: '${broadcast.recipientCount} recipients',
                          icon: Icons.verified_rounded,
                        ),
                        _BroadcastMetaChip(
                          label: DateFormat('d MMM, h:mm a').format(broadcast.sentAt),
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailLine(label: 'Broadcast ID', value: broadcast.broadcastId),
                    _DetailLine(label: 'Target audience', value: broadcast.targetRole ?? 'ALL'),
                    _DetailLine(label: 'Deep link', value: broadcast.route ?? 'None'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: broadcast.broadcastId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Broadcast ID copied')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copy ID'),
                        ),
                        if (broadcast.route != null && broadcast.route!.trim().isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: broadcast.route!.trim()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Deep link copied')),
                              );
                            },
                            icon: const Icon(Icons.link_rounded, size: 16),
                            label: const Text('Copy deep link'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Delivery records', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (broadcast.deliveries.isEmpty)
                Text('No delivery records found.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))
              else
                ...broadcast.deliveries.map(
                  (delivery) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  delivery.title,
                                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              Text(DateFormat('d MMM, h:mm a').format(delivery.sentAt), style: tt.bodySmall),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(delivery.body, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _BroadcastMetaChip(label: delivery.targetRole ?? 'ALL', icon: Icons.group_rounded),
                              if (delivery.route != null && delivery.route!.trim().isNotEmpty)
                                _BroadcastMetaChip(label: delivery.route!, icon: Icons.open_in_new_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
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
            width: 120,
            child: Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: SelectableText(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
