import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../data/booking_otp_api.dart';

class CompletionOtpPage extends ConsumerStatefulWidget {
  const CompletionOtpPage({
    super.key,
    required this.bookingId,
  });

  final String bookingId;

  @override
  ConsumerState<CompletionOtpPage> createState() => _CompletionOtpPageState();
}

class _CompletionOtpPageState extends ConsumerState<CompletionOtpPage> {
  late final BookingOtpApi _api;
  Future<_CompletionOtpScreenData>? _future;

  @override
  void initState() {
    super.initState();
    _api = BookingOtpApi(ref.read(apiClientProvider).dio);
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<_CompletionOtpScreenData> _load() async {
    if (widget.bookingId.trim().isEmpty) {
      throw StateError('Missing booking id.');
    }

    final details = await _api.fetchDetails(widget.bookingId);
    final otpInfo = await _api.fetchCompletionOtp(widget.bookingId);
    return _CompletionOtpScreenData(details: details, otpInfo: otpInfo);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookingId.trim().isEmpty) {
      return const _MissingBookingPage(
        title: 'Completion OTP unavailable',
        subtitle: 'We could not determine which booking to open.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Completion OTP')),
      body: FutureBuilder<_CompletionOtpScreenData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Unable to load the completion code: ${snapshot.error}',
              onRetry: _reload,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return _ErrorState(
              message: 'No completion code was returned for this booking.',
              onRetry: _reload,
            );
          }

          final expiry = data.otpInfo.otpExpiresAt;
          final afterPhotos = data.details.afterPhotoUrls;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const PremiumSectionHeader(
                title: 'Completion OTP',
                subtitle:
                    'Check the finished work, then share this code with your professional to close the job.',
              ),
              const SizedBox(height: 16),
              PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _Avatar(
                            imageUrl: data.details.workerPhotoUrl,
                            fallbackLabel: _initials(data.details.workerName),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data.details.workerName,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data.details.serviceName,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (afterPhotos.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'After photos',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 112,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: afterPhotos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final url = afterPhotos[index];
                              return MarketplaceNetworkImage(
                                imageUrl: url,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                borderRadius: AbzioTheme.buttonRadius,
                                cloudinaryWidth: 220,
                                cloudinaryHeight: 220,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Completion code',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              data.otpInfo.otp,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 8,
                                    height: 1.1,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: PremiumStatCard(
                              label: 'Booking',
                              value: data.details.bookingCode,
                              icon: Icons.receipt_long_rounded,
                              accentColor: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: PremiumStatCard(
                              label: 'Expires',
                              value: _expiryLabel(expiry),
                              icon: Icons.schedule_rounded,
                              accentColor: const Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.push(
                          Uri(
                            path: '/booking-rating',
                            queryParameters: {'bookingId': widget.bookingId},
                          ).toString(),
                        ),
                        icon: const Icon(Icons.thumb_up_alt_rounded),
                        label: const Text('Job looks good'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              PremiumGlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What happens next',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your professional will verify the code. After that you can leave a rating and short comment.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _CompletionOtpScreenData {
  const _CompletionOtpScreenData({
    required this.details,
    required this.otpInfo,
  });

  final BookingOtpDetails details;
  final BookingOtpInfo otpInfo;
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.imageUrl,
    required this.fallbackLabel,
  });

  final String? imageUrl;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: 56,
      child: MarketplaceNetworkAvatar(
        imageUrl: imageUrl,
        radius: 28,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.8),
        fallback: Text(
          fallbackLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumEmptyState(
          icon: Icons.lock_clock_rounded,
          title: 'Completion code unavailable',
          subtitle: message,
          actionLabel: 'Try again',
          onAction: onRetry,
        ),
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
          icon: Icons.receipt_long_rounded,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }
}

String _expiryLabel(DateTime? expiry) {
  if (expiry == null) {
    return '10 min';
  }

  final local = expiry.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList(growable: false);
  if (parts.isEmpty) {
    return 'PF';
  }
  final first = parts.first.substring(0, 1);
  if (parts.length == 1) {
    return first.toUpperCase();
  }
  return (first + parts.last.substring(0, 1)).toUpperCase();
}
