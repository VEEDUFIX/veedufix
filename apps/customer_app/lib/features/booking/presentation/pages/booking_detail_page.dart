import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../profile/data/saved_addresses_api.dart';
import '../../../../core/payments/razorpay_service.dart';

class BookingDetailPage extends ConsumerWidget {
  const BookingDetailPage({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bookingAsync = ref.watch(bookingDetailPageProvider(bookingId));

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
        title: Text(
          'Booking Details',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          bookingAsync.whenOrNull(
                data: (b) => IconButton(
                  tooltip: 'Share booking',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => _shareBooking(context, b),
                ),
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bookingDetailPageProvider(bookingId));
            try {
              await ref.read(bookingDetailPageProvider(bookingId).future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 44),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load booking',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.invalidate(bookingDetailPageProvider(bookingId)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        data: (booking) => _BookingDetailBody(booking: booking),
      ),
    );
  }

  Future<void> _shareBooking(
    BuildContext context,
    BookingDetail booking,
  ) async {
    await Share.share(
      'Booking #${booking.code} — ${booking.serviceName}\n'
      'Status: ${_statusLabel(booking.status)}\n'
      'Total: ₹${booking.totalAmount.toStringAsFixed(0)}',
      subject: 'Veedufix booking ${booking.code}',
    );
  }

  static String _statusLabel(String s) => switch (s) {
    'PENDING' => 'Pending',
    'ACCEPTED' => 'Accepted',
    'WORKER_ASSIGNED' => 'Worker Assigned',
    'EN_ROUTE' => 'En Route',
    'ARRIVED' => 'Arrived',
    'IN_PROGRESS' => 'In Progress',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    'REFUNDED' => 'Refunded',
    _ => s.toLowerCase().replaceAll('_', ' '),
  };
}

class _BookingDetailBody extends ConsumerWidget {
  const _BookingDetailBody({required this.booking});
  final BookingDetail booking;

  static const _accent = Color(0xFFC2A15E);

  String get _statusLabel => switch (booking.status) {
    'PENDING' => 'Pending',
    'ACCEPTED' => 'Accepted',
    'WORKER_ASSIGNED' => 'Worker Assigned',
    'EN_ROUTE' => 'En Route',
    'ARRIVED' => 'Arrived',
    'IN_PROGRESS' => 'In Progress',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    'REFUNDED' => 'Refunded',
    _ => booking.status,
  };

  Color get _statusColor => switch (booking.status) {
    'COMPLETED' => AbzioTheme.successColor,
    'CANCELLED' || 'REFUNDED' => AbzioTheme.dangerColor,
    'IN_PROGRESS' || 'ARRIVED' => AbzioTheme.infoColor,
    'EN_ROUTE' => AbzioTheme.infoColor,
    _ => _accent,
  };

