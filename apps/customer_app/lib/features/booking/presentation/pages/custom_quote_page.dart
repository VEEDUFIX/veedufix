import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class CustomQuotePage extends ConsumerStatefulWidget {
  const CustomQuotePage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<CustomQuotePage> createState() => _CustomQuotePageState();
}

class _CustomQuotePageState extends ConsumerState<CustomQuotePage> {
  static const _maxNotesLength = 500;

  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _error;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _requestError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final message = data is Map ? data['message']?.toString() : null;
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Could not connect. Check your connection and try again.';
      }
      if (message?.isNotEmpty == true) return message!;
    }
    return 'We could not send your request. Please try again.';
  }

  Future<void> _submit() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      setState(
        () => _error =
            'Add a few details so the professional can prepare a quote.',
      );
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
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _requestError(error);
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.request_quote_rounded,
                      size: 38,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Request sent',
                    textAlign: TextAlign.center,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The professional will review your requirements and share a quote. You can review the price before deciding whether to proceed.',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Return to booking'),
                    ),
                  ),
                ],
              ),
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
        leading: IconButton(
          tooltip: 'Back to booking',
          onPressed: _isSubmitting ? null : () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          'Request a quote',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.home_repair_service_rounded,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tell us what you need',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Describe the size of the job, areas involved, materials, or any special requirements. The professional will send a quote for your approval before the work proceeds.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _notesController,
                        maxLength: _maxNotesLength,
                        maxLines: 6,
                        minLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                        decoration: InputDecoration(
                          labelText: 'Job details',
                          hintText:
                              'For example: repaint two bedrooms, including the ceilings',
                          alignLabelWithHint: true,
                          helperText:
                              'Include measurements or photos in the booking chat if helpful.',
                          errorText: _error,
                          filled: true,
                          fillColor: cs.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AbzioTheme.cardRadius,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Sending request…' : 'Send quote request',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
