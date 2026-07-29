import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

class ReviewBottomSheet extends ConsumerStatefulWidget {
  const ReviewBottomSheet({
    super.key,
    required this.bookingId,
    required this.workerName,
    required this.workerImageUrl,
  });

  final String bookingId;
  final String workerName;
  final String? workerImageUrl;

  static Future<void> show(
    BuildContext context, {
    required String bookingId,
    required String workerName,
    String? workerImageUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewBottomSheet(
        bookingId: bookingId,
        workerName: workerName,
        workerImageUrl: workerImageUrl,
      ),
    );
  }

  @override
  ConsumerState<ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends ConsumerState<ReviewBottomSheet> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    // In a real app, you would call your API here
    // await ref.read(apiClientProvider).dio.post('/reviews', data: { ... });
    
    await Future.delayed(const Duration(milliseconds: 1500)); // Simulate network

    if (mounted) {
      setState(() => _isSubmitting = false);
      context.pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Rate your experience',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'How was the service provided by ${widget.workerName}?',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = starValue <= _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.diagonal3Values(isSelected ? 1.1 : 1.0, isSelected ? 1.1 : 1.0, 1.0),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 40,
                      color: isSelected ? const Color(0xFFF59E0B) : cs.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Leave a comment (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: PrimaryActionButton(
              label: _isSubmitting ? 'Submitting...' : 'Submit Review',
              onPressed: _isSubmitting ? null : _submitReview,
            ),
          ),
        ],
      ),
    );
  }
}
