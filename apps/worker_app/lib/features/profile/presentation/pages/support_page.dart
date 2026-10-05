import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../domain/entities/worker_support_ticket.dart';
import '../providers/support_providers.dart';

class SupportPage extends ConsumerStatefulWidget {
  const SupportPage({
    super.key,
    this.initialCategory,
    this.initialSubject,
    this.initialMessage,
    this.autoFocusForm = false,
  });

  final String? initialCategory;
  final String? initialSubject;
  final String? initialMessage;
  final bool autoFocusForm;

  @override
  ConsumerState<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends ConsumerState<SupportPage> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _ticketFormKey = GlobalKey();
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = 'payment';
  bool _isSubmitting = false;
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    const categories = {'payment', 'app', 'customer', 'account', 'other'};
    final requestedCategory = widget.initialCategory?.trim();
    _selectedCategory = categories.contains(requestedCategory)
        ? requestedCategory!
        : _selectedCategory;
    _subjectCtrl.text = widget.initialSubject?.trim().isNotEmpty == true
        ? widget.initialSubject!.trim()
        : '';
    _messageCtrl.text = widget.initialMessage?.trim().isNotEmpty == true
        ? widget.initialMessage!.trim()
        : '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didPrefill || !widget.autoFocusForm) {
        return;
      }
      _didPrefill = true;
      final context = _ticketFormKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.submitTicket(
        subject: subject,
        message: message,
        category: _selectedCategory,
      );
      if (!mounted) return;
      _subjectCtrl.clear();
      _messageCtrl.clear();
      ref.invalidate(workerSupportTicketsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket submitted.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit your ticket. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final ticketsAsync = ref.watch(workerSupportTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.refresh(workerSupportTicketsProvider.future).then<void>(
                (_) {},
              );
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EmergencyContactCard(
                onTap: () => _showEmergencyDialog(context),
              ),
              const SizedBox(height: 24),
              Text('Frequently Asked Questions', style: tt.titleLarge),
              const SizedBox(height: 16),
              _buildFaqList(),
              const SizedBox(height: 32),
              Container(
                key: _ticketFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Raise a Ticket', style: tt.titleLarge),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _buildTicketForm(context),
              const SizedBox(height: 32),
              Text('My Tickets', style: tt.titleLarge),
              const SizedBox(height: 16),
              ticketsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load your tickets. Your support form is still available above.',
                      style: tt.bodyMedium,
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(workerSupportTicketsProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const PremiumEmptyState(
                      icon: Icons.support_agent_rounded,
                      title: 'No support tickets yet',
                      subtitle:
                          'Submitted issues will show up here with status updates.',
                    );
                  }
                  return Column(
                    children: tickets
                        .map(
                          (ticket) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TicketCard(
                              ticket: ticket,
                              onTap: () => _openTicketThread(ticket.id),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFaqList() {
    final faqs = [
      {
        'q': 'How do I get paid?',
        'a':
            'Eligible earnings are sent to your verified payout account. Check Earnings for the current payout status, or raise a ticket if something looks wrong.'
      },
      {
        'q': 'What if the customer cancels the job?',
        'a':
            'Cancellation handling depends on the booking status and the applicable platform rules. Check the booking details and contact support if you need help.'
      },
      {
        'q': 'How can I update my service areas?',
        'a':
            'Open Profile and choose Service Area to review the locations configured for your account. If editing is unavailable, contact support.'
      },
      {
        'q': 'Can I decline a job request?',
        'a':
            'You can decline a request from its details. If you have already accepted a job and can no longer attend, let the customer and support team know as soon as possible.'
      },
      {
        'q': 'What should I do if I\'m running late?',
        'a':
            'Please use the in-app chat to inform the customer as soon as possible, or contact support if the delay is significant.'
      },
    ];

    return Column(
      children: faqs
          .map((faq) => ExpansionTile(
                title: Text(faq['q']!),
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(faq['a']!),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildTicketForm(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedCategory,
                items: const [
                  DropdownMenuItem(
                    value: 'payment',
                    child: Text('Payment Issue'),
                  ),
                  DropdownMenuItem(value: 'app', child: Text('App Issue')),
                  DropdownMenuItem(
                    value: 'customer',
                    child: Text('Customer Issue'),
                  ),
                  DropdownMenuItem(
                    value: 'account',
                    child: Text('Account Issue'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(
                          () => _selectedCategory = value ?? 'other',
                        ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectCtrl,
                maxLength: 120,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Short summary of the issue',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.15),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 3) return 'Use at least 3 characters';
                  if (length > 120) {
                    return 'Keep the subject under 120 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                maxLength: 5000,
                enabled: !_isSubmitting,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your issue in detail...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.15),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 10) {
                    return 'Describe the issue in at least 10 characters';
                  }
                  if (length > 5000) {
                    return 'Keep the description under 5,000 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryActionButton(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  label: _isSubmitting ? 'Submitting...' : 'Submit Ticket',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openTicketThread(String ticketId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _WorkerSupportThreadSheet(ticketId: ticketId),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency support'),
        content: const Text(
          'For active job emergencies, use this page to submit a ticket and contact the customer directly in chat if possible. '
          'If safety is at risk, contact local emergency services first.',
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('OK')),
        ],
      ),
    );
  }
}

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      child: Container(
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
          border: Border.all(color: cs.error.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.health_and_safety_rounded, color: cs.error, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Urgent safety support',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap for safety guidance during an active job. If anyone is in immediate danger, contact local emergency services.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
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

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final WorkerSupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = switch (ticket.status) {
      'RESOLVED' => const Color(0xFF10B981),
      'IN_PROGRESS' => const Color(0xFFF59E0B),
      'CLOSED' => cs.onSurfaceVariant,
      _ => const Color(0xFF2563EB),
    };

    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
          color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
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
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    ticket.status.replaceAll('_', ' '),
                    style: tt.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket.message,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Text(
              DateTime.now().difference(ticket.createdAt).inDays == 0
                  ? 'Submitted today'
                  : 'Submitted on ${_threadDate(ticket.createdAt)}',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.forum_outlined, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  '${ticket.replyCount} ${ticket.replyCount == 1 ? 'reply' : 'replies'}',
                  style: tt.labelMedium?.copyWith(color: cs.primary),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerSupportThreadSheet extends ConsumerStatefulWidget {
  const _WorkerSupportThreadSheet({required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<_WorkerSupportThreadSheet> createState() =>
      _WorkerSupportThreadSheetState();
}

class _WorkerSupportThreadSheetState
    extends ConsumerState<_WorkerSupportThreadSheet> {
  final _replyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (_isSending || message.length < 2) return;

    setState(() => _isSending = true);
    try {
      await ref.read(supportRepositoryProvider).replyToTicket(
            ticketId: widget.ticketId,
            message: message,
          );
      if (!mounted) return;
      _replyController.clear();
      ref.invalidate(workerSupportThreadProvider(widget.ticketId));
      ref.invalidate(workerSupportTicketsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply sent.')),
      );
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
    final threadAsync = ref.watch(workerSupportThreadProvider(widget.ticketId));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.84,
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
                  const Text('Could not load this support conversation.'),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(
                      workerSupportThreadProvider(widget.ticketId),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (thread) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.ticket.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${thread.ticket.status.replaceAll('_', ' ')} · ${thread.replies.length} ${thread.replies.length == 1 ? 'reply' : 'replies'}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      itemCount: thread.replies.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final isOriginal = index == 0;
                        final reply =
                            isOriginal ? null : thread.replies[index - 1];
                        final isPartner = isOriginal ||
                            reply?.authorRole.toUpperCase() == 'WORKER';
                        return Align(
                          alignment: isPartner
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isOriginal || isPartner
                                    ? cs.primaryContainer
                                    : cs.surfaceContainerHighest
                                        .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isOriginal
                                        ? 'You · ${_threadDate(thread.ticket.createdAt)}'
                                        : '${isPartner ? 'You' : reply!.authorName} · ${_threadDate(reply!.createdAt)}',
                                    style: tt.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    isOriginal
                                        ? thread.ticket.message
                                        : reply!.message,
                                    style: tt.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _replyController,
                    enabled: !_isSending,
                    maxLines: 3,
                    maxLength: 5000,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Write a reply',
                      helperText: 'At least 2 characters',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          _isSending || _replyController.text.trim().length < 2
                              ? null
                              : _sendReply,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_isSending ? 'Sending...' : 'Send reply'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _threadDate(DateTime date) {
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} $hour:$minute';
}
