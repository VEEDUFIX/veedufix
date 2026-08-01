import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:marketplace_shared/marketplace_shared.dart';

import '../../../profile/data/saved_addresses_api.dart';
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
        title: Text('Booking Details', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          bookingAsync.whenOrNull(
            data: (b) => IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () => _shareBooking(context, b),
            ),
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: bookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: PremiumEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Could not load booking',
            subtitle: 'Pull down to try again.',
          ),
        ),
        data: (booking) => _BookingDetailBody(booking: booking),
      ),
    );
  }

  void _shareBooking(BuildContext context, BookingDetail booking) {
    Clipboard.setData(ClipboardData(
      text: 'Booking #${booking.code} — ${booking.serviceName}\n'
          'Status: ${_statusLabel(booking.status)}\n'
          'Total: ₹${booking.totalAmount.toStringAsFixed(0)}',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking info copied to clipboard')),
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
        _ => s,
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
        'COMPLETED' => const Color(0xFF10B981),
        'CANCELLED' || 'REFUNDED' => const Color(0xFFEF4444),
        'IN_PROGRESS' || 'ARRIVED' => const Color(0xFF6366F1),
        'EN_ROUTE' => const Color(0xFF14B8A6),
        _ => const Color(0xFFF59E0B),
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
    final isActive = ['PENDING', 'ACCEPTED', 'WORKER_ASSIGNED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS']
        .contains(booking.status);
    final canCancel = isActive;
    final canRebook = booking.serviceSlug != null && !isActive;

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
                  width: 48, height: 48,
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
                      Text(_statusLabel,
                          style: tt.titleMedium?.copyWith(color: _statusColor, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Booking #${booking.code}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 0.5)),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_calendar_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('Edit address & time', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (isActive) ...[
            if (booking.status == 'EN_ROUTE' || booking.status == 'ARRIVED' || booking.status == 'IN_PROGRESS')
              Consumer(
                builder: (context, ref, _) => TapScale(
                  onTap: () => context.push('/tracking?bookingId=${booking.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                      boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text('Track Professional', style: tt.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
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
                      onTap: () => context.push('/chat?bookingId=${booking.id}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 18, color: cs.primary),
                            const SizedBox(width: 8),
                            Text('Chat', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
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
                        width: 48, height: 48,
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
                            Text(booking.serviceName,
                                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEE, d MMM y • h:mm a').format(booking.scheduledAt),
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                        Icon(Icons.location_on_rounded, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(booking.addressLabel!,
                              style: tt.bodyMedium?.copyWith(color: cs.onSurface, height: 1.4)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Worker info ───────────────────────────────────────────────────
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
                      onTap: () => context.push('/professional?id=${booking.worker!.id}'),
                      child: Row(
                          children: [
                          MarketplaceNetworkAvatar(
                            imageUrl: booking.worker!.avatarUrl,
                            radius: 26,
                            backgroundColor: _accent.withValues(alpha: 0.15),
                            fallback: Text(
                              booking.worker!.name.substring(0, 1).toUpperCase(),
                              style: tt.titleMedium?.copyWith(color: _accent, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(booking.worker!.name,
                                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 4),
                                    Text(booking.worker!.rating.toStringAsFixed(1),
                                        style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
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
                  _PayRow(label: 'Service total', value: '₹${booking.totalAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount paid', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '₹${booking.totalAmount.toStringAsFixed(2)}',
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Timeline ─────────────────────────────────────────────────────
          PremiumGlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: 'Booking Timeline'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _TimelineBadge(
                        icon: Icons.update_rounded,
                        label: '${booking.timeline.isNotEmpty ? booking.timeline.length : 4} updates',
                      ),
                      const SizedBox(width: 8),
                      _TimelineBadge(
                        icon: Icons.schedule_rounded,
                        label: DateFormat('d MMM, h:mm a').format(
                          booking.timeline.isNotEmpty ? booking.timeline.last.createdAt : booking.scheduledAt,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (booking.timeline.isNotEmpty) ...[
                    for (var index = 0; index < booking.timeline.length; index++)
                      _TimelineStep(
                        status: booking.timeline[index].status,
                        label: booking.timeline[index].title,
                        time: DateFormat('d MMM, h:mm a').format(booking.timeline[index].createdAt),
                        description: booking.timeline[index].description,
                        isCompleted: true,
                        isFirst: index == 0,
                        isLast: index == booking.timeline.length - 1,
                      ),
                  ] else ...[
                    _TimelineStep(
                      status: 'PENDING',
                      label: 'Booking placed',
                      time: DateFormat('d MMM, h:mm a').format(booking.scheduledAt),
                      isCompleted: true,
                      isFirst: true,
                    ),
                    _TimelineStep(
                      status: booking.worker != null ? 'WORKER_ASSIGNED' : 'PENDING',
                      label: 'Worker assigned',
                      time: booking.worker != null ? booking.worker!.name : '',
                      isCompleted: booking.worker != null,
                    ),
                    _TimelineStep(
                      status: 'IN_PROGRESS',
                      label: 'Work in progress',
                      time: '',
                      isCompleted: ['IN_PROGRESS', 'ARRIVED', 'COMPLETED'].contains(booking.status),
                    ),
                    _TimelineStep(
                      status: booking.status,
                      label: 'Completed',
                      time: '',
                      isCompleted: booking.status == 'COMPLETED',
                      isLast: true,
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
              onTap: () => context.push('/booking-rating?bookingId=${booking.id}'),
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
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('Rate this service',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            )),
                  ],
                ),
              ),
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
                    borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
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

          if (canRebook) ...[
            TapScale(
              onTap: () => context.push('/service/${booking.serviceSlug}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
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
            const SizedBox(height: 10),
          ],
          TapScale(
            onTap: () => context.push('/invoice/${booking.id}'),
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AbzioTheme.buttonRadius),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded, color: cs.onSurface, size: 18),
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

Future<void> _confirmCancelBooking(
  BuildContext context,
  WidgetRef ref,
  BookingDetail booking,
) async {
  final controller = TextEditingController();
  try {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel booking?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tell us why you want to cancel so we can improve support.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'Reason for cancellation',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep booking'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Cancel booking'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final reason = controller.text.trim();
    if (reason.length < 3) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a short cancellation reason.')),
      );
      return;
    }

    await ref.read(apiClientProvider).post(
      '/bookings/${booking.id}/cancel',
      data: {'reason': reason},
    );
    ref.invalidate(bookingDetailPageProvider(booking.id));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking cancelled.')),
    );
    context.go('/bookings');
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not cancel booking: $error')),
    );
  } finally {
    controller.dispose();
  }
}

// ─── Supporting widgets ───────────────────────────────────────────────────────

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
  DateTime _selectedDateTime = DateTime.now();
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addressesApi = SavedAddressesApi(ref.read(apiClientProvider).dio);
    _selectedDateTime = widget.booking.scheduledAt;
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final addresses = await _addressesApi.listAddresses();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _selectedAddressId = addresses.isNotEmpty ? addresses.first.id : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedDateTime.hour,
        _selectedDateTime.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        _selectedDateTime.year,
        _selectedDateTime.month,
        _selectedDateTime.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an address.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch(
        '/bookings/${widget.booking.id}',
        data: {
          'addressId': _selectedAddressId,
          'scheduledAt': _selectedDateTime.toIso8601String(),
        },
      );
      ref.invalidate(bookingDetailPageProvider(widget.booking.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update booking: $error')),
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
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              Text('Edit booking', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Update the address or reschedule before dispatch starts.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (_error != null)
                Text(_error!, style: tt.bodyMedium?.copyWith(color: cs.error))
              else ...[
                Text('Saved address', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                RadioGroup<String>(
                  groupValue: _selectedAddressId,
                  onChanged: (value) => setState(() => _selectedAddressId = value),
                  child: Column(
                    children: [
                      ..._addresses.map((address) {
                        return RadioListTile<String>(
                          value: address.id,
                          title: Text(address.label, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Text(address.displayAddress),
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(DateFormat('d MMM y').format(_selectedDateTime)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(DateFormat('h:mm a').format(_selectedDateTime)),
                      ),
                    ),
                  ],
                ),
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
        Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
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
        'COMPLETED' => const Color(0xFF10B981),
        'REFUNDED' || 'CANCELLED' || 'CANCELLED_MANUAL' || 'CANCELLED_NO_SHOW' => const Color(0xFFEF4444),
        'ARRIVED' || 'IN_PROGRESS' => const Color(0xFF6366F1),
        'WORKER_ASSIGNED' => const Color(0xFF0F766E),
        'PAYMENT_CAPTURED' => const Color(0xFF14B8A6),
        'DISPATCH_FAILED' => const Color(0xFFF59E0B),
        _ => cs.primary,
      };

  IconData _statusIcon() => switch (status) {
        'COMPLETED' => Icons.task_alt_rounded,
        'REFUNDED' || 'CANCELLED' || 'CANCELLED_MANUAL' || 'CANCELLED_NO_SHOW' => Icons.cancel_rounded,
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
                width: 20, height: 20,
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
                    color: isCompleted ? accent.withValues(alpha: 0.35) : cs.outlineVariant.withValues(alpha: 0.4),
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
                Text(label,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCompleted ? accent : cs.onSurfaceVariant,
                    )),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(time, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
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
  const _TimelineBadge({
    required this.icon,
    required this.label,
  });

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
          Text(label, style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
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
    this.timeline = const [],
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
  final List<BookingTimelineEvent> timeline;

  factory BookingDetail.fromJson(Map<String, dynamic> json) => BookingDetail(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ?? DateTime.now(),
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        serviceName: json['serviceName'] as String? ?? 'Service',
        serviceIcon: json['serviceIcon'] as String?,
        serviceSlug: json['serviceSlug'] as String?,
        addressLabel: json['addressLabel'] as String?,
        worker: json['worker'] != null
            ? BookingWorker.fromJson(json['worker'] as Map<String, dynamic>)
            : null,
        timeline: (json['timeline'] as List<dynamic>? ?? [])
            .map((item) => BookingTimelineEvent.fromJson(item as Map<String, dynamic>))
            .toList(),
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

  factory BookingTimelineEvent.fromJson(Map<String, dynamic> json) => BookingTimelineEvent(
        id: json['id'] as String? ?? '',
        status: json['status'] as String? ?? 'PENDING',
        title: json['title'] as String? ?? 'Update',
        description: json['description'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final bookingDetailPageProvider =
    FutureProvider.family.autoDispose<BookingDetail, String>((ref, bookingId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/users/bookings/$bookingId');
  return BookingDetail.fromJson(data['booking'] as Map<String, dynamic>);
});
