import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../admin/presentation/widgets/admin_surface.dart';
import '../../data/payout_changes_api.dart';

class PayoutChangeQueuePage extends ConsumerStatefulWidget {
  const PayoutChangeQueuePage({super.key});

  @override
  ConsumerState<PayoutChangeQueuePage> createState() =>
      _PayoutChangeQueuePageState();
}

class _PayoutChangeQueuePageState extends ConsumerState<PayoutChangeQueuePage> {
  late final PayoutChangesApi _api;
  late Future<List<PayoutChangeRequest>> _requests;
  final Set<String> _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _api = PayoutChangesApi(ref.read(apiClientProvider).dio);
    _requests = _api.fetchPending();
  }

  void _reload() => setState(() => _requests = _api.fetchPending());

  Future<String?> _rejectionReason() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject payout change'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            decoration:
                const InputDecoration(labelText: 'Reason for the worker'),
            validator: (value) => (value?.trim().length ?? 0) >= 3
                ? null
                : 'Enter at least 3 characters.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    return reason;
  }

  Future<void> _decide(PayoutChangeRequest item,
      {required bool approve}) async {
    final reason = approve ? null : await _rejectionReason();
    if (!approve && reason == null) return;
    setState(() => _busy.add(item.id));
    try {
      if (approve) {
        await _api.approve(item.id);
      } else {
        await _api.reject(item.id, reason!);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(approve
                ? 'Payout account approved.'
                : 'Payout account rejected.')),
      );
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update request: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) => AdminPageShell(
        title: 'Payout account changes',
        actions: [
          IconButton(
              onPressed: _reload,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded))
        ],
        child: FutureBuilder<List<PayoutChangeRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 32),
                      const SizedBox(height: 12),
                      const Text(
                        'Could not load payout account changes.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final requests = snapshot.data ?? const <PayoutChangeRequest>[];
            if (requests.isEmpty) {
              return const Center(
                  child: Text(
                      'No payout account changes are waiting for review.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = requests[index];
                final busy = _busy.contains(item.id);
                return AdminSurfacePanel(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdminSectionHeader(
                          title: item.workerName,
                          subtitle:
                              '${item.city} • ${item.phone} • ${item.email}',
                        ),
                        const SizedBox(height: 16),
                        if (item.bankAccountNumber != null) ...[
                          SelectableText(
                              'Bank account: ${item.bankAccountNumber}'),
                          const SizedBox(height: 6),
                          SelectableText(
                              'IFSC: ${item.bankIfsc ?? 'Not provided'}'),
                        ],
                        if (item.upiId != null) ...[
                          const SizedBox(height: 6),
                          SelectableText('UPI ID: ${item.upiId}'),
                        ],
                        const SizedBox(height: 8),
                        Text(
                            'Submitted ${item.createdAt?.toLocal().toString().split('.').first ?? 'date unavailable'}',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 14),
                        Wrap(spacing: 10, runSpacing: 8, children: [
                          FilledButton.icon(
                            onPressed: busy
                                ? null
                                : () => _decide(item, approve: true),
                            icon: busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.verified_rounded),
                            label: const Text('Approve'),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy
                                ? null
                                : () => _decide(item, approve: false),
                            icon: const Icon(Icons.block_rounded),
                            label: const Text('Reject'),
                          ),
                        ]),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
