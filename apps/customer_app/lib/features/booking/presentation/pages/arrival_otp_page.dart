import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../data/booking_otp_api.dart';

class ArrivalOtpPage extends ConsumerStatefulWidget {
  const ArrivalOtpPage({
    super.key,
    required this.bookingId,
  });

  final String bookingId;

  @override
  ConsumerState<ArrivalOtpPage> createState() => _ArrivalOtpPageState();
}

class _ArrivalOtpPageState extends ConsumerState<ArrivalOtpPage> {
  late final BookingOtpApi _api;
  Future<_ArrivalOtpScreenData>? _future;

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

  Future<_ArrivalOtpScreenData> _load() async {
    if (widget.bookingId.trim().isEmpty) {
      throw StateError('Missing booking id.');
    }

    final details = await _api.fetchDetails(widget.bookingId);
    final otpInfo = await _api.fetchArrivalOtp(widget.bookingId);
    return _ArrivalOtpScreenData(details: details, otpInfo: otpInfo);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bookingId.trim().isEmpty) {
      return const _MissingBookingPage(
        title: 'Arrival OTP unavailable',
        subtitle: 'We could not determine which booking to open.',
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Arrival OTP')),
      body: FutureBuilder<_ArrivalOtpScreenData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Unable to load the arrival code: ${snapshot.error}',
              onRetry: _reload,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return _ErrorState(
              message: 'No arrival code was returned for this booking.',
              onRetry: _reload,
            );
          }

          final workerPhotoUrl = data.details.workerPhotoUrl;
          final workerInitials = _initials(data.details.workerName);
          final expiry = data.otpInfo.otpExpiresAt;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const PremiumSectionHeader(
                title: 'Arrival code',
                subtitle:
                    'Share this code with your professional to start the job - never share it with anyone else.',
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
                            imageUrl: workerPhotoUrl,
                            fallbackLabel: workerInitials,
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
                                if (data.details.locationLabel != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    data.details.locationLabel!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
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
                              'Arrival code',
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
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Didn't get it? Resend"),
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
                        'Once your professional enters this code, the job will start and live tracking will continue automatically.',
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

class _ArrivalOtpScreenData {
  const _ArrivalOtpScreenData({
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
          title: 'Arrival code unavailable',
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
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}
