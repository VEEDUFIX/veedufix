import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/job_execution.dart';
import '../../data/worker_job_providers.dart';

/// Page where a worker can add spare parts used during a job.
/// Each line item has a label and a price. An optional receipt photo URL
/// can be added. On submit the request is sent to the backend and the
/// customer receives a push notification to review and pay.
class AddSparePartsPage extends ConsumerStatefulWidget {
  const AddSparePartsPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<AddSparePartsPage> createState() => _AddSparePartsPageState();
}

class _AddSparePartsPageState extends ConsumerState<AddSparePartsPage> {
  final List<_PartItem> _items = [_PartItem()];
  final _receiptUrlController = TextEditingController();
  bool _submitting = false;

  static const _accent = Color(0xFF6366F1);

  double get _total => _items.fold(0.0, (sum, i) => sum + (i.amount ?? 0.0));

  @override
  void dispose() {
    _receiptUrlController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    // Validate
    final valid = _items.every((i) => i.label.text.trim().isNotEmpty && i.amount != null);
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all part names and amounts')),
      );
      return;
    }
    if (_total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total must be greater than ₹0')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(workerJobRepositoryProvider);
      final payload = SparePartsPayload(
        items: _items
            .map((i) => SparePartItem(label: i.label.text.trim(), amount: i.amount!))
            .toList(),
        receiptPhotoUrl: _receiptUrlController.text.trim().isNotEmpty 
            ? _receiptUrlController.text.trim() 
            : null,
      );
      await repo.addSpareParts(widget.bookingId, payload.toJson());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Spare Parts'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  // Header card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: _accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Add each spare part used. The customer will review and pay before you finish the job.',
                            style: tt.bodySmall?.copyWith(color: _accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Line items
                  Text('Parts Used',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),

                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: item.label,
                              decoration: InputDecoration(
                                labelText: 'Part name',
                                hintText: 'e.g. Copper pipe 1m',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: item.amountCtrl,
                              decoration: InputDecoration(
                                labelText: '₹ Amount',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                prefixText: '₹ ',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (_items.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                              color: cs.error,
                              onPressed: () => setState(() => _items.removeAt(index)),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Add row button
                  TextButton.icon(
                    onPressed: () => setState(() => _items.add(_PartItem())),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add another part'),
                  ),
                  const SizedBox(height: 16),

                  // Receipt photo URL
                  TextFormField(
                    controller: _receiptUrlController,
                    decoration: InputDecoration(
                      labelText: 'Receipt photo URL (optional)',
                      hintText: 'Paste image link from camera/upload',
                      prefixIcon: const Icon(Icons.receipt_long_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),

                  // Total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total',
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          '₹${_total.toStringAsFixed(0)}',
                          style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: cs.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Submit button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                      _submitting ? 'Sending…' : 'Send to Customer  •  ₹${_total.toStringAsFixed(0)}'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle:
                        const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartItem {
  final label = TextEditingController();
  final amountCtrl = TextEditingController();

  double? get amount => double.tryParse(amountCtrl.text.trim());

  void dispose() {
    label.dispose();
    amountCtrl.dispose();
  }
}
