import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../data/booking_otp_api.dart';

class BookingRatingPage extends ConsumerStatefulWidget {
  const BookingRatingPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingRatingPage> createState() => _BookingRatingPageState();
}

class _BookingRatingPageState extends ConsumerState<BookingRatingPage> {
  late final BookingOtpApi _api;
  Future<BookingOtpDetails>? _detailsFuture;
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  bool _alreadySubmitted = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _api = BookingOtpApi(ref.read(apiClientProvider).dio);
    _detailsFuture = _api.fetchDetails(widget.bookingId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.submitRating(
        bookingId: widget.bookingId,
        rating: _rating.toDouble(),
        comment: _commentController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback.')),
      );
      context.go('/bookings');
    } catch (error) {
      if (!mounted) {
        return;
      }
      final statusCode = error is DioException
          ? error.response?.statusCode
          : null;
      if (statusCode == 409) {
        setState(() => _alreadySubmitted = true);
      } else {
        setState(() => _submissionError = _ratingErrorMessage(error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookingId.trim().isEmpty) {
      return const _MissingBookingPage(
        title: 'Rating unavailable',
        subtitle: 'We could not determine which booking to review.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rate your experience')),
      body: FutureBuilder<BookingOtpDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return PremiumRetryState(
              icon: Icons.rate_review_outlined,
              title: 'Could not load booking details',
              subtitle: 'Check your connection and try again.',
              onRetry: () => setState(() {
                _detailsFuture = _api.fetchDetails(widget.bookingId);
              }),
              onRefresh: () async {
                final future = _api.fetchDetails(widget.bookingId);
                setState(() => _detailsFuture = future);
                await future;
              },
            );
          }
          final details = snapshot.data;
          if (details == null) {
            return const _MissingBookingPage(
              title: 'Not found',
              subtitle: 'No details found for this booking.',
            );
          }

          if (_alreadySubmitted) {
            return _ReviewNotice(
              icon: Icons.verified_rounded,
              title: 'Review already submitted',
              message: 'Thanks for sharing your feedback for this booking.',
              actionLabel: 'Back to bookings',
              onAction: () => context.go('/bookings'),
            );
          }

          if (details.statusLabel?.toUpperCase() != 'COMPLETED') {
            return _ReviewNotice(
              icon: Icons.lock_clock_rounded,
              title: 'Review after completion',
              message:
                  'You can share your feedback once this service is marked complete.',
              actionLabel: 'View booking',
              onAction: () => context.go('/booking/${widget.bookingId}'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const PremiumSectionHeader(
                title: 'Rate your experience',
                subtitle:
                    'A quick rating helps keep the marketplace premium and trustworthy.',
              ),
              const SizedBox(height: 16),
              PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.serviceName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details.workerName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: List.generate(5, (index) {
                            final starValue = index + 1;
                            return IconButton(
                              tooltip:
                                  '$starValue star${starValue == 1 ? '' : 's'}',
                              onPressed: _submitting
                                  ? null
                                  : () => setState(() {
                                      _rating = starValue;
                                      _submissionError = null;
                                    }),
                              icon: Icon(
                                starValue <= _rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: const Color(0xFFB58B3A),
                                size: 36,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _rating == 0
                            ? 'Tap a star to rate your experience'
                            : '$_rating / 5 · ${_ratingLabel(_rating)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        readOnly: _submitting,
                        decoration: const InputDecoration(
                          labelText: 'Optional comment',
                          hintText:
                              'Tell us what went well or what could improve',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_submissionError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _submissionError!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting || _rating == 0
                              ? null
                              : _submit,
                          child: _submitting
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Submitting review'),
                                  ],
                                )
                              : const Text('Submit review'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _ratingLabel(int rating) => switch (rating) {
  1 => 'Needs improvement',
  2 => 'Below expectations',
  3 => 'Good',
  4 => 'Very good',
  5 => 'Excellent',
  _ => '',
};

String _ratingErrorMessage(Object error) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return 'Your sign-in session expired. Please sign in and try again.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Reviews are temporarily unavailable. Please try again shortly.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Check your internet connection and try again.';
    }
  }
  return 'We could not submit your review. Please try again.';
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: cs.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _MissingBookingPage extends StatelessWidget {
  const _MissingBookingPage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: PremiumEmptyState(
          icon: Icons.star_border_rounded,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }
}
