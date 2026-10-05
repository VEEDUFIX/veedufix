import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class CustomerSupportTicket {
  const CustomerSupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.replyCount,
  });

  final String id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final int replyCount;

  factory CustomerSupportTicket.fromJson(Map<String, dynamic> json) {
    return CustomerSupportTicket(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? 'Support ticket',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      replyCount: (json['replyCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CustomerSupportReply {
  const CustomerSupportReply({
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

  factory CustomerSupportReply.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return CustomerSupportReply(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isInternal: json['isInternal'] as bool? ?? false,
      authorName: author?['name'] as String?,
      authorRole: author?['role'] as String?,
    );
  }
}

class CustomerSupportThread {
  const CustomerSupportThread({required this.ticket, required this.replies});

  final CustomerSupportTicket ticket;
  final List<CustomerSupportReply> replies;

  factory CustomerSupportThread.fromJson(Map<String, dynamic> json) {
    final replies = (json['replies'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CustomerSupportReply.fromJson)
        .toList(growable: false);
    return CustomerSupportThread(
      ticket: CustomerSupportTicket.fromJson(json),
      replies: replies,
    );
  }
}

final customerSupportTicketsProvider =
    FutureProvider.autoDispose<List<CustomerSupportTicket>>((ref) async {
      final api = ref.watch(apiClientProvider);
      final response = await api.get('/support/tickets/me');
      return (response['tickets'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CustomerSupportTicket.fromJson)
          .toList(growable: false);
    });

final customerSupportThreadProvider = FutureProvider.autoDispose
    .family<CustomerSupportThread, String>((ref, ticketId) async {
      final api = ref.watch(apiClientProvider);
      final response = await api.get('/support/tickets/$ticketId');
      return CustomerSupportThread.fromJson(
        response['ticket'] as Map<String, dynamic>,
      );
    });

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({
    super.key,
    this.bookingId,
    this.bookingCode,
    this.serviceName,
    this.autoCompose = false,
    this.initialCategory,
    this.initialSubject,
    this.initialMessage,
  });

  final String? bookingId;
  final String? bookingCode;
  final String? serviceName;
  final bool autoCompose;
  final String? initialCategory;
  final String? initialSubject;
  final String? initialMessage;

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  bool _openedDraft = false;
  final _faqSearchController = TextEditingController();

  @override
  void dispose() {
    _faqSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeOpenDraft();
    });
  }

  void _maybeOpenDraft() {
    if (!mounted || _openedDraft || !widget.autoCompose) {
      return;
    }

    final subject = widget.initialSubject?.trim();
    if (subject == null || subject.isEmpty) {
      return;
    }

    _openedDraft = true;
    unawaited(
      _createSupportTicket(
        context,
        ref: ref,
        category: widget.initialCategory?.trim().isNotEmpty == true
            ? widget.initialCategory!.trim()
            : 'other',
        subject: subject,
        initialMessage: widget.initialMessage?.trim().isNotEmpty == true
            ? widget.initialMessage!.trim()
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bookingIdLabel = widget.bookingId?.trim().isNotEmpty == true
        ? widget.bookingId!.trim()
        : null;

    final faqs = const [
      _Faq(
        q: 'How do I cancel a booking?',
        a:
            'Open My Bookings, select the booking, and choose Cancel. '
            'If a payment was captured, refund eligibility is reviewed separately; cancellation does not issue a refund automatically.',
      ),
      _Faq(
        q: 'What if the professional does not arrive?',
        a:
            'Open the booking and send us a support request with the booking details. '
            'We will review what happened and explain the available next steps.',
      ),
      _Faq(
        q: 'Is there a warranty on the work done?',
        a:
            'Coverage can depend on the service and its terms. Open a support request '
            'with your booking details and our team can review the applicable coverage.',
      ),
      _Faq(
        q: 'How do referral rewards work?',
        a:
            'Current reward amounts and eligibility are shown in the Referral section before you share your code. '
            'Offers may vary, so check the terms displayed in your account.',
      ),
      _Faq(
        q: 'What payment methods are accepted?',
        a:
            'The payment methods currently available for your booking are shown at checkout. '
            'If a payment is pending, check its status before trying again to avoid paying twice.',
      ),
    ];
    final query = _faqSearchController.text.trim().toLowerCase();
    final visibleFaqs = faqs
        .where(
          (faq) =>
              query.isEmpty ||
              faq.q.toLowerCase().contains(query) ||
              faq.a.toLowerCase().contains(query),
        )
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
        title: Text(
          'Help & Support',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PremiumCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AbzioTheme.buttonRadius,
                      ),
                    ),
                    child: Icon(Icons.support_agent_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How can we help?',
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send a request and follow replies in My Requests.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => _createSupportTicket(
                            context,
                            ref: ref,
                            category: 'general',
                            subject: 'Support request',
                          ),
                          icon: const Icon(Icons.add_comment_outlined),
                          label: const Text('Create support request'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Report an Issue',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _SupportOption(
            icon: Icons.receipt_long_rounded,
            label: 'Issue with a booking',
            accent: const Color(0xFFF59E0B),
            onTap: _SupportAction.bookingIssue,
            bookingId: bookingIdLabel,
            bookingCode: widget.bookingCode,
            serviceName: widget.serviceName,
          ),
          const _SupportOption(
            icon: Icons.payment_rounded,
            label: 'Payment or refund issue',
            accent: Color(0xFF10B981),
            onTap: _SupportAction.paymentIssue,
          ),
          const _SupportOption(
            icon: Icons.person_rounded,
            label: 'Report a professional',
            accent: Color(0xFFEF4444),
            onTap: _SupportAction.professionalReport,
          ),
          const SizedBox(height: 32),
          const _MyTicketsSection(),
          const SizedBox(height: 32),
          Text(
            'Frequently Asked Questions',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _faqSearchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search help topics',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _faqSearchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (visibleFaqs.isEmpty)
            const PremiumEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching help topics',
              subtitle: 'Try another search or send us a support request.',
            )
          else
            ...visibleFaqs.map((faq) => _FaqTile(faq: faq)),
        ],
      ),
    );
  }
}

class _MyTicketsSection extends ConsumerWidget {
  const _MyTicketsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ticketsAsync = ref.watch(customerSupportTicketsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Requests',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ticketsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.support_agent_rounded,
                          color: cs.error,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Could not load your tickets',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try again in a moment. Your existing support options are still available above.',
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
                    onPressed: () =>
                        ref.refresh(customerSupportTicketsProvider.future),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (tickets) {
            if (tickets.isEmpty) {
              return PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.inbox_rounded, color: cs.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No support requests yet',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your open tickets will appear here, together with replies and support updates.',
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
                ),
              );
            }

            return Column(
              children: tickets
                  .map((ticket) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TapScale(
                        onTap: () => _openThread(context, ticket.id),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.support_agent_rounded,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _ticketDisplaySubject(ticket.subject),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _TicketStatusPill(status: ticket.status),
                                        Text(
                                          '${ticket.replyCount} ${ticket.replyCount == 1 ? 'reply' : 'replies'}',
                                          style: tt.labelSmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          _supportDate(ticket.createdAt),
                                          style: tt.labelSmall?.copyWith(
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (ticket.message.trim().isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Text(
                                        ticket.message.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openThread(BuildContext context, String ticketId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CustomerSupportThreadSheet(ticketId: ticketId),
    );
  }
}

class _TicketStatusPill extends StatelessWidget {
  const _TicketStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalized = status.toUpperCase();
    final isComplete = normalized == 'RESOLVED' || normalized == 'CLOSED';
    final color = isComplete ? cs.tertiary : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _ticketStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CustomerSupportThreadSheet extends ConsumerStatefulWidget {
  const _CustomerSupportThreadSheet({required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<_CustomerSupportThreadSheet> createState() =>
      _CustomerSupportThreadSheetState();
}

class _CustomerSupportThreadSheetState
    extends ConsumerState<_CustomerSupportThreadSheet> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (_isSending || message.length < 2) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/support/tickets/${widget.ticketId}/replies',
        data: {'message': message},
      );
      if (!mounted) return;
      _replyController.clear();
      ref.invalidate(customerSupportThreadProvider(widget.ticketId));
      ref.invalidate(customerSupportTicketsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reply sent.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send your reply. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final threadAsync = ref.watch(
      customerSupportThreadProvider(widget.ticketId),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: threadAsync.when(
          loading: () => const SizedBox(
            height: 360,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => SizedBox(
            height: 360,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not open this support request.'),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(
                      customerSupportThreadProvider(widget.ticketId),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (thread) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      thread.ticket.subject,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _ticketStatusLabel(thread.ticket.status),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (thread.ticket.status == 'RESOLVED' ||
                        thread.ticket.status == 'CLOSED') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Sending a reply will reopen this request.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(thread.ticket.message, style: tt.bodyMedium),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: thread.replies.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final reply = thread.replies[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: reply.authorRole == 'ADMIN'
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest.withValues(
                                      alpha: 0.35,
                                    ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reply.authorName ?? 'Support',
                                  style: tt.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(reply.message),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _replyController,
                      maxLines: 3,
                      maxLength: 5000,
                      enabled: !_isSending,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Add a reply',
                        helperText: 'At least 2 characters',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed:
                            _isSending ||
                                _replyController.text.trim().length < 2
                            ? null
                            : _sendReply,
                        child: Text(_isSending ? 'Sending...' : 'Send reply'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SupportOption extends ConsumerWidget {
  const _SupportOption({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.bookingId,
    this.bookingCode,
    this.serviceName,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final _SupportAction onTap;
  final String? bookingId;
  final String? bookingCode;
  final String? serviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TapScale(
        onTap: () {
          final bookingIdValue = bookingId?.trim().isNotEmpty == true
              ? bookingId!.trim()
              : null;
          final bookingCodeValue = bookingCode?.trim().isNotEmpty == true
              ? bookingCode!.trim()
              : null;
          final serviceLabel = serviceName?.trim().isNotEmpty == true
              ? serviceName!.trim()
              : null;
          final bookingLabel = bookingCodeValue != null
              ? 'booking $bookingCodeValue'
              : bookingIdValue != null
              ? 'booking ID $bookingIdValue'
              : null;
          switch (onTap) {
            case _SupportAction.bookingIssue:
              _createSupportTicket(
                context,
                ref: ref,
                category: 'booking',
                subject: bookingLabel == null
                    ? 'Issue with a booking'
                    : 'Issue with $bookingLabel',
                initialMessage: bookingLabel == null
                    ? null
                    : 'I need help with $bookingLabel${serviceLabel == null ? '' : ' for $serviceLabel'}. Please review this booking and let me know the next steps.',
              );
              break;
            case _SupportAction.paymentIssue:
              _createSupportTicket(
                context,
                ref: ref,
                category: 'payment',
                subject: 'Payment or refund issue',
              );
              break;
            case _SupportAction.professionalReport:
              _createSupportTicket(
                context,
                ref: ref,
                category: 'professional',
                subject: 'Report a professional',
              );
              break;
          }
        },
        child: PremiumCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SupportAction { bookingIssue, paymentIssue, professionalReport }

Future<void> _createSupportTicket(
  BuildContext context, {
  required WidgetRef ref,
  required String category,
  required String subject,
  String? initialMessage,
}) async {
  final messageController = TextEditingController(text: initialMessage ?? '');
  try {
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(subject),
          content: TextField(
            controller: messageController,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: 'Describe your issue in detail',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (created != true) {
      return;
    }

    final message = messageController.text.trim();
    if (message.length < 10) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a bit more detail before sending.'),
        ),
      );
      return;
    }

    final api = ref.read(apiClientProvider);
    await api.post(
      '/support/tickets',
      data: {'subject': subject, 'message': message, 'category': category},
    );
    if (!context.mounted) {
      return;
    }
    ref.invalidate(customerSupportTicketsProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Support request sent.')));
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not send request. Please try again.'),
      ),
    );
  } finally {
    messageController.dispose();
  }
}

class _Faq {
  const _Faq({required this.q, required this.a});
  final String q;
  final String a;
}

String _ticketStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'OPEN':
      return 'Open';
    case 'IN_PROGRESS':
      return 'In progress';
    case 'RESOLVED':
      return 'Resolved';
    case 'CLOSED':
      return 'Closed';
    default:
      return status.replaceAll('_', ' ');
  }
}

String _ticketDisplaySubject(String subject) =>
    subject.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');

String _supportDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});
  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: PremiumCard(
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            title: Text(
              faq.q,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              Text(faq.a, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
