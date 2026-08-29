import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../finance/data/finance_api.dart';
import '../../../ops/data/disputes_api.dart';
import '../../../ops/data/ops_api.dart';
import '../../../worker_review/data/worker_review_api.dart';
import 'support_tickets_page.dart';

class AdminActionInboxPage extends ConsumerStatefulWidget {
  const AdminActionInboxPage({super.key});

  @override
  ConsumerState<AdminActionInboxPage> createState() =>
      _AdminActionInboxPageState();
}

class _AdminActionInboxPageState extends ConsumerState<AdminActionInboxPage> {
  late final OpsApi _opsApi;
  late final FinanceApi _financeApi;
  late final WorkerReviewApi _workerReviewApi;
  late final DisputesApi _disputesApi;
  late Future<_InboxSnapshot> _snapshotFuture;
  bool _busy = false;
  final Set<String> _selectedSupportTicketIds = <String>{};
  final Set<String> _selectedPayoutIds = <String>{};
  final Set<String> _selectedRefundIds = <String>{};

  @override
  void initState() {
    super.initState();
    final dio = ref.read(apiClientProvider).dio;
    _opsApi = OpsApi(dio);
    _financeApi = FinanceApi(dio);
    _workerReviewApi = WorkerReviewApi(dio);
    _disputesApi = DisputesApi(dio);
    _snapshotFuture = _loadSnapshot();
  }

  Future<_InboxSnapshot> _loadSnapshot() async {
    final overviewFuture = _safe(_opsApi.fetchOverview);
    final supportFuture = _safe(_fetchOpenSupportTickets);
    final reviewsFuture = _safe(() => _workerReviewApi.fetchPending(page: 1, limit: 8));
    final payoutsFuture = _safe(() => _financeApi.fetchPayouts(status: 'failed', page: 1, limit: 8));
    final refundsFuture = _safe(() => _financeApi.fetchRefunds(status: 'failed', page: 1, pageSize: 8));
    final disputesFuture = _safe(() => _disputesApi.fetchQueue(status: 'open', page: 1, pageSize: 8));

    final overview = await overviewFuture;
    final support = await supportFuture;
    final reviews = await reviewsFuture;
    final payouts = await payoutsFuture;
    final refunds = await refundsFuture;
    final disputes = await disputesFuture;

    return _InboxSnapshot(
      overview: overview.value,
      overviewError: overview.error,
      supportTickets: support.value ?? const <AdminSupportTicket>[],
      supportError: support.error,
      workerReviews: reviews.value?.items ?? const <WorkerReviewProfile>[],
      workerReviewError: reviews.error,
      payouts: payouts.value?.items ?? const <FinancePayoutItem>[],
      payoutError: payouts.error,
      refunds: refunds.value?.items ?? const <FinanceRefundItem>[],
      refundError: refunds.error,
      disputes: disputes.value?.items ?? const <DisputeQueueItem>[],
      disputeError: disputes.error,
    );
  }

  Future<_LoadResult<T>> _safe<T>(Future<T> Function() loader) async {
    try {
      return _LoadResult(value: await loader());
    } catch (error) {
      return _LoadResult<T>(error: error);
    }
  }