  IconData get _statusIcon => switch (booking.status) {
    'COMPLETED' => Icons.task_alt_rounded,
    'CANCELLED' || 'REFUNDED' => Icons.cancel_rounded,
    'IN_PROGRESS' => Icons.build_rounded,
    'EN_ROUTE' => Icons.directions_car_rounded,
    'ARRIVED' => Icons.location_on_rounded,
    _ => Icons.schedule_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isActive = [
      'PENDING',
      'ACCEPTED',
      'WORKER_ASSIGNED',
      'EN_ROUTE',
      'ARRIVED',
      'IN_PROGRESS',
    ].contains(booking.status);
    final canCancel = isActive;
    final canRebook = !isActive;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingDetailPageProvider(booking.id));
        await ref.read(bookingDetailPageProvider(booking.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ─── Status banner ────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
              border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_statusIcon, color: _statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _statusLabel,
                        style: tt.titleMedium?.copyWith(
                          color: _statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Booking #${booking.code}',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── Active job CTA buttons ────────────────────────────────────────
          if (booking.status == 'PENDING') ...[
            TapScale(
              onTap: () => _showEditBookingSheet(context, ref, booking),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit address & time',
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if ((booking.status == 'PENDING' || booking.status == 'ACCEPTED') &&
              booking.customQuoteStatus == null) ...[
            TapScale(
              onTap: () => context.push('/bookings/${booking.id}/custom-quote'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.request_quote_rounded,
                      size: 18,
                      color: Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Request custom quote',
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (isActive) ...[
            if (booking.status == 'EN_ROUTE' ||
                booking.status == 'ARRIVED' ||
                booking.status == 'IN_PROGRESS')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      context.push('/tracking?bookingId=${booking.id}'),
                  icon: const Icon(Icons.location_on_rounded),
                  label: const Text('Track your professional'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            if (booking.worker != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TapScale(
                      onTap: () =>
                          context.push('/chat?bookingId=${booking.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Chat',
                              style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ],

          _BookingHelpCard(
            booking: booking,
            canEdit: booking.status == 'PENDING',
          ),
          const SizedBox(height: 16),

          // ─── Service info ──────────────────────────────────────────────────
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: 'Service'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.build_rounded, color: _accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.serviceName,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat(
                                'EEE, d MMM y • h:mm a',
                              ).format(booking.scheduledAt.toLocal()),
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (booking.addressLabel != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            booking.addressLabel!,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurface,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Custom Quote Banner ─────────────────────────────────────────────────────
          if (booking.customQuoteStatus != null) ...[
            _CustomQuoteBanner(booking: booking),
            const SizedBox(height: 12),
          ],

          // ─── Spare Parts Banner ─────────────────────────────────────────────────────
          if (booking.sparePartStatus != null) ...[
            _SparePartsBanner(booking: booking),
            const SizedBox(height: 12),
          ],

          if (booking.worker != null)
            PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(label: 'Professional'),
                    const SizedBox(height: 12),
                    TapScale(
                      onTap: () => context.push(
                        '/professional?id=${booking.worker!.id}',
                      ),
                      child: Row(
                        children: [
                          MarketplaceNetworkAvatar(
                            imageUrl: booking.worker!.avatarUrl,
                            radius: 26,
                            backgroundColor: _accent.withValues(alpha: 0.15),
                            fallback: Text(
                              booking.worker!.name.trim().isEmpty
                                  ? 'P'
                                  : booking.worker!.name
                                        .trim()
                                        .substring(0, 1)
                                        .toUpperCase(),
                              style: tt.titleMedium?.copyWith(
                                color: _accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.worker!.name,
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      booking.worker!.rating.toStringAsFixed(1),
                                      style: tt.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // ─── Payment summary ───────────────────────────────────────────────
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: 'Payment'),
                  const SizedBox(height: 16),
                  _PayRow(
                    label: 'Booking total',
                    value: '₹${booking.totalAmount.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your payment summary and invoice are available here. Refund progress appears below when a refund is issued.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (booking.refunds.isNotEmpty) ...[
            PremiumGlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(label: 'Refund tracking'),
                    const SizedBox(height: 14),
                    for (var index = 0; index < booking.refunds.length; index++) ...[
                      _RefundStatusRow(refund: booking.refunds[index]),
                      if (index < booking.refunds.length - 1)
                        const Divider(height: 24),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (booking.beforePhotoUrls.isNotEmpty ||
              booking.afterPhotoUrls.isNotEmpty) ...[
            _JobPhotoGallery(booking: booking),
            const SizedBox(height: 12),
          ],

          // ─── Timeline ─────────────────────────────────────────────────────
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: 'Booking Timeline'),
                  const SizedBox(height: 16),
                  if (booking.timeline.isNotEmpty) ...[
                    Row(
                      children: [
                        _TimelineBadge(
                          icon: Icons.update_rounded,
                          label: '${booking.timeline.length} updates',
                        ),
                        const SizedBox(width: 8),
                        _TimelineBadge(
                          icon: Icons.schedule_rounded,
                          label: DateFormat(
                            'd MMM, h:mm a',
                          ).format(booking.timeline.last.createdAt.toLocal()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (
                      var index = 0;
                      index < booking.timeline.length;
                      index++
                    )
                      _TimelineStep(
                        status: booking.timeline[index].status,
                        label: booking.timeline[index].title,
                        time: DateFormat(
                          'd MMM, h:mm a',
                        ).format(booking.timeline[index].createdAt.toLocal()),
                        description: booking.timeline[index].description,
                        isCompleted: true,
                        isFirst: index == 0,
                        isLast: index == booking.timeline.length - 1,
                      ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No timeline updates yet',
                                style: tt.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Booking progress will appear here as it changes.',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Rate / Rebook CTAs ────────────────────────────────────────────
          if (booking.status == 'COMPLETED') ...[
            TapScale(
              onTap: () =>
                  context.push('/booking-rating?bookingId=${booking.id}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Rate this service',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Consumer(
              builder: (context, ref, _) {
                final disputeAsync = ref.watch(
                  bookingDisputeStatusProvider(booking.id),
                );
                return disputeAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                  error: (_, _) => TextButton.icon(
                    onPressed: () => ref.invalidate(
                      bookingDisputeStatusProvider(booking.id),
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry dispute status'),
                  ),
                  data: (dispute) {
                    if (dispute != null) {
                      return _CustomerDisputeCard(dispute: dispute);
                    }
                    return booking.canDispute
                        ? _DisputeAction(
                            onPressed: () =>
                                _raiseDisputeDialog(context, ref, booking),
                          )
                        : const SizedBox.shrink();
                  },
                );
              },
            ),
            const SizedBox(height: 10),
          ],

          if (canCancel) ...[
            Consumer(
              builder: (context, ref, _) => TapScale(
                onTap: () => _confirmCancelBooking(context, ref, booking),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(
                      AbzioTheme.buttonRadius,
                    ),
                    border: Border.all(color: cs.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cancel_outlined, color: cs.error, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Cancel Booking',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: cs.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          TapScale(
            onTap: () => context.push(
              '/support?autoCompose=true&bookingId=${Uri.encodeComponent(booking.id)}&bookingCode=${Uri.encodeComponent(booking.code)}&serviceName=${Uri.encodeComponent(booking.serviceName)}&category=booking&subject=${Uri.encodeComponent('Issue with booking ${booking.code}')}&message=${Uri.encodeComponent('I need help with booking ${booking.code} for ${booking.serviceName}. Please review this booking and let me know the next steps.')}',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    color: cs.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Need help? Contact support',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (canRebook) ...[
            TapScale(
              onTap: () => _openRebookBooking(context, booking),
              child: Semantics(
                button: true,
                label: 'Book again for ${booking.serviceName}',
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(
                      AbzioTheme.buttonRadius,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Book Again',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TapScale(
            onTap: () => context.push('/invoice/${booking.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: cs.onSurface,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View Invoice',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingHelpCard extends StatelessWidget {
  const _BookingHelpCard({required this.booking, required this.canEdit});

  final BookingDetail booking;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bookingCode = booking.code;
    final serviceName = booking.serviceName;

    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.support_agent_rounded, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help with this booking?',
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Get help with timing, payment, or the professional without leaving this page.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HelpActionChip(
                  label: 'Booking issue',
                  icon: Icons.receipt_long_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openSupportDraft(
                    context,
                    category: 'booking',
                    subject: 'Issue with booking #$bookingCode',
                    message:
                        'I need help with booking #$bookingCode for $serviceName. Please review the booking and let me know the next steps.',
                    bookingId: booking.id,
                    bookingCode: bookingCode,
                    serviceName: serviceName,
                  ),
                ),
                _HelpActionChip(
                  label: 'Payment issue',
                  icon: Icons.payments_rounded,
                  color: AbzioTheme.successColor,
                  onTap: () => _openSupportDraft(
                    context,
                    category: 'payment',
                    subject: 'Payment or refund issue',
                    message:
                        'I need help with a payment or refund for booking #$bookingCode ($serviceName).',
                    bookingId: booking.id,
                    bookingCode: bookingCode,
                    serviceName: serviceName,
                  ),
                ),
                _HelpActionChip(
                  label: 'Report professional',
                  icon: Icons.person_off_rounded,
                  color: const Color(0xFFEF4444),
                  onTap: () => _openSupportDraft(
                    context,
                    category: 'professional',
                    subject: 'Report a professional',
                    message:
                        'I want to report an issue with the professional on booking #$bookingCode ($serviceName).',
                    bookingId: booking.id,
                    bookingCode: bookingCode,
                    serviceName: serviceName,
                  ),
                ),
                if (canEdit)
                  _HelpActionChip(
                    label: 'Edit booking',
                    icon: Icons.edit_calendar_rounded,
                    color: cs.primary,
                    onTap: () => _openSupportDraft(
                      context,
                      category: 'booking',
                      subject: 'Need to update booking #$bookingCode',
                      message:
                          'I would like help updating booking #$bookingCode for $serviceName. Please advise on the next step.',
                      bookingId: booking.id,
                      bookingCode: bookingCode,
                      serviceName: serviceName,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpActionChip extends StatelessWidget {
  const _HelpActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return ActionChip(
      label: Text(label),
      avatar: Icon(icon, size: 18, color: color),
      labelStyle: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    );
  }
}

void _openSupportDraft(
  BuildContext context, {
  required String category,
  required String subject,
  required String message,
  required String bookingId,
  required String bookingCode,
  required String serviceName,
}) {
  context.push(
    '/support?autoCompose=true&category=${Uri.encodeComponent(category)}&bookingId=${Uri.encodeComponent(bookingId)}&bookingCode=${Uri.encodeComponent(bookingCode)}&serviceName=${Uri.encodeComponent(serviceName)}&subject=${Uri.encodeComponent(subject)}&message=${Uri.encodeComponent(message)}',
  );
}

Future<void> _confirmCancelBooking(
  BuildContext context,
  WidgetRef ref,
  BookingDetail booking,
) async {
  final controller = TextEditingController();
  final cancellationInformation = _cancellationInformationForBooking(booking);
  try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isSubmitting = false;
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Cancel booking?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancellation & refund',
                          style: Theme.of(dialogContext).textTheme.labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(
                                  dialogContext,
                                ).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cancellationInformation,
                          style: Theme.of(dialogContext).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  dialogContext,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Tell us why you want to cancel so we can improve support.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 200,
                    enabled: !isSubmitting,
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setDialogState(() => errorMessage = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Reason for cancellation',
                      errorText: errorMessage,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep booking'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final reason = controller.text.trim();
                        if (reason.length < 3) {
                          setDialogState(
                            () => errorMessage =
                                'Enter a reason with at least 3 characters.',
                          );
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = true;
                          errorMessage = null;
                        });
                        try {
                          await ref
                              .read(apiClientProvider)
                              .post(
                                '/bookings/${booking.id}/cancel',
                                data: {'reason': reason},
                              );
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(true);
                          }
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          if (error is DioException &&
                              error.response?.statusCode == 409) {
                            try {
                              ref.invalidate(
                                bookingDetailPageProvider(booking.id),
                              );
                              final latestBooking = await ref.read(
                                bookingDetailPageProvider(booking.id).future,
                              );
                              if (!dialogContext.mounted) return;
                              if (const {
                                'CANCELLED',
                                'CANCELLED_MANUAL',
                                'CANCELLED_NO_SHOW',
                              }.contains(latestBooking.status.toUpperCase())) {
                                Navigator.of(dialogContext).pop(true);
                                return;
                              }
                            } catch (_) {
                              if (!dialogContext.mounted) return;
                            }
                          }
                          setDialogState(() {
                            isSubmitting = false;
                            errorMessage = error is DioException
                                ? _errorMessageFromDio(error)
                                : 'Could not cancel this booking. Please try again.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Cancel booking'),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    ref.invalidate(bookingDetailPageProvider(booking.id));
    ref.invalidate(customerBookingsProvider('upcoming'));
    ref.invalidate(customerBookingsProvider('cancelled'));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Booking cancelled. Any eligible refund is handled separately.',
        ),
      ),
    );
    context.go('/bookings');
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    final message = error is DioException
        ? _errorMessageFromDio(error)
        : error.toString();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  } finally {
    controller.dispose();
  }
}

void _openRebookBooking(BuildContext context, BookingDetail booking) {
  final serviceSlug = booking.serviceSlug;
  if (serviceSlug != null && serviceSlug.isNotEmpty) {
    context.push('/service?id=${Uri.encodeComponent(serviceSlug)}');
    return;
  }

  context.push('/search?q=${Uri.encodeComponent(booking.serviceName)}');
}

String _errorMessageFromDio(DioException error) {
  final data = error.response?.data;
  if (error.response?.statusCode != null &&
      error.response!.statusCode! < 500 &&
      data is Map<String, dynamic>) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    final errorMessage = data['error_message'];
    if (errorMessage is String && errorMessage.trim().isNotEmpty) {
      return errorMessage;
    }
  }

  return 'Could not cancel this booking. Please check your connection and try again.';
}

String _cancellationInformationForBooking(BookingDetail booking) {
  if (booking.status.toUpperCase() == 'COMPLETED') {
    return 'This booking is complete. Contact support to ask whether a refund can be reviewed.';
  }

  return 'Cancelling stops this booking. If a payment was captured, refund eligibility is reviewed separately; this action does not issue a refund automatically.';
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

Future<void> _raiseDisputeDialog(
  BuildContext context,
  WidgetRef ref,
  BookingDetail booking,
) async {
  final reasonController = TextEditingController();

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.flag_rounded,
                      color: Color(0xFFF97316),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Raise a Dispute',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Booking #${booking.code}',
                          style: Theme.of(sheetContext).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFF97316).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFFF97316),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You have 48 hours after job completion to raise a dispute. Worker payment will be paused until the admin reviews your case.',
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(
                              color: const Color(0xFFF97316),
                              height: 1.5,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Describe the issue',
                  hintText:
                      'e.g. Work was incomplete, professional was unprofessional, damage caused...',
                  alignLabelWithHint: true,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      icon: const Icon(Icons.flag_rounded, size: 18),
                      label: const Text('Submit Dispute'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (confirmed != true) {
    reasonController.dispose();
    return;
  }

  final reason = reasonController.text.trim();
  reasonController.dispose();

  if (reason.length < 10) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please provide a more detailed reason (min 10 characters).',
        ),
      ),
    );
    return;
  }

  try {
    await ref
        .read(apiClientProvider)
        .post('/bookings/${booking.id}/dispute', data: {'reason': reason});
    ref.invalidate(bookingDetailPageProvider(booking.id));
    ref.invalidate(bookingDisputeStatusProvider(booking.id));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Dispute submitted. Our team will review within 24–48 hours.',
        ),
        backgroundColor: Color(0xFF0F766E),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not submit dispute.')));
  }
}

class _DisputeAction extends StatelessWidget {
  const _DisputeAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.flag_rounded),
    label: const Text('Raise a dispute'),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFFF97316),
      side: const BorderSide(color: Color(0xFFF97316)),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
    ),
  );
}

class _CustomerDisputeCard extends StatelessWidget {
  const _CustomerDisputeCard({required this.dispute});

  final CustomerDisputeStatus dispute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (dispute.status) {
      'resolved_refund' => AbzioTheme.successColor,
      'resolved_rejected' => cs.onSurfaceVariant,
      'refund_pending' => AbzioTheme.infoColor,
      _ => AbzioTheme.warningColor,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Dispute ${_disputeStatusLabel(dispute.status)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                DateFormat('d MMM').format(dispute.createdAt.toLocal()),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(dispute.reason, style: Theme.of(context).textTheme.bodyMedium),
          if (dispute.resolutionNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              dispute.resolutionNote!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _disputeStatusLabel(String status) => switch (status) {
  'open' => 'submitted',
  'under_review' => 'under review',
  'refund_pending' => 'refund processing',
  'resolved_refund' => 'resolved with refund',
  'resolved_rejected' => 'resolved',
  _ => status.replaceAll('_', ' '),
};

Future<void> _showEditBookingSheet(
  BuildContext context,
  WidgetRef ref,
  BookingDetail booking,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookingEditSheet(booking: booking),
  );
}

class _BookingEditSheet extends ConsumerStatefulWidget {
  const _BookingEditSheet({required this.booking});

  final BookingDetail booking;

  @override
  ConsumerState<_BookingEditSheet> createState() => _BookingEditSheetState();
}

class _BookingEditSheetState extends ConsumerState<_BookingEditSheet> {
  late final SavedAddressesApi _addressesApi;
  List<SavedAddressItem> _addresses = const [];
  String? _selectedAddressId;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlotIso;
  List<DateTime> _availableSlots = const [];
  bool _loading = true;
  bool _loadingSlots = false;
  bool _saving = false;
  String? _error;
  String? _slotError;
  String? _slotNotice;
  int _slotRequestId = 0;

  @override
  void initState() {
    super.initState();
    _addressesApi = SavedAddressesApi(ref.read(apiClientProvider).dio);
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _addressesApi.listAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        final matchingAddresses = addresses.where(
          (address) =>
              address.pincode == widget.booking.addressPincode &&
              address.addressLine1.trim().toLowerCase() ==
                  (widget.booking.addressLine1 ?? '').trim().toLowerCase() &&
              address.city.trim().toLowerCase() ==
                  (widget.booking.cityName ?? '').trim().toLowerCase(),
        );
        _selectedAddressId = matchingAddresses.isNotEmpty
            ? matchingAddresses.first.id
            : addresses.isNotEmpty
            ? addresses.first.id
            : null;
        _loading = false;
      });
      await _loadSlots();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadSlots() async {
    final requestId = ++_slotRequestId;
    final addressId = _selectedAddressId;
    if (addressId == null || widget.booking.serviceIds.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingSlots = false;
          _availableSlots = const [];
          _selectedSlotIso = null;
          _slotError = null;
        });
      }
      return;
    }
    final selectedDate = _selectedDate;
    setState(() {
      _loadingSlots = true;
      _slotError = null;
      _slotNotice = null;
      _availableSlots = const [];
      _selectedSlotIso = null;
    });
    try {
      final data = await ref
          .read(apiClientProvider)
          .get(
            '/users/bookings/${widget.booking.id}/reschedule-slots',
            queryParameters: {
              'addressId': addressId,
              'startDate': DateFormat('yyyy-MM-dd').format(selectedDate),
              'days': 7,
            },
          );
      if (!mounted || requestId != _slotRequestId) return;
      final rows = data['slots'];
      final slots = rows is List
          ? rows.whereType<Map>().map((row) {
              final slot = Map<String, dynamic>.from(row);
              return DateTime.parse(slot['scheduledFor'] as String).toLocal();
            }).toList()
          : <DateTime>[];
      if (!mounted) return;
      final currentTime = widget.booking.scheduledAt.toLocal();
      DateTime? currentSlot;
      for (final slot in slots) {
        if (slot.isAtSameMomentAs(currentTime)) {
          currentSlot = slot;
          break;
        }
      }
      setState(() {
        _availableSlots = slots;
        _selectedSlotIso = currentSlot?.toUtc().toIso8601String();
      });
    } catch (error) {
      if (mounted && requestId == _slotRequestId) {
        setState(
          () => _slotError =
              'Could not load available appointment times. Please retry.',
        );
      }
    } finally {
      if (mounted && requestId == _slotRequestId) {
        setState(() => _loadingSlots = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || date == null) return;
    setState(() {
      _selectedDate = date;
    });
    await _loadSlots();
  }

  Future<void> _save() async {
    if (_selectedAddressId == null || _selectedSlotIso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an address and an available time.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .patch(
            '/bookings/${widget.booking.id}',
            data: {
              'addressId': _selectedAddressId,
              'scheduledAt': DateTime.parse(
                _selectedSlotIso!,
              ).toUtc().toIso8601String(),
            },
          );
      if (!mounted) return;
      ref.invalidate(bookingDetailPageProvider(widget.booking.id));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Booking updated.')));
    } on DioException catch (error) {
      if (!mounted) return;
      final responseBody = error.response?.data;
      final responseMessage = responseBody is Map
          ? responseBody['message']?.toString()
          : null;
      if (error.response?.statusCode == 409 &&
          responseMessage?.toLowerCase().contains('appointment slot') == true) {
        await _loadSlots();
        if (!mounted) return;
        setState(
          () => _slotNotice =
              'That time was just booked. Available times have been refreshed; choose another time.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseMessage ?? 'Could not update booking. Please try again.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update booking. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Edit booking',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Update the address or reschedule before dispatch starts.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error))
              else ...[
                Text(
                  'Saved address',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _selectedAddressId,
                  onChanged: (value) async {
                    setState(() => _selectedAddressId = value);
                    await _loadSlots();
                  },
                  child: Column(
                    children: [
                      ..._addresses.map((address) {
                        return RadioListTile<String>(
                          value: address.id,
                          title: Text(
                            address.label,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(address.displayAddress),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    'Starting ${DateFormat('d MMM y').format(_selectedDate)}',
                  ),
                ),
                const SizedBox(height: 10),
                if (_loadingSlots)
                  const LinearProgressIndicator()
                else if (_slotError != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _slotError!,
                          style: tt.bodySmall?.copyWith(color: cs.error),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadSlots,
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                else ...[
                  if (_slotNotice != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _slotNotice!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_availableSlots.isEmpty)
                    Text(
                      'No available appointment times for this date range.',
                      style: tt.bodySmall?.copyWith(color: cs.error),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSlotIso,
                      decoration: const InputDecoration(
                        labelText: 'Available appointment time',
                      ),
                      items: _availableSlots.map((slot) {
                        final value = slot.toUtc().toIso8601String();
                        return DropdownMenuItem(
                          value: value,
                          child: Text(
                            DateFormat('EEE, d MMM · h:mm a').format(slot),
                          ),
                        );
                      }).toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _selectedSlotIso = value;
                              _slotNotice = null;
                            }),
                    ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundStatusRow extends StatelessWidget {
  const _RefundStatusRow({required this.refund});

  final BookingRefund refund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = refund.status.toLowerCase();
    final (label, color, icon) = switch (status) {
      'processed' => ('Completed', const Color(0xFF15803D), Icons.check_circle_rounded),
      'failed' => ('Needs attention', theme.colorScheme.error, Icons.error_rounded),
      _ => ('Processing', const Color(0xFF2563EB), Icons.hourglass_top_rounded),
    };
    final gatewayAmount = refund.gatewayAmount ??
        (refund.amount - refund.walletAmount).clamp(0, refund.amount).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '₹${refund.amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (gatewayAmount > 0)
          Text('Refund to original payment: ₹${gatewayAmount.toStringAsFixed(2)}'),
        if (refund.walletAmount > 0)
          Text(
            refund.walletCreditedAt != null
                ? 'Wallet credit: ₹${refund.walletAmount.toStringAsFixed(2)} (credited)'
                : 'Wallet credit: ₹${refund.walletAmount.toStringAsFixed(2)}',
          ),
        const SizedBox(height: 4),
        Text(
          'Last updated ${DateFormat('d MMM y, h:mm a').format(refund.updatedAt.toLocal())}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (status == 'failed')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Please contact support if you need help with this refund.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.status,
    required this.label,
    required this.time,
    required this.isCompleted,
    this.description,
    this.isFirst = false,
    this.isLast = false,
  });

  final String status;
  final String label;
  final String time;
  final String? description;
  final bool isCompleted;
  final bool isFirst;
  final bool isLast;

  Color _statusColor(ColorScheme cs) => switch (status) {
    'COMPLETED' => AbzioTheme.successColor,
    'REFUNDED' ||
    'CANCELLED' ||
    'CANCELLED_MANUAL' ||
    'CANCELLED_NO_SHOW' => AbzioTheme.dangerColor,
    'ARRIVED' || 'IN_PROGRESS' || 'WORKER_ASSIGNED' => AbzioTheme.infoColor,
    'PAYMENT_CAPTURED' => AbzioTheme.successColor,
    'DISPATCH_FAILED' => AbzioTheme.warningColor,
    _ => cs.primary,
  };

  IconData _statusIcon() => switch (status) {
    'COMPLETED' => Icons.task_alt_rounded,
    'REFUNDED' ||
    'CANCELLED' ||
    'CANCELLED_MANUAL' ||
    'CANCELLED_NO_SHOW' => Icons.cancel_rounded,
    'ARRIVED' => Icons.location_on_rounded,
    'IN_PROGRESS' => Icons.handyman_rounded,
    'WORKER_ASSIGNED' => Icons.verified_rounded,
    'PAYMENT_CAPTURED' => Icons.payments_rounded,
    'DISPATCH_FAILED' => Icons.report_problem_rounded,
    _ => Icons.schedule_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = _statusColor(cs);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isCompleted ? accent : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? accent : cs.outlineVariant,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? Icon(_statusIcon(), size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isCompleted
                        ? accent.withValues(alpha: 0.35)
                        : cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? accent : cs.onSurfaceVariant,
                  ),
                ),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineBadge extends StatelessWidget {
  const _TimelineBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _JobPhotoGallery extends StatelessWidget {
  const _JobPhotoGallery({required this.booking});

  final BookingDetail booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionLabel(label: 'Work photos'),
            const SizedBox(height: 14),
            if (booking.beforePhotoUrls.isNotEmpty) ...[
              Text('Before', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _PhotoStrip(urls: booking.beforePhotoUrls),
            ],
            if (booking.beforePhotoUrls.isNotEmpty &&
                booking.afterPhotoUrls.isNotEmpty)
              const SizedBox(height: 16),
            if (booking.afterPhotoUrls.isNotEmpty) ...[
              Text('After', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              _PhotoStrip(urls: booking.afterPhotoUrls),
            ],
            const SizedBox(height: 10),
            Text(
              'Photos shared by your professional during the job.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 104,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: urls.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final url = urls[index];
        return Semantics(
          button: true,
          label: 'Open work photo ${index + 1}',
          child: GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      tooltip: 'Close photo',
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    title: Text('Photo ${index + 1} of ${urls.length}'),
                  ),
                  body: Center(
                    child: InteractiveViewer(
                      child: MarketplaceNetworkImage(
                        imageUrl: url,
                        width: MediaQuery.sizeOf(dialogContext).width,
                        height: MediaQuery.sizeOf(dialogContext).height,
                        fit: BoxFit.contain,
                        backgroundColor: Theme.of(dialogContext).colorScheme.surface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
              child: MarketplaceNetworkImage(
                imageUrl: url,
                width: 104,
                height: 104,
                fit: BoxFit.cover,
                cloudinaryWidth: 240,
                cloudinaryHeight: 240,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ─── BookingDetail entity ──────────────────────────────────────────────────────
// Extended entity with full detail for this page

class BookingDetail {
  const BookingDetail({
    required this.id,
    required this.code,
    required this.status,
    required this.scheduledAt,
    required this.totalAmount,
    required this.serviceName,
    this.serviceIcon,
    this.serviceSlug,
    this.addressLabel,
    this.worker,
    this.refunds = const [],
    this.timeline = const [],
    this.customQuoteAmount,
    this.customQuoteItemized,
    this.customQuoteNotes,
    this.customQuoteStatus,
    this.sparePartStatus,
    this.sparePartTotal,
    this.sparePartItems,
    this.sparePartReceiptUrl,
    this.completedAt,
    this.beforePhotoUrls = const [],
    this.afterPhotoUrls = const [],
    this.bookingType,
    this.addressId,
    this.serviceIds = const [],
    this.addressLine1,
    this.addressPincode,
    this.addressLatitude,
    this.addressLongitude,
    this.cityName,
  });

  final String id;
  final String code;
  final String status;
  final DateTime scheduledAt;
  final double totalAmount;
  final String serviceName;
  final String? serviceIcon;
  final String? serviceSlug;
  final String? addressLabel;
  final BookingWorker? worker;
  final List<BookingRefund> refunds;
  final List<BookingTimelineEvent> timeline;
  final double? customQuoteAmount;
  final List<Map<String, dynamic>>? customQuoteItemized;
  final String? customQuoteNotes;
  final String? customQuoteStatus;
  final String? sparePartStatus;
  final double? sparePartTotal;
  final List<Map<String, dynamic>>? sparePartItems;
  final String? sparePartReceiptUrl;
  final DateTime? completedAt;
  final List<String> beforePhotoUrls;
  final List<String> afterPhotoUrls;
  final String? bookingType;
  final String? addressId;
  final List<String> serviceIds;
  final String? addressLine1;
  final String? addressPincode;
  final double? addressLatitude;
  final double? addressLongitude;
  final String? cityName;

  /// Returns true if booking can still be disputed (within 48-hour window).
  bool get canDispute {
    if (status != 'COMPLETED') return false;
    final completed = completedAt;
    if (completed == null) return false;
    return DateTime.now().difference(completed).inHours < 48;
  }

  factory BookingDetail.fromJson(Map<String, dynamic> json) => BookingDetail(
    id: json['id'] as String? ?? '',
    code: json['code'] as String? ?? '',
    status: json['status'] as String? ?? 'PENDING',
    bookingType: json['bookingType'] as String?,
    addressId: json['addressId'] as String?,
    serviceIds: (json['serviceIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(),
    addressLine1: json['addressLine1'] as String?,
    addressPincode: json['addressPincode'] as String?,
    addressLatitude: (json['addressLatitude'] as num?)?.toDouble(),
    addressLongitude: (json['addressLongitude'] as num?)?.toDouble(),
    cityName: json['cityName'] as String?,
    scheduledAt:
        DateTime.tryParse(json['scheduledAt'] as String? ?? '') ??
        DateTime.now(),
    totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    serviceName: json['serviceName'] as String? ?? 'Service',
    serviceIcon: json['serviceIcon'] as String?,
    serviceSlug: json['serviceSlug'] as String?,
    addressLabel: json['addressLabel'] as String?,
    worker: json['worker'] != null
        ? BookingWorker.fromJson(json['worker'] as Map<String, dynamic>)
        : null,
    refunds: (json['refunds'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((refund) => BookingRefund.fromJson(
              Map<String, dynamic>.from(refund),
            ))
        .toList(growable: false),
    timeline: (json['timeline'] as List<dynamic>? ?? [])
        .map(
          (item) => BookingTimelineEvent.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    customQuoteAmount: (json['customQuoteAmount'] as num?)?.toDouble(),
    customQuoteItemized: (json['customQuoteItemized'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    customQuoteNotes: json['customQuoteNotes'] as String?,
    customQuoteStatus: json['customQuoteStatus'] as String?,
    sparePartStatus: json['sparePartStatus'] as String?,
    sparePartTotal: (json['sparePartTotal'] as num?)?.toDouble(),
    sparePartItems: (json['sparePartItems'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    sparePartReceiptUrl: json['sparePartReceiptUrl'] as String?,
    completedAt: json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'] as String)
        : null,
    beforePhotoUrls: (json['beforePhotoUrls'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false),
    afterPhotoUrls: (json['afterPhotoUrls'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList(growable: false),
  );
}

class BookingRefund {
  const BookingRefund({
    required this.id,
    required this.amount,
    required this.walletAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.gatewayAmount,
    this.walletCreditedAt,
  });

  final String id;
  final double amount;
  final double? gatewayAmount;
  final double walletAmount;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? walletCreditedAt;

  factory BookingRefund.fromJson(Map<String, dynamic> json) => BookingRefund(
        id: json['id'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        gatewayAmount: (json['gatewayAmount'] as num?)?.toDouble(),
        walletAmount: (json['walletAmount'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
        walletCreditedAt: json['walletCreditedAt'] is String
            ? DateTime.tryParse(json['walletCreditedAt'] as String)
            : null,
      );
}

class BookingTimelineEvent {
  const BookingTimelineEvent({
    required this.id,
    required this.status,
    required this.title,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String status;
  final String title;
  final String? description;
  final DateTime createdAt;

  factory BookingTimelineEvent.fromJson(Map<String, dynamic> json) =>
      BookingTimelineEvent(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        title: json['title'] as String? ?? 'Update',
        description: json['description'] as String?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── Spare Parts Banner ───────────────────────────────────────────────────────

class _SparePartsBanner extends ConsumerStatefulWidget {
  const _SparePartsBanner({required this.booking});
  final BookingDetail booking;

  @override
  ConsumerState<_SparePartsBanner> createState() => _SparePartsBannerState();
}

class _SparePartsBannerState extends ConsumerState<_SparePartsBanner> {
  late final RazorpayService _razorpayService;
  bool _loading = false;
  // Stored while checkout is open so the success callback can call verify
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService.create();
    _razorpayService.registerCallbacks(
      onSuccess: _handlePaymentSuccess,
      onError: _handlePaymentError,
      onExternalWallet: (_) {},
    );
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final orderId = response.orderId ?? _pendingOrderId ?? '';
    final paymentId = response.paymentId ?? '';
    final signature = response.signature ?? '';
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/bookings/${widget.booking.id}/spare-parts/verify-payment',
        data: {
          'razorpayOrderId': orderId,
          'razorpayPaymentId': paymentId,
          'razorpaySignature': signature,
        },
      );
      ref.invalidate(bookingDetailPageProvider(widget.booking.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Payment successful! Spare parts added to your bill.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification failed. Please try again.'),
          ),
        );
      }
    } finally {
      _pendingOrderId = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingOrderId = null;
    if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment failed: ${response.message ?? 'Unknown error'}',
          ),
        ),
      );
    }
  }

  Future<void> _pay() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      // 1. Create Razorpay order on our backend
      final orderData = await api.post(
        '/bookings/${widget.booking.id}/spare-parts/payment-order',
      );

      final keyId = orderData['keyId'] as String? ?? '';
      final rzpOrderId = orderData['orderId'] as String? ?? '';
      final amountPaise = orderData['amountPaise'] as int?;
      final customerName = orderData['customerName'] as String? ?? 'Customer';
      final phone = orderData['customerPhone'] as String? ?? '';

      if (keyId.isEmpty || rzpOrderId.isEmpty || amountPaise == null) {
        throw Exception('Payment order response was incomplete.');
      }

      _pendingOrderId = rzpOrderId;

      // 2. Open Razorpay native checkout
      _razorpayService.openCheckout(
        keyId: keyId,
        orderId: rzpOrderId,
        bookingCode: widget.booking.code,
        customerName: customerName,
        email: '',
        phone: phone,
        amountInPaise: amountPaise,
      );
      // _loading is cleared by success/error callback
    } catch (_) {
      _pendingOrderId = null;
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start payment. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/bookings/${widget.booking.id}/spare-parts/reject');
      ref.invalidate(bookingDetailPageProvider(widget.booking.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Spare parts request rejected.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reject spare parts request.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = widget.booking.sparePartStatus ?? 'PENDING';
    final total = widget.booking.sparePartTotal ?? 0.0;
    final items = widget.booking.sparePartItems ?? [];
    final receiptUrl = widget.booking.sparePartReceiptUrl;

    final (borderColor, bgColor, icon, label) = switch (status) {
      'PAID' => (
        AbzioTheme.successColor,
        AbzioTheme.successColor,
        Icons.check_circle_rounded,
        'Spare Parts Paid',
      ),
      'REJECTED' => (
        cs.outline,
        cs.outlineVariant,
        Icons.cancel_rounded,
        'Spare Parts Rejected',
      ),
      _ => (
        AbzioTheme.warningColor,
        AbzioTheme.warningColor,
        Icons.hardware_rounded,
        'Spare Parts Added — Payment Required',
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(icon, color: borderColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: borderColor,
                    ),
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: borderColor,
                  ),
                ),
              ],
            ),

            // Line items
            if (items.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['label'] as String? ?? '',
                          style: tt.bodyMedium,
                        ),
                      ),
                      Text(
                        '₹${(item['amount'] as num).toStringAsFixed(0)}',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Receipt photo link
            if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Receipt photo attached',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],

            // Pay / Reject buttons — only when PENDING
            if (status == 'PENDING') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(
                          color: cs.error.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _pay,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.payment_rounded, size: 18),
                      label: Text(
                        _loading
                            ? 'Processing…'
                            : 'Pay ₹${total.toStringAsFixed(0)}',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Custom Quote Banner ──────────────────────────────────────────────────────

class _CustomQuoteBanner extends ConsumerStatefulWidget {
  const _CustomQuoteBanner({required this.booking});
  final BookingDetail booking;

  @override
  ConsumerState<_CustomQuoteBanner> createState() => _CustomQuoteBannerState();
}

class _CustomQuoteBannerState extends ConsumerState<_CustomQuoteBanner> {
  bool _loading = false;

  Future<void> _respond(String action) async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/bookings/${widget.booking.id}/$action-quote');
      ref.invalidate(bookingDetailPageProvider(widget.booking.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'accept'
                  ? '✅ Quote accepted! Proceed to payment.'
                  : 'Quote rejected.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to complete verification.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = widget.booking.customQuoteStatus ?? 'PENDING';
    final amount = widget.booking.customQuoteAmount ?? 0.0;
    final items = widget.booking.customQuoteItemized ?? [];
    final notes = widget.booking.customQuoteNotes;

    final (borderColor, bgColor, icon, label) = switch (status) {
      'ACCEPTED' => (
        AbzioTheme.successColor,
        AbzioTheme.successColor,
        Icons.check_circle_rounded,
        'Quote Accepted',
      ),
      'REJECTED' => (
        cs.outline,
        cs.outlineVariant,
        Icons.cancel_rounded,
        'Quote Rejected',
      ),
      _ => (
        AbzioTheme.warningColor,
        AbzioTheme.warningColor,
        Icons.request_quote_rounded,
        'Quote Received — Review Required',
      ),
    };

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AbzioTheme.cardRadius),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(icon, color: borderColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: borderColor,
                    ),
                  ),
                ),
                Text(
                  '₹${amount.toStringAsFixed(0)}',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: borderColor,
                  ),
                ),
              ],
            ),

            // Line items
            if (items.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['label'] as String? ?? '',
                          style: tt.bodyMedium,
                        ),
                      ),
                      Text(
                        '₹${(item['amount'] as num).toStringAsFixed(0)}',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Accept / Reject buttons — only when PENDING
            if (status == 'PENDING') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _respond('reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(
                          color: cs.error.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : () => _respond('accept'),
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _loading ? 'Processing…' : 'Accept & Proceed',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AbzioTheme.successColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final bookingDetailPageProvider = FutureProvider.family
    .autoDispose<BookingDetail, String>((ref, bookingId) async {
      final api = ref.watch(apiClientProvider);
      final data = await api.get('/users/bookings/$bookingId');
      return BookingDetail.fromJson(data['booking'] as Map<String, dynamic>);
    });

class CustomerDisputeStatus {
  const CustomerDisputeStatus({
    required this.status,
    required this.reason,
    required this.createdAt,
    this.resolutionNote,
  });

  final String status;
  final String reason;
  final DateTime createdAt;
  final String? resolutionNote;

  factory CustomerDisputeStatus.fromJson(Map<String, dynamic> json) =>
      CustomerDisputeStatus(
        status: json['status'] as String? ?? 'open',
        reason: json['reason'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        resolutionNote: json['resolutionNote'] as String?,
      );
}

final bookingDisputeStatusProvider = FutureProvider.family
    .autoDispose<CustomerDisputeStatus?, String>((ref, bookingId) async {
      final api = ref.watch(apiClientProvider);
      final data = await api.get('/bookings/$bookingId/dispute');
      final raw = data['dispute'];
      if (raw is! Map) return null;
      return CustomerDisputeStatus.fromJson(Map<String, dynamic>.from(raw));
    });
