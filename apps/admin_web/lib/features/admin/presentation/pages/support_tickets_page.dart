import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class AdminSupportTicket {
  const AdminSupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.replyCount,
    this.userName,
    this.userPhone,
    this.assignedToName,
  });

  final String id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final int replyCount;
  final String? userName;
  final String? userPhone;
  final String? assignedToName;

  factory AdminSupportTicket.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final assignedTo = json['assignedTo'] as Map<String, dynamic>?;
    return AdminSupportTicket(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Support ticket',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
      userName: user?['name'] as String?,
      userPhone: user?['phone'] as String?,
      assignedToName: assignedTo?['name'] as String?,
    );
  }
}

final adminSupportTicketsProvider = FutureProvider.autoDispose
    .family<List<AdminSupportTicket>, ({String search, String status})>((ref, filter) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get(
    '/admin/support/tickets',
    queryParameters: {
      if (filter.search.isNotEmpty) 'search': filter.search,
      if (filter.status.isNotEmpty) 'status': filter.status,
    },
  );
  return (data['tickets'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(AdminSupportTicket.fromJson)
      .toList(growable: false);
});

class AdminSupportTicketReply {
  const AdminSupportTicketReply({
    required this.id,
    required this.message,
    required this.createdAt,
    required this.isInternal,
    this.authorName,
    this.authorRole,
  });

  final String id;
  final String message;
  final DateTime createdAt;
  final bool isInternal;
  final String? authorName;
  final String? authorRole;

  factory AdminSupportTicketReply.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return AdminSupportTicketReply(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isInternal: json['isInternal'] as bool? ?? false,
      authorName: author?['name'] as String?,
      authorRole: author?['role'] as String?,
    );
  }
}

class AdminSupportTicketThread {
  const AdminSupportTicketThread({
    required this.ticket,
    required this.replies,
  });

  final AdminSupportTicket ticket;
  final List<AdminSupportTicketReply> replies;

  factory AdminSupportTicketThread.fromJson(Map<String, dynamic> json) {
    final ticket = AdminSupportTicket.fromJson(json);
    final replies = (json['replies'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdminSupportTicketReply.fromJson)
        .toList(growable: false);
    return AdminSupportTicketThread(ticket: ticket, replies: replies);
  }
}

final adminSupportTicketThreadProvider =
    FutureProvider.autoDispose.family<AdminSupportTicketThread, String>((ref, ticketId) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/admin/support/tickets/$ticketId');
  return AdminSupportTicketThread.fromJson(response['ticket'] as Map<String, dynamic>);
});

class SupportTicketsPage extends ConsumerStatefulWidget {
  const SupportTicketsPage({super.key, this.initialSearch = ''});

  final String initialSearch;

  @override
  ConsumerState<SupportTicketsPage> createState() => _SupportTicketsPageState();
}

