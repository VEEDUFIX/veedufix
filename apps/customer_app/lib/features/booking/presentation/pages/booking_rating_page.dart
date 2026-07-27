import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../data/booking_otp_api.dart';

class BookingRatingPage extends ConsumerStatefulWidget {
  const BookingRatingPage({
    super.key,
    required this.bookingId,
  });

  final String bookingId;

  @override
  ConsumerState<BookingRatingPage> createState() => _BookingRatingPageState();
}

class _BookingRatingPageState extends ConsumerState<BookingRatingPage> {
  late final BookingOtpApi _api;
  Future<BookingOtpDetails>? _detailsFuture;
  final TextEditingController _commentController = TextEditingController();
  double _rating = 5;
  bool _submitting = false;

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
        rating: _rating,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit rating: $error')),
      );
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
          final details = snapshot.data ?? BookingOtpDetails.fallback(widget.bookingId);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const PremiumSectionHeader(
                title: 'Rate your experience',
                subtitle: 'A quick rating helps keep the marketplace premium and trustworthy.',
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
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: List.generate(5, (index) {
                            final starValue = index + 1;
                            final filled = starValue <= _rating.round();
                            return InkResponse(
                              onTap: () => setState(() => _rating = starValue.toDouble()),
                              radius: 28,
                              child: Icon(
                                filled ? Icons.star_rounded : Icons.star_border_rounded,
                                color: const Color(0xFFF59E0B),
                                size: 38,
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your rating: ${_rating.toStringAsFixed(0)} / 5',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _commentController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Optional comment',
                          hintText: 'Tell us what went well or what could improve',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit rating'),
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

class _MissingBookingPage extends StatelessWidget {
  const _MissingBookingPage({
    required this.title,
    required this.subtitle,
  });

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