  Future<List<AdminSupportTicket>> _fetchOpenSupportTickets() async {
    final api = ref.read(apiClientProvider);
    final response = await api.get(
      '/admin/support/tickets',
      queryParameters: const {'status': 'OPEN'},
    );
    return (response['tickets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdminSupportTicket.fromJson)
        .take(8)
        .toList(growable: false);
  }

  Future<void> _reload() async {
    setState(() {
      _snapshotFuture = _loadSnapshot();
    });
    await _snapshotFuture;
  }

  Future<bool> _runAction(
    String successMessage,
    Future<void> Function() action,
  ) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) {
        return false;
      }
      await _reload();
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _toggleSelection(Set<String> selection, String id) {
    setState(() {
      if (!selection.add(id)) {
        selection.remove(id);
      }
    });
  }

  void _clearSelection(Set<String> selection) {
    setState(selection.clear);
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = 'Continue',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<String?> _promptForReason(
    String title,
    String message,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Add a short rejection note',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                Navigator.of(dialogContext).pop(
                  value.isEmpty ? null : value,
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return reason;
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

  Future<void> _retryAlert(OpsAlert alert) async {
    final sourceId = alert.sourceId ?? alert.bookingId;
    if (!alert.retryAvailable || sourceId == null || sourceId.isEmpty) {
      return;
    }

    final confirmed = await _confirm(
      'Retry alert?',
      'This will retry the ${alert.kind.replaceAll('_', ' ')} action for ${alert.title}.',
      confirmLabel: 'Retry',
    );
    if (!confirmed) {
      return;
    }

    if (alert.isDispatchFailure) {
      await _runAction(
        'Dispatch retried',
        () => _opsApi.redispatchBooking(sourceId),
      );
      return;
    }

    if (alert.isPayoutFailure) {
      await _runAction(
        'Payout retry queued',
        () => _opsApi.retryPayout(sourceId),
      );
      return;
    }

    if (alert.isRefundFailure) {
      await _runAction(
        'Refund retry queued',
        () => _opsApi.retryRefund(sourceId),
      );
    }
  }

  Future<void> _markSupportInProgress(AdminSupportTicket ticket) async {
    await _runAction(
      'Ticket moved to in progress',
      () async {
        final api = ref.read(apiClientProvider);
        await api.patch(
          '/admin/support/tickets/${ticket.id}/status',
          data: const {'status': 'IN_PROGRESS'},
        );
      },
    );
  }

  Future<void> _resolveSupportTicket(AdminSupportTicket ticket) async {
    await _runAction(
      'Ticket resolved',
      () async {
        final api = ref.read(apiClientProvider);
        await api.patch(
          '/admin/support/tickets/${ticket.id}/status',
          data: const {'status': 'RESOLVED'},
        );
      },
    );
  }

  Future<void> _bulkMarkSupportInProgress(List<AdminSupportTicket> tickets) async {
    if (tickets.isEmpty) {
      return;
    }

    final confirmed = await _confirm(
      'Start selected tickets?',
      'Move ${tickets.length} support ticket${tickets.length == 1 ? '' : 's'} into in progress?',
      confirmLabel: 'Start',
    );
    if (!confirmed) {
      return;
    }

    final success = await _runAction(
      'Selected tickets moved to in progress',
      () async {
        final api = ref.read(apiClientProvider);
        for (final ticket in tickets) {
          await api.patch(
            '/admin/support/tickets/${ticket.id}/status',
            data: const {'status': 'IN_PROGRESS'},
          );
        }
      },
    );
    if (success && mounted) {
      _clearSelection(_selectedSupportTicketIds);
    }
  }

  Future<void> _bulkResolveSupportTickets(List<AdminSupportTicket> tickets) async {
    if (tickets.isEmpty) {
      return;
    }

    final confirmed = await _confirm(
      'Resolve selected tickets?',
      'Mark ${tickets.length} support ticket${tickets.length == 1 ? '' : 's'} as resolved?',
      confirmLabel: 'Resolve',
    );
    if (!confirmed) {
      return;
    }

    final success = await _runAction(
      'Selected tickets resolved',
      () async {
        final api = ref.read(apiClientProvider);
        for (final ticket in tickets) {
          await api.patch(
            '/admin/support/tickets/${ticket.id}/status',
            data: const {'status': 'RESOLVED'},
          );
        }
      },
    );
    if (success && mounted) {
      _clearSelection(_selectedSupportTicketIds);
    }
  }

  Future<void> _approveWorker(WorkerReviewProfile profile) async {
    final confirmed = await _confirm(
      'Approve worker?',
      'Approve ${profile.displayName} for onboarding?',
      confirmLabel: 'Approve',
    );
    if (!confirmed) {
      return;
    }

    await _runAction(
      'Worker approved',
      () => _workerReviewApi.approve(profile.id),
    );
  }

  Future<void> _rejectWorker(WorkerReviewProfile profile) async {
    final reason = await _promptForReason(
      'Reject worker?',
      'Add a short reason that will be saved with the rejection.',
    );
    if (reason == null) {
      return;
    }

    await _runAction(
      'Worker rejected',
      () => _workerReviewApi.reject(profile.id, reason),
    );
  }

  Future<void> _retryPayout(FinancePayoutItem payout) async {
    final confirmed = await _confirm(
      'Retry payout?',
      'Retry payout ${payout.id} for booking ${payout.bookingCode.isEmpty ? payout.bookingId : payout.bookingCode}?',
      confirmLabel: 'Retry',
    );
    if (!confirmed) {
      return;
    }

    await _runAction(
      'Payout retry queued',
      () => _financeApi.retryPayout(payout.id),
    );
  }

  Future<void> _bulkRetryPayouts(List<FinancePayoutItem> payouts) async {
    if (payouts.isEmpty) {
      return;
    }

    final confirmed = await _confirm(
      'Retry selected payouts?',
      'Retry ${payouts.length} failed payout${payouts.length == 1 ? '' : 's'} now?',
      confirmLabel: 'Retry',
    );
    if (!confirmed) {
      return;
    }

    final success = await _runAction(
      'Selected payouts retry queued',
      () async {
        for (final payout in payouts) {
          await _financeApi.retryPayout(payout.id);
        }
      },
    );
    if (success && mounted) {
      _clearSelection(_selectedPayoutIds);
    }
  }

  Future<void> _retryRefund(FinanceRefundItem refund) async {
    final confirmed = await _confirm(
      'Retry refund?',
      'Retry refund ${refund.id} for booking ${refund.bookingCode.isEmpty ? refund.bookingId : refund.bookingCode}?',
      confirmLabel: 'Retry',
    );
    if (!confirmed) {
      return;
    }

    await _runAction(
      'Refund retry queued',
      () => _financeApi.retryRefund(refund.id),
    );
  }

  Future<void> _bulkRetryRefunds(List<FinanceRefundItem> refunds) async {
    if (refunds.isEmpty) {
      return;
    }

    final confirmed = await _confirm(
      'Retry selected refunds?',
      'Retry ${refunds.length} failed refund${refunds.length == 1 ? '' : 's'} now?',
      confirmLabel: 'Retry',
    );
    if (!confirmed) {
      return;
    }

    final success = await _runAction(
      'Selected refunds retry queued',
      () async {
        for (final refund in refunds) {
          await _financeApi.retryRefund(refund.id);
        }
      },
    );
    if (success && mounted) {
      _clearSelection(_selectedRefundIds);
    }
  }

  void _openAlert(OpsAlert alert) {
    if (alert.isDispatchFailure && alert.bookingId != null) {
      context.push('/ops/live-jobs/${alert.bookingId}');
      return;
    }

    if (alert.isPayoutFailure && alert.sourceId != null) {
      context.push('/finance/payouts/${alert.sourceId}');
      return;
    }

    if (alert.isRefundFailure && alert.sourceId != null) {
      context.push('/finance/refunds/${alert.sourceId}');
      return;
    }

    context.push('/ops/alerts/${alert.id}');
  }

  void _openSupportTicket(AdminSupportTicket ticket) {
    context.push('/support-tickets/${ticket.id}');
  }

  void _openWorkerReview(WorkerReviewProfile profile) {
    context.push('/worker-review/${profile.id}');
  }

  void _openPayout(FinancePayoutItem payout) {
    context.push('/finance/payouts/${payout.id}', extra: payout);
  }

  void _openRefund(FinanceRefundItem refund) {
    context.push('/finance/refunds/${refund.id}', extra: refund);
  }

  void _openDispute(DisputeQueueItem dispute) {
    context.push('/ops/disputes/${dispute.id}');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Action inbox',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh'),
            ),
        ],
      ),
      body: FutureBuilder<_InboxSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: _InboxSkeleton(),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: PremiumEmptyState(
                icon: Icons.inbox_rounded,
                title: 'Inbox unavailable',
                subtitle: 'We could not load the action inbox. Please retry.',
                actionLabel: 'Retry',
                onAction: _reload,
              ),
            );
          }

          final summary = data.overview?.summary;
          final alerts = data.overview?.alerts ?? const <OpsAlert>[];
          final totalAttention = _attentionCount(data);

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _Panel(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unified action inbox',
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'One place for alerts, support, reviews, payouts, refunds, and disputes that need a human decision.',
                                    style: GoogleFonts.inter(
                                      color: cs.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$totalAttention open',
                                style: tt.labelLarge?.copyWith(
                                  color: const Color(0xFF0F766E),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _StatChip(
                              label: 'Alerts',
                              value: alerts.length,
                              color: const Color(0xFFEF4444),
                            ),
                            _StatChip(
                              label: 'Support',
                              value: data.supportTickets.length,
                              color: const Color(0xFF2563EB),
                            ),
                            _StatChip(
                              label: 'Reviews',
                              value: data.workerReviews.length,
                              color: const Color(0xFFF59E0B),
                            ),
                            _StatChip(
                              label: 'Payouts',
                              value: data.payouts.length,
                              color: const Color(0xFF0F766E),
                            ),
                            _StatChip(
                              label: 'Refunds',
                              value: data.refunds.length,
                              color: const Color(0xFF8B5CF6),
                            ),
                            _StatChip(
                              label: 'Disputes',
                              value: data.disputes.length,
                              color: const Color(0xFFB45309),
                            ),
                            if (summary != null)
                              _StatChip(
                                label: 'Dispatch failures',
                                value: summary.dispatchFailuresCount,
                                color: const Color(0xFFDC2626),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (data.overviewError != null) ...[
                  const SizedBox(height: 16),
                  _NoticeCard(
                    icon: Icons.cloud_off_rounded,
                    title: 'Some alert data could not load',
                    message: data.overviewError.toString(),
                  ),
                ],
                const SizedBox(height: 16),
                _ActionSection<OpsAlert>(
                  icon: Icons.notification_important_rounded,
                  title: 'Urgent alerts',
                  subtitle: 'Retry failures and jump into the exact record in one tap.',
                  count: alerts.length,
                  onSeeAll: () => context.go('/ops/alerts'),
                  onRetry: _reload,
                  items: alerts.take(8).toList(growable: false),
                  error: data.overviewError,
                  emptyTitle: 'No alerts right now',
                  emptySubtitle: 'Dispatch, finance, support, and dispute alerts will appear here when they need attention.',
                  itemBuilder: (context, alert) {
                    return _AlertCard(
                      alert: alert,
                      onOpen: () => _openAlert(alert),
                      onRetry: alert.retryAvailable ? () => _retryAlert(alert) : null,
                      onCopy: () => _copyToClipboard(alert.id, 'Alert ID'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ActionSection<AdminSupportTicket>(
                  icon: Icons.support_agent_rounded,
                  title: 'Support tickets',
                  subtitle: 'Move tickets forward or jump straight into the thread.',
                  count: data.supportTickets.length,
                  onSeeAll: () => context.go('/support-tickets'),
                  onRetry: _reload,
                  items: data.supportTickets,
                  selectedIds: _selectedSupportTicketIds,
                  itemIdOf: (ticket) => ticket.id,
                  onToggleSelection: (ticketId) => _toggleSelection(_selectedSupportTicketIds, ticketId),
                  onClearSelection: () => _clearSelection(_selectedSupportTicketIds),
                  bulkActions: [
                    _SectionBulkAction<AdminSupportTicket>(
                      label: 'Start selected',
                      icon: Icons.play_arrow_rounded,
                      onPressed: (context, selected) => _bulkMarkSupportInProgress(selected),
                    ),
                    _SectionBulkAction<AdminSupportTicket>(
                      label: 'Resolve selected',
                      icon: Icons.check_circle_rounded,
                      onPressed: (context, selected) => _bulkResolveSupportTickets(selected),
                    ),
                  ],
                  error: data.supportError,
                  emptyTitle: 'No open support tickets',
                  emptySubtitle: 'Customer issues will show up here once they are waiting for an admin response.',
                  itemBuilder: (context, ticket) {
                    return _SupportTicketCard(
                      ticket: ticket,
                      onOpen: () => _openSupportTicket(ticket),
                      onMarkInProgress: ticket.status == 'OPEN' ? () => _markSupportInProgress(ticket) : null,
                      onResolve: ticket.status != 'RESOLVED' && ticket.status != 'CLOSED' ? () => _resolveSupportTicket(ticket) : null,
                      onCopy: () => _copyToClipboard(ticket.id, 'Ticket ID'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ActionSection<WorkerReviewProfile>(
                  icon: Icons.how_to_reg_rounded,
                  title: 'Worker reviews',
                  subtitle: 'Approve or reject onboarding requests without opening another screen.',
                  count: data.workerReviews.length,
                  onSeeAll: () => context.go('/worker-review'),
                  onRetry: _reload,
                  items: data.workerReviews,
                  error: data.workerReviewError,
                  emptyTitle: 'No pending worker reviews',
                  emptySubtitle: 'New onboarding submissions will appear here when they are ready for review.',
                  itemBuilder: (context, profile) {
                    return _WorkerReviewCard(
                      profile: profile,
                      onOpen: () => _openWorkerReview(profile),
                      onApprove: () => _approveWorker(profile),
                      onReject: () => _rejectWorker(profile),
                      onCopy: () => _copyToClipboard(profile.id, 'Worker profile ID'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ActionSection<FinancePayoutItem>(
                  icon: Icons.payments_rounded,
                  title: 'Failed payouts',
                  subtitle: 'Retry only the items that are stuck in payout failure.',
                  count: data.payouts.length,
                  onSeeAll: () => context.go('/finance/payouts'),
                  onRetry: _reload,
                  items: data.payouts,
                  selectedIds: _selectedPayoutIds,
                  itemIdOf: (payout) => payout.id,
                  onToggleSelection: (payoutId) => _toggleSelection(_selectedPayoutIds, payoutId),
                  onClearSelection: () => _clearSelection(_selectedPayoutIds),
                  bulkActions: [
                    _SectionBulkAction<FinancePayoutItem>(
                      label: 'Retry selected',
                      icon: Icons.refresh_rounded,
                      onPressed: (context, selected) => _bulkRetryPayouts(selected),
                    ),
                  ],
                  error: data.payoutError,
                  emptyTitle: 'No failed payouts',
                  emptySubtitle: 'Failed worker payouts will land here if any retries are needed.',
                  itemBuilder: (context, payout) {
                    return _PayoutCard(
                      payout: payout,
                      onOpen: () => _openPayout(payout),
                      onRetry: payout.status == 'failed' ? () => _retryPayout(payout) : null,
                      onCopy: () => _copyToClipboard(payout.id, 'Payout ID'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ActionSection<FinanceRefundItem>(
                  icon: Icons.receipt_long_rounded,
                  title: 'Failed refunds',
                  subtitle: 'Retry refund requests that need another gateway attempt.',
                  count: data.refunds.length,
                  onSeeAll: () => context.go('/finance/refunds'),
                  onRetry: _reload,
                  items: data.refunds,
                  selectedIds: _selectedRefundIds,
                  itemIdOf: (refund) => refund.id,
                  onToggleSelection: (refundId) => _toggleSelection(_selectedRefundIds, refundId),
                  onClearSelection: () => _clearSelection(_selectedRefundIds),
                  bulkActions: [
                    _SectionBulkAction<FinanceRefundItem>(
                      label: 'Retry selected',
                      icon: Icons.refresh_rounded,
                      onPressed: (context, selected) => _bulkRetryRefunds(selected),
                    ),
                  ],
                  error: data.refundError,
                  emptyTitle: 'No failed refunds',
                  emptySubtitle: 'Refund failures will appear here when they need another try.',
                  itemBuilder: (context, refund) {
                    return _RefundCard(
                      refund: refund,
                      onOpen: () => _openRefund(refund),
                      onRetry: refund.status == 'failed' ? () => _retryRefund(refund) : null,
                      onCopy: () => _copyToClipboard(refund.id, 'Refund ID'),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _ActionSection<DisputeQueueItem>(
                  icon: Icons.gavel_rounded,
                  title: 'Open disputes',
                  subtitle: 'Escalations that need review before they can be closed.',
                  count: data.disputes.length,
                  onSeeAll: () => context.go('/ops/disputes'),
                  onRetry: _reload,
                  items: data.disputes,
                  error: data.disputeError,
                  emptyTitle: 'No open disputes',
                  emptySubtitle: 'Disputes will appear here when the resolution queue is active.',
                  itemBuilder: (context, dispute) {
                    return _DisputeCard(
                      dispute: dispute,
                      onOpen: () => _openDispute(dispute),
                      onCopy: () => _copyToClipboard(dispute.id, 'Dispute ID'),
                      onOpenBooking: dispute.bookingId.isNotEmpty
                          ? () => context.push('/admin-bookings/${dispute.bookingId}')
                          : null,
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _attentionCount(_InboxSnapshot data) {
    return (data.overview?.alerts.length ?? 0) +
        data.supportTickets.length +
        data.workerReviews.length +
        data.payouts.length +
        data.refunds.length +
        data.disputes.length;
  }
}

class _InboxSnapshot {
  const _InboxSnapshot({
    required this.overview,
    required this.overviewError,
    required this.supportTickets,
    required this.supportError,
    required this.workerReviews,
    required this.workerReviewError,
    required this.payouts,
    required this.payoutError,
    required this.refunds,
    required this.refundError,
    required this.disputes,
    required this.disputeError,
  });

  final OpsOverviewSnapshot? overview;
  final Object? overviewError;
  final List<AdminSupportTicket> supportTickets;
  final Object? supportError;
  final List<WorkerReviewProfile> workerReviews;
  final Object? workerReviewError;
  final List<FinancePayoutItem> payouts;
  final Object? payoutError;
  final List<FinanceRefundItem> refunds;
  final Object? refundError;
  final List<DisputeQueueItem> disputes;
  final Object? disputeError;
}

class _LoadResult<T> {
  const _LoadResult({this.value, this.error});

  final T? value;
  final Object? error;
}

class _SectionBulkAction<T> {
  const _SectionBulkAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function(BuildContext context, List<T> selectedItems)
      onPressed;
}

class _ActionSection<T> extends StatelessWidget {
  const _ActionSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onSeeAll,
    required this.onRetry,
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.itemBuilder,
    this.selectedIds,
    this.itemIdOf,
    this.onToggleSelection,
    this.onClearSelection,
    this.bulkActions = const [],
    this.error,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onSeeAll;
  final VoidCallback onRetry;
  final List<T> items;
  final String emptyTitle;
  final String emptySubtitle;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Set<String>? selectedIds;
  final String Function(T item)? itemIdOf;
  final ValueChanged<String>? onToggleSelection;
  final VoidCallback? onClearSelection;
  final List<_SectionBulkAction<T>> bulkActions;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final canSelect = selectedIds != null && itemIdOf != null && onToggleSelection != null;
    final selectedItems = canSelect
        ? items.where((item) => selectedIds!.contains(itemIdOf!(item))).toList(growable: false)
        : <T>[];

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF0F766E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: tt.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onSeeAll,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text('Open $title'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (canSelect && selectedIds!.isNotEmpty && bulkActions.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${selectedIds!.length} selected',
                      style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    TextButton(
                      onPressed: onClearSelection,
                      child: const Text('Clear'),
                    ),
                    for (final action in bulkActions)
                      FilledButton.tonalIcon(
                        onPressed: () => action.onPressed(context, selectedItems),
                        icon: Icon(action.icon, size: 18),
                        label: Text(action.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (error != null && items.isEmpty)
              _SectionMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Section unavailable',
                subtitle: error.toString(),
                actionLabel: 'Retry',
                onAction: onRetry,
              )
            else if (items.isEmpty)
              _SectionMessage(
                icon: Icons.check_circle_outline_rounded,
                title: emptyTitle,
                subtitle: emptySubtitle,
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final child = itemBuilder(context, item);
                  if (!canSelect) {
                    return child;
                  }

                  final itemId = itemIdOf!(item);
                  return Stack(
                    children: [
                      child,
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Tooltip(
                          message: 'Select ${title.toLowerCase()} item',
                          child: Material(
                            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                            shape: const CircleBorder(),
                            child: Checkbox(
                              value: selectedIds!.contains(itemId),
                              onChanged: (_) => onToggleSelection!(itemId),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.onOpen,
    required this.onCopy,
    this.onRetry,
  });

  final OpsAlert alert;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _QueueCard(
      accent: _accent,
      title: alert.title,
      subtitle: alert.message,
      meta: [
        if (alert.bookingCode != null && alert.bookingCode!.isNotEmpty)
          'Booking ${alert.bookingCode}',
        if (alert.customerName != null && alert.customerName!.isNotEmpty)
          alert.customerName!,
        MaterialLocalizations.of(context).formatMediumDate(alert.createdAt),
        if (alert.amount != null) '₹${alert.amount!.toStringAsFixed(2)}',
      ],
      trailing: [
        _CardAction(label: 'Open', icon: Icons.open_in_new_rounded, onTap: onOpen),
        if (onRetry != null)
          _CardAction(label: 'Retry', icon: Icons.refresh_rounded, onTap: onRetry!),
        _CardAction(label: 'Copy', icon: Icons.copy_rounded, onTap: onCopy),
      ],
    );
  }

  Color get _accent {
    return switch (alert.kind) {
      'support_escalation' => const Color(0xFF2563EB),
      'dispute_escalation' => const Color(0xFF7C3AED),
      'payout_failure' => const Color(0xFF0F766E),
      'refund_failure' => const Color(0xFF8B5CF6),
      'payment_mismatch' => const Color(0xFFF59E0B),
      _ => const Color(0xFFEF4444),
    };
  }
}

class _SupportTicketCard extends StatelessWidget {
  const _SupportTicketCard({
    required this.ticket,
    required this.onOpen,
    required this.onCopy,
    this.onMarkInProgress,
    this.onResolve,
  });

  final AdminSupportTicket ticket;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback? onMarkInProgress;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    return _QueueCard(
      accent: const Color(0xFF2563EB),
      title: ticket.subject,
      subtitle: ticket.message,
      meta: [
        ticket.status,
        if ((ticket.userName ?? '').isNotEmpty) ticket.userName!,
        if ((ticket.userPhone ?? '').isNotEmpty) ticket.userPhone!,
        MaterialLocalizations.of(context).formatMediumDate(ticket.createdAt),
        '${ticket.replyCount} replies',
      ],
      trailing: [
        _CardAction(label: 'Open', icon: Icons.open_in_new_rounded, onTap: onOpen),
        if (onMarkInProgress != null)
          _CardAction(
            label: 'Start',
            icon: Icons.play_arrow_rounded,
            onTap: onMarkInProgress!,
          ),
        if (onResolve != null)
          _CardAction(
            label: 'Resolve',
            icon: Icons.check_circle_rounded,
            onTap: onResolve!,
          ),
        _CardAction(label: 'Copy', icon: Icons.copy_rounded, onTap: onCopy),
      ],
    );
  }
}

class _WorkerReviewCard extends StatelessWidget {
  const _WorkerReviewCard({
    required this.profile,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    required this.onCopy,
  });

  final WorkerReviewProfile profile;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return _QueueCard(
      accent: const Color(0xFFF59E0B),
      title: profile.displayName,
      subtitle: profile.requestedCategoryNames.isEmpty
          ? 'Pending onboarding review'
          : profile.requestedCategoryNames.join(', '),
      meta: [
        profile.onboardingStatus.replaceAll('_', ' '),
        profile.cityLabel,
        profile.submittedLabel,
      ],
      trailing: [
        _CardAction(label: 'Open', icon: Icons.open_in_new_rounded, onTap: onOpen),
        _CardAction(label: 'Approve', icon: Icons.verified_rounded, onTap: onApprove),
        _CardAction(label: 'Reject', icon: Icons.block_rounded, onTap: onReject),
        _CardAction(label: 'Copy', icon: Icons.copy_rounded, onTap: onCopy),
      ],
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({
    required this.payout,
    required this.onOpen,
    required this.onCopy,
    this.onRetry,
  });

  final FinancePayoutItem payout;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _QueueCard(
      accent: const Color(0xFF0F766E),
      title: payout.bookingCode.isEmpty ? payout.id : payout.bookingCode,
      subtitle: payout.workerName ?? 'Worker payout',
      meta: [
        payout.status,
        _money(payout.amount),
        _money(payout.commissionAmount, decimals: 0),
        MaterialLocalizations.of(context).formatMediumDate(payout.createdAt),
        if ((payout.failureReason ?? '').isNotEmpty) payout.failureReason!,
      ],
      trailing: [
        _CardAction(label: 'Open', icon: Icons.open_in_new_rounded, onTap: onOpen),
        if (onRetry != null)
          _CardAction(label: 'Retry', icon: Icons.refresh_rounded, onTap: onRetry!),
        _CardAction(label: 'Copy', icon: Icons.copy_rounded, onTap: onCopy),
      ],
    );
  }
}

class _RefundCard extends StatelessWidget {
  const _RefundCard({
    required this.refund,
    required this.onOpen,
    required this.onCopy,
    this.onRetry,
  });

  final FinanceRefundItem refund;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _QueueCard(
      accent: const Color(0xFF8B5CF6),
      title: refund.bookingCode.isEmpty ? refund.id : refund.bookingCode,
      subtitle: refund.customerName ?? 'Customer refund',
      meta: [
        refund.status,
        _money(refund.amount),
        refund.reason,
        MaterialLocalizations.of(context).formatMediumDate(refund.createdAt),
        if ((refund.failureReason ?? '').isNotEmpty) refund.failureReason!,
      ],
      trailing: [
        _CardAction(label: 'Open', icon: Icons.open_in_new_rounded, onTap: onOpen),
        if (onRetry != null)
          _CardAction(label: 'Retry', icon: Icons.refresh_rounded, onTap: onRetry!),
        _CardAction(label: 'Copy', icon: Icons.copy_rounded, onTap: onCopy),
      ],
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.dispute,
    required this.onOpen,
    required this.onCopy,
    this.onOpenBooking,
  });

  final DisputeQueueItem dispute;
  final VoidCallback onOpen;
  final VoidCallback onCopy;
  final VoidCallback? onOpenBooking;

  @override
  Widget build(BuildContext context) {
    return _QueueCard(
      accent: const Color(0xFFB45309),
      title: dispute.bookingCode.isEmpty ? dispute.id : dispute.bookingCode,
      subtitle: dispute.reason,
      meta: [
        dispute.status,
        dispute.customerName,
        if ((dispute.workerName ?? '').isNotEmpty) dispute.workerName!,
        MaterialLocalizations.of(context).formatMediumDate(dispute.createdAt),
        if ((dispute.resolutionNote ?? '').isNotEmpty) dispute.resolutionNote!,
      ],
      trailing: [
        _CardAction(label: 'Open', icon: Icons.open_in_new_rounded, onTap: onOpen),
        if (onOpenBooking != null)
          _CardAction(
            label: 'Booking',
            icon: Icons.receipt_long_rounded,
            onTap: onOpenBooking!,
          ),
        _CardAction(label: 'Copy', icon: Icons.copy_rounded, onTap: onCopy),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.trailing,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final List<String> meta;
  final List<_CardAction> trailing;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final filteredMeta = meta
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.bolt_rounded, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: tt.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (filteredMeta.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredMeta
                    .take(5)
                    .map(
                      (value) => _MetaChip(label: value),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trailing,
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            offset: Offset(0, 10),
            color: Color(0x0E000000),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InboxSkeleton extends StatelessWidget {
  const _InboxSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonBlock(height: 180),
        SizedBox(height: 16),
        _SkeletonBlock(height: 220),
        SizedBox(height: 16),
        _SkeletonBlock(height: 220),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

String _money(double value, {int decimals = 2}) {
  return NumberFormat.currency(symbol: '₹', decimalDigits: decimals).format(value);
}