class _SupportTicketsPageState extends ConsumerState<SupportTicketsPage> {
  final _searchController = TextEditingController();
  String _status = '';
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSearch.isNotEmpty) {
      _searchController.text = widget.initialSearch;
      _search = widget.initialSearch;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String ticketId, String status) async {
    final api = ref.read(apiClientProvider);
    await api.patch('/admin/support/tickets/$ticketId/status', data: {'status': status});
    ref.invalidate(adminSupportTicketsProvider((search: _search, status: _status)));
  }

  Future<void> _escalate(AdminSupportTicket ticket) async {
    final noteController = TextEditingController(text: 'Escalated by admin for urgent review.');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Escalate ${ticket.subject}'),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Internal escalation note',
              hintText: 'Describe why this ticket needs attention',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Escalate'),
            ),
          ],
        );
      },
    );

    if (accepted != true) {
      noteController.dispose();
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final adminId = ref.read(authControllerProvider).valueOrNull?.user.id;
      if (adminId != null && ticket.assignedToName == null) {
        await api.patch('/admin/support/tickets/${ticket.id}/assignment', data: {'assignedToUserId': adminId});
      }
      await api.post(
        '/admin/support/tickets/${ticket.id}/replies',
        data: {
          'message': noteController.text.trim(),
          'isInternal': true,
        },
      );
      await api.patch('/admin/support/tickets/${ticket.id}/status', data: {'status': 'IN_PROGRESS'});
      ref.invalidate(adminSupportTicketsProvider((search: _search, status: _status)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket escalated')),
        );
      }
    } finally {
      noteController.dispose();
    }
  }

  Future<void> _openTicketDetails(AdminSupportTicket ticket) async {
    await context.push('/support-tickets/${ticket.id}');
    if (mounted) {
      ref.invalidate(adminSupportTicketsProvider((search: _search, status: _status)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ticketsAsync = ref.watch(adminSupportTicketsProvider((search: _search, status: _status)));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Support Tickets', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminSupportTicketsProvider((search: _search, status: _status)).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.support_agent_rounded, color: cs.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Support command center',
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep customer issues moving by filtering, escalating, and resolving tickets from one place.',
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => context.go('/admin/action-inbox'),
                      icon: const Icon(Icons.inbox_rounded, size: 18),
                      label: const Text('Open inbox'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AdminKpiPill(
                    label: 'Open',
                    value: ticketsAsync.maybeWhen(
                      data: (tickets) => tickets.where((ticket) => ticket.status == 'OPEN').length.toString(),
                      orElse: () => '...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminKpiPill(
                    label: 'In progress',
                    value: ticketsAsync.maybeWhen(
                      data: (tickets) => tickets.where((ticket) => ticket.status == 'IN_PROGRESS').length.toString(),
                      orElse: () => '...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AdminKpiPill(
                    label: 'Resolved',
                    value: ticketsAsync.maybeWhen(
                      data: (tickets) => tickets.where((ticket) => ticket.status == 'RESOLVED').length.toString(),
                      orElse: () => '...',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by ticket ID, subject, user name, phone, assignee, or message...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status.isEmpty ? null : _status,
              decoration: InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('All')),
                DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                DropdownMenuItem(value: 'IN_PROGRESS', child: Text('In progress')),
                DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
            ),
            const SizedBox(height: 16),
            ticketsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    _TicketSkeletonCard(),
                    SizedBox(height: 12),
                    _TicketSkeletonCard(),
                    SizedBox(height: 12),
                    _TicketSkeletonCard(),
                  ],
                ),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PremiumGlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: cs.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Icons.cloud_off_rounded, color: cs.error),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Could not load support tickets',
                                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'The ticket queue is unavailable right now. Please retry in a moment.',
                                    style: tt.bodyMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => ref.refresh(adminSupportTicketsProvider((search: _search, status: _status)).future),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (tickets) {
                if (tickets.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: PremiumGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(Icons.support_agent_rounded, color: cs.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'No tickets found',
                                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'There are no support tickets for this filter yet. Try another status or search term.',
                                        style: tt.bodyMedium?.copyWith(
                                          color: cs.onSurfaceVariant,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _search = '';
                                    _status = '';
                                  }),
                                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                                  label: const Text('Clear filters'),
                                ),
                                FilledButton.icon(
                                  onPressed: () => context.go('/admin/action-inbox'),
                                  icon: const Icon(Icons.inbox_rounded, size: 18),
                                  label: const Text('Open inbox'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final openCount = tickets.where((ticket) => ticket.status == 'OPEN').length;
                final inProgressCount = tickets.where((ticket) => ticket.status == 'IN_PROGRESS').length;
                final resolvedCount = tickets.where((ticket) => ticket.status == 'RESOLVED').length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: tickets.map((ticket) {
                    final statusColor = switch (ticket.status) {
                      'RESOLVED' => const Color(0xFF10B981),
                      'IN_PROGRESS' => const Color(0xFFF59E0B),
                      'CLOSED' => cs.onSurfaceVariant,
                      _ => const Color(0xFF2563EB),
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ticket.subject,
                                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    ticket.status.replaceAll('_', ' '),
                                    style: tt.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(ticket.message),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetaPill(label: ticket.userName ?? 'Unknown user'),
                                _MetaPill(label: ticket.userPhone ?? 'No phone'),
                                _MetaPill(label: ticket.assignedToName == null ? 'Unassigned' : ticket.assignedToName!),
                                _MetaPill(label: '${ticket.replyCount} replies'),
                                _MetaPill(label: DateFormat('d MMM, h:mm a').format(ticket.createdAt)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () => _openTicketDetails(ticket),
                                  child: const Text('Open'),
                                ),
                                TextButton(
                                  onPressed: ticket.status == 'OPEN'
                                      ? () => _setStatus(ticket.id, 'IN_PROGRESS')
                                      : null,
                                  child: const Text('Take'),
                                ),
                                TextButton(
                                  onPressed: ticket.status == 'CLOSED' ? null : () => _escalate(ticket),
                                  child: const Text('Escalate'),
                                ),
                                TextButton(
                                  onPressed: ticket.status == 'RESOLVED'
                                      ? null
                                      : () => _setStatus(ticket.id, 'RESOLVED'),
                                  child: const Text('Resolve'),
                                ),
                                TextButton(
                                  onPressed: ticket.status == 'CLOSED'
                                      ? null
                                      : () => _setStatus(ticket.id, 'CLOSED'),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: ticket.id));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Ticket ID copied')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 16),
                                  label: const Text('Copy ID'),
                                ),
                                TextButton.icon(
                                  onPressed: () => context.push('/audit-logs?search=${Uri.encodeComponent(ticket.id)}'),
                                  icon: const Icon(Icons.manage_search_rounded, size: 16),
                                  label: const Text('Audit'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList()
                    ..insert(
                      0,
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetaPill(label: 'Open: $openCount'),
                            _MetaPill(label: 'In progress: $inProgressCount'),
                            _MetaPill(label: 'Resolved: $resolvedCount'),
                          ],
                        ),
                      ),
                    ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketSkeletonCard extends StatelessWidget {
  const _TicketSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumGlassCard(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: ShimmerWidget(width: 180, height: 16, radius: 8)),
                SizedBox(width: 12),
                ShimmerWidget(width: 84, height: 28, radius: 999),
              ],
            ),
            SizedBox(height: 10),
            ShimmerWidget(width: double.infinity, height: 12, radius: 6),
            SizedBox(height: 8),
            ShimmerWidget(width: 220, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }
}

class _AdminKpiPill extends StatelessWidget {
  const _AdminKpiPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class SupportTicketDetailPage extends ConsumerStatefulWidget {
  const SupportTicketDetailPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<SupportTicketDetailPage> createState() => _SupportTicketDetailPageState();
}

class _SupportTicketDetailPageState extends ConsumerState<SupportTicketDetailPage> {
  final _replyController = TextEditingController();
  bool _internalNote = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _reply(String ticketId) async {
    final message = _replyController.text.trim();
    if (message.isEmpty) {
      return;
    }

    final api = ref.read(apiClientProvider);
    await api.post(
      '/admin/support/tickets/$ticketId/replies',
      data: {
        'message': message,
        'isInternal': _internalNote,
      },
    );
    _replyController.clear();
    ref.invalidate(adminSupportTicketThreadProvider(ticketId));
  }

  Future<void> _assignToMe(String ticketId) async {
    final adminId = ref.read(authControllerProvider).valueOrNull?.user.id;
    if (adminId == null) {
      return;
    }
    final api = ref.read(apiClientProvider);
    await api.patch(
      '/admin/support/tickets/$ticketId/assignment',
      data: {'assignedToUserId': adminId},
    );
    ref.invalidate(adminSupportTicketThreadProvider(ticketId));
  }

  Future<void> _unassign(String ticketId) async {
    final api = ref.read(apiClientProvider);
    await api.patch(
      '/admin/support/tickets/$ticketId/assignment',
      data: {'assignedToUserId': null},
    );
    ref.invalidate(adminSupportTicketThreadProvider(ticketId));
  }

  Future<void> _setStatus(String ticketId, String status) async {
    final api = ref.read(apiClientProvider);
    await api.patch(
      '/admin/support/tickets/$ticketId/status',
      data: {'status': status},
    );
    ref.invalidate(adminSupportTicketThreadProvider(ticketId));
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  Future<void> _escalate(AdminSupportTicket ticket) async {
    final noteController = TextEditingController(text: 'Escalated for urgent review.');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Escalate ticket'),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Internal note',
              hintText: 'Add the reason for escalation',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Escalate'),
            ),
          ],
        );
      },
    );

    if (accepted != true) {
      noteController.dispose();
      return;
    }

    try {
      if (ticket.assignedToName == null) {
        await _assignToMe(ticket.id);
      }
      final api = ref.read(apiClientProvider);
      await api.post(
        '/admin/support/tickets/${ticket.id}/replies',
        data: {
          'message': noteController.text.trim(),
          'isInternal': true,
        },
      );
      await _setStatus(ticket.id, 'IN_PROGRESS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket escalated')),
        );
      }
    } finally {
      noteController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final threadAsync = ref.watch(adminSupportTicketThreadProvider(widget.ticketId));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text('Support Ticket', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: threadAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not open ticket: $error', textAlign: TextAlign.center),
              ),
            ),
            data: (thread) {
              final ticket = thread.ticket;
              final customerLookup =
                  (ticket.userPhone ?? '').trim().isNotEmpty ? ticket.userPhone!.trim() : ticket.id;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(ticket.subject, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    ticket.userName ?? 'Unknown user',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(label: 'Status: ${ticket.status.replaceAll('_', ' ')}'),
                      _MetaPill(label: ticket.assignedToName == null ? 'Unassigned' : 'Assigned to ${ticket.assignedToName}'),
                      _MetaPill(label: '${thread.replies.length} replies'),
                      _MetaPill(label: ticket.userPhone ?? 'No phone'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(ticket.id, 'Ticket ID'),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy ticket ID'),
                      ),
                      if ((ticket.userPhone ?? '').trim().isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _copyToClipboard(ticket.userPhone!, 'Phone number'),
                          icon: const Icon(Icons.phone_rounded),
                          label: const Text('Copy phone'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/audit-logs?search=${Uri.encodeComponent(ticket.id)}'),
                        icon: const Icon(Icons.manage_search_rounded),
                        label: const Text('Audit trail'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(
                          '/search?q=${Uri.encodeComponent((ticket.userPhone ?? '').trim().isNotEmpty ? ticket.userPhone!.trim() : ticket.id)}',
                        ),
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Open search'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/admin-bookings?search=${Uri.encodeComponent(customerLookup)}'),
                        icon: const Icon(Icons.receipt_long_rounded),
                        label: const Text('Customer bookings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(ticket.message, style: tt.bodyMedium),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: ticket.assignedToName == null ? () => _assignToMe(ticket.id) : null,
                        child: const Text('Assign to me'),
                      ),
                      TextButton(
                        onPressed: ticket.assignedToName == null ? null : () => _unassign(ticket.id),
                        child: const Text('Unassign'),
                      ),
                      TextButton(
                        onPressed: ticket.status == 'OPEN' ? () => _setStatus(ticket.id, 'IN_PROGRESS') : null,
                        child: const Text('In progress'),
                      ),
                      TextButton(
                        onPressed: ticket.status == 'RESOLVED' ? null : () => _setStatus(ticket.id, 'RESOLVED'),
                        child: const Text('Resolve'),
                      ),
                      TextButton(
                        onPressed: ticket.status == 'CLOSED' ? null : () => _setStatus(ticket.id, 'CLOSED'),
                        child: const Text('Close'),
                      ),
                      TextButton(
                        onPressed: ticket.status == 'CLOSED' ? null : () => _escalate(ticket),
                        child: const Text('Escalate'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (thread.replies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('No replies yet.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    )
                  else
                    ...thread.replies.map((reply) {
                      final isMine = reply.authorRole == 'ADMIN';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 540),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMine ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      reply.authorName ?? 'Agent',
                                      style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      reply.isInternal ? 'Internal note' : 'Reply',
                                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(reply.message),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _replyController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilterChip(
                        selected: _internalNote,
                        label: const Text('Internal note'),
                        onSelected: (value) => setState(() => _internalNote = value),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          await _reply(ticket.id);
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        child: const Text('Send reply'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
