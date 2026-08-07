import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:dio/dio.dart';

class CustomQuotePage extends ConsumerStatefulWidget {
  const CustomQuotePage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<CustomQuotePage> createState() => _CustomQuotePageState();
}

class _CustomQuotePageState extends ConsumerState<CustomQuotePage> {
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      setState(() => _error = 'Please provide details for the custom quote.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/bookings/${widget.bookingId}/custom-quote/request',
        data: {'notes': notes},
      );
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        final data = e is DioException ? e.response?.data : null;
        _error = data is Map ? (data['message'] ?? e.toString()) : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isSuccess) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(backgroundColor: cs.surface, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF10B981)),
                const SizedBox(height: 24),
                Text('Quote Requested', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(
                  'We have received your request for a custom quote. Our professional will review the details and get back to you shortly.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {
                    // Assuming bookingDetailPageProvider is exported from marketplace_shared or handled by refresh on pop
                    context.pop();
                  },
                  child: const Text('Return to Booking'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
        title: Text('Request Custom Quote', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Describe your requirements',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For big jobs or special requirements, please describe what needs to be done. We will review and provide a custom quote before proceeding.',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _notesController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'E.g., I need to repaint the entire living room including the ceiling...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Request'),
          ),
        ),
      ),
    );
  }
}
