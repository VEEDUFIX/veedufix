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
  String _selectedCategory = 'payment';
  bool _isSubmitting = false;
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory?.trim().isNotEmpty == true
        ? widget.initialCategory!.trim()
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
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a subject and description.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.submitTicket(
        subject: subject,
        message: message,
        category: _selectedCategory,
      );
      _subjectCtrl.clear();
      _messageCtrl.clear();
      ref.invalidate(workerSupportTicketsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support ticket submitted.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit ticket: $error')),
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
        onRefresh: () async => ref.refresh(workerSupportTicketsProvider.future),
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
                error: (error, stack) => Text('Unable to load your tickets: $error'),
                data: (tickets) {
                  if (tickets.isEmpty) {
                    return const PremiumEmptyState(
                      icon: Icons.support_agent_rounded,
                      title: 'No support tickets yet',
                      subtitle: 'Submitted issues will show up here with status updates.',
                    );
                  }
                  return Column(
                    children: tickets
                        .map(
                          (ticket) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _TicketCard(ticket: ticket),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text('Other ways to contact us', style: tt.titleMedium),
              const SizedBox(height: 16),
              _buildContactOptions(context),
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
        'a': 'Payments are settled directly to your registered bank account within 24 hours of job completion.'
      },
      {
        'q': 'What if the customer cancels the job?',
        'a': 'If the customer cancels within 2 hours of the scheduled time, you will receive a cancellation fee.'
      },
      {
        'q': 'How can I update my service areas?',
        'a': 'Go to Profile > Settings > Service Areas to update the regions you want to receive job requests from.'
      },
      {
        'q': 'Can I decline a job request?',
        'a': 'Yes, you can decline job requests, but maintaining a high acceptance rate is recommended for better visibility.'
      },
      {
        'q': 'What should I do if I\'m running late?',
        'a': 'Please use the in-app chat to inform the customer as soon as possible, or contact support if the delay is significant.'
      },
    ];

    return Column(
      children: faqs
          .map((faq) => ExpansionTile(
                title: Text(faq['q']!),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          initialValue: _selectedCategory,
          items: const [
            DropdownMenuItem(value: 'payment', child: Text('Payment Issue')),
            DropdownMenuItem(value: 'app', child: Text('App Issue')),
            DropdownMenuItem(value: 'customer', child: Text('Customer Issue')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (val) {
            setState(() {
              _selectedCategory = val ?? 'other';
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _subjectCtrl,
          decoration: InputDecoration(
            labelText: 'Subject',
            hintText: 'Short summary of the issue',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _messageCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Describe your issue in detail...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.15),
          ),
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
    );
  }

  Widget _buildContactOptions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ContactOption(
          icon: Icons.email,
          label: 'Email',
          color: cs.primary,
          onTap: () => _showContactSnack(context, 'support@veedufix.com'),
        ),
        _ContactOption(
          icon: Icons.phone,
          label: 'Phone',
          color: Colors.green,
          onTap: () => _showContactSnack(context, '+91 1800 123 8899'),
        ),
        _ContactOption(
          icon: Icons.chat,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
          onTap: () => _showContactSnack(context, 'WhatsApp support is handled by the ops team.'),
        ),
      ],
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

  void _showContactSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade400,
              Colors.red.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contact',
                    style: tt.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap here for urgent job-related help or safety issues.',
                    style: tt.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
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
  const _TicketCard({required this.ticket});

  final WorkerSupportTicket ticket;

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

    return Container(
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
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          ),
          const SizedBox(height: 10),
          Text(
            DateTime.now().difference(ticket.createdAt).inDays == 0
                ? 'Submitted today'
                : 'Submitted on ${ticket.createdAt.toLocal()}',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: tt.bodySmall),
        ],
      ),
    );
  }
}
