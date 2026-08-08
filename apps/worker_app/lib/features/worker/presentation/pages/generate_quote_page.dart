import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../domain/entities/job_execution.dart';
import '../../data/worker_job_providers.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class _QuoteItem {
  _QuoteItem({required this.label, required this.amount});
  String label;
  double amount;
}

// ── Page ─────────────────────────────────────────────────────────────────────

class GenerateQuotePage extends ConsumerStatefulWidget {
  const GenerateQuotePage({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<GenerateQuotePage> createState() => _GenerateQuotePageState();
}

class _GenerateQuotePageState extends ConsumerState<GenerateQuotePage> {
  final _items = <_QuoteItem>[];
  final _notesController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _addItem(); // start with one empty row
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_QuoteItem(label: '', amount: 0)));

  void _removeItem(int index) {
    if (_items.length > 1) setState(() => _items.removeAt(index));
  }

  double get _total => _items.fold(0.0, (s, i) => s + i.amount);

  Future<void> _submit() async {
    if (_items.any((i) => i.label.trim().isEmpty || i.amount <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all line items with valid amounts.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(workerJobRepositoryProvider);
      final total = _total;
      final payload = QuotePayload(
        amount: total,
        itemized: _items.map((i) => QuoteItem(
          label: i.label.trim(),
          qty: 1,
          unitPrice: i.amount,
        )).toList(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );
      await repo.generateQuote(widget.bookingId, payload.toJson());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom quote submitted successfully ✅')),
        );
        Navigator.of(context).pop(true); // pop and signal success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send quote: $e')),
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
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Generate Quote'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.request_quote_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Site Visit Complete',
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'Add materials and labor charges below. The customer will review and approve before you proceed.',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Line items header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Line Items', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Items list
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              initialValue: item.label,
                              decoration: InputDecoration(
                                labelText: 'Description',
                                hintText: 'e.g. Asian Paints Royale',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                              ),
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (v) => item.label = v,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              initialValue: item.amount > 0 ? item.amount.toStringAsFixed(0) : '',
                              decoration: InputDecoration(
                                labelText: 'Amount (₹)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                prefixText: '₹ ',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              onChanged: (v) => setState(() => item.amount = double.tryParse(v) ?? 0),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline_rounded,
                                color: _items.length > 1 ? cs.error : cs.outlineVariant),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'Notes for customer (optional)',
              hintText: 'e.g. Includes 2 coats of paint. Work takes 3 days.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.all(14),
            ),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 24),

          // Total summary
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Quote',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '₹${_total.toStringAsFixed(0)}',
                    style: tt.headlineSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Sending...' : 'Send Quote to Customer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
